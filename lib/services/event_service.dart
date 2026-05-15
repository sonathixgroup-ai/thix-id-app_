import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/event_item.dart';
import 'package:thix_id/models/event_registration.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class EventService {
  static const _kEvents = 'thix_events_v1';
  static const _kRegistrations = 'thix_event_registrations_v1';
  static const _kSaved = 'thix_event_saves_v1';

  static const String eventsTable = 'thix_events';
  static const String eventsStatusView = 'thix_events_status';
  static const String registrationsTable = 'thix_event_registrations';
  static const String savesTable = 'thix_event_saves';

  final SupabaseClient _client;

  EventService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  bool get _hasSession => _client.auth.currentSession != null;

  Future<List<EventItem>> listEvents() async {
    // User-facing list: Prefer Supabase (published events), fallback to local seed.
    final remote = await _tryListPublishedEventsRemote();
    if (remote != null && remote.isNotEmpty) return remote;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kEvents);
      if (raw == null || raw.trim().isEmpty) {
        final seeded = _seedEvents();
        await prefs.setString(_kEvents, EventItem.encodeList(seeded));
        return seeded;
      }
      final items = EventItem.decodeList(raw);
      if (items.isEmpty) {
        final seeded = _seedEvents();
        await prefs.setString(_kEvents, EventItem.encodeList(seeded));
        return seeded;
      }
      return items;
    } catch (e) {
      debugPrint('EventService.listEvents failed err=$e');
      return _seedEvents();
    }
  }

  Future<EventItem?> fetchEvent(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return null;

    // Prefer Supabase.
    final remote = await _tryFetchEventRemote(id);
    if (remote != null) return remote;

    final all = await listEvents();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<List<EventItem>?> _tryListPublishedEventsRemote() async {
    try {
      final res = await _client
          .from(eventsStatusView)
          .select('*')
          .eq('status', 'published')
          .order('is_featured', ascending: false)
          .order('starts_at', ascending: true)
          .limit(300);
      if (res is! List) return const <EventItem>[];
      final rows = res.cast<Map<String, dynamic>>();
      return rows.map(EventItem.fromJson).toList(growable: false);
    } catch (e) {
      if (e is PostgrestException) {
        // Missing view/table: keep local mode.
        if (e.code == 'PGRST205' || e.code == '42P01') return null;
      }
      debugPrint('EventService._tryListPublishedEventsRemote failed err=$e');
      return null;
    }
  }

  Future<EventItem?> _tryFetchEventRemote(String id) async {
    try {
      final row = await _client.from(eventsStatusView).select('*').eq('id', id).maybeSingle();
      if (row == null) return null;
      // If unpublished, we still allow reading when admin uses the normal UI
      // route; DB RLS is the authority.
      return EventItem.fromJson(row);
    } catch (e) {
      if (e is PostgrestException) {
        if (e.code == 'PGRST205' || e.code == '42P01') return null;
      }
      debugPrint('EventService._tryFetchEventRemote failed err=$e');
      return null;
    }
  }

  Future<List<EventItem>> listFeaturedEvents({int limit = 8}) async {
    final remote = await _tryListFeaturedEventsRemote(limit: limit);
    if (remote != null) return remote;
    final all = await listEvents();
    return all.take(limit).toList(growable: false);
  }

  Future<List<EventItem>?> _tryListFeaturedEventsRemote({required int limit}) async {
    try {
      final res = await _client
          .from(eventsStatusView)
          .select('*')
          .eq('status', 'published')
          .eq('is_featured', true)
          .order('starts_at', ascending: true)
          .limit(limit);
      if (res is! List) return const <EventItem>[];
      return res.cast<Map<String, dynamic>>().map(EventItem.fromJson).toList(growable: false);
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.code == '42P01')) return null;
      debugPrint('EventService._tryListFeaturedEventsRemote failed err=$e');
      return null;
    }
  }

  Future<EventRegistration> register({
    required String eventId,
    required String attendeeThixId,
    required int tickets,
    String? note,
  }) async {
    final remote = await _tryRegisterRemote(eventId: eventId, attendeeThixId: attendeeThixId, tickets: tickets, note: note);
    if (remote != null) {
      // Also cache locally for offline ticket display.
      await _cacheRegistration(remote);
      return remote;
    }

    final now = DateTime.now();
    final reg = EventRegistration(
      id: _id('reg'),
      eventId: eventId,
      userId: null,
      attendeeThixId: attendeeThixId.trim().toUpperCase(),
      tickets: tickets <= 0 ? 1 : tickets,
      ticketCode: _ticketCode(eventId: eventId, attendeeThixId: attendeeThixId),
      status: 'registered',
      checkedInAt: null,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _cacheRegistration(reg);
    return reg;
  }

  Future<EventRegistration?> _tryRegisterRemote({
    required String eventId,
    required String attendeeThixId,
    required int tickets,
    required String? note,
  }) async {
    if (!_hasSession) return null;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final now = DateTime.now().toUtc();
      final regId = _id('reg');
      final payload = {
        'id': regId,
        'event_id': eventId,
        'user_id': uid,
        'attendee_thix_id': attendeeThixId.trim().toUpperCase(),
        'tickets': tickets <= 0 ? 1 : tickets,
        'ticket_code': _ticketCode(eventId: eventId, attendeeThixId: attendeeThixId),
        'status': 'registered',
        'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final row = await _client.from(registrationsTable).insert(payload).select('*').maybeSingle();
      if (row == null) {
        // Best-effort: reconstruct.
        return EventRegistration.fromJson(payload);
      }
      return EventRegistration.fromJson(row);
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.code == '42P01')) return null;
      debugPrint('EventService._tryRegisterRemote failed err=$e');
      return null;
    }
  }

  Future<void> _cacheRegistration(EventRegistration reg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRegistrations);
      final list = (raw == null || raw.trim().isEmpty) ? <EventRegistration>[] : EventRegistration.decodeList(raw).toList(growable: true);
      // De-dupe by id.
      list.removeWhere((e) => e.id == reg.id);
      list.insert(0, reg);
      await prefs.setString(_kRegistrations, EventRegistration.encodeList(list));
    } catch (e) {
      debugPrint('EventService._cacheRegistration failed err=$e');
    }
  }

  Future<EventRegistration?> fetchRegistrationById(String registrationId) async {
    final id = registrationId.trim();
    if (id.isEmpty) return null;

    final remote = await _tryFetchRegistrationRemote(id);
    if (remote != null) {
      await _cacheRegistration(remote);
      return remote;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRegistrations);
      if (raw == null || raw.trim().isEmpty) return null;
      final list = EventRegistration.decodeList(raw);
      for (final r in list) {
        if (r.id == id) return r;
      }
      return null;
    } catch (e) {
      debugPrint('EventService.fetchRegistrationById failed err=$e');
      return null;
    }
  }

  Future<EventRegistration?> _tryFetchRegistrationRemote(String id) async {
    if (!_hasSession) return null;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final row = await _client.from(registrationsTable).select('*').eq('id', id).maybeSingle();
      if (row == null) return null;
      // RLS should enforce owner-only; we keep an extra guard.
      final rowUid = (row['user_id'] ?? '').toString();
      if (rowUid.isNotEmpty && rowUid != uid) return null;
      return EventRegistration.fromJson(row);
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.code == '42P01')) return null;
      debugPrint('EventService._tryFetchRegistrationRemote failed err=$e');
      return null;
    }
  }

  Future<List<EventRegistration>> listMyRegistrations() async {
    final remote = await _tryListMyRegistrationsRemote();
    if (remote != null) {
      // Cache a subset for offline.
      for (final r in remote.take(25)) {
        await _cacheRegistration(r);
      }
      return remote;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRegistrations);
      if (raw == null || raw.trim().isEmpty) return const <EventRegistration>[];
      return EventRegistration.decodeList(raw);
    } catch (e) {
      debugPrint('EventService.listMyRegistrations failed err=$e');
      return const <EventRegistration>[];
    }
  }

  Future<List<EventRegistration>?> _tryListMyRegistrationsRemote() async {
    if (!_hasSession) return null;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final res = await _client.from(registrationsTable).select('*').eq('user_id', uid).order('created_at', ascending: false).limit(200);
      if (res is! List) return const <EventRegistration>[];
      return res.cast<Map<String, dynamic>>().map(EventRegistration.fromJson).toList(growable: false);
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.code == '42P01')) return null;
      debugPrint('EventService._tryListMyRegistrationsRemote failed err=$e');
      return null;
    }
  }

  Future<Set<String>> listSavedEventIds() async {
    final remote = await _tryListSavedEventIdsRemote();
    if (remote != null) {
      await _cacheSaved(remote);
      return remote;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSaved);
      if (raw == null || raw.trim().isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toSet();
    } catch (e) {
      debugPrint('EventService.listSavedEventIds failed err=$e');
      return <String>{};
    }
  }

  Future<void> toggleSaveEvent({required String eventId, required bool saved}) async {
    final id = eventId.trim();
    if (id.isEmpty) return;
    final remoteOk = await _tryToggleSaveRemote(eventId: id, saved: saved);
    // Always keep local cache for UI snappiness.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSaved);
      final list = (raw == null || raw.trim().isEmpty) ? <String>[] : (jsonDecode(raw) as List).map((e) => e.toString()).toList(growable: true);
      list.removeWhere((e) => e == id);
      if (saved) list.insert(0, id);
      await prefs.setString(_kSaved, jsonEncode(list));
    } catch (e) {
      debugPrint('EventService.toggleSaveEvent local cache failed err=$e');
    }
    if (!remoteOk) return;
  }

  Future<Set<String>?> _tryListSavedEventIdsRemote() async {
    if (!_hasSession) return null;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final res = await _client.from(savesTable).select('event_id').eq('user_id', uid).order('created_at', ascending: false).limit(500);
      if (res is! List) return <String>{};
      return res.map((e) => (e['event_id'] ?? '').toString()).where((e) => e.trim().isNotEmpty).toSet();
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.code == '42P01')) return null;
      debugPrint('EventService._tryListSavedEventIdsRemote failed err=$e');
      return null;
    }
  }

  Future<bool> _tryToggleSaveRemote({required String eventId, required bool saved}) async {
    if (!_hasSession) return false;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return false;
      if (saved) {
        await _client.from(savesTable).upsert({'user_id': uid, 'event_id': eventId});
      } else {
        await _client.from(savesTable).delete().eq('user_id', uid).eq('event_id', eventId);
      }
      return true;
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.code == '42P01')) return false;
      debugPrint('EventService._tryToggleSaveRemote failed err=$e');
      return false;
    }
  }

  Future<void> _cacheSaved(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSaved, jsonEncode(ids.toList(growable: false)));
    } catch (e) {
      debugPrint('EventService._cacheSaved failed err=$e');
    }
  }

  String _ticketCode({required String eventId, required String attendeeThixId}) {
    // Lisible, scannable et unique (best-effort) sans dépendance externe.
    // Exemple: THIXT-EVT-9F3A2C7B4D
    final rnd = Random.secure();
    final token = List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join().toUpperCase();
    final evt = eventId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final evtShort = evt.length <= 6 ? evt : evt.substring(0, 6);
    return 'THIXT-$evtShort-$token';
  }

  String _id(String prefix) {
    final rnd = Random.secure();
    final n = List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${prefix}_$n';
  }

  List<EventItem> _seedEvents() {
    final now = DateTime.now();
    DateTime d(int days, int hour) => DateTime(now.year, now.month, now.day).add(Duration(days: days, hours: hour));
    return [
      EventItem(
        id: 'evt_ai_masterclass',
        title: 'Masterclass Intelligence Artificielle',
        dateLabel: '15 Oct 2024 • 10:00',
        startsAt: d(2, 10),
        endsAt: d(2, 13),
        location: 'Silikin Village, Kinshasa',
        category: 'Formation',
        priceLabel: 'Gratuit',
        isFree: true,
        price: null,
        currency: 'USD',
        eventType: 'physical',
        meetingLink: null,
        quickHook: 'LLMs • Gouvernance • Sécurité',
        attendeesLabel: '120 inscrits',
        description:
            'Session intensive (niveau pro) : LLMs, gouvernance, sécurité des données et mise en production. Accès prioritaire aux profils THIX vérifiés.',
        highlights: const ['Ateliers pratiques', 'Accès replay', 'Certificat de participation'],
        imageAssetPath: 'assets/images/African_businessman_in_suit_grayscale_1775573970767.jpg',
        coverImageBucket: null,
        coverImagePath: null,
        isFeatured: true,
        status: 'published',
        speakers: const [
          {'name': 'THIX Lab', 'title': 'AI Security Team'},
        ],
        sponsors: const [
          {'name': 'THIX ID'},
        ],
        agenda: const [
          {'time': '10:00', 'title': 'Opening'},
          {'time': '11:00', 'title': 'Hands-on workshop'},
        ],
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      EventItem(
        id: 'evt_entrepreneurs_gala',
        title: 'Gala des Entrepreneurs THIX',
        dateLabel: '20 Oct 2024 • 19:00',
        startsAt: d(7, 19),
        endsAt: d(7, 23),
        location: 'Pullman Grand Hotel',
        category: 'Networking',
        priceLabel: '50 USD',
        isFree: false,
        price: 50,
        currency: 'USD',
        eventType: 'physical',
        meetingLink: null,
        quickHook: 'Matching pro • Badges vérifiés',
        attendeesLabel: '45 places restantes',
        description:
            'Soirée premium: networking sécurisé, matching pro, tables thématiques. Contrôle d’accès THIX ID à l’entrée (anti-fraude + liste blanche).',
        highlights: const ['Networking premium', 'Invités institutionnels', 'Badges THIX'],
        imageAssetPath: 'assets/images/Senior_professional_man_grayscale_1775573975687.jpg',
        coverImageBucket: null,
        coverImagePath: null,
        isFeatured: true,
        status: 'published',
        speakers: const [],
        sponsors: const [
          {'name': 'SONATHIX GROUP'},
        ],
        agenda: const [
          {'time': '19:00', 'title': 'Accueil'},
          {'time': '20:00', 'title': 'Networking'},
        ],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
      EventItem(
        id: 'evt_design_thinking',
        title: 'Atelier Design Thinking',
        dateLabel: '22 Oct 2024 • 09:00',
        startsAt: d(9, 9),
        endsAt: d(9, 12),
        location: 'En ligne (Zoom)',
        category: 'Atelier',
        priceLabel: '10 USD',
        isFree: false,
        price: 10,
        currency: 'USD',
        eventType: 'online',
        meetingLink: 'https://example.com/zoom',
        quickHook: 'Idéation → Prototype → Pitch',
        attendeesLabel: '300 inscrits',
        description:
            'Atelier structuré: idéation, prototypage, validation, pitch. Un THIX ID valide est requis pour recevoir le lien sécurisé.',
        highlights: const ['Templates fournis', 'Exercices en groupe', 'Accès ressources'],
        imageAssetPath: 'assets/images/tech_conference_stage_audience_grayscale_1778649599691.jpg',
        coverImageBucket: null,
        coverImagePath: null,
        isFeatured: false,
        status: 'published',
        speakers: const [],
        sponsors: const [],
        agenda: const [],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 4)),
      ),
      EventItem(
        id: 'evt_mines_energy_forum',
        title: 'Forum Mines & Énergie',
        dateLabel: '05 Nov 2024 • 08:30',
        startsAt: d(23, 8),
        endsAt: d(23, 18),
        location: "L'Hôtel Fleuve Congo",
        category: 'Conférence',
        priceLabel: '100 USD',
        isFree: false,
        price: 100,
        currency: 'USD',
        eventType: 'physical',
        meetingLink: null,
        quickHook: 'Cybersécurité industrielle • ESG',
        attendeesLabel: 'Sold Out',
        description:
            'Forum stratégique: supply chain, cybersécurité industrielle, conformité, ESG. Accréditations THIX requises pour les zones restreintes.',
        highlights: const ['Conférences', 'Panels', 'Accréditations'],
        imageAssetPath: 'assets/images/Office_team_grayscale_1775574009745.jpg',
        coverImageBucket: null,
        coverImagePath: null,
        isFeatured: false,
        status: 'published',
        speakers: const [],
        sponsors: const [],
        agenda: const [],
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
