import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/services/call_service.dart';
import 'package:thix_id/services/chat_service.dart';
import 'package:thix_id/services/presence_service.dart';
import 'package:thix_id/services/status_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/theme.dart';
import 'package:thix_id/nav.dart';

import 'package:thix_id/presentation/chat/thix_agora_call_sheet.dart';

/// THIX CHAT — Premium rebuild (from scratch)
///
/// Goals:
/// - Zero “white screen”: no unbounded Stack/Clip/Blur tricks.
/// - Premium look with clean spacing + subtle gradients.
/// - Works with existing services: [ChatService], [StatusService], [CallService].
/// - Uses bottom sheets (no extra routes) to keep go_router stable.
class ThixChatPage extends StatefulWidget {
  const ThixChatPage({super.key});

  @override
  State<ThixChatPage> createState() => _ThixChatPageState();
}

class _ThixChatPageState extends State<ThixChatPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _chat = ChatService();
  final _status = StatusService();
  final _calls = CallService();
  final _presence = PresenceService();

  StreamSubscription<List<ThixCall>>? _incomingCallsSub;
  String? _incomingForUid;
  bool _incomingSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Presence: best-effort.
    unawaited(_presence.setOnline(true));
    _presence.startHeartbeat();
  }

  @override
  void dispose() {
    unawaited(_incomingCallsSub?.cancel());
    _presence.stopHeartbeat();
    unawaited(_presence.setOnline(false));
    _tabs.dispose();
    super.dispose();
  }

  void _ensureIncomingCallListener(AppUser me) {
    if (_incomingForUid == me.id) return;
    _incomingForUid = me.id;
    unawaited(_incomingCallsSub?.cancel());
    _incomingCallsSub = _calls.streamIncomingOngoingCalls(receiverId: me.id).listen((calls) {
      if (!mounted) return;
      if (calls.isEmpty) return;
      if (_incomingSheetOpen) return;
      final c = calls.first;
      _incomingSheetOpen = true;
      unawaited(_showIncomingCallSheet(me: me, call: c));
    });
  }

  Future<void> _showIncomingCallSheet({required AppUser me, required ThixCall call}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _IncomingCallSheet(
        kind: call.kind,
        callerId: call.callerId,
        onDecline: () async {
          try {
            await _calls.setCallStatus(callId: call.id, status: 'declined');
          } catch (e) {
            debugPrint('IncomingCall: decline failed err=$e');
          }
          if (context.mounted) context.pop();
        },
        onAccept: () async {
          if (!context.mounted) return;
          context.pop();
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            useSafeArea: true,
            builder: (_) => ThixAgoraCallSheet(
              callId: call.id,
              otherUserId: call.callerId,
              kind: call.kind,
              isCaller: false,
              calls: _calls,
            ),
          );
        },
      ),
    );
    _incomingSheetOpen = false;
  }

  AppUser? _me(BuildContext context) => context.read<AuthController>().currentUser;

  @override
  Widget build(BuildContext context) {
    debugPrint('ThixChatPage: build route=/chat');
    final scheme = Theme.of(context).colorScheme;
    final me = context.watch<AuthController>().currentUser;

    if (me == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Text(
              'Veuillez vous connecter pour accéder à THIX CHAT.',
              style: context.textStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    _ensureIncomingCallListener(me);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ThixChatBackground()),
          SafeArea(
            child: Column(
              children: [
                ThixChatTemplateHeader(
                  onSearch: () => _openSearch(context, me),
                  onSettings: () => context.push(AppRoutes.settings),
                  onNewChat: () => _openNewChat(context, me),
                  onGroups: () => _openGroups(context, me),
                  onCalls: () => _openCalls(context, me),
                  onDocs: () => context.push(AppRoutes.vault),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      dividerHeight: 0,
                      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      labelStyle: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      unselectedLabelStyle: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        gradient: AppPremiumGradients.thixNavyToGold(scheme),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: scheme.onPrimary,
                      unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.7),
                      tabs: const [
                        Tab(text: 'Discussions'),
                        Tab(text: 'Statut'),
                        Tab(text: 'Contacts'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      ThixChatsTab(
                        me: me,
                        chat: _chat,
                        onOpenThread: (chatId, otherUid, otherName) => _openThreadSheet(context, me: me, chatId: chatId, otherUid: otherUid, otherName: otherName),
                        onStartByThixId: () => _openStartByThixId(context, me),
                      ),
                      ThixStatusTab(me: me, status: _status),
                      ThixContactsTab(me: me, chat: _chat, onOpenThread: (chatId, otherUid, otherName) => _openThreadSheet(context, me: me, chatId: chatId, otherUid: otherUid, otherName: otherName)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGroups(BuildContext context, AppUser me) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ThixGroupComposerSheet(me: me, chat: _chat),
    );
  }

  Future<void> _openCalls(BuildContext context, AppUser me) async {
    // Lightweight sheet: we keep navigation stable and reuse existing Call bottom-sheet.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ThixCallLauncherSheet(me: me, chat: _chat, calls: _calls),
    );
  }

  Future<void> _openThreadSheet(BuildContext context, {required AppUser me, required String chatId, required String otherUid, required String otherName}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ThixChatThreadSheet(
        me: me,
        chatId: chatId,
        otherUid: otherUid,
        otherName: otherName,
        chat: _chat,
        calls: _calls,
      ),
    );
  }

  Future<void> _openSearch(BuildContext context, AppUser me) async {
    final selected = await showModalBottomSheet<_SearchPick?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ThixChatSearchSheet(me: me, chat: _chat),
    );

    if (!mounted) return;
    if (selected == null) return;
    final otherUid = selected.uid;
    if (otherUid.isEmpty) return;
    try {
      final other = AppUser(
        id: otherUid,
        thixId: selected.thixId,
        thixChat: '',
        thixScore: null,
        email: '',
        phone: null,
        displayName: selected.displayName,
        accountType: AccountType.personal,
        photoUrl: null,
        bio: null,
        countryOrOrigin: null,
        contactPhone: null,
        maritalStatus: null,
        gender: null,
        occupation: null,
        profession: null,
        dateOfBirth: null,
        placeOfBirth: null,
        nationality: null,
        address: null,
        fatherName: null,
        motherName: null,
        emergencyContactName: null,
        emergencyContactPhone: null,
        emergencyContactRelation: null,
        education: const [],
        experience: const [],
        skills: const [],
        enrollments: const [],
        languages: const [],
        biometricsEnabled: true,
        twoFaEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final chatId = await _chat.getOrCreateDirectChat(me: me, other: other);
      if (!mounted) return;
      await _openThreadSheet(context, me: me, chatId: chatId, otherUid: otherUid, otherName: selected.displayName);
    } catch (e) {
      debugPrint('ThixChatPage: openSearch create chat failed err=$e');
    }
  }

  Future<void> _openNewChat(BuildContext context, AppUser me) async {
    final pick = await showModalBottomSheet<_NewChatPick?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ThixChatNewChatSheet(me: me, chat: _chat),
    );

    if (!mounted) return;
    if (pick == null) return;
    await _openThreadSheet(context, me: me, chatId: pick.chatId, otherUid: pick.otherUid, otherName: pick.title);
  }

  Future<void> _openStartByThixId(BuildContext context, AppUser me) async {
    final selected = await showModalBottomSheet<_SearchPick?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ThixStartChatByThixIdSheet(me: me, chat: _chat),
    );

    if (!mounted) return;
    if (selected == null) return;

    final otherUid = selected.uid;
    if (otherUid.isEmpty) return;
    try {
      final other = AppUser(
        id: otherUid,
        thixId: selected.thixId,
        thixChat: '',
        thixScore: null,
        email: '',
        phone: null,
        displayName: selected.displayName,
        accountType: AccountType.personal,
        photoUrl: null,
        bio: null,
        countryOrOrigin: null,
        contactPhone: null,
        maritalStatus: null,
        gender: null,
        occupation: null,
        profession: null,
        dateOfBirth: null,
        placeOfBirth: null,
        nationality: null,
        address: null,
        fatherName: null,
        motherName: null,
        emergencyContactName: null,
        emergencyContactPhone: null,
        emergencyContactRelation: null,
        education: const [],
        experience: const [],
        skills: const [],
        enrollments: const [],
        languages: const [],
        biometricsEnabled: true,
        twoFaEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final chatId = await _chat.getOrCreateDirectChat(me: me, other: other);
      if (!mounted) return;
      await _openThreadSheet(context, me: me, chatId: chatId, otherUid: otherUid, otherName: selected.displayName);
    } catch (e) {
      debugPrint('ThixChatPage: startByThixId failed err=$e');
    }
  }
}

class ThixChatTemplateHeader extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onNewChat;
  final VoidCallback onGroups;
  final VoidCallback onCalls;
  final VoidCallback onDocs;
  const ThixChatTemplateHeader({super.key, required this.onSearch, required this.onSettings, required this.onNewChat, required this.onGroups, required this.onCalls, required this.onDocs});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerBg0 = Color.lerp(scheme.primary, Colors.black, 0.35) ?? scheme.primary;
    final headerBg1 = Color.lerp(scheme.primary, scheme.tertiary, 0.35) ?? scheme.tertiary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [headerBg0, headerBg1]),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('THIX CHAT', style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: scheme.onPrimary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.lock_rounded, size: 16, color: scheme.onPrimary.withValues(alpha: 0.90)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Chiffrement de bout en bout',
                                style: context.textStyles.bodySmall?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.90), fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TopAction(icon: Icons.search_rounded, tooltip: 'Rechercher', onTap: onSearch, onColor: scheme.onPrimary),
                  const SizedBox(width: AppSpacing.sm),
                  _TopAction(icon: Icons.settings_rounded, tooltip: 'Réglages', onTap: onSettings, onColor: scheme.onPrimary),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: ThixHeaderActionButton(icon: Icons.add_comment_rounded, label: 'Nouveau', isPrimary: true, onTap: onNewChat)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: ThixHeaderActionButton(icon: Icons.groups_rounded, label: 'Groupes', onTap: onGroups)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: ThixHeaderActionButton(icon: Icons.call_rounded, label: 'Appels', onTap: onCalls)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: ThixHeaderActionButton(icon: Icons.folder_copy_rounded, label: 'Docs', onTap: onDocs)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? onColor;
  const _TopAction({required this.icon, required this.tooltip, required this.onTap, this.onColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          splashFactory: NoSplash.splashFactory,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 18, color: onColor ?? scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class ThixHeaderActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;
  const ThixHeaderActionButton({super.key, required this.icon, required this.label, required this.onTap, this.isPrimary = false});

  @override
  State<ThixHeaderActionButton> createState() => _ThixHeaderActionButtonState();
}

class _ThixHeaderActionButtonState extends State<ThixHeaderActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.isPrimary ? scheme.tertiary.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.12);
    final fg = widget.isPrimary ? scheme.onTertiary : scheme.onPrimary;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: Colors.white.withValues(alpha: widget.isPrimary ? 0.0 : 0.20)),
        ),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.white.withValues(alpha: 0.06),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: fg, size: 22),
                const SizedBox(height: 6),
                Text(widget.label, style: context.textStyles.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ThixChatsTab extends StatefulWidget {
  final AppUser me;
  final ChatService chat;
  final void Function(String chatId, String otherUid, String otherName) onOpenThread;
  final VoidCallback onStartByThixId;
  const ThixChatsTab({super.key, required this.me, required this.chat, required this.onOpenThread, required this.onStartByThixId});

  @override
  State<ThixChatsTab> createState() => _ThixChatsTabState();
}

class _ThixChatsTabState extends State<ThixChatsTab> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _q.addListener(() {
      final next = _q.text.trim().toLowerCase();
      if (next == _query) return;
      setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: StreamBuilder<List<ChatSummary>>(
        stream: widget.chat.streamChatsForUser(widget.me.id),
        builder: (context, snap) {
          final data = snap.data;
          if (snap.connectionState == ConnectionState.waiting && data == null) {
            return const ThixChatLoadingState();
          }
          final all = data ?? const <ChatSummary>[];
          final chats = _query.isEmpty
              ? all
              : all.where((c) {
                  final otherUid = c.participants.firstWhere((p) => p != widget.me.id, orElse: () => '');
                  final isGroup = c.participants.length > 2;
                  final otherName = isGroup ? 'Groupe' : (c.participantName[otherUid] ?? 'Utilisateur');
                  final hay = '${otherName.toLowerCase()} ${c.lastMessage.toLowerCase()}';
                  return hay.contains(_query);
                }).toList(growable: false);

          return Column(
            children: [
              _TemplateSearchField(controller: _q),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text('En ligne maintenant', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 2))),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.chat_bubble_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.70)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Discussions récentes', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                  TextButton(
                    onPressed: all.isEmpty
                        ? null
                        : () async {
                            try {
                              await Future.wait(all.map((c) => widget.chat.markChatRead(chatId: c.id, uid: widget.me.id)));
                            } catch (e) {
                              debugPrint('ChatsTab: mark all read failed err=$e');
                            }
                          },
                    style: TextButton.styleFrom(foregroundColor: scheme.tertiary),
                    child: const Text('Tout marquer lu'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: all.isEmpty
                    ? ThixChatEmptyState(
                        title: 'Aucune discussion',
                        subtitle: 'Démarre une conversation en trouvant une personne via son THIX ID.',
                        icon: Icons.forum_rounded,
                        actionLabel: 'Démarrer (THIX ID)',
                        onAction: widget.onStartByThixId,
                      )
                    : chats.isEmpty
                        ? ThixChatEmptyState(title: 'Aucun résultat', subtitle: 'Essaie une autre recherche.', icon: Icons.search_off_rounded)
                        : ListView.separated(
                            itemCount: chats.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, i) {
                              final c = chats[i];
                              final otherUid = c.participants.firstWhere((p) => p != widget.me.id, orElse: () => '');
                              final isGroup = c.participants.length > 2;
                              final otherName = isGroup ? 'Groupe' : (c.participantName[otherUid] ?? 'Utilisateur');
                              return ThixChatListTile(
                                title: otherName,
                                subtitle: c.lastMessage.isEmpty ? '…' : c.lastMessage,
                                time: c.lastMessageAt,
                                onTap: otherUid.isEmpty ? null : () => widget.onOpenThread(c.id, otherUid, otherName),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateSearchField extends StatelessWidget {
  final TextEditingController controller;
  const _TemplateSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurface.withValues(alpha: 0.55)),
        hintText: 'Rechercher une conversation…',
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide(color: scheme.tertiary.withValues(alpha: 0.9), width: 1.4)),
      ),
    );
  }
}

class ThixCallLauncherSheet extends StatefulWidget {
  final AppUser me;
  final ChatService chat;
  final CallService calls;
  const ThixCallLauncherSheet({super.key, required this.me, required this.chat, required this.calls});

  @override
  State<ThixCallLauncherSheet> createState() => _ThixCallLauncherSheetState();
}

class _ThixCallLauncherSheetState extends State<ThixCallLauncherSheet> {
  String _kind = 'audio';
  bool _busy = false;

  Future<void> _startCall(ChatContact c) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final other = AppUser(
        id: c.uid,
        thixId: c.thixId,
        thixChat: '',
        thixScore: null,
        email: '',
        phone: null,
        displayName: c.displayName,
        accountType: AccountType.personal,
        photoUrl: null,
        bio: null,
        countryOrOrigin: null,
        contactPhone: null,
        maritalStatus: null,
        gender: null,
        occupation: null,
        profession: null,
        dateOfBirth: null,
        placeOfBirth: null,
        nationality: null,
        address: null,
        fatherName: null,
        motherName: null,
        emergencyContactName: null,
        emergencyContactPhone: null,
        emergencyContactRelation: null,
        education: const [],
        experience: const [],
        skills: const [],
        enrollments: const [],
        languages: const [],
        biometricsEnabled: true,
        twoFaEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final chatId = await widget.chat.getOrCreateDirectChat(me: widget.me, other: other);
      final callId = await widget.calls.startCall(chatId: chatId, kind: _kind, receiverId: c.uid);
      if (!mounted) return;
      context.pop();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => ThixAgoraCallSheet(callId: callId, otherUserId: c.uid, kind: _kind, isCaller: true, calls: widget.calls),
      );
    } catch (e) {
      debugPrint('CallLauncher: start call failed err=$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de démarrer l\'appel. (${e.toString()})')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ThixBottomSheetShell(
      title: 'Démarrer un appel',
      subtitle: 'Choisis un contact récent (audio/vidéo).',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Audio'),
                            selected: _kind == 'audio',
                            onSelected: _busy ? null : (_) => setState(() => _kind = 'audio'),
                            selectedColor: scheme.tertiary,
                            labelStyle: context.textStyles.labelLarge?.copyWith(color: _kind == 'audio' ? scheme.onTertiary : scheme.onSurface, fontWeight: FontWeight.w800),
                            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.0)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Vidéo'),
                            selected: _kind == 'video',
                            onSelected: _busy ? null : (_) => setState(() => _kind = 'video'),
                            selectedColor: scheme.tertiary,
                            labelStyle: context.textStyles.labelLarge?.copyWith(color: _kind == 'video' ? scheme.onTertiary : scheme.onSurface, fontWeight: FontWeight.w800),
                            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: StreamBuilder<List<ChatContact>>(
              stream: widget.chat.streamRecentContacts(uid: widget.me.id, limit: 40),
              builder: (context, snap) {
                final contacts = snap.data ?? const <ChatContact>[];
                if (snap.connectionState == ConnectionState.waiting && snap.data == null) return const ThixChatLoadingState();
                if (contacts.isEmpty) {
                  return ThixChatEmptyState(
                    title: 'Aucun contact',
                    subtitle: 'Démarre une discussion d’abord pour voir des contacts ici.',
                    icon: Icons.call_rounded,
                  );
                }
                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final c = contacts[i];
                    return ThixChatListTile(
                      title: c.displayName,
                      subtitle: c.thixId.isEmpty ? 'THIX ID non renseigné' : c.thixId,
                      time: null,
                      leadingIcon: _kind == 'video' ? Icons.videocam_rounded : Icons.call_rounded,
                      onTap: _busy ? null : () => _startCall(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ThixBottomSheetShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const ThixBottomSheetShell({super.key, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 680, maxHeight: h * 0.86),
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 44, height: 5, decoration: BoxDecoration(color: scheme.outlineVariant.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(99))),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                              if ((subtitle ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(subtitle!, style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70))),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.pop(),
                          style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory),
                          icon: Icon(Icons.close_rounded, color: scheme.onSurface),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ThixChatBackground extends StatelessWidget {
  const ThixChatBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface.withValues(alpha: 0.92),
            scheme.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _ThixRingsPainter(
          ring: scheme.primary.withValues(alpha: 0.05),
          ring2: scheme.tertiary.withValues(alpha: 0.06),
        ),
      ),
    );
  }
}

class _ThixRingsPainter extends CustomPainter {
  final Color ring;
  final Color ring2;
  const _ThixRingsPainter({required this.ring, required this.ring2});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.56, size.height * 0.78);
    final p1 = Paint()..style = PaintingStyle.stroke..strokeWidth = 34..color = ring..strokeCap = StrokeCap.round;
    final p2 = Paint()..style = PaintingStyle.stroke..strokeWidth = 22..color = ring2..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final r = size.shortestSide * (0.22 + i * 0.14);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), 0.5, 4.8, false, i.isEven ? p1 : p2);
    }
  }

  @override
  bool shouldRepaint(covariant _ThixRingsPainter oldDelegate) => oldDelegate.ring != ring || oldDelegate.ring2 != ring2;
}

