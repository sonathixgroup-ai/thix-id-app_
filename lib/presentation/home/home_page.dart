import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/alert_info_sheet.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/thix_id_service.dart';

import '../../nav.dart';

class PremiumColors {
  static const Color primaryDark = Color(0xFF071B8C);
  static const Color primaryElectric = Color(0xFF2E5BFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF6F8FC);
  static const Color mintLight = Color(0xFFCFF7E8);
  static const Color lavenderLight = Color(0xFFEEE7FF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C6C7A);
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
  final _uidLikeRegex = RegExp(r'^[A-Za-z0-9_\-]{20,}$');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final raw = _searchController.text.trim();
    if (raw.isEmpty) {
      await FullScreenMessage.showError(
        context,
        title: 'Identifiant requis',
        message: "Saisissez un THIX ID.",
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
        message: 'Format incorrect.',
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
          message: "Aucun profil pour $normalized.",
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
      await FullScreenMessage.showError(context, title: 'Erreur', message: '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _handleRequestAccount() async {
    final auth = context.read<AuthController>();
    final choice = await showModalBottomSheet<_AccountRequestChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _AccountRequestSheet(),
    );
    switch (choice) {
      case _AccountRequestChoice.personal:
        if (auth.isAuthenticated) await auth.signOut();
        if (context.mounted) context.push(AppRoutes.personalReg);
        break;
      case _AccountRequestChoice.enterprise:
        if (auth.isAuthenticated) await auth.signOut();
        if (context.mounted) context.push(AppRoutes.enterpriseReg);
        break;
      default:
        break;
    }
  }

  void _onMessagesTap() {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
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
    final badgeStream = auth.currentUser == null
        ? Stream.value(SectionBadgeCounts.zero)
        : _counters.streamCounts(auth.currentUser!.id);
    final safeTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PremiumColors.backgroundLight,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ========== HEADER TRÈS COMPACT ==========
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [PremiumColors.primaryDark, PremiumColors.primaryElectric],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: 10,
                        child: Icon(Icons.fingerprint, size: 80, color: Colors.white.withOpacity(0.06)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: safeTop + 10, left: 20, right: 20, bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'THIX ID',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Identité Sécurisée. Avenir de Confiance.',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: _onProfileTap,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.15),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: const Icon(Icons.person_outline, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Bienvenue !',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Que voulez-vous faire aujourd’hui ?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Barre de recherche compacte
                            Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded, color: PremiumColors.textSecondary, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (_) => _searching ? null : _handleSearch(),
                                      decoration: const InputDecoration(
                                        hintText: 'Rechercher un THIX ID...',
                                        hintStyle: TextStyle(fontSize: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _searching ? null : _handleSearch,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [PremiumColors.primaryElectric, PremiumColors.primaryDark],
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: const Text(
                                        'Vérifier',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
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
                const SizedBox(height: 12),
                // ========== BANDES NFC / QR (style bande horizontale) ==========
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _CompactActionBar(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scanner un QR',
                        subtitle: 'Scannez un code en toute sécurité',
                        bgColor: PremiumColors.mintLight,
                        iconColor: PremiumColors.primaryDark,
                        onTap: () => ThixIdentitySheets.showQrScanSheet(context),
                      ),
                      const SizedBox(height: 8),
                      _CompactActionBar(
                        icon: Icons.nfc_rounded,
                        title: 'Lire via NFC',
                        subtitle: 'Approchez votre appareil',
                        bgColor: PremiumColors.lavenderLight,
                        iconColor: PremiumColors.primaryDark,
                        onTap: () => ThixIdentitySheets.showNfcScanSheet(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ========== NOTIFICATIONS (version compacte) ==========
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _CompactNotificationsCard(
                    isAuthenticated: auth.isAuthenticated,
                    notifications: _notifications.streamForHome(uid: auth.currentUser?.id),
                    onSeeMore: () {
                      if (!auth.isAuthenticated) {
                        context.push(AppRoutes.login);
                      } else {
                        NotificationsSheet.show(context);
                      }
                    },
                    onMarkRead: (id) {
                      final me = auth.currentUser;
                      if (me != null) _notifications.markRead(uid: me.id, notificationId: id);
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
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // ========== NOS SERVICES (GRILLE 2x4 ULTRA COMPACTE) ==========
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nos services',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                            child: const Text('Tout voir >', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<SectionBadgeCounts>(
                        stream: badgeStream,
                        builder: (context, snap) {
                          final counts = snap.data ?? SectionBadgeCounts.zero;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.85,
                            children: [
                              _CompactServiceCard(
                                title: 'Demander un Compte',
                                icon: Icons.person_add_alt_1,
                                gradient: [PremiumColors.primaryElectric, PremiumColors.primaryDark],
                                iconColor: Colors.white,
                                onTap: _handleRequestAccount,
                              ),
                              _CompactServiceCard(
                                title: 'Mon Compte',
                                icon: Icons.account_circle,
                                gradient: [PremiumColors.mintLight, Colors.white],
                                onTap: _onProfileTap,
                              ),
                              _CompactServiceCard(
                                title: 'Formations',
                                icon: Icons.school_rounded,
                                badge: counts.formations,
                                onTap: () => context.push(AppRoutes.trainingHome),
                              ),
                              _CompactServiceCard(
                                title: 'Emplois',
                                icon: Icons.work_rounded,
                                badge: counts.jobs,
                                onTap: () => context.push(AppRoutes.jobs),
                              ),
                              _CompactServiceCard(
                                title: 'THIX INFO',
                                icon: Icons.newspaper_rounded,
                                badge: counts.info,
                                onTap: () => AlertInfoSheet.show(context),
                              ),
                              _CompactServiceCard(
                                title: 'Opportunités',
                                icon: Icons.lightbulb_rounded,
                                badge: counts.opportunities,
                                onTap: () => context.push(AppRoutes.opportunities),
                              ),
                              _CompactServiceCard(
                                title: 'Événements',
                                icon: Icons.event_rounded,
                                badge: counts.events,
                                onTap: () => context.push(AppRoutes.events),
                              ),
                              _CompactServiceCard(
                                title: 'Réseau Pro',
                                icon: Icons.groups_rounded,
                                onTap: () => context.push(AppRoutes.network),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ========== MISSION (compact) ==========
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [PremiumColors.primaryDark, PremiumColors.primaryElectric],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NOTRE MISSION',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Construisons ensemble l’avenir de la jeunesse.',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Accédez à des opportunités, des ressources et un réseau engagé.',
                                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.9)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                          ),
                          child: const Icon(Icons.diversity_3_rounded, size: 28, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (_searching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
        ],
      ),
      // ========== BOTTOM NAVIGATION COMPACTE ==========
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_outlined, label: 'Accueil', selected: true, onTap: () {}),
                _NavItem(icon: Icons.grid_view_rounded, label: 'Services', onTap: () {}),
                _NavItem(icon: Icons.message_outlined, label: 'Messages', onTap: _onMessagesTap),
                _NavItem(icon: Icons.person_outline, label: 'Profil', onTap: _onProfileTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========== BANDE HORIZONTALE POUR NFC/QR ==========
class _CompactActionBar extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  const _CompactActionBar({required this.icon, required this.title, required this.subtitle, required this.bgColor, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: PremiumColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: PremiumColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ========== CARTE SERVICE COMPACTE ==========
class _CompactServiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int badge;
  final List<Color> gradient;
  final Color? iconColor;
  final VoidCallback onTap;
  const _CompactServiceCard({required this.title, required this.icon, this.badge = 0, this.gradient = const [Colors.white, Colors.white], this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 22, color: iconColor ?? PremiumColors.primaryElectric),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ========== NOTIFICATIONS COMPACTES ==========
class _CompactNotificationsCard extends StatelessWidget {
  final bool isAuthenticated;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final VoidCallback onSeeMore;
  final void Function(String) onMarkRead;
  final void Function(Map<String, dynamic>) onOpen;
  const _CompactNotificationsCard({required this.isAuthenticated, required this.notifications, required this.onSeeMore, required this.onMarkRead, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_rounded, color: Color(0xFF3B82F6), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: !isAuthenticated
                ? const Text('Connectez-vous pour voir vos notifications.', style: TextStyle(fontSize: 12, color: PremiumColors.textSecondary))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: notifications,
                    builder: (context, snap) {
                      final rows = snap.data ?? [];
                      if (rows.isEmpty) {
                        return const Text('Aucune notification', style: TextStyle(fontSize: 12, color: PremiumColors.textSecondary, fontWeight: FontWeight.w500));
                      }
                      final first = rows.first;
                      final title = (first['title'] ?? '') as String;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Notifications', style: TextStyle(fontSize: 10, color: PremiumColors.textSecondary)),
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final id = (first['id'] ?? '').toString();
                              onMarkRead(id);
                              onOpen(first);
                            },
                            child: const Icon(Icons.chevron_right, size: 16),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          TextButton(onPressed: onSeeMore, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text('Voir tout >', style: TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: selected ? PremiumColors.primaryElectric : PremiumColors.textSecondary),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? PremiumColors.primaryElectric : PremiumColors.textSecondary)),
        ],
      ),
    );
  }
}

// ========== SHEETS ==========
enum _AccountRequestChoice { personal, enterprise }

class _AccountRequestSheet extends StatelessWidget {
  const _AccountRequestSheet();

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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Demander un compte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Choisissez le type de compte que vous souhaitez créer.', style: TextStyle(color: PremiumColors.textSecondary)),
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
              TextButton(onPressed: () => context.pop(), child: const Text('Annuler')),
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
  const _AccountChoiceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PremiumColors.backgroundLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: PremiumColors.primaryElectric, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: PremiumColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: PremiumColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
