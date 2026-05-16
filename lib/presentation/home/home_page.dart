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
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import '../../theme.dart';
import '../../nav.dart';

// Palette de couleurs premium
class PremiumColors {
  static const Color primaryDark = Color(0xFF071B8C);
  static const Color primaryElectric = Color(0xFF2E5BFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF6F8FC);
  static const Color mintLight = Color(0xFFCFF7E8);
  static const Color lavenderLight = Color(0xFFEEE7FF);
  static const Color peachLight = Color(0xFFFFE9D6);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C6C7A);
}

// Page d'accueil complète
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
              border: Border.all(color: PremiumColors.primaryElectric.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 12))],
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [PremiumColors.primaryElectric, PremiumColors.primaryDark]),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.language_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.loc.t('choose_language'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.close_rounded, color: cs.onSurface),
                      style: const ButtonStyle(overlayColor: WidgetStatePropertyAll(Colors.transparent)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _LanguageTile(
                  label: context.loc.t('system_default'),
                  selected: currentCode == null,
                  onTap: () async {
                    await localeCtrl.setSystem();
                    if (context.mounted) context.pop();
                  },
                ),
                const SizedBox(height: 8),
                ...LocaleController.supportedLocales.map((l) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
    final badgeCountsStream = auth.currentUser == null ? Stream<SectionBadgeCounts>.value(SectionBadgeCounts.zero) : _counters.streamCounts(auth.currentUser!.id);
    final safeTop = MediaQuery.paddingOf(context).top;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: PremiumColors.backgroundLight,
      body: Stack(
        children: [
          // Contenu principal scrollable
          CustomScrollView(
            slivers: [
              // Header bleu avec gradient + décors
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [PremiumColors.primaryDark, PremiumColors.primaryElectric],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Décors abstraits
                      Positioned(
                        top: 40,
                        right: -30,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -50,
                        left: -40,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 120,
                        left: 20,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 180,
                        right: 50,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                      // Fingerprint discret
                      Positioned(
                        bottom: -30,
                        right: -20,
                        child: Icon(
                          Icons.fingerprint,
                          size: 140,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: safeTop + 16, left: 20, right: 20, bottom: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ligne logo + avatar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'THIX ID',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Identité Sécurisée. Avenir de Confiance.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                // Avatar rond (profil)
                                GestureDetector(
                                  onTap: _onProfileTap,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                                      gradient: LinearGradient(
                                        colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)],
                                      ),
                                    ),
                                    child: const Icon(Icons.person_outline, color: Colors.white, size: 24),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Zone Hero
                            const Text(
                              'Bienvenue !',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Que voulez-vous faire aujourd’hui ?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Barre de recherche flottante
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.search, color: PremiumColors.textSecondary, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (_) => _searching ? null : _handleHomeSearchVerify(),
                                      decoration: const InputDecoration(
                                        hintText: 'Rechercher un THIX ID...',
                                        hintStyle: TextStyle(color: PremiumColors.textSecondary, fontSize: 15),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _searching ? null : _handleHomeSearchVerify,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [PremiumColors.primaryElectric, PremiumColors.primaryDark],
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: const Text(
                                        'Vérifier',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
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
                ),
              ),
              // Espacement
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              // Cartes actions : Scanner QR & Lire via NFC
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Scanner un QR',
                          subtitle: 'Scannez un code en toute sécurité',
                          onTap: () => ThixIdentitySheets.showQrScanSheet(context),
                          gradientColors: [PremiumColors.mintLight, PremiumColors.mintLight.withOpacity(0.5)],
                          iconColor: PremiumColors.primaryElectric,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.nfc_rounded,
                          title: 'Lire via NFC',
                          subtitle: 'Approchez votre appareil',
                          onTap: () => ThixIdentitySheets.showNfcScanSheet(context),
                          gradientColors: [PremiumColors.lavenderLight, PremiumColors.lavenderLight.withOpacity(0.5)],
                          iconColor: PremiumColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              // Section Notifications
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _NotificationsCard(
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
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              // Section Nos services
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nos services',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: PremiumColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: PremiumColors.primaryElectric,
                            ),
                            child: const Text('Tout voir >'),
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
                              _ServiceCard(
                                icon: Icons.person_add_alt_1_rounded,
                                title: 'Demander un Compte',
                                onTap: () => _handleRequestAccount(context),
                                badgeCount: 0,
                                gradient: const [PremiumColors.primaryElectric, PremiumColors.primaryDark],
                              ),
                              _ServiceCard(
                                icon: Icons.account_circle_rounded,
                                title: 'Mon Compte',
                                onTap: () {
                                  if (auth.isAuthenticated) {
                                    final t = auth.currentUser?.accountType;
                                    context.go(t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard);
                                  } else {
                                    context.push(AppRoutes.login);
                                  }
                                },
                                gradient: const [PremiumColors.mintLight, PremiumColors.mintLight],
                                iconColor: PremiumColors.primaryDark,
                              ),
                              _ServiceCard(
                                icon: Icons.school_rounded,
                                title: 'Formations',
                                badgeCount: counts.formations,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.formations);
                                  if (context.mounted) context.push(AppRoutes.trainingHome);
                                },
                              ),
                              _ServiceCard(
                                icon: Icons.work_rounded,
                                title: 'Emplois',
                                badgeCount: counts.jobs,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.jobs);
                                  if (context.mounted) context.push(AppRoutes.jobs);
                                },
                              ),
                              _ServiceCard(
                                icon: Icons.newspaper_rounded,
                                title: 'THIX INFO',
                                badgeCount: counts.info,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.info);
                                  if (context.mounted) AlertInfoSheet.show(context);
                                },
                                gradient: const [PremiumColors.lavenderLight, PremiumColors.lavenderLight],
                                iconColor: PremiumColors.primaryElectric,
                              ),
                              _ServiceCard(
                                icon: Icons.lightbulb_rounded,
                                title: 'Opportunités',
                                badgeCount: counts.opportunities,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.opportunities);
                                  if (context.mounted) context.push(AppRoutes.opportunities);
                                },
                              ),
                              _ServiceCard(
                                icon: Icons.event_available_rounded,
                                title: 'Événements',
                                badgeCount: counts.events,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.events);
                                  if (context.mounted) context.push(AppRoutes.events);
                                },
                                gradient: const [PremiumColors.peachLight, PremiumColors.peachLight],
                                iconColor: PremiumColors.primaryDark,
                              ),
                              _ServiceCard(
                                icon: Icons.groups_rounded,
                                title: 'Réseau Pro',
                                onTap: () => context.push(AppRoutes.network),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              // Section Mission
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [PremiumColors.primaryDark, PremiumColors.primaryElectric],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOTRE MISSION',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Construisons ensemble l’avenir de la jeunesse.',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Accédez à des opportunités, des ressources et un réseau engagé.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Illustration simplifiée (jeunesse africaine)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                        ),
                        child: const Icon(
                          Icons.diversity_3_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Espace pour bottom nav
            ],
          ),
          // Boutons flottants (urgence + chat)
          Positioned(
            bottom: 80,
            left: 20,
            child: const EmergencyFab(),
          ),
          Positioned(
            bottom: 80,
            right: 20,
            child: GestureDetector(
              onTap: _onMessagesTap,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [PremiumColors.primaryElectric, PremiumColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
              ),
            ),
          ),
          // Indicateur de recherche
          if (_searching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              ),
            ),
        ],
      ),
      // Bottom Navigation Bar flottante style iOS
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: PremiumColors.primaryElectric,
            unselectedItemColor: PremiumColors.textSecondary,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            currentIndex: 0,
            onTap: (index) {
              switch (index) {
                case 0:
                  break;
                case 1:
                  // Services : déjà visible en scroll
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
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
              BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), label: 'Services'),
              BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: 'Messages'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}