class ThixContactsTab extends StatelessWidget {
  final AppUser me;
  final ChatService chat;
  final void Function(String chatId, String otherUid, String otherName) onOpenThread;
  const ThixContactsTab({super.key, required this.me, required this.chat, required this.onOpenThread});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: StreamBuilder<List<ChatContact>>(
        stream: chat.streamRecentContacts(uid: me.id, limit: 30),
        builder: (context, snap) {
          final contacts = snap.data ?? const <ChatContact>[];
          if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
            return const ThixChatLoadingState();
          }
          if (contacts.isEmpty) {
            return ThixChatEmptyState(
              title: 'Aucun contact récent',
              subtitle: 'Les contacts apparaissent après des échanges.',
              icon: Icons.contact_page_rounded,
            );
          }
          return ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final c = contacts[i];
              return ThixChatListTile(
                title: c.displayName,
                subtitle: c.thixId.isEmpty ? 'THIX ID non renseigné' : c.thixId,
                time: null,
                leadingIcon: Icons.person_rounded,
                onTap: () async {
                  try {
                    final other = AppUser(
                      id: c.uid,
                      thixId: c.thixId,
                      thixChat: '',
                      thixScore: null,
                      email: '',
                      phone: null,
                      displayName: c.displayName,
                      accountType: AccountType.personal,
                      photoUrl: null,
                      bio: null,
                      countryOrOrigin: null,
                      contactPhone: null,
                      maritalStatus: null,
                      gender: null,
                      occupation: null,
                      profession: null,
                      dateOfBirth: null,
                      placeOfBirth: null,
                      nationality: null,
                      address: null,
                      fatherName: null,
                      motherName: null,
                      emergencyContactName: null,
                      emergencyContactPhone: null,
                      emergencyContactRelation: null,
                      education: const [],
                      experience: const [],
                      skills: const [],
                      enrollments: const [],
                      languages: const [],
                      biometricsEnabled: true,
                      twoFaEnabled: false,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    final chatId = await chat.getOrCreateDirectChat(me: me, other: other);
                    onOpenThread(chatId, c.uid, c.displayName);
                  } catch (e) {
                    debugPrint('ContactsTab: open thread failed err=$e');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ThixStatusTab extends StatelessWidget {
  final AppUser me;
  final StatusService status;
  const ThixStatusTab({super.key, required this.me, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Column(
        children: [
          ThixStatusComposer(me: me, status: status),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: StreamBuilder<List<StatusUpdate>>(
              stream: status.streamActiveStatuses(),
              builder: (context, snap) {
                final list = snap.data ?? const <StatusUpdate>[];
                if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                  return const ThixChatLoadingState();
                }
                if (list.isEmpty) {
                  return ThixChatEmptyState(
                    title: 'Aucun statut actif',
                    subtitle: 'Publie un statut pour qu’il apparaisse ici.',
                    icon: Icons.auto_awesome_rounded,
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => ThixStatusCard(update: list[i], isMine: list[i].uid == me.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ThixChatListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime? time;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  const ThixChatListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.onTap,
    this.leadingIcon,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ThixAvatarChip(icon: leadingIcon ?? Icons.person_rounded),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(subtitle, style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (time != null)
                Text(
                  _formatTime(time!),
                  style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.55), fontWeight: FontWeight.w700),
                ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class ThixAvatarChip extends StatelessWidget {
  final IconData icon;
  const ThixAvatarChip({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppPremiumGradients.thixNavyToGold(scheme),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 18, color: scheme.onPrimary),
      ),
    );
  }
}

class ThixChatLoadingState extends StatelessWidget {
  const ThixChatLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
  }
}

class ThixChatEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const ThixChatEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(icon, color: scheme.onSurface.withValues(alpha: 0.65), size: 26),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(subtitle, style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70)), textAlign: TextAlign.center),
              if ((actionLabel ?? '').trim().isNotEmpty && onAction != null) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.tertiary,
                      foregroundColor: scheme.onTertiary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    ),
                    icon: Icon(Icons.person_search_rounded, size: 18, color: scheme.onTertiary),
                    label: Text(actionLabel!, style: context.textStyles.labelLarge?.copyWith(color: scheme.onTertiary, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ThixStartChatByThixIdSheet extends StatefulWidget {
  final AppUser me;
  final ChatService chat;
  const ThixStartChatByThixIdSheet({super.key, required this.me, required this.chat});

  @override
  State<ThixStartChatByThixIdSheet> createState() => _ThixStartChatByThixIdSheetState();
}

class _ThixStartChatByThixIdSheetState extends State<ThixStartChatByThixIdSheet> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _start() async {
    final raw = _c.text;
    final normalized = ThixIdService.normalize(raw);

    // We *prefer* a valid THIX ID, but in real usage users often:
    // - omit the checksum
    // - mistype the checksum digit
    // We try to canonicalize before rejecting.
    final canonical = ThixIdService.canonicalizeOrNull(normalized);

    if (!ThixIdService.isValid(normalized) && canonical == null) {
      // Still allow searching by handle (thix_chat) or a pasted identifier.
      // We don't hard fail here; we'll try lookup below.
      debugPrint('ThixStartChatByThixIdSheet: input not a valid THIX ID; will try lookup anyway raw=$raw normalized=$normalized');
    }
    setState(() => _busy = true);
    try {
      ChatContact? contact;
      final attempts = <String>{};
      if (ThixIdService.isValid(normalized)) attempts.add(normalized);
      if (canonical != null && ThixIdService.isValid(canonical)) attempts.add(canonical);

      // 1) Exact THIX ID match (best).
      for (final v in attempts) {
        contact = await widget.chat.fetchProfileByThixId(v);
        if (contact != null) break;
      }

      // 2) Exact match on thix_id OR thix_chat.
      contact ??= await widget.chat.fetchProfileByThixIdOrHandle(normalized);

      // 3) Last resort: a small search (useful when user pasted with spaces).
      if (contact == null) {
        final results = await widget.chat.searchProfiles(normalized, limit: 5);
        if (results.length == 1) contact = results.first;
      }

      if (!mounted) return;
      if (contact == null) {
        final hint = (canonical != null && canonical != normalized)
            ? 'Vérifie le THIX ID. Astuce: checksum attendu → $canonical'
            : 'Vérifie le THIX ID.';
        _snack('Utilisateur introuvable (ou accès refusé). $hint');
        return;
      }
      if (contact.uid == widget.me.id) {
        _snack('Impossible de démarrer un chat avec soi-même.');
        return;
      }
      context.pop(_SearchPick(uid: contact.uid, displayName: contact.displayName, thixId: contact.thixId));
    } catch (e) {
      debugPrint('ThixStartChatByThixIdSheet: start failed err=$e');
      _snack('Erreur de recherche.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Démarrer une discussion', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  _ThreadAction(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => context.pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Entre le THIX ID de la personne pour ouvrir directement la conversation.',
                style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70), height: 1.45),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _c,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'THIX ID',
                  hintText: ThixIdService.exampleV2,
                  prefixIcon: const Icon(Icons.verified_user_rounded),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
                onSubmitted: (_) {
                  if (_busy) return;
                  unawaited(_start());
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.tertiary,
                    foregroundColor: scheme.onTertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(Icons.chat_rounded, size: 18, color: scheme.onTertiary),
                  label: Text(_busy ? '...' : 'Ouvrir le chat', style: context.textStyles.labelLarge?.copyWith(color: scheme.onTertiary, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Status UI
// =============================================================================

class ThixStatusComposer extends StatefulWidget {
  final AppUser me;
  final StatusService status;
  const ThixStatusComposer({super.key, required this.me, required this.status});

  @override
  State<ThixStatusComposer> createState() => _ThixStatusComposerState();
}

class _ThixStatusComposerState extends State<ThixStatusComposer> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _postText() async {
    final text = _c.text.trim();
    if (text.isEmpty) {
      _snack('Écris un statut.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.status.postTextStatus(
        uid: widget.me.id,
        displayName: widget.me.displayName,
        thixId: widget.me.thixId,
        text: text,
      );
      _c.clear();
      _snack('Statut publié.');
    } catch (e) {
      debugPrint('ThixStatusComposer: postText failed err=$e');
      _snack('Erreur publication.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _postMedia(String kind) async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.pickFiles(withData: kIsWeb);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      await widget.status.postMediaStatus(
        uid: widget.me.id,
        displayName: widget.me.displayName,
        thixId: widget.me.thixId,
        statusType: kind,
        file: f,
        caption: _c.text.trim().isEmpty ? null : _c.text.trim(),
      );
      _c.clear();
      _snack('Statut publié.');
    } catch (e) {
      debugPrint('ThixStatusComposer: postMedia failed kind=$kind err=$e');
      _snack('Erreur publication média.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mon statut', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _c,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Partage une info…',
                hintStyle: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.45)),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.8), width: 1.2)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _postText,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(_busy ? '...' : 'Publier', style: context.textStyles.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ComposerIconButton(icon: Icons.photo_rounded, tooltip: 'Photo', onPressed: _busy ? null : () => _postMedia('photo')),
                const SizedBox(width: AppSpacing.sm),
                _ComposerIconButton(icon: Icons.videocam_rounded, tooltip: 'Vidéo', onPressed: _busy ? null : () => _postMedia('video')),
                const SizedBox(width: AppSpacing.sm),
                _ComposerIconButton(icon: Icons.mic_rounded, tooltip: 'Audio', onPressed: _busy ? null : () => _postMedia('audio')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const _ComposerIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 18, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class ThixStatusCard extends StatelessWidget {
  final StatusUpdate update;
  final bool isMine;
  const ThixStatusCard({super.key, required this.update, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ThixAvatarChip(icon: isMine ? Icons.verified_user_rounded : Icons.person_rounded),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(update.displayName, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        _statusMeta(update),
                        style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.60), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.auto_awesome_rounded, color: scheme.tertiary.withValues(alpha: 0.9)),
              ],
            ),
            if ((update.text).trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(update.text, style: context.textStyles.bodyMedium?.copyWith(height: 1.45)),
            ],
            if ((update.mediaUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.35)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(update.mediaUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image_rounded, color: scheme.onSurface.withValues(alpha: 0.5)))),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Text(
                                  update.statusType.toUpperCase(),
                                  style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusMeta(StatusUpdate u) {
    final exp = u.expiresAt.toLocal();
    final hh = exp.hour.toString().padLeft(2, '0');
    final mm = exp.minute.toString().padLeft(2, '0');
    final kind = _prettyKind(u.statusType);
    return 'Expire à $hh:$mm • $kind';
  }

  String _prettyKind(String raw) {
    final v = raw.trim().toLowerCase();
    // Some legacy rows / bad values end up storing "erreur" or other variants.
    // We normalize to something user-friendly instead of showing the raw value.
    if (v.isEmpty || v == 'erreur' || v == 'error') return 'texte';
    if (v == 'text') return 'texte';
    if (v == 'photo' || v == 'image') return 'photo';
    if (v == 'video' || v == 'vidéo') return 'vidéo';
    if (v == 'audio' || v == 'voice') return 'audio';
    return v;
  }
}

// =============================================================================
// Thread Sheet
// =============================================================================

class ThixChatThreadSheet extends StatefulWidget {
  final AppUser me;
  final String chatId;
  final String otherUid;
  final String otherName;
  final ChatService chat;
  final CallService calls;
  const ThixChatThreadSheet({
    super.key,
    required this.me,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
    required this.chat,
    required this.calls,
  });

  @override
  State<ThixChatThreadSheet> createState() => _ThixChatThreadSheetState();
}

class _ThixChatThreadSheetState extends State<ThixChatThreadSheet> {
  final _text = TextEditingController();
  bool _sending = false;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(widget.chat.markChatRead(chatId: widget.chatId, uid: widget.me.id));
    _text.addListener(_onTypingChanged);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _text.removeListener(_onTypingChanged);
    unawaited(widget.chat.setTyping(chatId: widget.chatId, isTyping: false));
    _text.dispose();
    super.dispose();
  }

  void _onTypingChanged() {
    final isTyping = _text.text.trim().isNotEmpty;
    unawaited(widget.chat.setTyping(chatId: widget.chatId, isTyping: isTyping));
    _typingDebounce?.cancel();
    if (!isTyping) return;
    _typingDebounce = Timer(const Duration(milliseconds: 1500), () {
      unawaited(widget.chat.setTyping(chatId: widget.chatId, isTyping: false));
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendText() async {
    final msg = _text.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.chat.sendMessage(chatId: widget.chatId, sender: widget.me, text: msg);
      _text.clear();
    } catch (e) {
      debugPrint('ThixChatThreadSheet: sendText failed err=$e');
      _snack('Erreur envoi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment() async {
    setState(() => _sending = true);
    try {
      final result = await FilePicker.pickFiles(withData: kIsWeb);
      if (result == null || result.files.isEmpty) return;
      await widget.chat.sendAttachment(chatId: widget.chatId, sender: widget.me, file: result.files.first);
    } catch (e) {
      debugPrint('ThixChatThreadSheet: sendAttachment failed err=$e');
      _snack('Erreur pièce jointe.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendMeeting() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ThixMeetingComposerSheet(
        onSubmit: (title, at, duration, location, note) async {
          try {
            await widget.chat.sendMeetingInvite(
              chatId: widget.chatId,
              sender: widget.me,
              title: title,
              scheduledAt: at,
              durationMinutes: duration,
              location: location,
              note: note,
            );
            _snack('Invitation meeting envoyée.');
          } catch (e) {
            debugPrint('ThixChatThreadSheet: sendMeeting failed err=$e');
            _snack('Erreur meeting.');
          }
        },
      ),
    );
  }

  Future<void> _sendMoney() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ThixMoneyComposerSheet(
        onSubmit: (senderPhone, receiverPhone, network, amount, currency, note, password) async {
          // Password validation here is UI-only. Real verification should be done
          // server-side via provider API / Edge Function.
          if (password.trim().length < 4) {
            _snack('Mot de passe trop court.');
            return;
          }
          try {
            await widget.chat.sendMoneyTransfer(
              chatId: widget.chatId,
              sender: widget.me,
              senderPhone: senderPhone,
              receiverPhone: receiverPhone,
              network: network,
              amount: amount,
              currency: currency,
              note: note,
            );
            _snack('Transfert envoyé.');
          } catch (e) {
            debugPrint('ThixChatThreadSheet: sendMoney failed err=$e');
            _snack('Erreur transfert.');
          }
        },
      ),
    );
  }

  Future<void> _startCall(String kind) async {
    try {
      await widget.chat.sendCallRequest(chatId: widget.chatId, sender: widget.me, kind: kind);
      final id = await widget.calls.startCall(chatId: widget.chatId, kind: kind, receiverId: widget.otherUid);
      debugPrint('Call started id=$id kind=$kind chat=${widget.chatId}');
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => ThixAgoraCallSheet(
          callId: id,
          otherUserId: widget.otherUid,
          kind: kind == 'video' ? 'video' : 'audio',
          isCaller: true,
          calls: widget.calls,
        ),
      );
    } catch (e) {
      debugPrint('ThixChatThreadSheet: startCall failed kind=$kind err=$e');
      _snack('Erreur appel.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.otherName, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        StreamBuilder<List<String>>(
                          stream: widget.chat.streamTypingUsers(chatId: widget.chatId, excludeUid: widget.me.id),
                          builder: (context, snap) {
                            final typing = (snap.data ?? const <String>[]).isNotEmpty;
                            if (typing) {
                              return Text('Écrit…', style: context.textStyles.labelSmall?.copyWith(color: scheme.primary.withValues(alpha: 0.95), fontWeight: FontWeight.w900));
                            }
                            return StreamBuilder<DateTime?>(
                              stream: widget.chat.streamReadAt(chatId: widget.chatId, uid: widget.otherUid),
                              builder: (context, readSnap) {
                                final v = readSnap.data;
                                final label = v == null ? 'Non vu' : 'Vu';
                                return Text(label, style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.55), fontWeight: FontWeight.w700));
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  _ThreadAction(icon: Icons.call_rounded, tooltip: 'Appel audio', onTap: () => _startCall('audio')),
                  const SizedBox(width: AppSpacing.sm),
                  _ThreadAction(icon: Icons.videocam_rounded, tooltip: 'Appel vidéo', onTap: () => _startCall('video')),
                  const SizedBox(width: AppSpacing.sm),
                  _ThreadAction(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => context.pop()),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: widget.chat.streamMessages(widget.chatId),
                builder: (context, snap) {
                  final list = snap.data ?? const <ChatMessage>[];
                  if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                    return const ThixChatLoadingState();
                  }
                  if (list.isEmpty) {
                    return ThixChatEmptyState(
                      title: 'Démarre la conversation',
                      subtitle: 'Envoie un message ou utilise les actions ci-dessous.',
                      icon: Icons.mark_chat_unread_rounded,
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final m = list[i];
                      final mine = m.senderId == widget.me.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ThixMessageBubble(message: m, isMine: mine),
                      );
                    },
                  );
                },
              ),
            ),
            ThixThreadComposer(
              controller: _text,
              busy: _sending,
              onSend: _sendText,
              onAttach: _sendAttachment,
              onMeeting: _sendMeeting,
              onMoney: _sendMoney,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ThreadAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 18, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class ThixThreadComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onMoney;
  final VoidCallback onMeeting;
  const ThixThreadComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onAttach,
    required this.onMoney,
    required this.onMeeting,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ComposerIconButton(icon: Icons.attach_file_rounded, tooltip: 'Pièce jointe', onPressed: busy ? null : onAttach),
              const SizedBox(width: AppSpacing.sm),
              _ComposerIconButton(icon: Icons.calendar_month_rounded, tooltip: 'Meeting', onPressed: busy ? null : onMeeting),
              const SizedBox(width: AppSpacing.sm),
              _ComposerIconButton(icon: Icons.payments_rounded, tooltip: 'Transfert', onPressed: busy ? null : onMoney),
              const Spacer(),
              Text(busy ? 'Envoi…' : '', style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.55), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Écrire un message…',
                    hintStyle: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.45)),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.8), width: 1.2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: busy ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.tertiary,
                  foregroundColor: scheme.onTertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
                child: Icon(Icons.send_rounded, color: scheme.onTertiary, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ThixMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  const ThixMessageBubble({super.key, required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isMine ? AppPremiumGradients.thixNavyToGold(scheme) : LinearGradient(colors: [scheme.surfaceContainerHighest, scheme.surface]);
    final fg = isMine ? scheme.onPrimary : scheme.onSurface;

    final rich = _tryMoneyPayload(message.text);
    final isMoney = rich != null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: bg,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Text(
                    message.senderName.isEmpty ? 'Utilisateur' : message.senderName,
                    style: context.textStyles.labelSmall?.copyWith(color: fg.withValues(alpha: 0.85), fontWeight: FontWeight.w900),
                  ),
                if (!isMine) const SizedBox(height: 6),
                if (isMoney)
                  ThixMoneyBubble(payload: rich!, isMine: isMine)
                else
                  Text(
                    message.text.trim().isEmpty ? '…' : message.text,
                    style: context.textStyles.bodyMedium?.copyWith(color: fg, height: 1.45, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _formatTs(message.createdAt),
                    style: context.textStyles.labelSmall?.copyWith(color: fg.withValues(alpha: 0.70), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTs(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Map<String, dynamic>? _tryMoneyPayload(String raw) {
    final t = raw.trim();
    if (!t.startsWith(ChatService.moneyTransferMarker)) return null;
    final payloadPart = t.substring(ChatService.moneyTransferMarker.length);
    final firstNewline = payloadPart.indexOf('\n');
    final jsonText = (firstNewline >= 0) ? payloadPart.substring(0, firstNewline) : payloadPart;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('ThixMessageBubble: money payload parse failed err=$e');
      return null;
    }
  }
}

class ThixMoneyBubble extends StatelessWidget {
  final Map<String, dynamic> payload;
  final bool isMine;
  const ThixMoneyBubble({super.key, required this.payload, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = (payload['amount'] ?? '').toString();
    final currency = (payload['currency'] ?? '').toString();
    final network = (payload['network'] ?? '').toString();
    final receiver = (payload['receiver_phone'] ?? '').toString();
    final status = (payload['status'] ?? 'pending').toString();
    final note = (payload['note'] ?? '').toString();

    final tagBg = isMine ? Colors.white.withValues(alpha: 0.18) : scheme.primary.withValues(alpha: 0.10);
    final tagFg = isMine ? scheme.onPrimary : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.payments_rounded, color: isMine ? scheme.onPrimary : scheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Transfert',
                style: context.textStyles.titleMedium?.copyWith(color: isMine ? scheme.onPrimary : scheme.onSurface, fontWeight: FontWeight.w900),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(AppRadius.full)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  status.toUpperCase(),
                  style: context.textStyles.labelSmall?.copyWith(color: tagFg, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '$amount $currency',
          style: context.textStyles.headlineMedium?.copyWith(color: isMine ? scheme.onPrimary : scheme.onSurface, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Réseau: $network',
          style: context.textStyles.bodyMedium?.copyWith(color: (isMine ? scheme.onPrimary : scheme.onSurface).withValues(alpha: 0.85), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          'Vers: $receiver',
          style: context.textStyles.bodyMedium?.copyWith(color: (isMine ? scheme.onPrimary : scheme.onSurface).withValues(alpha: 0.85), fontWeight: FontWeight.w700),
        ),
        if (note.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            note,
            style: context.textStyles.bodyMedium?.copyWith(color: (isMine ? scheme.onPrimary : scheme.onSurface).withValues(alpha: 0.85), height: 1.35),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// New chat / Search sheets
// =============================================================================

class ThixChatSearchSheet extends StatefulWidget {
  final AppUser me;
  final ChatService chat;
  const ThixChatSearchSheet({super.key, required this.me, required this.chat});

  @override
  State<ThixChatSearchSheet> createState() => _ThixChatSearchSheetState();
}

class _ThixChatSearchSheetState extends State<ThixChatSearchSheet> {
  final _c = TextEditingController();
  Timer? _debounce;
  bool _busy = false;
  String _q = '';
  List<ChatContact> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(v));
  }

  Future<void> _search(String v) async {
    final q = v.trim();
    setState(() {
      _q = q;
      _busy = true;
    });
    try {
      if (q.isEmpty) {
        setState(() {
          _results = const [];
          _busy = false;
        });
        return;
      }
      final list = await widget.chat.searchProfiles(q, limit: 30);
      if (!mounted) return;
      setState(() {
        _results = list.where((e) => e.uid != widget.me.id).toList(growable: false);
      });
    } catch (e) {
      debugPrint('ThixChatSearchSheet: search failed err=$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Rechercher', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  _ThreadAction(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => context.pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _c,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Nom / THIX ID / @handle',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _busy && _results.isEmpty
                    ? const ThixChatLoadingState()
                    : _q.isEmpty
                        ? ThixChatEmptyState(
                            title: 'Recherche',
                            subtitle: 'Tape un nom, THIX ID, ou @handle.',
                            icon: Icons.manage_search_rounded,
                          )
                        : _results.isEmpty
                            ? ThixChatEmptyState(
                                title: 'Aucun résultat',
                                subtitle: 'Essaie une autre recherche.',
                                icon: Icons.search_off_rounded,
                              )
                            : ListView.separated(
                                itemCount: _results.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, i) {
                                  final r = _results[i];
                                  return ThixChatListTile(
                                    title: r.displayName,
                                    subtitle: r.thixId.isEmpty ? r.uid : r.thixId,
                                    time: null,
                                    leadingIcon: Icons.person_rounded,
                                    onTap: () => context.pop(_SearchPick(uid: r.uid, displayName: r.displayName, thixId: r.thixId)),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPick {
  final String uid;
  final String displayName;
  final String thixId;
  const _SearchPick({required this.uid, required this.displayName, required this.thixId});
}

class ThixChatNewChatSheet extends StatelessWidget {
  final AppUser me;
  final ChatService chat;
  const ThixChatNewChatSheet({super.key, required this.me, required this.chat});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Nouveau chat', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  _ThreadAction(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => context.pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showModalBottomSheet<_SearchPick?>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        useSafeArea: true,
                        builder: (_) => ThixStartChatByThixIdSheet(me: me, chat: chat),
                      );
                      if (picked == null) return;
                      if (!context.mounted) return;
                      // Convert pick to a chat and return it.
                      final other = AppUser(
                        id: picked.uid,
                        thixId: picked.thixId,
                        thixChat: '',
                        thixScore: null,
                        email: '',
                        phone: null,
                        displayName: picked.displayName,
                        accountType: AccountType.personal,
                        photoUrl: null,
                        bio: null,
                        countryOrOrigin: null,
                        contactPhone: null,
                        maritalStatus: null,
                        gender: null,
                        occupation: null,
                        profession: null,
                        dateOfBirth: null,
                        placeOfBirth: null,
                        nationality: null,
                        address: null,
                        fatherName: null,
                        motherName: null,
                        emergencyContactName: null,
                        emergencyContactPhone: null,
                        emergencyContactRelation: null,
                        education: const [],
                        experience: const [],
                        skills: const [],
                        enrollments: const [],
                        languages: const [],
                        biometricsEnabled: true,
                        twoFaEnabled: false,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      try {
                        final chatId = await chat.getOrCreateDirectChat(me: me, other: other);
                        if (!context.mounted) return;
                        context.pop(_NewChatPick(chatId: chatId, otherUid: picked.uid, title: picked.displayName));
                      } catch (e) {
                        debugPrint('NewChatSheet: start by thix id failed err=$e');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
                    ),
                    icon: const Icon(Icons.person_search_rounded, size: 18),
                    label: Text('Trouver par THIX ID', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final created = await showModalBottomSheet<_NewChatPick?>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      useSafeArea: true,
                      builder: (_) => ThixGroupComposerSheet(me: me, chat: chat),
                    );
                    if (created == null) return;
                    if (!context.mounted) return;
                    context.pop(created);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  ),
                  icon: Icon(Icons.group_add_rounded, size: 18, color: scheme.onPrimary),
                  label: Text('Créer un groupe', style: context.textStyles.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                  'Tu peux aussi lancer un chat depuis la recherche (loupe) ou depuis tes contacts récents ci-dessous.',
                style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70), height: 1.45),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: StreamBuilder<List<ChatContact>>(
                  stream: chat.streamRecentContacts(uid: me.id, limit: 12),
                  builder: (context, snap) {
                    final list = snap.data ?? const <ChatContact>[];
                    if (list.isEmpty) {
                      return ThixChatEmptyState(
                        title: 'Suggestions',
                        subtitle: 'Tes contacts récents apparaîtront ici.',
                        icon: Icons.auto_awesome_rounded,
                      );
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return ThixChatListTile(
                          title: c.displayName,
                          subtitle: c.thixId.isEmpty ? 'Contact' : c.thixId,
                          time: null,
                        onTap: () async {
                          try {
                            final other = AppUser(
                              id: c.uid,
                              thixId: c.thixId,
                              thixChat: '',
                              thixScore: null,
                              email: '',
                              phone: null,
                              displayName: c.displayName,
                              accountType: AccountType.personal,
                              photoUrl: null,
                              bio: null,
                              countryOrOrigin: null,
                              contactPhone: null,
                              maritalStatus: null,
                              gender: null,
                              occupation: null,
                              profession: null,
                              dateOfBirth: null,
                              placeOfBirth: null,
                              nationality: null,
                              address: null,
                              fatherName: null,
                              motherName: null,
                              emergencyContactName: null,
                              emergencyContactPhone: null,
                              emergencyContactRelation: null,
                              education: const [],
                              experience: const [],
                              skills: const [],
                              enrollments: const [],
                              languages: const [],
                              biometricsEnabled: true,
                              twoFaEnabled: false,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            );
                            final chatId = await chat.getOrCreateDirectChat(me: me, other: other);
                            if (!context.mounted) return;
                            context.pop(_NewChatPick(chatId: chatId, otherUid: c.uid, title: c.displayName));
                          } catch (e) {
                            debugPrint('NewChatSheet: open direct failed err=$e');
                          }
                        },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChatPick {
  final String chatId;
  final String otherUid;
  final String title;
  const _NewChatPick({required this.chatId, required this.otherUid, required this.title});
}

class ThixGroupComposerSheet extends StatefulWidget {
  final AppUser me;
  final ChatService chat;
  const ThixGroupComposerSheet({super.key, required this.me, required this.chat});

  @override
  State<ThixGroupComposerSheet> createState() => _ThixGroupComposerSheetState();
}

class _ThixGroupComposerSheetState extends State<ThixGroupComposerSheet> {
  final _title = TextEditingController();
  final _q = TextEditingController();
  Timer? _debounce;
  bool _busy = false;
  List<ChatContact> _results = const [];
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String v) async {
    final q = v.trim();
    setState(() => _busy = true);
    try {
      if (q.isEmpty) {
        setState(() => _results = const []);
        return;
      }
      final list = await widget.chat.searchProfiles(q, limit: 30);
      if (!mounted) return;
      setState(() => _results = list.where((e) => e.uid != widget.me.id).toList(growable: false));
    } catch (e) {
      debugPrint('ThixGroupComposerSheet: search failed err=$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final title = _title.text.trim().isEmpty ? 'Groupe' : _title.text.trim();
    if (_selected.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoute au moins 1 membre.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final chatId = await widget.chat.createGroup(me: widget.me, title: title, memberUids: _selected.toList(growable: false));
      if (!mounted) return;
      context.pop(_NewChatPick(chatId: chatId, otherUid: widget.me.id, title: title));
    } catch (e) {
      debugPrint('ThixGroupComposerSheet: createGroup failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur création groupe.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.86,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Nouveau groupe', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  _ThreadAction(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => context.pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Nom du groupe', prefixIcon: Icon(Icons.badge_rounded))),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _q,
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 250), () => _search(v));
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher des membres…',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _busy && _results.isEmpty
                    ? const ThixChatLoadingState()
                    : _results.isEmpty
                        ? ThixChatEmptyState(title: 'Membres', subtitle: 'Cherche des utilisateurs et coche-les.', icon: Icons.group_rounded)
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, i) {
                              final r = _results[i];
                              final selected = _selected.contains(r.uid);
                              return Material(
                                color: scheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                                ),
                                child: InkWell(
                                  onTap: () => setState(() => selected ? _selected.remove(r.uid) : _selected.add(r.uid)),
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    child: Row(
                                      children: [
                                        Checkbox(value: selected, onChanged: (_) => setState(() => selected ? _selected.remove(r.uid) : _selected.add(r.uid))),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(r.displayName, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 4),
                                              Text(r.thixId.isEmpty ? r.uid : r.thixId, style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary),
                  label: Text(_busy ? '...' : 'Créer', style: context.textStyles.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Meeting / Money composers
// =============================================================================

class ThixMeetingComposerSheet extends StatefulWidget {
  final Future<void> Function(String title, DateTime at, int durationMinutes, String? location, String? note) onSubmit;
  const ThixMeetingComposerSheet({super.key, required this.onSubmit});

  @override
  State<ThixMeetingComposerSheet> createState() => _ThixMeetingComposerSheetState();
}

class _ThixMeetingComposerSheetState extends State<ThixMeetingComposerSheet> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  DateTime _when = DateTime.now().add(const Duration(minutes: 30));
  int _duration = 30;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _when,
    );
    if (date == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        _title.text.trim().isEmpty ? 'Meeting' : _title.text.trim(),
        _when,
        _duration,
        _location.text.trim().isEmpty ? null : _location.text.trim(),
        _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('ThixMeetingComposerSheet: submit failed err=$e');
      _snack('Erreur meeting.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Créer un meeting', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  _ThreadAction(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => context.pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Titre', prefixIcon: Icon(Icons.event_rounded))),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: _location, decoration: const InputDecoration(labelText: 'Lieu (optionnel)', prefixIcon: Icon(Icons.place_rounded))),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: _note, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Note (optionnel)', prefixIcon: Icon(Icons.notes_rounded))),
              const SizedBox(height: AppSpacing.md),
              Material(
                color: scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quand', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(_when.toLocal().toString().substring(0, 16), style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pickTime,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                        ),
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: const Text('Choisir'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: Text('Durée (min)', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 15, label: Text('15')),
                      ButtonSegment(value: 30, label: Text('30')),
                      ButtonSegment(value: 60, label: Text('60')),
                    ],
                    selected: {_duration},
                    onSelectionChanged: _busy ? null : (s) => setState(() => _duration = s.first),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(_busy ? '...' : 'Envoyer', style: context.textStyles.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThixMoneyComposerSheet extends StatefulWidget {
  final Future<void> Function(
    String senderPhone,
    String receiverPhone,
    String network,
    String amount,
    String currency,
    String? note,
    String password,
  ) onSubmit;
  const ThixMoneyComposerSheet({super.key, required this.onSubmit});

  @override
  State<ThixMoneyComposerSheet> createState() => _ThixMoneyComposerSheetState();
}

class _IncomingCallSheet extends StatelessWidget {
  final String kind;
  final String callerId;
  final VoidCallback onDecline;
  final VoidCallback onAccept;
  const _IncomingCallSheet({required this.kind, required this.callerId, required this.onDecline, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isVideo = kind == 'video';
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.42,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppPremiumGradients.thixNavyToGold(scheme),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded, size: 18, color: scheme.onPrimary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Appel entrant', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          'De: $callerId',
                          style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isVideo ? 'Quelqu’un t’appelle en vidéo.' : 'Quelqu’un t’appelle en audio.',
                style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70), height: 1.45),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.9)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.call_end_rounded, size: 18),
                      label: Text('Refuser', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(Icons.call_rounded, size: 18, color: scheme.onPrimary),
                      label: Text('Accepter', style: context.textStyles.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThixMoneyComposerSheetState extends State<ThixMoneyComposerSheet> {
  final _sender = TextEditingController();
  final _receiver = TextEditingController();
  final _network = TextEditingController();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'XOF');
  final _note = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _sender.dispose();
    _receiver.dispose();
    _network.dispose();
    _amount.dispose();
    _currency.dispose();
    _note.dispose();
    _password.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        _sender.text,
        _receiver.text,
        _network.text,
        _amount.text,
        _currency.text,
        _note.text.trim().isEmpty ? null : _note.text.trim(),
        _password.text,
      );
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('ThixMoneyComposerSheet: submit failed err=$e');
      _snack('Erreur transfert.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.86,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Transfert (sans wallet)', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  _ThreadAction(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => context.pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Numéro expéditeur + numéro destinataire + réseau, puis confirmation par mot de passe.',
                style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.70), height: 1.45),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(controller: _sender, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Numéro expéditeur', prefixIcon: Icon(Icons.phone_rounded))),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: _receiver, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Numéro destinataire', prefixIcon: Icon(Icons.phone_android_rounded))),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: _network, decoration: const InputDecoration(labelText: 'Réseau (ex: Orange / MTN)', prefixIcon: Icon(Icons.cell_tower_rounded))),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant', prefixIcon: Icon(Icons.money_rounded)))),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 92,
                    child: TextField(controller: _currency, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Devise')),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: _note, minLines: 1, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optionnel)', prefixIcon: Icon(Icons.edit_note_rounded))),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe de confirmation', prefixIcon: Icon(Icons.lock_rounded)),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(_busy ? '...' : 'Envoyer', style: context.textStyles.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
