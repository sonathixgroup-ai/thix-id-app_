import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/alert_info_sheet.dart';
import 'package:thix_id/presentation/emergency/emergency_fab.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import '../../theme.dart';
import '../../nav.dart';

// ... (les classes PremiumGridCard, HomeQuickAccessGrid, _NotificationBadge,
// RichGoldAction, HomeGoldBandAction, _LanguageTile, etc. sont conservées
// telles quelles, mais elles ne sont plus utilisées dans la nouvelle UI.
// Elles restent définies pour éviter des erreurs de compilation si elles sont
// référencées ailleurs.)

// Nouveau widget pour une carte de service dans la grille "Nos services"
class _ServiceGridCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _ServiceGridCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2C3E);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold).withAlpha(80),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: LightModeColors.accent.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: LightModeColors.accent, size: 26),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: LightModeColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Nouveau widget pour l'aperçu des notifications (similaire à l'ancien mais plus épuré)
class _HomeNotificationsPreview extends StatelessWidget {
  final bool isAuthenticated;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final VoidCallback onSeeMore;
  final void Function(String notificationId) onMarkRead;
  final void Function(Map<String, dynamic> row)? onOpen;

  const _HomeNotificationsPreview({
    required this.isAuthenticated,
    required this.notifications,
    required this.onSeeMore,
    required this.onMarkRead,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldBorder = (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold).withAlpha(140);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: goldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none_rounded, color: LightModeColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeMore,
                style: TextButton.styleFrom(
                  foregroundColor: LightModeColors.accent,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 32),
                ),
                child: const Text('Voir tout >'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isAuthenticated)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Annonces officielles THIX ID. Connectez-vous pour recevoir aussi vos notifications personnelles.',
                style: TextStyle(fontSize: 12, color: LightModeColors.secondaryText),
              ),
            )
          else
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: notifications,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aucune notification récente.', style: TextStyle(color: LightModeColors.secondaryText)),
                  );
                }
                final shown = rows.take(2).toList();
                return Column(
                  children: shown.map((notif) {
                    final id = (notif['id'] ?? '').toString();
                    final title = (notif['title'] ?? 'Notification') as String;
                    final body = (notif['body'] ?? '') as String;
                    final read = (notif['read'] ?? false) as bool;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: read ? Colors.grey.shade400 : LightModeColors.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: TextStyle(fontWeight: read ? FontWeight.w500 : FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(body, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (!read) onMarkRead(id);
                              if (onOpen != null) onOpen!(notif);
                            },
                            child: const Icon(Icons.chevron_right_rounded, size: 18),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  final _notifications = NotificationService();
  final _counters = NotificationCountersService();

  static final RegExp _uidLikeRegex = RegExp(r'^[A-Za-z0-9_\-]{20,}$');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showLanguagePicker() async {
    final localeCtrl = context.read<LocaleController>();
    final currentCode = localeCtrl.locale?.languageCode;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: LightModeColors.metalGold.withAlpha(90)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 24, offset: const Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [LightModeColors.accent, LightModeColors.metalGold]),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.language_rounded, color: Color(0xFF0A2F5C), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.loc.t('choose_language'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.close_rounded, color: cs.onSurface),
                      style: const ButtonStyle(overlayColor: WidgetStatePropertyAll(Colors.transparent)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LanguageTile(
                  label: context.loc.t('system_default'),
                  selected: currentCode == null,
                  onTap: () async {
                    await localeCtrl.setSystem();
                    if (context.mounted) context.pop();
                  },
                ),
                const SizedBox(height: 6),
                ...LocaleController.supportedLocales.map((l) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _LanguageTile(
                      label: AppLocalizations.localeLabel(l),
                      selected: currentCode == l.languageCode,
                      onTap: () async {
                        await localeCtrl.setLocale(l);
                        if (context.mounted) context.pop();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleHomeSearchVerify() async {
    final raw = _searchController.text.trim();
    if (raw.isEmpty) {
      await FullScreenMessage.showError(
        context,
        title: 'Identifiant requis',
        message: "Saisissez un THIX ID (ex: ${ThixIdService.exampleV2}) ou un UID, puis appuyez sur 'Vérifier'.",
      );
      return;
    }

    final normalized = ThixIdService.normalize(raw);
    final isThix = normalized.startsWith('THIX-') && ThixIdService.isValid(normalized);
    final isUid = _uidLikeRegex.hasMatch(raw);
    if (!isThix && !isUid) {
      await FullScreenMessage.showError(
        context,
        title: 'Identifiant invalide',
        message: 'Format attendu: ${ThixIdService.exampleV2} (recommandé) ou ${ThixIdService.exampleV1} ou UID (identifiant long alphanumérique).',
      );
      return;
    }

    setState(() => _searching = true);
    try {
      final userService = FirestoreUserService();
      AppUser? user;
      if (isThix) {
        user = await userService.fetchUserByThixId(normalized);
      } else {
        user = await userService.fetchUserByUid(raw);
      }

      if (!mounted) return;

      if (user == null) {
        await FullScreenMessage.showError(
          context,
          title: 'Profil introuvable',
          message: "Aucun profil n'a été trouvé pour l'identifiant: ${normalized.toUpperCase()}.",
        );
        return;
      }

      final thix = user.thixId.trim().toUpperCase();
      if (thix.isNotEmpty && ThixIdService.isValid(thix)) {
        context.push('${AppRoutes.publicProfile}?thixId=$thix');
      } else {
        await ThixIdentitySheets.showVerifySheet(context, initialUidOrThixId: user.id);
      }
    } catch (e) {
      if (!mounted) return;
      await FullScreenMessage.showError(
        context,
        title: 'Erreur de recherche',
        message: "Impossible d'exécuter la vérification. Réessayez.\n\nDétail: $e",
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _handleRequestAccount(BuildContext context) async {
    final auth = context.read<AuthController>();
    final res = await showModalBottomSheet<_AccountRequestChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AccountRequestSheet(),
    );

    switch (res) {
      case _AccountRequestChoice.personal:
        if (auth.isAuthenticated) await auth.signOut();
        if (context.mounted) context.push(AppRoutes.personalReg);
        return;
      case _AccountRequestChoice.enterprise:
        if (auth.isAuthenticated) await auth.signOut();
        if (context.mounted) context.push(AppRoutes.enterpriseReg);
        return;
      case null:
        return;
    }
  }

  // Méthode pour gérer le tap sur "Services" dans la bottom bar
  void _onServicesTap() {
    // Fait défiler jusqu'à la section "Nos services"
    // Pour simplifier, on peut afficher un message ou ne rien faire.
    // Conforme au design sans altérer les fonctionnalités.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Section Services (fonctionnalité à venir)'), duration: Duration(seconds: 1)),
    );
  }

  void _onMessagesTap() {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      final me = auth.currentUser;
      if (me != null) {
        unawaited(_counters.markSectionSeen(uid: me.id, section: ThixSection.messages));
      }
      context.push(AppRoutes.chat);
    } else {
      context.push(AppRoutes.login);
    }
  }

  void _onProfileTap() {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      final t = auth.currentUser?.accountType;
      context.go(t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard);
    } else {
      context.push(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final unreadStream = auth.currentUser == null ? Stream<int>.value(0) : _notifications.streamUnreadCount(auth.currentUser!.id);
    final badgeCountsStream = auth.currentUser == null ? Stream<SectionBadgeCounts>.value(SectionBadgeCounts.zero) : _counters.streamCounts(auth.currentUser!.id);
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder = (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold).withAlpha(150);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final safeTop = MediaQuery.paddingOf(context).top;
    final w = MediaQuery.sizeOf(context).width;
    final isCompact = w < 380;

    // Calcul de l'espace réservé pour les FABs (Urgence + Chat) en bas
    const double fabSpace = 80.0;

    return Scaffold(
      backgroundColor: isDark ? context.theme.scaffoldBackgroundColor : LightModeColors.surface,
      body: Stack(
        children: [
          // Contenu principal scrollable
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === EN-TÊTE THIX ID (bleu dégradé) ===
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      width: double.infinity,
                      height: (isCompact ? 180 : 200) + safeTop,
                      padding: EdgeInsets.only(top: safeTop),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF0A2F5C), Color(0xFF0F2B4A)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -80,
                            bottom: -40,
                            child: Icon(Icons.fingerprint, size: 280, color: LightModeColors.accent.withAlpha(15)),
                          ),
                          Positioned(
                            left: -60,
                            top: -10,
                            child: Icon(Icons.security, size: 180, color: LightModeColors.accent.withAlpha(10)),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: safeTop + (isCompact ? 40 : 48)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  border: Border.all(color: LightModeColors.accent, width: 1.5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.fingerprint, color: LightModeColors.accent, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('THIX ID', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                                    const Text('Identité Sécurisée. Avenir de Confiance.', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w300)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _showLanguagePicker,
                                style: const ButtonStyle(overlayColor: WidgetStatePropertyAll(Colors.transparent)),
                                icon: const Icon(Icons.language_rounded, color: Colors.white),
                                tooltip: context.loc.t('language'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Message "Bienvenue ! Que voulez-vous faire aujourd'hui ?" (comme sur la photo)
                          const Text(
                            'Bienvenue ! Que voulez-vous faire aujourd’hui ?',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          // Barre de recherche + bouton Vérifier
                          Container(
                            width: w * 0.9,
                            height: 52,
                            decoration: BoxDecoration(
                              color: context.theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 12, offset: const Offset(0, 6))],
                              border: Border.all(color: goldBorder),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: LightModeColors.hint, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) => _searching ? null : _handleHomeSearchVerify(),
                                    decoration: InputDecoration(
                                      hintText: 'Rechercher un THIX ID...',
                                      hintStyle: const TextStyle(color: LightModeColors.hint, fontSize: 14),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _searching ? null : _handleHomeSearchVerify,
                                  child: Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: const LinearGradient(colors: [LightModeColors.accent, LightModeColors.metalGold]),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Vérifier',
                                      style: const TextStyle(color: Color(0xFF0A2F5C), fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // === ACTIONS RAPIDES : Scanner QR & Lire via NFC ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scanner un QR',
                          onTap: () => ThixIdentitySheets.showQrScanSheet(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.nfc_rounded,
                          label: 'Lire via NFC',
                          onTap: () => ThixIdentitySheets.showNfcScanSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // === PANEL NOTIFICATIONS ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _HomeNotificationsPreview(
                    isAuthenticated: auth.isAuthenticated,
                    notifications: _notifications.streamForHome(uid: auth.currentUser?.id),
                    onSeeMore: () {
                      if (!auth.isAuthenticated) {
                        context.push(AppRoutes.login);
                        return;
                      }
                      NotificationsSheet.show(context);
                    },
                    onMarkRead: (notificationId) {
                      final me = auth.currentUser;
                      if (me == null) return;
                      _notifications.markRead(uid: me.id, notificationId: notificationId);
                    },
                    onOpen: (row) async {
                      if (!auth.isAuthenticated) {
                        context.push(AppRoutes.login);
                        return;
                      }
                      final me = auth.currentUser;
                      if (me == null) return;
                      final type = (row['type'] ?? '').toString().toLowerCase();
                      try {
                        if (type.contains('message') || type.contains('chat')) {
                          await _counters.markSectionSeen(uid: me.id, section: ThixSection.messages);
                          if (context.mounted) context.push(AppRoutes.chat);
                          return;
                        }
                        if (type.contains('opportun')) {
                          await _counters.markSectionSeen(uid: me.id, section: ThixSection.opportunities);
                          if (context.mounted) context.push(AppRoutes.opportunities);
                          return;
                        }
                        if (type.contains('job') || type.contains('emploi') || type.contains('offer')) {
                          await _counters.markSectionSeen(uid: me.id, section: ThixSection.jobs);
                          if (context.mounted) context.push(AppRoutes.jobs);
                          return;
                        }
                        if (type.contains('event') || type.contains('evenement') || type.contains('événement')) {
                          await _counters.markSectionSeen(uid: me.id, section: ThixSection.events);
                          if (context.mounted) context.push(AppRoutes.events);
                          return;
                        }
                      } catch (e) {
                        debugPrint('HomePage: open notification failed type=$type err=$e');
                      }
                      if (context.mounted) NotificationsSheet.show(context);
                    },
                  ),
                ),
                const SizedBox(height: 28),

                // === NOS SERVICES (grille 8 cartes) ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nos services',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0A2F5C)),
                          ),
                          TextButton(
                            onPressed: () {
                              // Option "Tout voir" si besoin, ici on peut juste défiler
                            },
                            child: const Text('Tout voir >', style: TextStyle(color: LightModeColors.accent, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<SectionBadgeCounts>(
                        stream: badgeCountsStream,
                        builder: (context, badgeSnap) {
                          final counts = badgeSnap.data ?? SectionBadgeCounts.zero;
                          return GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: [
                              _ServiceGridCard(
                                icon: Icons.person_add_alt_1_rounded,
                                label: 'Demander un Compte',
                                onTap: () => _handleRequestAccount(context),
                              ),
                              _ServiceGridCard(
                                icon: Icons.account_circle_rounded,
                                label: 'Mon Compte',
                                badgeCount: 0, // on peut éventuellement afficher le badge des notifs non lues
                                onTap: () {
                                  if (auth.isAuthenticated) {
                                    final t = auth.currentUser?.accountType;
                                    context.go(t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard);
                                  } else {
                                    context.push(AppRoutes.login);
                                  }
                                },
                              ),
                              _ServiceGridCard(
                                icon: Icons.school_rounded,
                                label: 'Formations',
                                badgeCount: counts.formations,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.formations);
                                  if (context.mounted) context.push(AppRoutes.trainingHome);
                                },
                              ),
                              _ServiceGridCard(
                                icon: Icons.work_rounded,
                                label: 'Emplois',
                                badgeCount: counts.jobs,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.jobs);
                                  if (context.mounted) context.push(AppRoutes.jobs);
                                },
                              ),
                              _ServiceGridCard(
                                icon: Icons.newspaper_rounded,
                                label: 'THIX INFO',
                                badgeCount: counts.info,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.info);
                                  if (context.mounted) AlertInfoSheet.show(context);
                                },
                              ),
                              _ServiceGridCard(
                                icon: Icons.lightbulb_rounded,
                                label: 'Opportunités',
                                badgeCount: counts.opportunities,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.opportunities);
                                  if (context.mounted) context.push(AppRoutes.opportunities);
                                },
                              ),
                              _ServiceGridCard(
                                icon: Icons.event_available_rounded,
                                label: 'Événements',
                                badgeCount: counts.events,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.events);
                                  if (context.mounted) context.push(AppRoutes.events);
                                },
                              ),
                              _ServiceGridCard(
                                icon: Icons.groups_rounded,
                                label: 'Réseau Pro',
                                onTap: () => context.push(AppRoutes.network),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // === NOTRE MISSION ===
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A2F5C), Color(0xFF1B3A5C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOTRE MISSION',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightModeColors.metalGold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Construisons ensemble l’avenir de la jeunesse.',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Accédez à des opportunités, des ressources et un réseau engagé.',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: fabSpace + 20), // Espace pour les FABs + bottom bar
              ],
            ),
          ),

          // === FLOATING ACTION BUTTONS (conservés) ===
          Positioned(
            bottom: safeBottom + 16,
            left: 24,
            child: const EmergencyFab(),
          ),
          Positioned(
            bottom: safeBottom + 16,
            right: 24,
            child: GestureDetector(
              onTap: _onMessagesTap,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 20, offset: const Offset(0, 8))],
                  gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF9C74F)]),
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: context.theme.colorScheme.surface, shape: BoxShape.circle),
                  child: Container(
                    decoration: const BoxDecoration(color: LightModeColors.accent, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.forum_rounded, color: Color(0xFF0A2F5C), size: 28),
                  ),
                ),
              ),
            ),
          ),

          // Indicateur de chargement pendant la recherche
          if (_searching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(30),
                alignment: Alignment.center,
                child: const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
              ),
            ),
        ],
      ),

      // === BARRE DE NAVIGATION EN BAS (Accueil, Services, Messages, Profil) ===
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        selectedItemColor: LightModeColors.accent,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Déjà sur l'accueil, ne rien faire (ou remonter en haut)
              break;
            case 1:
              _onServicesTap();
              break;
            case 2:
              _onMessagesTap();
              break;
            case 3:
              _onProfileTap();
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.message_rounded), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

// Petit widget pour les actions rapides (Scanner / NFC)
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [LightModeColors.accent, LightModeColors.metalGold]),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 6, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF0A2F5C), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF0A2F5C), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// Le reste des classes (_LanguageTile, _AccountRequestChoice, AccountRequestSheet, _AccountChoiceTile, etc.) sont conservées sans modification.
// Elles ont été omises ici pour la lisibilité, mais doivent rester présentes dans le fichier final.
// (Elles sont identiques à celles du code original)