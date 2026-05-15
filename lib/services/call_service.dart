import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class ThixCall {
  final String id;
  final String? chatId;
  final String kind; // audio|video
  final String status; // ongoing|completed|missed|declined
  final String callerId;
  final String receiverId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const ThixCall({
    required this.id,
    required this.chatId,
    required this.kind,
    required this.status,
    required this.callerId,
    required this.receiverId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  static ThixCall fromRow(Map<String, dynamic> row) {
    DateTime parseDt(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    DateTime? parseDtOrNull(Object? v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ThixCall(
      id: (row['id'] as String?) ?? '',
      chatId: (row['chat_id'] as String?),
      kind: (row['kind'] as String?) ?? 'audio',
      status: (row['status'] as String?) ?? 'ongoing',
      callerId: (row['caller_id'] as String?) ?? '',
      receiverId: (row['receiver_id'] as String?) ?? '',
      startedAt: parseDt(row['started_at']),
      endedAt: parseDtOrNull(row['ended_at']),
      durationSeconds: (row['duration_seconds'] as int?) ?? 0,
    );
  }
}

class CallService {
  static const String table = 'call_history';
  static const String signalsTable = 'thix_call_signals';

  /// Supabase Edge Function that returns an Agora token.
  /// You will create it in Supabase as: `agora-token`.
  static const String agoraTokenFunction = 'agora-token';

  final SupabaseClient _client;
  CallService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  /// Agora requires an integer UID. We derive a stable positive int from the auth UID.
  /// Not cryptographically strong, but good enough for mapping (token is the real auth).
  int agoraUidFor(String userId) {
    // FNV-1a 32-bit
    var hash = 0x811c9dc5;
    for (final codeUnit in userId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    // Agora UID must be > 0
    final uid = hash & 0x7fffffff;
    return uid == 0 ? 1 : uid;
  }

  /// Fetch an Agora RTC token from Supabase Edge Function.
  ///
  /// The Edge Function validates that the caller is authenticated and returns:
  /// `{ "appId": "...", "token": "...", "channel": "...", "uid": 123 }`
  Future<Map<String, dynamic>> fetchAgoraToken({required String channel, required int uid, required String role}) async {
    try {
      final res = await _client.functions.invoke(
        agoraTokenFunction,
        body: {'channel': channel, 'uid': uid, 'role': role},
      );
      final data = res.data;
      if (data is Map) return data.cast<String, dynamic>();
      throw Exception('Unexpected token response');
    } catch (e) {
      debugPrint('CallService: fetchAgoraToken failed channel=$channel uid=$uid err=$e');
      rethrow;
    }
  }

  bool _isUuidLike(String v) => RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(v.trim());

  Future<String> startCall({required String chatId, required String kind, required String receiverId}) async {
    final caller = _client.auth.currentUser;
    if (caller == null) throw Exception('Not authenticated');
    final safeKind = (kind == 'video') ? 'video' : 'audio';

    // chat_id is uuid in DB; some UI flows may pass virtual ids.
    final safeChatId = _isUuidLike(chatId) ? chatId : null;

    final inserted = await _client
        .from(table)
        .insert({
          'chat_id': safeChatId,
          'kind': safeKind,
          'status': 'ongoing',
          'caller_id': caller.id,
          'receiver_id': receiverId,
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    return (inserted['id'] as String?) ?? '';
  }

  /// Sends a WebRTC signaling message via Postgres (Realtime).
  Future<void> sendSignal({
    required String callId,
    required String toUserId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw Exception('Not authenticated');
    final safeType = switch (type) {
      'offer' || 'answer' || 'candidate' || 'hangup' || 'decline' => type,
      _ => 'candidate',
    };
    try {
      await _client.from(signalsTable).insert({
        'call_id': callId,
        'from_user_id': me.id,
        'to_user_id': toUserId,
        'type': safeType,
        'payload': payload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('CallService: sendSignal failed call=$callId type=$safeType err=$e');
      rethrow;
    }
  }

  /// Stream signals for this user for a given call.
  Stream<List<Map<String, dynamic>>> streamSignals({required String callId, required String forUserId}) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final channel = _client.channel('thix_call_signals:$callId:$forUserId');
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'call_id', value: callId);

    Future<void> emitLatest() async {
      try {
        final rows = await _client
            .from(signalsTable)
            .select('*')
            .eq('call_id', callId)
            .eq('to_user_id', forUserId)
            .order('created_at', ascending: false)
            .limit(50);
        final list = (rows is List) ? rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false) : const <Map<String, dynamic>>[];
        controller.add(list);
      } catch (e) {
        debugPrint('CallService: streamSignals emitLatest failed call=$callId for=$forUserId err=$e');
        controller.add(const <Map<String, dynamic>>[]);
      }
    }

    controller.onListen = () {
      unawaited(emitLatest());
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: signalsTable,
            filter: filter,
            callback: (_) => emitLatest(),
          )
          .subscribe((status, err) {
        if (err != null) debugPrint('CallService: signals realtime subscribe error status=$status err=$err');
      });
    };

    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };

    return controller.stream;
  }

  Future<void> completeCall({required String callId, required DateTime startedAt, required DateTime endedAt}) async {
    final seconds = endedAt.difference(startedAt).inSeconds.clamp(0, 24 * 60 * 60);
    try {
      await _client.from(table).update({
        'status': 'completed',
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_seconds': seconds,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', callId);
    } catch (e) {
      debugPrint('CallService: completeCall failed id=$callId err=$e');
      rethrow;
    }
  }

  Future<void> setCallStatus({required String callId, required String status}) async {
    final safe = switch (status) {
      'ongoing' || 'completed' || 'missed' || 'declined' => status,
      _ => 'declined',
    };
    try {
      await _client.from(table).update({'status': safe, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', callId);
    } catch (e) {
      debugPrint('CallService: setCallStatus failed id=$callId status=$safe err=$e');
      rethrow;
    }
  }

  Stream<List<ThixCall>> streamIncomingOngoingCalls({required String receiverId}) {
    final controller = StreamController<List<ThixCall>>.broadcast();
    final channel = _client.channel('call_history:incoming:$receiverId');
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: receiverId);

    Future<void> emitLatest() async {
      try {
        final rows = await _client
            .from(table)
            .select('*')
            .eq('receiver_id', receiverId)
            .eq('status', 'ongoing')
            .order('started_at', ascending: false)
            .limit(5);
        final list = (rows is List)
            ? rows.map((r) => ThixCall.fromRow((r as Map).cast<String, dynamic>())).toList(growable: false)
            : const <ThixCall>[];
        controller.add(list);
      } catch (e) {
        debugPrint('CallService: emitLatest incoming failed receiver=$receiverId err=$e');
        controller.add(const <ThixCall>[]);
      }
    }

    unawaited(emitLatest());
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: filter,
          callback: (_) => emitLatest(),
        )
        .subscribe((status, err) {
          if (err != null) debugPrint('CallService: realtime subscribe error=$err');
        });

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };

    return controller.stream;
  }
}
