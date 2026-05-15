import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/admin_metrics_service.dart';
import 'package:thix_id/services/chat_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// High-level buckets used by the UI to show per-section badges.
///
/// The badge for a section is computed as "items created since the last time the
/// user opened that section".
///
/// This is intentionally lightweight and works even if you don't have a
/// dedicated push-notification infrastructure.
enum ThixSection {
  messages,
  info,
  events,
  formations,
  opportunities,
  jobs,
}

class SectionBadgeCounts {
  final int messages;
  final int info;
  final int events;
  final int formations;
  final int opportunities;
  final int jobs;

  const SectionBadgeCounts({
    required this.messages,
    required this.info,
    required this.events,
    required this.formations,
    required this.opportunities,
    required this.jobs,
  });

  static const zero = SectionBadgeCounts(messages: 0, info: 0, events: 0, formations: 0, opportunities: 0, jobs: 0);

  int forSection(ThixSection s) {
    return switch (s) {
      ThixSection.messages => messages,
      ThixSection.info => info,
      ThixSection.events => events,
      ThixSection.formations => formations,
      ThixSection.opportunities => opportunities,
      ThixSection.jobs => jobs,
    };
  }

  SectionBadgeCounts copyWith({
    int? messages,
    int? info,
    int? events,
    int? formations,
    int? opportunities,
    int? jobs,
  }) {
    return SectionBadgeCounts(
      messages: messages ?? this.messages,
      info: info ?? this.info,
      events: events ?? this.events,
      formations: formations ?? this.formations,
      opportunities: opportunities ?? this.opportunities,
      jobs: jobs ?? this.jobs,
    );
  }
}

class NotificationCountersService {
  NotificationCountersService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  static const String _prefsPrefix = 'thix_seen_section_v1';

  static const String infoTable = 'thix_info_news';
  static const String eventsTable = 'thix_events';
  static const String opportunitiesTable = 'thix_opportunities';
  static const String jobsTable = 'thix_job_offers';

  String _k(String uid, ThixSection section) => '$_prefsPrefix:$uid:${section.name}';

