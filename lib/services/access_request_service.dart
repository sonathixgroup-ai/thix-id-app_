import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'dart:async';
import 'package:thix_id/services/supabase_safe_write.dart';

enum AccessRequestStatus { none, pending, approved, rejected }

class AccessRequestState {
  final String? requestId;
  final AccessRequestStatus status;
  /// When approved, access remains valid until this UTC timestamp.
  ///
  /// If null, the backend doesn't support time-bounded access (legacy schema).
  final DateTime? approvedUntil;

  const AccessRequestState({required this.requestId, required this.status, this.approvedUntil});

  bool get isApproved => status == AccessRequestStatus.approved;

  bool isActiveAt(DateTime nowUtc) {
    if (!isApproved) return false;
    final until = approvedUntil;
    if (until == null) return true;
    return until.isAfter(nowUtc);
  }
}

class AccessRequestService {
  final SupabaseClient _client;
  AccessRequestService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  /// Definitive table name in this Supabase project.
  ///
  /// The connected DB uses `public.profile_access_requests`.
  static const String _table = 'profile_access_requests';

  String _activeTable = _table;
  bool _disabled = false;

  bool _isMissingTableError(Object e) => e is PostgrestException && (e.code == 'PGRST205' || e.message.contains('Could not find the table'));

  Future<void> _disableIfMissing(Object e) async {
    if (!_isMissingTableError(e)) return;
    _disabled = true;
    debugPrint('AccessRequestService: table missing ($_activeTable). Disabling access requests. err=$e');
  }

  /// Returns the latest state for (requester -> target).
  Future<AccessRequestState> fetchState({required String requesterId, required String targetUserId}) async {
    if (_disabled) return const AccessRequestState(requestId: null, status: AccessRequestStatus.none);
    try {
      Map<String, dynamic>? row;
      try {
        final q = _client.from(_activeTable).select('id,status,approved_until').eq('requester_id', requesterId);
        // profile_access_requests uses `profile_id` (the profile/user being requested).
        row = await q.eq('profile_id', targetUserId).maybeSingle();
      } catch (e) {
        // Backward compat: column not present.
        debugPrint('AccessRequestService: fetchState select approved_until failed (legacy schema). err=$e');
        final q = _client.from(_activeTable).select('id,status').eq('requester_id', requesterId);
        row = await q.eq('profile_id', targetUserId).maybeSingle();
      }
      if (row == null) return const AccessRequestState(requestId: null, status: AccessRequestStatus.none);
      final id = (row['id'] ?? '').toString();
      final status = _parseStatus((row['status'] ?? '').toString());
      final approvedUntil = _parseDateTimeOrNull(row['approved_until']);
      return AccessRequestState(requestId: id.isEmpty ? null : id, status: status, approvedUntil: approvedUntil);
    } catch (e) {
      await _disableIfMissing(e);
      debugPrint('AccessRequestService: fetchState failed requester=$requesterId target=$targetUserId err=$e');
      rethrow;
    }
  }

  // streamState is implemented below (Realtime + polling fallback).

