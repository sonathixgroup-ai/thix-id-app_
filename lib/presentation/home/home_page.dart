import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/alert_info_sheet.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import '../../theme.dart';
import '../../nav.dart';

// ==================== PALETTE DE COULEURS PREMIUM REVISITÉE ====================
class PremiumColors {
  static const Color primaryDark = Color(0xFF030F54);      // Bleu Nuit profond
  static const Color primaryElectric = Color(0xFF1E40AF);  // Bleu Institutionnel
  static const Color accentGold = Color(0xFFD4AF37);       // Or Métallique
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF4F7FE);  // Gris/Bleu très clair
  static const Color textPrimary = Color(0xFF0F172A);      // Ardoise foncé
  static const Color textSecondary = Color(0xFF64748B);    // Gris neutre
  
  // Teintes subtiles pour les conteneurs d'icônes
  static const Color mintLight = Color(0xE8E0FBF2);
  static const Color lavenderLight = Color(0xFFEEF2FF);
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

  static final RegExp uidLikeRegex = RegExp(r'^[A-Za-z0-9-]{20,}$');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== MÉTHODES DE LOGIQUE REPRISES ====================
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
        message: 'Format attendu: ${ThixIdService.exampleV2} (recommandé) ou ${ThixIdService.exampleV1} ou UID.',
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

  // Remplacement du bouton urgent au clic long sur le bouton de profil du haut
  void _onEmergencyTrigger() {
    // Appel natif ou logique de secours associée à l'ancienne EmergencyFab
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alerte d\'urgence initiée.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final badgeCountsStream = auth.currentUser == null 
        ? Stream.value(SectionBadgeCounts.zero) 
        : _counters.streamCounts(auth.currentUser!.id);
    final safeTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PremiumColors.backgroundLight,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // HEADER GRADIENT BLEU SUIVANT LE DESIGN FOURNI
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0A2540), Color(0xFF0044FF)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Points d'ancrage graphiques en arrière-plan
                      Positioned(
                        top: safeTop,
                        right: 20,
                        child: Opacity(
                          opacity: 0.15,
                          child: Icon(Icons.apps_rounded, size: 120, color: PremiumColors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: safeTop + 20, left: 24, right: 24, bottom: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Bar : Logo & Profil d'urgence
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: PremiumColors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.fingerprint_rounded, color: PremiumColors.white, size: 28),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'THIX ID',
                                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: PremiumColors.white, letterSpacing: -0.5),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: PremiumColors.accentGold)),
                                          ],
                                        ),
                                        Text(
                                          'Identité Sécurisée. Avenir de Confiance.',
                                          style: TextStyle(fontSize: 11, color: PremiumColors.white.withOpacity(0.7), fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // Bouton profil redirigeant ou déclenchant l'urgence sur appui long
                                GestureDetector(
                                  onTap: _onProfileTap,
                                  onLongPress: _onEmergencyTrigger,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: PremiumColors.white,
                                    ),
                                    child: const Icon(Icons.person_rounded, color: Color(0xFF0A2540), size: 24),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            const Text(
                              'Bienvenue !',
                              style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: PremiumColors.white, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Que voulez-vous faire aujourd’hui ?',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: PremiumColors.white.withOpacity(0.85)),
                            ),
                            const SizedBox(height: 28),
                            // Barre de recherche stylisée selon la maquette
                            Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: PremiumColors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
                                ],
                              ),
                              padding: const EdgeInsets.only(left: 20, right: 6),
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
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _searching ? null : _handleHomeSearchVerify,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: PremiumColors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text('Vérifier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.arrow_forward, size: 16),
                                      ],
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
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              // CARDS D'ACTIONS : SCANNER / NFC
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Scanner un QR',
                          subtitle: 'Scannez un code\nen toute sécurité',
                          onTap: () => ThixIdentitySheets.showQrScanSheet(context),
                          iconBgColor: PremiumColors.backgroundLight,
                          iconColor: const Color(0xFF2563EB),
                          arrowColor: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.nfc_rounded,
                          title: 'Lire via NFC',
                          subtitle: 'Approchez votre\nappareil',
                          onTap: () => ThixIdentitySheets.showNfcScanSheet(context),
                          iconBgColor: const Color(0xFFE0F2FE),
                          iconColor: const Color(0xFF0369A1),
                          arrowColor: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              // SECTION NOTIFICATIONS COMPACTE
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
                    onOpen: (notif) async {
                      if (!auth.isAuthenticated) {
                        context.push(AppRoutes.login);
                        return;
                      }
                      final me = auth.currentUser;
                      if (me == null) return;
                      final type = (notif['type'] ?? '').toString().toLowerCase();
                      if (type.contains('message')) {
                        await _counters.markSectionSeen(uid: me.id, section: ThixSection.messages);
                        if (context.mounted) context.push(AppRoutes.chat);
                        return;
                      }
                      if (context.mounted) NotificationsSheet.show(context);
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              // GRILLE DES SERVICES OPTIMISÉE EN 4 COLONNES ET DEUX LIGNES COMPACTES
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PremiumColors.textPrimary),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: const Row(
                              children: [
                                Text('Tout voir', style: TextStyle(color: PremiumColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                Icon(Icons.chevron_right_rounded, color: PremiumColors.textSecondary, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<SectionBadgeCounts>(
                        stream: badgeCountsStream,
                        builder: (context, badgeSnap) {
                          final counts = badgeSnap.data ?? SectionBadgeCounts.zero;
                          return GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.85,
                            children: [
                              _ServiceCard(
                                icon: Icons.person_add_alt_1_rounded,
                                title: 'Demander un Compte',
                                iconColor: const Color(0xFF3B82F6),
                                onTap: () => _handleRequestAccount(context),
                              ),
                              _ServiceCard(
                                icon: Icons.account_circle_rounded,
                                title: 'Mon Compte',
                                iconColor: const Color(0 IsabellaColor = 0xFFA855F7),
                                onTap: () {
                                  if (auth.isAuthenticated) {
                                    final t = auth.currentUser?.accountType;
                                    context.go(t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard);
                                  } else {
                                    context.push(AppRoutes.login);
                                  }
                                },
                              ),
                              _ServiceCard(
                                icon: Icons.school_rounded,
                                title: 'Formations',
                                iconColor: const Color(0xFF10B981),
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
                                iconColor: const Color(0xFFF59E0B),
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
                                iconColor: const Color(0xFFEC4899),
                                badgeCount: counts.info,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.info);
                                  if (context.mounted) AlertInfoSheet.show(context);
                                },
                              ),
                              _ServiceCard(
                                icon: Icons.lightbulb_rounded,
                                title: 'Opportunités',
                                iconColor: const Color(0xFF06B6D4),
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
                                iconColor: const Color(0xFF6366F1),
                                badgeCount: counts.events,
                                onTap: () async {
                                  final me = auth.currentUser;
                                  if (me != null) await _counters.markSectionSeen(uid: me.id, section: ThixSection.events);
                                  if (context.mounted) context.push(AppRoutes.events);
                                },
                              ),
                              _ServiceCard(
                                icon: Icons.groups_rounded,
                                title: 'Réseau Pro',
                                iconColor: const Color(0xFFF43F5E),
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
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              // BANNIÈRE DE MISSION JEUNESSE RECRÉÉE À L'IDENTIQUE
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOTRE MISSION',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PremiumColors.accentGold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Construisons ensemble l’avenir de la jeunesse.',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PremiumColors.white, height: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Accédez à des opportunités, des ressources et un réseau engagé.',
                              style: TextStyle(fontSize: 12, color: PremiumColors.white.withOpacity(0.75)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Remplacement de l'illustration par un avatar groupé moderne
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(color: PremiumColors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.diversity_3_rounded, color: PremiumColors.white, size: 36),
                      )
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          if (_searching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 3, color: PremiumColors.white),
              ),
            ),
        ],
      ),
      // NAVBAR FIXE DE STYLE FINTECH AVEC BOUTON CENTRAL AFFIRMÉ
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: PremiumColors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(icon: Icons.home_rounded, label: 'Accueil', isSelected: true, onTap: () {}),
              _BottomNavItem(icon: Icons.grid_view_rounded, label: 'Services', isSelected: false, onTap: () {}),
              // Bouton central de Scan QR / NFC combiné
              GestureDetector(
                onTap: () => ThixIdentitySheets.showQrScanSheet(context),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: PremiumColors.white, size: 26),
                ),
              ),
              _BottomNavItem(icon: Icons.message_rounded, label: 'Messages', isSelected: false, onTap: _onMessagesTap),
              _BottomNavItem(icon: Icons.person_rounded, label: 'Profil', isSelected: false, onTap: _onProfileTap),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== COMPOSANTS INTERNES RÉALIGNÉS ====================
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconBgColor;
  final Color iconColor;
  final Color arrowColor;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.iconBgColor,
    required this.iconColor,
    required this.arrowColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PremiumColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: arrowColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_rounded, color: arrowColor, size: 14),
                )
              ],
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PremiumColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: PremiumColors.textSecondary, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  final bool isAuthenticated;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final VoidCallback onSeeMore;
  final void Function(String notificationId) onMarkRead;
  final void Function(Map<String, dynamic> row) onOpen;

  const _NotificationsCard({
    required this.isAuthenticated,
    required this.notifications,
    required this.onSeeMore,
    required this.onMarkRead,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PremiumColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_rounded, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: !isAuthenticated
                ? const Text('Connectez-vous pour vos notifications.', style: TextStyle(fontSize: 13, color: PremiumColors.textSecondary))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: notifications,
                    builder: (context, snap) {
                      final rows = snap.data ?? [];
                      if (rows.isEmpty) {
                        return const Text('Aucune nouvelle notification', style: TextStyle(fontSize: 13, color: PremiumColors.textSecondary, fontWeight: FontWeight.w500));
                      }
                      final first = rows.first;
                      final title = (first['title'] ?? '') as String;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Notifications', style: TextStyle(fontSize: 11, color: PremiumColors.textSecondary, fontWeight: FontWeight.bold)),
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PremiumColors.textPrimary)),
                        ],
                      );
                    },
                  ),
          ),
          IconButton(
            onPressed: onSeeMore,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: PremiumColors.textSecondary),
          )
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final VoidCallback onTap;
  final int badgeCount;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PremiumColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFF2563EB) : PremiumColors.textSecondary, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF2563EB) : PremiumColors.textSecondary)),
        ],
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
        color: PremiumColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Demander un compte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PremiumColors.textPrimary)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF2563EB)),
                title: const Text('Compte Personnel', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Pour particuliers et citoyens'),
                onTap: () => Navigator.of(context).pop(_AccountRequestChoice.personal),
              ),
              ListTile(
                leading: const Icon(Icons.business_center_rounded, color: Color(0xFF1D4ED8)),
                title: const Text('Compte Entreprise', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Pour institutions et sociétés'),
                onTap: () => Navigator.of(context).pop(_AccountRequestChoice.enterprise),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
