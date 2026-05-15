import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart' if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class ChatSummary {
  final String id;
  final String type; // direct | group | etc.
  final String? directKey;
  final List<String> participants;
  final Map<String, String> participantName;
  final Map<String, String> participantThix;
  final String lastMessage;
  final DateTime? lastMessageAt;

  const ChatSummary({
    required this.id,
    required this.type,
    required this.directKey,
    required this.participants,
    required this.participantName,
    required this.participantThix,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  static List<String> _parseParticipants(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is List) return raw.whereType<String>().toList(growable: false);
    // Sometimes PostgREST returns JSONB as Map or as a JSON string depending on settings.
    if (raw is Map) {
      final v = raw['uids'] ?? raw['participants'] ?? raw['users'];
      if (v is List) return v.whereType<String>().toList(growable: false);
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        return _parseParticipants(decoded);
      } catch (_) {
        return const <String>[];
      }
    }
    return const <String>[];
  }

  static ChatSummary fromRow(Map<String, dynamic> row) {
    final id = (row['id'] as String?) ?? '';
    final participants = _parseParticipants(row['participants']);
    final pn = (row['participant_name'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pt = (row['participant_thix'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dk = (row['direct_key'] as String?)?.trim();
    return ChatSummary(
      id: id,
      type: (row['type'] as String?) ?? 'direct',
      directKey: (dk == null || dk.isEmpty) ? null : dk,
      participants: participants,
      participantName: pn.map((k, v) => MapEntry(k, (v as String?) ?? 'Utilisateur')),
      participantThix: pt.map((k, v) => MapEntry(k, (v as String?) ?? '')),
      lastMessage: (row['last_message'] as String?) ?? '',
      lastMessageAt: _tryParseDate(row['last_message_at']),
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String type;
  final String senderId;
  final String senderName;
  final String senderThixId;
  final String? senderAvatarUrl;
  final bool senderCertified;
  final String text;
  final DateTime? createdAt;
  final Map<String, dynamic> extra;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.senderThixId,
    required this.senderAvatarUrl,
    required this.senderCertified,
    required this.text,
    required this.createdAt,
    required this.extra,
  });

  static ChatMessage fromRow(Map<String, dynamic> row) {
    final id = (row['id'] as String?) ?? '';
    final chatId = (row['chat_id'] as String?) ?? '';
    final type = (row['type'] as String?) ?? 'text';
    final senderId = (row['sender_id'] as String?) ?? '';
    final senderName = (row['sender_name'] as String?) ?? '';
    final senderThixId = (row['sender_thix_id'] as String?) ?? '';
    final senderAvatarUrl = (row['sender_profile_avatar_url'] as String?) ?? (row['avatar_url'] as String?);
    final profileName = (row['sender_profile_display_name'] as String?)?.trim();
    final effectiveName = profileName != null && profileName.isNotEmpty ? profileName : senderName;
    final nationalId = (row['sender_profile_national_id_number'] as String?) ?? (row['national_id_number'] as String?);
    final senderCertified = (nationalId ?? '').trim().isNotEmpty;
    final text = (row['text'] as String?) ?? '';
    final createdAt = _tryParseDate(row['created_at']);

    final extra = Map<String, dynamic>.from(row);
    extra.removeWhere((k, _) => const {
      'id',
      'chat_id',
      'type',
      'sender_id',
      'sender_name',
      'sender_thix_id',
      'sender_profile_display_name',
      'sender_profile_avatar_url',
      'sender_profile_national_id_number',
      'text',
      'created_at'
    }.contains(k));
    return ChatMessage(
      id: id,
      chatId: chatId,
      type: type,
      senderId: senderId,
      senderName: effectiveName,
      senderThixId: senderThixId,
      senderAvatarUrl: senderAvatarUrl,
      senderCertified: senderCertified,
      text: text,
      createdAt: createdAt,
      extra: extra,
    );
  }
}

class ChatProfileBasics {
  final String uid;
  final String displayName;
  final String? avatarUrl;
  final bool certified;

  const ChatProfileBasics({required this.uid, required this.displayName, required this.avatarUrl, required this.certified});
}

class ChatContact {
  final String uid;
  final String displayName;
  final String thixId;

  const ChatContact({required this.uid, required this.displayName, required this.thixId});
}

DateTime? _tryParseDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class ChatService {
  /// Marker used to embed rich payloads inside the plain-text message.
  ///
  /// This is intentionally text-based to stay compatible with Supabase schema
  /// drift across projects (some deployments don't have `type`/`extra` columns).
  static const String moneyTransferMarker = '[[THIX_MONEY_TRANSFER_V1]]';

  final SupabaseClient _client;
  ChatService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  // Canonical tables (provided by supabase/migrations in this repo).
  static const String chatsTable = 'thix_chat_chats';
  static const String messagesTable = 'thix_chat_messages';
  static const String readsTable = 'thix_chat_reads';
  static const String typingTable = 'thix_chat_typing';
  static const String attachmentsBucket = 'thix-chat';
  static const String profilesTable = 'profiles';

  final Map<String, ChatProfileBasics> _profileCache = <String, ChatProfileBasics>{};

  // Some Supabase projects connected to this repo were created earlier with a
  // simplified chat schema where `thix_chat_chats` stores *messages* directly
  // (columns: sender_id, receiver_id, message_content, direct_key, is_read ...)
  // and the canonical tables `thix_chat_messages`, `thix_chat_reads` don't
  // exist. We detect and adapt at runtime.
  bool? _legacySchema;

  Future<bool> _isLegacySchema() async {
    final cached = _legacySchema;
    if (cached != null) return cached;
    try {
      // If this succeeds, canonical schema is present.
      await _client.from(messagesTable).select('id').limit(1);
      _legacySchema = false;
      return false;
    } catch (e) {
      debugPrint('ChatService: canonical messages table missing; using legacy chat schema. err=$e');
      _legacySchema = true;
      return true;
    }
  }

  /// Legacy helper still used by UI in a few places.
  ///
  /// Returns a *virtual* id `direct:<sorted_uidA_uidB>`. Most APIs accept either
  /// a real chat UUID or this virtual id.
  String directChatIdForUids(String a, String b) => 'direct:${_directKey(a, b)}';

  ({String a, String b})? _parseDirectChatVirtualId(String chatId) {
    final raw = chatId.trim();
    if (!raw.startsWith('direct:')) return null;
    final key = raw.substring('direct:'.length);
    final parts = key.split('_');
    if (parts.length != 2) return null;
    final a = parts[0].trim();
    final b = parts[1].trim();
    if (a.isEmpty || b.isEmpty) return null;
    return (a: a, b: b);
  }

  Future<String> _resolveChatUuid(String chatId, {AppUser? me}) async {
    final raw = chatId.trim();
    // Already a uuid.
    if (isUuidLike(raw)) return raw;

    final parsed = _parseDirectChatVirtualId(raw);
    if (parsed == null) throw Exception('ChatId invalide.');
    final a = parsed.a;
    final b = parsed.b;
    final key = _directKey(a, b);
    return _getOrCreateChatByDirectKey(key: key, a: a, b: b, me: me);
  }

  Stream<T> _poll<T>(Future<T> Function() fetch, {Duration interval = const Duration(seconds: 2)}) async* {
    while (true) {
      try {
        yield await fetch();
      } catch (e) {
        debugPrint('ChatService: poll error=$e');
        // Keep the stream alive. Temporary network/RLS errors shouldn't
        // permanently break the UI.
      }
      await Future<void>.delayed(interval);
    }
  }

  Stream<List<T>> _realtimeListStream<T>({
    required String channelName,
    required Future<List<T>> Function() fetch,
    required void Function(RealtimeChannel channel, VoidCallback onAnyChange) bind,
    Duration debounce = const Duration(milliseconds: 250),
  }) {
    final controller = StreamController<List<T>>.broadcast();
    Timer? t;
    bool closed = false;

    void scheduleEmit() {
      if (closed) return;
      t?.cancel();
      t = Timer(debounce, () async {
        if (closed || controller.isClosed) return;
        try {
          controller.add(await fetch());
        } catch (e) {
          debugPrint('ChatService: realtime fetch failed channel=$channelName err=$e');
          // Keep stream alive.
        }
      });
    }

    final channel = _client.channel(channelName);
    controller.onListen = () {
      scheduleEmit();
      bind(channel, scheduleEmit);
      channel.subscribe((status, err) {
        if (err != null) debugPrint('ChatService: realtime subscribe error channel=$channelName status=$status err=$err');
      });
    };

    controller.onCancel = () async {
      closed = true;
      t?.cancel();
      try {
        await _client.removeChannel(channel);
      } catch (e) {
        debugPrint('ChatService: removeChannel failed channel=$channelName err=$e');
      }
      await controller.close();
    };

    return controller.stream;
  }

  Stream<List<ChatSummary>> streamChatsForUser(String uid) {
    Future<List<ChatSummary>> fetch() async {
      try {
        final legacy = await _isLegacySchema();
        if (legacy) {
          final rows = await _selectLegacyChatMessagesForUser(uid);
          return await _summariesFromLegacyMessageRows(uid, rows);
        }
        final chats = await _selectChatsForUser(uid);
        if (chats.isEmpty) return const <ChatSummary>[];
        final otherUids = <String>{};
        for (final c in chats) {
          final parts = ChatSummary._parseParticipants(c['participants']);
          for (final p in parts) {
            if (p != uid) otherUids.add(p);
          }
        }
        final profiles = await _fetchProfileBasics(otherUids.toList(growable: false));

        return chats.map((c) {
          final id = (c['id'] as String?) ?? '';
          final parts = ChatSummary._parseParticipants(c['participants']);
          final pnRaw = (c['participant_name'] as Map?)?.cast<String, dynamic>() ?? const {};
          final ptRaw = (c['participant_thix'] as Map?)?.cast<String, dynamic>() ?? const {};
          final type = (c['type'] as String?) ?? 'direct';
          final participantName = pnRaw.map((k, v) => MapEntry(k, (v as String?) ?? 'Utilisateur'));
          final participantThix = ptRaw.map((k, v) => MapEntry(k, (v as String?) ?? ''));
          final dk = (c['direct_key'] as String?)?.trim();

          final patchedNames = Map<String, String>.from(participantName);
          for (final p in parts) {
            if (p == uid) {
              patchedNames.putIfAbsent(p, () => 'Moi');
            } else {
              patchedNames.putIfAbsent(p, () => profiles[p]?.displayName ?? 'Utilisateur');
            }
          }

          return ChatSummary(
            id: id,
            type: type,
            directKey: (dk == null || dk.isEmpty) ? null : dk,
            participants: parts,
            participantName: patchedNames,
            participantThix: Map<String, String>.from(participantThix),
            lastMessage: (c['last_message'] as String?) ?? '',
            lastMessageAt: _tryParseDate(c['last_message_at']),
          );
        }).toList(growable: false);
      } catch (e) {
        debugPrint('ChatService: fetch chats failed uid=$uid err=$e');
        return const <ChatSummary>[];
      }
    }

    // Realtime doesn't support "contains" filters directly in the channel API,
    // so we subscribe to table changes and refetch for this user.
    return _realtimeListStream<ChatSummary>(
      channelName: 'thix_chat_chats:watch:$uid',
      fetch: fetch,
      bind: (channel, onAnyChange) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: chatsTable,
          callback: (_) => onAnyChange(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _selectChatsForUser(String uid) async {
    // Canonical schema (repo migrations) includes:
    // - title, participant_name, participant_thix, last_message, last_message_at
    // Some deployments created only a subset (type/participants/direct_key).
    // We try the canonical query first; on schema/cache errors we retry minimal.
    try {
      final rows = await _client
          .from(chatsTable)
          .select('id,type,direct_key,title,participants,participant_name,participant_thix,last_message,last_message_at,updated_at')
          .contains('participants', [uid])
          .order('last_message_at', ascending: false)
          .order('updated_at', ascending: false)
          .limit(100);
      if (rows is! List) return const <Map<String, dynamic>>[];
      return rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false);
    } catch (e) {
      debugPrint('ChatService: _selectChatsForUser canonical select failed uid=$uid err=$e');
    }

    try {
      final rows = await _client
          .from(chatsTable)
          .select('id,type,direct_key,participants,updated_at')
          .contains('participants', [uid])
          .order('updated_at', ascending: false)
          .limit(100);
      if (rows is! List) return const <Map<String, dynamic>>[];
      return rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false);
    } catch (e) {
      debugPrint('ChatService: _selectChatsForUser minimal select failed uid=$uid err=$e');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _selectLegacyChatMessagesForUser(String uid) async {
    // Legacy schema: `thix_chat_chats` contains messages. Fetch the latest N rows
    // involving the user, then summarize client-side by direct_key.
    final rows = await _client
        .from(chatsTable)
        .select('id, direct_key, sender_id, receiver_id, message_content, created_at, updated_at, type, participants')
        .or('sender_id.eq.$uid,receiver_id.eq.$uid')
        .order('created_at', ascending: false)
        .limit(300);
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false);
  }

  Future<List<ChatSummary>> _summariesFromLegacyMessageRows(String uid, List<Map<String, dynamic>> rows) async {
    // Pick the latest message per direct_key.
    final latestByKey = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final key = (r['direct_key'] as String?)?.trim() ?? '';
      if (key.isEmpty) continue;
      latestByKey.putIfAbsent(key, () => r);
    }

    final otherUids = <String>{};
    for (final entry in latestByKey.entries) {
      final r = entry.value;
      final sender = (r['sender_id'] as String?)?.trim() ?? '';
      final receiver = (r['receiver_id'] as String?)?.trim() ?? '';
      final other = sender == uid ? receiver : sender;
      if (other.isNotEmpty) otherUids.add(other);
    }

    final profiles = await _fetchProfileBasics(otherUids.toList(growable: false));
    final out = <ChatSummary>[];
    for (final entry in latestByKey.entries) {
      final key = entry.key;
      final r = entry.value;
      final sender = (r['sender_id'] as String?)?.trim() ?? '';
      final receiver = (r['receiver_id'] as String?)?.trim() ?? '';
      final participants = <String>[];
      if (sender.isNotEmpty) participants.add(sender);
      if (receiver.isNotEmpty && receiver != sender) participants.add(receiver);
      final other = sender == uid ? receiver : sender;
      final names = <String, String>{
        uid: 'Moi',
        if (other.isNotEmpty) other: profiles[other]?.displayName ?? 'Utilisateur',
      };
      out.add(ChatSummary(
        id: 'direct:$key',
        type: 'direct',
        directKey: key,
        participants: participants,
        participantName: names,
        participantThix: const {},
        lastMessage: (r['message_content'] as String?) ?? '',
        lastMessageAt: _tryParseDate(r['created_at']) ?? _tryParseDate(r['updated_at']),
      ));
    }

    out.sort((a, b) {
      final ad = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  /// Deprecated with the simplified schema.
  Future<ChatSummary?> fetchChatById({required String chatId}) async => null;

  bool isUuidLike(String v) => RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(v.trim());

  Stream<List<ChatContact>> streamRecentContacts({required String uid, int limit = 8}) {
    return streamChatsForUser(uid).map((chats) {
      final contacts = <String, ChatContact>{};
      for (final c in chats) {
        final otherUid = c.participants.firstWhere((p) => p != uid, orElse: () => '');
        if (otherUid.isEmpty) continue;
        final otherName = c.participantName[otherUid] ?? 'Utilisateur';
        final otherThix = c.participantThix[otherUid] ?? '';
        contacts.putIfAbsent(otherUid, () => ChatContact(uid: otherUid, displayName: otherName, thixId: otherThix));
        if (contacts.length >= limit) break;
      }
      return contacts.values.toList(growable: false);
    });
  }

  Stream<List<ChatMessage>> streamMessages(String chatId) {
    // Canonical schema: resolve UUID once, then subscribe with a chat_id filter.
    // Legacy schema: chatId is `direct:<key>` and we filter on direct_key.
    final controller = StreamController<List<ChatMessage>>.broadcast();
    RealtimeChannel? channel;
    String? uuid;
    Timer? debounce;
    bool closed = false;

    Future<void> emitLatest() async {
      if (closed) return;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 200), () async {
        if (closed) return;
        try {
          final legacy = await _isLegacySchema();
          if (legacy) {
            final parsed = _parseDirectChatVirtualId(chatId);
            if (parsed == null) throw Exception('ChatId invalide.');
            final key = _directKey(parsed.a, parsed.b);
            final rows = await _client
                .from(chatsTable)
                .select('id,direct_key,sender_id,receiver_id,message_content,created_at,updated_at,type')
                .eq('direct_key', key)
                .order('created_at', ascending: false)
                .limit(200);
            final base = (rows is List) ? rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false) : const <Map<String, dynamic>>[];
            final normalized = base.map((r) {
              final out = Map<String, dynamic>.from(r);
              out['chat_id'] = chatId; // virtual
              out['text'] = (r['message_content'] as String?) ?? '';
              out['sender_name'] = '';
              out['sender_thix_id'] = '';
              return out;
            }).toList(growable: false);
            final enriched = await _applyProfileEnrichmentForMessageRows(normalized);
            controller.add(enriched.map(ChatMessage.fromRow).toList(growable: false));
            return;
          }

          final id = uuid ?? await _resolveChatUuid(chatId);
          uuid ??= id;
          final rows = await _client.from(messagesTable).select('*').eq('chat_id', id).order('created_at', ascending: false).limit(200);
          final base = (rows is List) ? rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false) : const <Map<String, dynamic>>[];
          final enriched = await _applyProfileEnrichmentForMessageRows(base);
          controller.add(enriched.map(ChatMessage.fromRow).toList(growable: false));
        } catch (e) {
          debugPrint('ChatService: emitLatest messages failed chat=$chatId err=$e');
        }
      });
    }

    controller.onListen = () async {
      await emitLatest();
      try {
        final legacy = await _isLegacySchema();
        if (legacy) {
          final parsed = _parseDirectChatVirtualId(chatId);
          if (parsed == null) throw Exception('ChatId invalide.');
          final key = _directKey(parsed.a, parsed.b);
          channel = _client.channel('thix_chat_chats:direct:$key');
          final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'direct_key', value: key);
          channel!
              .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: chatsTable, filter: filter, callback: (_) => emitLatest())
              .subscribe((status, err) {
            if (err != null) debugPrint('ChatService: legacy messages realtime subscribe error status=$status err=$err');
          });
          return;
        }

        uuid ??= await _resolveChatUuid(chatId);
        final id = uuid!;
        channel = _client.channel('thix_chat_messages:$id');
        final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: id);
        channel!
            .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: messagesTable, filter: filter, callback: (_) => emitLatest())
            .subscribe((status, err) {
          if (err != null) debugPrint('ChatService: messages realtime subscribe error status=$status err=$err');
        });
      } catch (e) {
        debugPrint('ChatService: messages realtime setup failed chat=$chatId err=$e');
        // Fallback: keep it usable via polling.
        _poll(() async {
          try {
            final legacy = await _isLegacySchema();
            if (legacy) {
              final parsed = _parseDirectChatVirtualId(chatId);
              if (parsed == null) return const <ChatMessage>[];
              final key = _directKey(parsed.a, parsed.b);
              final rows = await _client
                  .from(chatsTable)
                  .select('id,direct_key,sender_id,receiver_id,message_content,created_at,updated_at,type')
                  .eq('direct_key', key)
                  .order('created_at', ascending: false)
                  .limit(200);
              final base = (rows is List) ? rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false) : const <Map<String, dynamic>>[];
              final normalized = base.map((r) {
                final out = Map<String, dynamic>.from(r);
                out['chat_id'] = chatId;
                out['text'] = (r['message_content'] as String?) ?? '';
                out['sender_name'] = '';
                out['sender_thix_id'] = '';
                return out;
              }).toList(growable: false);
              final enriched = await _applyProfileEnrichmentForMessageRows(normalized);
              return enriched.map(ChatMessage.fromRow).toList(growable: false);
            }

            final id = await _resolveChatUuid(chatId);
            final rows = await _client.from(messagesTable).select('*').eq('chat_id', id).order('created_at', ascending: false).limit(200);
            final base = (rows is List) ? rows.map((r) => (r as Map).cast<String, dynamic>()).toList(growable: false) : const <Map<String, dynamic>>[];
            final enriched = await _applyProfileEnrichmentForMessageRows(base);
            return enriched.map(ChatMessage.fromRow).toList(growable: false);
          } catch (e2) {
            debugPrint('ChatService: fallback poll messages failed chat=$chatId err=$e2');
            return const <ChatMessage>[];
          }
        }, interval: const Duration(seconds: 2)).listen((v) {
          if (!closed) controller.add(v);
        });
      }
    };

    controller.onCancel = () async {
      closed = true;
      debounce?.cancel();
      if (channel != null) {
        try {
          await _client.removeChannel(channel!);
        } catch (e) {
          debugPrint('ChatService: removeChannel messages failed err=$e');
        }
      }
      await controller.close();
    };

    return controller.stream;
  }

  Future<Map<String, ChatProfileBasics>> _fetchProfileBasics(List<String> uids) async {
    if (uids.isEmpty) return const {};
    final missing = <String>{};
    for (final id in uids) {
      final v = id.trim();
      if (v.isEmpty) continue;
      if (!_profileCache.containsKey(v)) missing.add(v);
    }
    if (missing.isNotEmpty) {
      try {
        final fetched = await _client
            .from(profilesTable)
            .select('id, display_name, full_name, avatar_url, national_id_number')
            .inFilter('id', missing.toList(growable: false));
        if (fetched is List) {
          for (final raw in fetched) {
            final row = (raw as Map).cast<String, dynamic>();
            final id = (row['id'] as String?) ?? '';
            if (id.isEmpty) continue;
            final fullName = (row['full_name'] as String?)?.trim();
            final displayName = (fullName != null && fullName.isNotEmpty)
                ? fullName
                : ((row['display_name'] as String?)?.trim() ?? 'Utilisateur');
            final avatarUrl = (row['avatar_url'] as String?)?.trim();
            final certified = ((row['national_id_number'] as String?) ?? '').trim().isNotEmpty;
            _profileCache[id] = ChatProfileBasics(uid: id, displayName: displayName, avatarUrl: avatarUrl, certified: certified);
          }
        }
      } catch (e) {
        debugPrint('ChatService: profile basics fetch failed err=$e');
      }
    }

    final out = <String, ChatProfileBasics>{};
    for (final id in uids) {
      final p = _profileCache[id];
      if (p != null) out[id] = p;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _applyProfileEnrichmentForMessageRows(List<Map<String, dynamic>> rows) async {
    final missing = <String>{};
    for (final r in rows) {
      final senderId = (r['sender_id'] as String?)?.trim() ?? '';
      if (senderId.isEmpty) continue;
      if (!_profileCache.containsKey(senderId)) missing.add(senderId);
    }
    if (missing.isNotEmpty) {
      await _fetchProfileBasics(missing.toList(growable: false));
    }
    return rows.map((r) {
      final senderId = (r['sender_id'] as String?)?.trim() ?? '';
      final p = _profileCache[senderId];
      if (p == null) return r;
      final out = Map<String, dynamic>.from(r);
      out['sender_profile_display_name'] = p.displayName;
      out['sender_profile_avatar_url'] = p.avatarUrl;
      out['sender_profile_national_id_number'] = p.certified ? '1' : '';
      return out;
    }).toList(growable: false);
  }

  Stream<DateTime?> streamReadAt({required String chatId, required String uid}) {
    return _poll(() async {
      try {
        final uuid = await _resolveChatUuid(chatId);
        final row = await _client.from(readsTable).select('read_at').eq('chat_id', uuid).eq('user_id', uid).maybeSingle();
        if (row == null) return null;
        return _tryParseDate((row as Map)['read_at']);
      } catch (e) {
        debugPrint('ChatService: streamReadAt failed chat=$chatId uid=$uid err=$e');
        return null;
      }
    }, interval: const Duration(seconds: 2));
  }

  Future<void> markChatRead({required String chatId, required String uid}) async {
    try {
      final uuid = await _resolveChatUuid(chatId);
      await _client.from(readsTable).upsert({
        'chat_id': uuid,
        'user_id': uid,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('ChatService: markChatRead failed chat=$chatId uid=$uid err=$e');
    }
  }

  Future<String> getOrCreateDirectChat({required AppUser me, required AppUser other}) async {
    final key = _directKey(me.id, other.id);
    return _getOrCreateChatByDirectKey(key: key, a: me.id, b: other.id, me: me);
  }

  Future<void> sendMessage({required String chatId, required AppUser sender, required String text}) async {
    final msg = text.trim();
    if (msg.isEmpty) return;
    await sendPayload(chatId: chatId, sender: sender, type: 'text', text: msg, previewText: msg, extra: const {});
  }

  Future<void> sendSticker({required String chatId, required AppUser sender, required String sticker}) async {
    final s = sticker.trim();
    if (s.isEmpty) return;
    await sendPayload(chatId: chatId, sender: sender, type: 'sticker', text: '', previewText: 'Sticker $s', extra: {'sticker': s});
  }

  Future<void> sendMeetingInvite({
    required String chatId,
    required AppUser sender,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? location,
    String? note,
  }) async {
    final safeTitle = title.trim().isEmpty ? 'Meeting' : title.trim();
    await sendPayload(
      chatId: chatId,
      sender: sender,
      type: 'meeting',
      text: '',
      previewText: 'Meeting: $safeTitle',
      extra: {
        'meeting_title': safeTitle,
        'meeting_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'meeting_duration_min': durationMinutes,
        'meeting_location': (location ?? '').trim().isEmpty ? null : location!.trim(),
        'meeting_note': (note ?? '').trim().isEmpty ? null : note!.trim(),
      },
    );
  }

  Future<void> sendCallRequest({required String chatId, required AppUser sender, required String kind}) async {
    final safeKind = (kind == 'video') ? 'video' : 'audio';
    await sendPayload(
      chatId: chatId,
      sender: sender,
      type: 'call_request',
      text: '',
      previewText: safeKind == 'video' ? 'Appel vidéo' : 'Appel audio',
      extra: {
        'call_kind': safeKind,
        'call_status': 'requested',
      },
    );
  }

  /// Sends a money transfer request/notification as a chat message.
  ///
  /// No wallet is used: this is a per-transaction instruction (e.g. Mobile Money).
  /// The payload is embedded into the text field using [moneyTransferMarker] so
  /// the UI can render it as a rich bubble.
  Future<void> sendMoneyTransfer({
    required String chatId,
    required AppUser sender,
    required String senderPhone,
    required String receiverPhone,
    required String network,
    required String amount,
    required String currency,
    String? note,
  }) async {
    final safeSender = senderPhone.trim();
    final safeReceiver = receiverPhone.trim();
    final safeNetwork = network.trim();
    final safeAmount = amount.trim();
    final safeCurrency = currency.trim().toUpperCase();
    if (safeSender.isEmpty || safeReceiver.isEmpty || safeNetwork.isEmpty || safeAmount.isEmpty) {
      throw Exception('Paramètres transfert invalides.');
    }

    final payload = {
      'sender_phone': safeSender,
      'receiver_phone': safeReceiver,
      'network': safeNetwork,
      'amount': safeAmount,
      'currency': safeCurrency,
      'note': (note ?? '').trim().isEmpty ? null : (note ?? '').trim(),
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Human-readable summary + machine payload.
    final summary = '💸 Transfert $safeAmount $safeCurrency • $safeNetwork';
    final text = '$moneyTransferMarker${jsonEncode(payload)}\n$summary';

    // Use the resilient text-only pipeline.
    await sendPayload(chatId: chatId, sender: sender, type: 'money_transfer', text: text, previewText: summary, extra: payload);
  }

  Future<void> updateMessage({
    required String messageId,
    required Map<String, dynamic> patch,
  }) async {
    try {
      final safe = Map<String, dynamic>.from(patch);
      safe['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _client.from(messagesTable).update(safe).eq('id', messageId);
    } catch (e) {
      debugPrint('ChatService: updateMessage failed id=$messageId err=$e');
      rethrow;
    }
  }

  Future<void> sendAttachment({required String chatId, required AppUser sender, required PlatformFile file}) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final objectPath = 'chats/$chatId/${ts}_${file.name}';
      final storage = _client.storage.from(attachmentsBucket);

      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('Impossible de lire le fichier (web).');
        await storage.uploadBinary(objectPath, bytes);
      } else {
        final path = file.path;
        if (path == null) throw Exception('Chemin fichier invalide.');
        final f = fileFromPath(path);
        await storage.upload(objectPath, f as dynamic);
      }

      final url = storage.getPublicUrl(objectPath);
      await sendPayload(
        chatId: chatId,
        sender: sender,
        type: 'attachment',
        text: '',
        previewText: 'Document: ${file.name}',
        extra: {
          'file_name': file.name,
          'file_ext': file.extension,
          'file_size': file.size,
          'download_url': url,
          'storage_path': objectPath,
        },
      );
    } catch (e) {
      debugPrint('ChatService: sendAttachment failed chat=$chatId err=$e');
      rethrow;
    }
  }

  Future<void> sendPayload({
    required String chatId,
    required AppUser sender,
    required String type,
    required String text,
    required String previewText,
    required Map<String, dynamic> extra,
  }) async {
    try {
      final authUid = _client.auth.currentUser?.id;
      final senderId = (authUid != null && authUid.trim().isNotEmpty) ? authUid : sender.id;
      final now = DateTime.now().toUtc().toIso8601String();

      final legacy = await _isLegacySchema();
      if (legacy) {
        final parsed = _parseDirectChatVirtualId(chatId);
        if (parsed == null) throw Exception('ChatId invalide.');
        final key = _directKey(parsed.a, parsed.b);
        final receiverId = senderId == parsed.a ? parsed.b : parsed.a;
        await _client.from(chatsTable).insert({
          'type': type,
          'direct_key': key,
          'sender_id': senderId,
          'receiver_id': receiverId,
          'participants': [parsed.a, parsed.b],
          'message_content': text.isEmpty ? previewText : text,
          'is_read': false,
          'created_at': now,
          'updated_at': now,
        });
        return;
      }

      final uuid = await _resolveChatUuid(chatId, me: sender);

      await _client.from(messagesTable).insert({
        'chat_id': uuid,
        'type': type,
        'sender_id': senderId,
        'sender_name': sender.displayName,
        'sender_thix_id': sender.thixId,
        'text': text,
        ..._extraToMessageColumns(extra),
        'created_at': now,
        'updated_at': now,
      });

      // Best-effort chat preview update.
      // Some deployments do not yet have last_message/last_message_at columns.
      try {
        await _client.from(chatsTable).update({
          'last_message': previewText,
          'last_message_at': now,
          'updated_at': now,
        }).eq('id', uuid);
      } catch (e) {
        debugPrint('ChatService: update chat preview failed (ignored) chat=$uuid err=$e');
        try {
          await _client.from(chatsTable).update({'updated_at': now}).eq('id', uuid);
        } catch (e2) {
          debugPrint('ChatService: update updated_at failed (ignored) chat=$uuid err=$e2');
        }
      }
    } catch (e) {
      debugPrint('ChatService: sendPayload failed chat=$chatId type=$type err=$e');
      rethrow;
    }
  }

  Map<String, dynamic> _extraToMessageColumns(Map<String, dynamic> extra) {
    // The table has explicit nullable columns for common payloads.
    // Only map known keys (avoid column-not-found in reduced schemas).
    final out = <String, dynamic>{};
    void set(String col, String key) {
      final v = extra[key];
      if (v == null) return;
      out[col] = v;
    }

    set('sticker', 'sticker');
    set('file_name', 'file_name');
    set('file_ext', 'file_ext');
    set('file_size', 'file_size');
    set('download_url', 'download_url');
    set('storage_path', 'storage_path');
    set('meeting_title', 'meeting_title');
    set('meeting_scheduled_at', 'meeting_scheduled_at');
    set('meeting_duration_min', 'meeting_duration_min');
    set('meeting_location', 'meeting_location');
    set('meeting_note', 'meeting_note');
    set('call_kind', 'call_kind');
    set('call_status', 'call_status');
    return out;
  }

  Future<String> _getOrCreateChatByDirectKey({
    required String key,
    required String a,
    required String b,
    AppUser? me,
  }) async {
    // Legacy schema: no separate chat row to create. The thread id is virtual.
    if (await _isLegacySchema()) return 'direct:$key';

    // Find by direct_key.
    try {
      final existing = await _client.from(chatsTable).select('id').eq('direct_key', key).maybeSingle();
      if (existing != null) {
        final id = ((existing as Map)['id'] as String?) ?? '';
        if (id.isNotEmpty) return id;
      }
    } catch (e) {
      debugPrint('ChatService: getOrCreateChatByDirectKey select failed key=$key err=$e');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final participants = [a, b];
    final profiles = await _fetchProfileBasics([a, b]);
    final participantName = {
      a: me?.id == a ? (me?.displayName ?? 'Utilisateur') : (profiles[a]?.displayName ?? 'Utilisateur'),
      b: me?.id == b ? (me?.displayName ?? 'Utilisateur') : (profiles[b]?.displayName ?? 'Utilisateur'),
    };

    try {
      final inserted = await _insertChatRowWithFallbacks(payload: {
        'type': 'direct',
        'direct_key': key,
        'participants': participants,
        'participant_name': participantName,
        'participant_thix': const {},
        'last_message': '',
        'last_message_at': null,
        'created_at': now,
        'updated_at': now,
      });
      return (inserted['id'] as String?) ?? '';
    } catch (e) {
      // If another client created it concurrently, fetch again.
      debugPrint('ChatService: getOrCreateChatByDirectKey insert failed key=$key err=$e');
      final existing = await _client.from(chatsTable).select('id').eq('direct_key', key).maybeSingle();
      if (existing != null) {
        return ((existing as Map)['id'] as String?) ?? '';
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _insertChatRowWithFallbacks({required Map<String, dynamic> payload}) async {
    // Progressive fallback to support manual/partial schemas and PostgREST schema-cache delay.
    final attempts = <Map<String, dynamic>>[
      payload,
      {
        'type': payload['type'],
        'direct_key': payload['direct_key'],
        'participants': payload['participants'],
        'created_at': payload['created_at'],
        'updated_at': payload['updated_at'],
      },
      {
        'type': payload['type'],
        'direct_key': payload['direct_key'],
        'participants': payload['participants'],
      },
    ];

    Object? lastErr;
    for (final p in attempts) {
      try {
        final inserted = await _client.from(chatsTable).insert(p).select('id').single();
        return (inserted as Map).cast<String, dynamic>();
      } catch (e) {
        lastErr = e;
        debugPrint('ChatService: insert chat retry failed keys=${p.keys.toList()} err=$e');
      }
    }
    throw lastErr ?? Exception('Insert chat failed.');
  }

  Future<String> createGroup({required AppUser me, required String title, required List<String> memberUids}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final set = <String>{me.id, ...memberUids.map((e) => e.trim()).where((e) => e.isNotEmpty)};
    final participants = set.toList(growable: false);
    final profiles = await _fetchProfileBasics(participants);
    final names = <String, String>{};
    for (final id in participants) {
      if (id == me.id) {
        names[id] = me.displayName;
      } else {
        names[id] = profiles[id]?.displayName ?? 'Utilisateur';
      }
    }
    final inserted = await _insertChatRowWithFallbacks(payload: {
      'type': 'group',
      'title': title.trim().isEmpty ? 'Groupe' : title.trim(),
      'created_by': me.id,
      'participants': participants,
      'participant_name': names,
      'participant_thix': const {},
      'last_message': '',
      'last_message_at': null,
      'created_at': now,
      'updated_at': now,
    });
    return (inserted['id'] as String?) ?? '';
  }

  Future<List<ChatContact>> searchProfiles(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return const <ChatContact>[];
    try {
      final rows = await _client
          .from(profilesTable)
          .select('id, display_name, full_name, thix_id, thix_chat')
          .or('display_name.ilike.%$q%,full_name.ilike.%$q%,thix_id.ilike.%$q%,thix_chat.ilike.%$q%')
          .limit(limit);
      if (rows is! List) return const <ChatContact>[];
      return rows
          .map((r) => (r as Map).cast<String, dynamic>())
          .map((r) {
            final id = (r['id'] as String?) ?? '';
            final full = (r['full_name'] as String?)?.trim();
            final display = (full != null && full.isNotEmpty) ? full : ((r['display_name'] as String?)?.trim() ?? 'Utilisateur');
            final thix = (r['thix_id'] as String?)?.trim() ?? '';
            return ChatContact(uid: id, displayName: display, thixId: thix);
          })
          .where((c) => c.uid.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint('ChatService: searchProfiles failed q=$q err=$e');
      return const <ChatContact>[];
    }
  }

  /// Fetches a profile by exact THIX ID (recommended for “start first chat”).
  ///
  /// Returns null when not found or when RLS denies access.
  Future<ChatContact?> fetchProfileByThixId(String thixId) async {
    final v = thixId.trim();
    if (v.isEmpty) return null;
    try {
      final row = await _client.from(profilesTable).select('id, display_name, full_name, thix_id').eq('thix_id', v).maybeSingle();
      if (row == null) return null;
      final r = (row as Map).cast<String, dynamic>();
      final id = (r['id'] as String?) ?? '';
      if (id.isEmpty) return null;
      final full = (r['full_name'] as String?)?.trim();
      final display = (full != null && full.isNotEmpty) ? full : ((r['display_name'] as String?)?.trim() ?? 'Utilisateur');
      final thix = (r['thix_id'] as String?)?.trim() ?? '';
      return ChatContact(uid: id, displayName: display, thixId: thix);
    } catch (e) {
      debugPrint('ChatService: fetchProfileByThixId failed thixId=$v err=$e');
      return null;
    }
  }

  /// Fetches a profile by **exact** THIX ID or **exact** THIX Chat handle.
  ///
  /// This helps when users paste either identifier in the same field.
  /// Returns null when not found (or when RLS denies access).
  Future<ChatContact?> fetchProfileByThixIdOrHandle(String input) async {
    final v = input.trim();
    if (v.isEmpty) return null;
    try {
      final row = await _client
          .from(profilesTable)
          .select('id, display_name, full_name, thix_id, thix_chat')
          .or('thix_id.eq.$v,thix_chat.eq.$v')
          .maybeSingle();
      if (row == null) return null;
      final r = (row as Map).cast<String, dynamic>();
      final id = (r['id'] as String?) ?? '';
      if (id.isEmpty) return null;
      final full = (r['full_name'] as String?)?.trim();
      final display = (full != null && full.isNotEmpty) ? full : ((r['display_name'] as String?)?.trim() ?? 'Utilisateur');
      final thix = (r['thix_id'] as String?)?.trim() ?? '';
      return ChatContact(uid: id, displayName: display, thixId: thix);
    } catch (e) {
      debugPrint('ChatService: fetchProfileByThixIdOrHandle failed input=$v err=$e');
      return null;
    }
  }

  Future<void> setTyping({required String chatId, required bool isTyping}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final uuid = await _resolveChatUuid(chatId);
      await _client.from(typingTable).upsert({
        'chat_id': uuid,
        'user_id': uid,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('ChatService: setTyping failed chat=$chatId typing=$isTyping err=$e');
    }
  }

  Stream<List<String>> streamTypingUsers({required String chatId, required String excludeUid}) {
    return _poll(() async {
      try {
        final uuid = await _resolveChatUuid(chatId);
        final rows = await _client
            .from(typingTable)
            .select('user_id,is_typing,updated_at')
            .eq('chat_id', uuid)
            .eq('is_typing', true)
            .order('updated_at', ascending: false)
            .limit(10);
        if (rows is! List) return const <String>[];
        return rows
            .map((r) => (r as Map)['user_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty && id != excludeUid)
            .toList(growable: false);
      } catch (e) {
        debugPrint('ChatService: streamTypingUsers failed chat=$chatId err=$e');
        return const <String>[];
      }
    }, interval: const Duration(seconds: 2));
  }

  String _directKey(String a, String b) {
    final pair = [a, b]..sort();
    return pair.join('_');
  }
}