  /// Incoming requests for a profile owner (the user being requested).
  ///
  /// This powers the “Réception” UI so the owner can approve/reject without
  /// relying on the notifications table schema.
  Stream<List<Map<String, dynamic>>> streamIncomingRequests({required String ownerId, String status = 'pending'}) {
    if (_disabled) return const Stream<List<Map<String, dynamic>>>.empty();

    late final StreamController<List<Map<String, dynamic>>> controller;
    final authedUid = _client.auth.currentUser?.id;
    if (authedUid == null) {
      debugPrint('AccessRequestService: streamIncomingRequests skipped (no auth user).');
      return const Stream<List<Map<String, dynamic>>>.empty();
    }
    if (authedUid != ownerId) {
      // Safety: do not subscribe as a different user.
      debugPrint('AccessRequestService: streamIncomingRequests owner mismatch. param=$ownerId auth=$authedUid');
      ownerId = authedUid;
    }

    RealtimeChannel? channel;
    Timer? pollTimer;
    var polling = false;

    Future<void> emitLatest() async {
      try {
        final rows = await _client
            .from(_activeTable)
            .select('id,requester_id,profile_id,status,created_at,approved_until')
            .eq('profile_id', ownerId)
            .order('created_at', ascending: false)
            .limit(50);
        final list = (rows is List) ? rows.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
        bool matches(String rowStatus) {
          final s = rowStatus.trim().toLowerCase();
          final f = status.trim().toLowerCase();
          if (f.isEmpty) return true;
          if (f == 'pending') return s == 'pending' || s == 'en_attente' || s == 'en attente';
          if (f == 'approved') return s == 'approved' || s == 'approuve' || s == 'approuvé';
          if (f == 'rejected') return s == 'rejected' || s == 'refuse' || s == 'refusé';
          return s == f;
        }

        final filtered = status.trim().isEmpty ? list : list.where((r) => matches((r['status'] ?? '').toString())).toList(growable: false);
        controller.add(filtered);
      } catch (e) {
        await _disableIfMissing(e);
        debugPrint('AccessRequestService: streamIncomingRequests emitLatest failed owner=$ownerId err=$e');
        controller.add(const <Map<String, dynamic>>[]);
      }
    }

    void startPolling() {
      if (polling) return;
      polling = true;
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emitLatest()));
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        unawaited(emitLatest());
      },
    );

    try {
      final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'profile_id', value: ownerId);
      channel = _client.channel('profile_access_requests:inbox:$ownerId');
      channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _activeTable,
            filter: filter,
            callback: (payload) {
              debugPrint('AccessRequestService: inbox realtime event owner=$ownerId event=${payload.eventType}');
              unawaited(emitLatest());
            },
          )
          .subscribe((status, err) {
            debugPrint('AccessRequestService: inbox subscribe status=$status err=$err');
            final msg = (err ?? '').toString().toLowerCase();
            if (status == RealtimeSubscribeStatus.channelError || msg.contains('permission denied') || msg.contains('rls')) {
              startPolling();
            }
          });
    } catch (e) {
      debugPrint('AccessRequestService: inbox realtime wiring failed, fallback to polling err=$e');
      startPolling();
    }

    controller.onCancel = () async {
      pollTimer?.cancel();
      final ch = channel;
      if (ch != null) await _client.removeChannel(ch);
    };

    return controller.stream;
  }

  Stream<int> streamIncomingPendingCount({required String ownerId}) => streamIncomingRequests(ownerId: ownerId, status: 'pending').map((l) => l.length);

  /// Create (or upsert) a request.
  /// Upsert allows re-request after rejection.
  Future<AccessRequestState> requestAccess({
    required String requesterId,
    required String targetUserId,
    String? message,
    String? thixId,
  }) async {
    if (_disabled) return const AccessRequestState(requestId: null, status: AccessRequestStatus.none);
    try {
      // IMPORTANT (RLS): ensure we always write as the authenticated user.
      // Some projects store a separate `users.id` that can diverge from auth.uid().
      // RLS policies almost always rely on `auth.uid()`, so we normalize here.
      var effectiveRequesterId = requesterId;
      final authedUid = _client.auth.currentUser?.id;
      if (authedUid != null && authedUid.trim().isNotEmpty && authedUid != effectiveRequesterId) {
        debugPrint('AccessRequestService: requesterId normalized to auth.uid(). requesterId=$effectiveRequesterId authedUid=$authedUid');
        effectiveRequesterId = authedUid;
      }

      // Prefer RPC when available (best for strict RLS + unified notifications bridge).
      try {
        final res = await _client.rpc('thix_request_profile_access', params: {
          'p_target_user_id': targetUserId,
          'p_message': (message ?? '').trim().isEmpty ? null : message!.trim(),
          'p_thix_id': (thixId ?? '').trim().isEmpty ? null : thixId!.trim(),
        });
        final id = (res ?? '').toString();
        if (id.trim().isNotEmpty) return AccessRequestState(requestId: id.trim(), status: AccessRequestStatus.pending);
      } catch (e) {
        // RPC might not exist in some projects; fall back to table write.
        debugPrint('AccessRequestService: rpc thix_request_profile_access failed, fallback to upsert. err=$e');
      }

      // IMPORTANT: some projects have a UNIQUE constraint on
      // (requester_id, profile_id). A blind INSERT can trigger duplicate-key.
      // We therefore:
      // 1) Try UPDATE existing row to status='en_attente'
      // 2) If no row, INSERT (with onConflict as extra safety)
      final nowIso = DateTime.now().toUtc().toIso8601String();
      const pendingDbValue = 'en_attente';

      try {
        // If a row exists, this avoids duplicate-key errors.
        final updated = await _client
            .from(_activeTable)
            .update({'status': pendingDbValue, 'updated_at': nowIso})
            .eq('requester_id', effectiveRequesterId)
            .eq('profile_id', targetUserId)
            .select('id,status')
            .maybeSingle();
        if (updated != null) {
          return AccessRequestState(requestId: updated['id']?.toString(), status: _parseStatus((updated['status'] ?? '').toString()));
        }
      } catch (e) {
        // If updated_at doesn't exist or other schema drift, fall back to safe insert/upsert.
        debugPrint('AccessRequestService: update existing request failed, fallback to upsert. err=$e');
      }

      final payload = {
        'requester_id': effectiveRequesterId,
        'profile_id': targetUserId,
        'status': pendingDbValue,
        // Keep it minimal: many schemas don't have message/updated_at.
        'created_at': nowIso,
        'updated_at': nowIso,
      };

      // Use safe-write to survive column drift (common when DB updated first).
      // onConflict protects against duplicate-key on (requester_id, profile_id).
      await SupabaseSafeWrite.upsert(
        client: _client,
        table: _activeTable,
        payload: payload,
        onConflict: 'requester_id,profile_id',
      );

      final row = await _client
          .from(_activeTable)
          .select('id,status,approved_until')
          .eq('requester_id', effectiveRequesterId)
          .eq('profile_id', targetUserId)
          .maybeSingle();
      if (row != null) {
        return AccessRequestState(
          requestId: row['id']?.toString(),
          status: _parseStatus((row['status'] ?? '').toString()),
          approvedUntil: _parseDateTimeOrNull(row['approved_until']),
        );
      }
      return await fetchState(requesterId: effectiveRequesterId, targetUserId: targetUserId);
    } catch (e) {
      await _disableIfMissing(e);
      debugPrint('AccessRequestService: requestAccess failed requester=$requesterId target=$targetUserId err=$e');
      rethrow;
    }
  }

  Future<void> setStatus({required String requestId, required String status}) async {
    if (_disabled) return;
    try {
      try {
        await _client.rpc('thix_set_access_request_status', params: {
          'p_request_id': requestId,
          'p_new_status': status,
        });
        return;
      } catch (e) {
        debugPrint('AccessRequestService: rpc thix_set_access_request_status failed, fallback to update. err=$e');
      }

      final payload = <String, dynamic>{'status': status};
      if (status.trim().toLowerCase() == 'approved') {
        payload['approved_until'] = DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String();
      }
      await SupabaseSafeWrite.update(client: _client, table: _activeTable, patch: payload, filters: {'id': requestId});
    } catch (e) {
      await _disableIfMissing(e);
      debugPrint('AccessRequestService: setStatus failed id=$requestId status=$status err=$e');
      rethrow;
    }
  }

  Future<void> approveFor10Minutes({required String requestId}) => setStatus(requestId: requestId, status: 'approved');

  static DateTime? _parseDateTimeOrNull(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toUtc();
  }

  /// Realtime stream (preferred) for one viewer->owner pair.
  /// Subscribes on requester_id and refetches state for target.
  Stream<AccessRequestState> streamState({required String requesterId, required String targetUserId}) {
    if (_disabled) return const Stream<AccessRequestState>.empty();
    // Realtime + RLS: we must filter using the authenticated user's id.
    // If we subscribe for a different requesterId, Supabase can legitimately block events.
    final authedUid = _client.auth.currentUser?.id;
    if (authedUid == null) {
      debugPrint('AccessRequestService: streamState skipped (no auth user).');
      return const Stream<AccessRequestState>.empty();
    }
    if (requesterId != authedUid) {
      debugPrint(
        'AccessRequestService: streamState blocked by safety check. requesterId=$requesterId authedUid=$authedUid target=$targetUserId',
      );
      return _pollingStreamState(requesterId: requesterId, targetUserId: targetUserId);
    }

    final controller = StreamController<AccessRequestState>.broadcast();
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'requester_id', value: requesterId);
    final channel = _client.channel('profile_access_requests:$requesterId:$targetUserId');

    Future<void> emitLatest() async {
      try {
        final state = await fetchState(requesterId: requesterId, targetUserId: targetUserId);
        controller.add(state);
      } catch (e) {
        debugPrint('AccessRequestService: emitLatest failed requester=$requesterId target=$targetUserId err=$e');
        controller.add(const AccessRequestState(requestId: null, status: AccessRequestStatus.none));
      }
    }

    unawaited(emitLatest());
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _activeTable,
          filter: filter,
          callback: (payload) {
            debugPrint(
              'AccessRequestService: realtime event requester=$requesterId target=$targetUserId event=${payload.eventType} old=${payload.oldRecord} new=${payload.newRecord}',
            );
            final newRow = payload.newRecord;
            if (newRow != null) {
              final tgt = (newRow['profile_id'] ?? '').toString();
              if (tgt != targetUserId) return;
            }
            emitLatest();
          },
        )
        .subscribe((status, err) {
          debugPrint('AccessRequestService: subscribe status=$status err=$err');
        });

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }

  Stream<AccessRequestState> _pollingStreamState({required String requesterId, required String targetUserId}) async* {
    while (true) {
      if (_disabled) {
        yield const AccessRequestState(requestId: null, status: AccessRequestStatus.none);
        return;
      }
      try {
        yield await fetchState(requesterId: requesterId, targetUserId: targetUserId);
      } catch (_) {
        yield const AccessRequestState(requestId: null, status: AccessRequestStatus.none);
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}

AccessRequestStatus _parseStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'pending':
    case 'en_attente':
    case 'en attente':
      return AccessRequestStatus.pending;
    case 'approved':
    case 'approuve':
    case 'approuvé':
      return AccessRequestStatus.approved;
    case 'rejected':
    case 'refuse':
    case 'refusé':
      return AccessRequestStatus.rejected;
    default:
      return AccessRequestStatus.none;
  }
}