// Cartes d'action (Scanner/Lire NFC)
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color iconColor;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.gradientColors = const [PremiumColors.backgroundLight, PremiumColors.backgroundLight],
    this.iconColor = PremiumColors.primaryElectric,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PremiumColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: PremiumColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Carte Notifications
class _NotificationsCard extends StatelessWidget {
  final bool isAuthenticated;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final VoidCallback onSeeMore;
  final void Function(String notificationId) onMarkRead;
  final void Function(Map<String, dynamic> row)? onOpen;

  const _NotificationsCard({
    required this.isAuthenticated,
    required this.notifications,
    required this.onSeeMore,
    required this.onMarkRead,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_none, color: PremiumColors.primaryElectric),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onSeeMore,
                style: TextButton.styleFrom(
                  foregroundColor: PremiumColors.primaryElectric,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Voir tout >'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isAuthenticated)
            const Text(
              'Connectez-vous pour voir vos notifications.',
              style: TextStyle(color: PremiumColors.textSecondary, fontSize: 14),
            )
          else
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: notifications,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) {
                  return const Text(
                    'Aucune notification récente.',
                    style: TextStyle(color: PremiumColors.textSecondary),
                  );
                }
                return Column(
                  children: rows.take(2).map((notif) {
                    final id = (notif['id'] ?? '').toString();
                    final title = (notif['title'] ?? 'Notification') as String;
                    final body = (notif['body'] ?? '') as String;
                    final read = (notif['read'] ?? false) as bool;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: read ? Colors.transparent : PremiumColors.primaryElectric,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: TextStyle(fontWeight: read ? FontWeight.normal : FontWeight.bold)),
                                Text(body, style: const TextStyle(fontSize: 12, color: PremiumColors.textSecondary)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (!read) onMarkRead(id);
                              if (onOpen != null) onOpen!(notif);
                            },
                            child: const Icon(Icons.chevron_right, size: 18),
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

// Carte Service (grille 2x4)
class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badgeCount;
  final List<Color> gradient;
  final Color? iconColor;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeCount = 0,
    this.gradient = const [PremiumColors.backgroundLight, PremiumColors.backgroundLight],
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor ?? PremiumColors.primaryElectric, size: 28),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Language tile (inchangé)
class _LanguageTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? PremiumColors.primaryElectric : Colors.grey.shade200),
          color: selected ? PremiumColors.primaryElectric.withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
            if (selected)
              const Icon(Icons.check_circle, color: PremiumColors.primaryElectric, size: 20)
            else
              const Icon(Icons.circle_outlined, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

enum _AccountRequestChoice { personal, enterprise }

class AccountRequestSheet extends StatelessWidget {
  const AccountRequestSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Demander un compte',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choisissez le type de compte que vous souhaitez créer.',
                style: TextStyle(color: PremiumColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _AccountChoiceTile(
                icon: Icons.person_outline,
                title: 'Compte Personnel',
                subtitle: 'Pour les citoyens, étudiants, particuliers',
                onTap: () => context.pop(_AccountRequestChoice.personal),
              ),
              const SizedBox(height: 12),
              _AccountChoiceTile(
                icon: Icons.business_outlined,
                title: 'Compte Entreprise',
                subtitle: 'Pour les institutions, sociétés, ONG',
                onTap: () => context.pop(_AccountRequestChoice.enterprise),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PremiumColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: PremiumColors.primaryElectric),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: PremiumColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: PremiumColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