  Future<DateTime> _getLastSeen(String uid, ThixSection section) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_k(uid, section));
      final parsed = raw == null ? null : DateTime.tryParse(raw);
      // Default: only count items from "now" onward (so old content doesn't
      // create a huge badge the first time the user signs in).
      return parsed ?? DateTime.now().toUtc();
    } catch (e) {
      debugPrint('NotificationCountersService: _getLastSeen failed err=$e');
      return DateTime.now().toUtc();
    }
  }

  Future<void> markSectionSeen({required String uid, required ThixSection section}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_k(uid, section), DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      debugPrint('NotificationCountersService: markSectionSeen failed uid=$uid section=${section.name} err=$e');
    }
  }

  Future<int> _countSince({required String table, required DateTime since, String? extraFilterColumn, Object? extraFilterValue}) async {
    try {
      final base = _client.from(table).select('id');
      final withExtra = (extraFilterColumn != null && extraFilterValue != null) ? base.eq(extraFilterColumn, extraFilterValue) : base;
      final res = await withExtra.gt('created_at', since.toIso8601String()).limit(500);
      if (res is List) return res.length;
      return 0;
    } catch (e) {
      debugPrint('NotificationCountersService: countSince failed table=$table err=$e');
      return 0;
    }
  }

  Future<int> _countMessagesSince({required String uid, required DateTime since}) async {
    // We count all messages created since [since] where sender != me.
    // This is a good proxy for "new messages" and works on both canonical and
    // legacy schemas.
    try {
      // Detect schema variant: canonical uses `thix_chat_messages`.
      var legacy = false;
      try {
        await _client.from(ChatService.messagesTable).select('id').limit(1);
        legacy = false;
      } catch (_) {
        legacy = true;
      }

      if (legacy) {
        // Legacy schema stores messages in thix_chat_chats.
        final res = await _client
            .from(ChatService.chatsTable)
            .select('id')
            .neq('sender_id', uid)
            .gt('created_at', since.toIso8601String())
            .limit(500);
        if (res is List) return res.length;
        return 0;
      }

      final res = await _client
          .from(ChatService.messagesTable)
          .select('id')
          .neq('sender_id', uid)
          .gt('created_at', since.toIso8601String())
          .limit(500);
      if (res is List) return res.length;
      return 0;
    } catch (e) {
      debugPrint('NotificationCountersService: _countMessagesSince failed err=$e');
      return 0;
    }
  }

  /// Stream badge counts for the main app sections.
  ///
  /// Implementation notes:
  /// - Uses Realtime (postgres_changes) to re-fetch counts.
  /// - Falls back to polling if Realtime cannot subscribe.
  Stream<SectionBadgeCounts> streamCounts(String uid) {
    late final StreamController<SectionBadgeCounts> controller;
    RealtimeChannel? channel;
    Timer? pollTimer;
    var polling = false;
    var cancelled = false;

    Future<SectionBadgeCounts> compute() async {
      final sinceMsg = await _getLastSeen(uid, ThixSection.messages);
      final sinceInfo = await _getLastSeen(uid, ThixSection.info);
      final sinceEvents = await _getLastSeen(uid, ThixSection.events);
      final sinceFormations = await _getLastSeen(uid, ThixSection.formations);
      final sinceOpp = await _getLastSeen(uid, ThixSection.opportunities);
      final sinceJobs = await _getLastSeen(uid, ThixSection.jobs);

      final results = await Future.wait<int>([
        _countMessagesSince(uid: uid, since: sinceMsg),
        _countSince(table: infoTable, since: sinceInfo),
        _countSince(table: eventsTable, since: sinceEvents),
        // Formations: for now we treat them as a subset of official events.
        // If later you add a dedicated `thix_formations` table, we can switch.
        _countSince(table: eventsTable, since: sinceFormations),
        _countSince(table: opportunitiesTable, since: sinceOpp),
        _countSince(table: jobsTable, since: sinceJobs),
      ]);

      return SectionBadgeCounts(
        messages: results[0],
        info: results[1],
        events: results[2],
        formations: results[3],
        opportunities: results[4],
        jobs: results[5],
      );
    }

    Future<void> emit() async {
      final value = await compute();
      if (!controller.isClosed) controller.add(value);
    }

    void startPolling() {
      if (polling) return;
      polling = true;
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => unawaited(emit()));
    }

    controller = StreamController<SectionBadgeCounts>.broadcast(
      onListen: () => unawaited(emit()),
      onCancel: () async {
        cancelled = true;
        pollTimer?.cancel();
        final ch = channel;
        if (ch != null) await _client.removeChannel(ch);
      },
    );

    Future<void> subscribeRealtime() async {
      if (cancelled) return;
      try {
        channel = _client.channel('thix:badge_counts:$uid');
        channel!
          ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: infoTable, callback: (_) => emit())
          ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: eventsTable, callback: (_) => emit())
          ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: opportunitiesTable, callback: (_) => emit())
          ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: jobsTable, callback: (_) => emit())
          ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: ChatService.messagesTable, callback: (_) => emit())
          ..subscribe((status, err) {
            debugPrint('NotificationCountersService: realtime status=$status err=$err');
            final msg = (err ?? '').toString().toLowerCase();
            final permanent = msg.contains('permission denied') || msg.contains('rls') || msg.contains('does not exist') || msg.contains('schema cache');
            if (permanent || status == RealtimeSubscribeStatus.channelError) startPolling();
          });
      } catch (e) {
        debugPrint('NotificationCountersService: realtime wiring failed err=$e');
        startPolling();
      }
    }

    unawaited(subscribeRealtime());
    return controller.stream.distinct((a, b) => a.messages == b.messages && a.info == b.info && a.events == b.events && a.formations == b.formations && a.opportunities == b.opportunities && a.jobs == b.jobs);
  }
}
