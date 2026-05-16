import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';

import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/notification_service.dart';

import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/alert_info_sheet.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';

import '../../nav.dart';

class PremiumColors {
  static const Color primaryDark = Color(0xFF071B8C);
  static const Color primaryElectric = Color(0xFF2E5BFF);
  static const Color background = Color(0xFFF6F8FC);
  static const Color white = Colors.white;
  static const Color mint = Color(0xFFCFF7E8);
  static const Color lavender = Color(0xFFEEE7FF);
  static const Color peach = Color(0xFFFFE9D6);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  final NotificationService _notifications = NotificationService();
  final NotificationCountersService _counters = NotificationCountersService();
  static final RegExp _uidLikeRegex = RegExp(r'^[A-Za-z0-9_-]{20,}$');

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
        message: 'Entrez un THIX ID.',
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
          title: 'Introuvable',
          message: 'Aucun profil trouvé.',
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

  void _onProfileTap() {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      final t = auth.currentUser?.accountType;
      context.go(
        t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard,
      );
    } else {
      context.push(AppRoutes.login);
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final safeTop = MediaQuery.paddingOf(context).top;
    final badgeCountsStream = auth.currentUser == null
        ? Stream.value(SectionBadgeCounts.zero)
        : _counters.streamCounts(auth.currentUser!.id);

    return Scaffold(
      backgroundColor: PremiumColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // HEADER RÉDUIT (hauteur ~300)
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [PremiumColors.primaryDark, PremiumColors.primaryElectric],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Décors légers
                      Positioned(
                        top: -30,
                        right: -20,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -40,
                        left: -30,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -10,
                        bottom: 10,
                        child: Icon(Icons.fingerprint, size: 120, color: Colors.white.withOpacity(0.06)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: safeTop + 12, left: 20, right: 20, bottom: 24),
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
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Identité Sécurisée. Avenir de Confiance.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: _onProfileTap,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.15),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: const Icon(Icons.person_outline, color: Colors.white, size: 22),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Bienvenue !',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Que voulez-vous faire aujourd’hui ?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.92),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Barre de recherche
                            Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded, color: PremiumColors.textSecondary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: const InputDecoration(
                                        hintText: 'Rechercher un THIX ID...',
                                        hintStyle: TextStyle(fontSize: 14),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _searching ? null : _handleSearch,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [PremiumColors.primaryElectric, PremiumColors.primaryDark],
                                        ),
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      child: const Text(
                                        'Vérifier',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
                const SizedBox(height: 20),
                // Ligne Scanner / NFC (plus compact)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          title: 'Scanner un QR',
                          subtitle: 'Scannez un code sécurisé',
                          icon: Icons.qr_code_scanner_rounded,
                          colors: [PremiumColors.mint, Colors.white],
                          iconColor: PremiumColors.primaryDark,
                          onTap: () => ThixIdentitySheets.showQrScanSheet(context),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ActionCard(
                          title: 'Lire via NFC',
                          subtitle: 'Approchez votre appareil',
                          icon: Icons.nfc_rounded,
                          colors: [PremiumColors.lavender, Colors.white],
                          iconColor: PremiumColors.primaryDark,
                          onTap: () => ThixIdentitySheets.showNfcScanSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Carte Notifications
                Padding(
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
                const SizedBox(height: 20),
                // Section Nos services
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            child: const Text('Tout voir >', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<SectionBadgeCounts>(
                        stream: badgeCountsStream,
                        builder: (context, snap) {
                          final counts = snap.data ?? SectionBadgeCounts.zero;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.9,
                            children: [
                              _ServiceCard(
                                title: 'Demander un Compte',
                                icon: Icons.person_add_alt_1,
                                gradient: const [PremiumColors.primaryElectric, PremiumColors.primaryDark],
                                iconColor: Colors.white,
                                onTap: () {}, // à implémenter si besoin
                              ),
                              _ServiceCard(
                                title: 'Mon Compte',
                                icon: Icons.account_circle,
                                gradient: const [PremiumColors.mint, Colors.white],
                                onTap: _onProfileTap,
                              ),
                              _ServiceCard(
                                title: 'Formations',
                                icon: Icons.school_rounded,
                                badge: counts.formations,
                                onTap: () => context.push(AppRoutes.trainingHome),
                              ),
                              _ServiceCard(
                                title: 'Emplois',
                                icon: Icons.work_rounded,
                                badge: counts.jobs,
                                onTap: () => context.push(AppRoutes.jobs),
                              ),
                              _ServiceCard(
                                title: 'THIX INFO',
                                icon: Icons.newspaper_rounded,
                                badge: counts.info,
                                onTap: () => AlertInfoSheet.show(context),
                              ),
                              _ServiceCard(
                                title: 'Opportunités',
                                icon: Icons.lightbulb_rounded,
                                badge: counts.opportunities,
                                onTap: () => context.push(AppRoutes.opportunities),
                              ),
                              _ServiceCard(
                                title: 'Événements',
                                icon: Icons.event_rounded,
                                badge: counts.events,
                                onTap: () => context.push(AppRoutes.events),
                              ),
                              _ServiceCard(
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
                const SizedBox(height: 24),
                // Mission
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [PremiumColors.primaryDark, PremiumColors.primaryElectric],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6))],
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
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Construisons ensemble l’avenir de la jeunesse.',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Accédez à des opportunités, des ressources et un réseau engagé.',
                                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                          ),
                          child: const Icon(Icons.diversity_3_rounded, size: 36, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 90), // espace pour la bottom bar flottante
              ],
            ),
          ),
          if (_searching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
        ],
      ),
      // Bottom Navigation Bar comme sur la photo
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

// ========== WIDGETS COMPACTS ==========
class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color iconColor;
  final VoidCallback onTap;
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.colors, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: PremiumColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int badge;
  final List<Color> gradient;
  final Color? iconColor;
  final VoidCallback onTap;
  const _ServiceCard({required this.title, required this.icon, this.badge = 0, this.gradient = const [Colors.white, Colors.white], this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, size: 26, color: iconColor ?? PremiumColors.primaryElectric),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
  final void Function(String) onMarkRead;
  final void Function(Map<String, dynamic>)? onOpen;
  const _NotificationsCard({required this.isAuthenticated, required this.notifications, required this.onSeeMore, required this.onMarkRead, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_none, color: PremiumColors.primaryElectric, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              TextButton(onPressed: onSeeMore, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Voir tout >', style: TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          if (!isAuthenticated)
            const Text('Connectez-vous pour voir vos notifications.', style: TextStyle(fontSize: 12, color: PremiumColors.textSecondary))
          else
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: notifications,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final rows = snap.data ?? [];
                if (rows.isEmpty) return const Text('Aucune notification récente.', style: TextStyle(fontSize: 12));
                return Column(
                  children: rows.take(2).map((notif) {
                    final id = (notif['id'] ?? '').toString();
                    final title = (notif['title'] ?? '') as String;
                    final body = (notif['body'] ?? '') as String;
                    final read = (notif['read'] ?? false) as bool;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: read ? Colors.transparent : PremiumColors.primaryElectric)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: TextStyle(fontSize: 13, fontWeight: read ? FontWeight.normal : FontWeight.bold)),
                                Text(body, style: const TextStyle(fontSize: 11, color: PremiumColors.textSecondary)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (!read) onMarkRead(id);
                              if (onOpen != null) onOpen!(notif);
                            },
                            child: const Icon(Icons.chevron_right, size: 16),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: selected ? PremiumColors.primaryElectric : PremiumColors.textSecondary),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? PremiumColors.primaryElectric : PremiumColors.textSecondary)),
        ],
      ),
    );
  }
}
