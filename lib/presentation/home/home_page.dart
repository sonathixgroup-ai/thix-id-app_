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
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Demander un compte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Choisissez le type de compte', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Color(0xFF2E5BFF)),
                title: const Text('Compte Personnel'),
                subtitle: const Text('Pour les citoyens, étudiants'),
                onTap: () => Navigator.pop(context, 'personal'),
              ),
              ListTile(
                leading: const Icon(Icons.business_outlined, color: Color(0xFF2E5BFF)),
                title: const Text('Compte Entreprise'),
                subtitle: const Text('Pour les institutions, sociétés'),
                onTap: () => Navigator.pop(context, 'enterprise'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (choice == 'personal') {
      if (auth.isAuthenticated) await auth.signOut();
      if (context.mounted) context.push(AppRoutes.personalReg);
    } else if (choice == 'enterprise') {
      if (auth.isAuthenticated) await auth.signOut();
      if (context.mounted) context.push(AppRoutes.enterpriseReg);
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

  void _onServicesTap() {
    // Faire défiler vers la section services
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final badgeStream = auth.currentUser == null
        ? Stream.value(SectionBadgeCounts.zero)
        : _counters.streamCounts(auth.currentUser!.id);
    final safeTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ========== HEADER ==========
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF071B8C), Color(0xFF2E5BFF)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: safeTop + 16, left: 20, right: 20, bottom: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'THIX ID',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Identité Sécurisée. Avenir de Confiance.',
                                  style: TextStyle(fontSize: 10, color: Colors.white70),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _onProfileTap,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Bienvenue !',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Que voulez-vous faire aujourd’hui ?',
                          style: TextStyle(fontSize: 15, color: Colors.white90),
                        ),
                        const SizedBox(height: 20),
                        // Barre de recherche
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _searching ? null : _handleSearch(),
                                  decoration: const InputDecoration(
                                    hintText: 'Rechercher un THIX ID...',
                                    hintStyle: TextStyle(fontSize: 13),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _searching ? null : _handleSearch,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2E5BFF), Color(0xFF071B8C)],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
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
                ),
                const SizedBox(height: 20),

                // ========== QR CODE & NFC côte à côte ==========
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Scanner un QR',
                          subtitle: 'Scannez un code sécurisé',
                          bgColor: const Color(0xFFD1FAE5),
                          iconColor: const Color(0xFF059669),
                          onTap: () => ThixIdentitySheets.showQrScanSheet(context),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.nfc_rounded,
                          title: 'Lire via NFC',
                          subtitle: 'Approchez votre appareil',
                          bgColor: const Color(0xFFF3E8FF),
                          iconColor: const Color(0xFF7C3AED),
                          onTap: () => ThixIdentitySheets.showNfcScanSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ========== NOTIFICATIONS ==========
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
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
                        const Expanded(
                          child: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        TextButton(
                          onPressed: () {
                            if (!auth.isAuthenticated) {
                              context.push(AppRoutes.login);
                            } else {
                              NotificationsSheet.show(context);
                            }
                          },
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('Voir tout >', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== NOS SERVICES ==========
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Nos services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          TextButton(
                            onPressed: _onServicesTap,
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            child: const Text('Tout voir >', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<SectionBadgeCounts>(
                        stream: badgeStream,
                        builder: (context, snap) {
                          final counts = snap.data ?? SectionBadgeCounts.zero;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.9,
                            children: [
                              _ServiceCard(
                                title: 'Demander un Compte',
                                icon: Icons.person_add_alt_1,
                                gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                iconColor: Colors.white,
                                onTap: _handleRequestAccount,
                              ),
                              _ServiceCard(
                                title: 'Mon Compte',
                                icon: Icons.account_circle,
                                gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                                iconColor: Colors.white,
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

                // ========== MISSION ==========
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF071B8C), Color(0xFF2E5BFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NOTRE MISSION', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              const Text('Construisons ensemble l’avenir de la jeunesse.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 4),
                              const Text('Accédez à des opportunités, des ressources et un réseau engagé.', style: TextStyle(fontSize: 11, color: Colors.white90)),
                            ],
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.diversity_3_rounded, size: 30, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 90),
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
      // ========== BOTTOM NAVIGATION ==========
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_outlined, label: 'Accueil', selected: true, onTap: () {}),
                _NavItem(icon: Icons.grid_view_rounded, label: 'Services', onTap: _onServicesTap),
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

// ========== CARTE ACTION ==========
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.bgColor, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF64748B)),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

// ========== CARTE SERVICE ==========
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, size: 26, color: iconColor ?? const Color(0xFF2E5BFF)),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ========== NAVIGATION ITEM ==========
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
          Icon(icon, size: 24, color: selected ? const Color(0xFF2E5BFF) : const Color(0xFF64748B)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? const Color(0xFF2E5BFF) : const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
