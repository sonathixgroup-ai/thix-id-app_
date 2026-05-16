// ===============================
// THIX ID — ULTRA PREMIUM HOME 2026
// Exact Startup Fintech Style
// ===============================

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
  final TextEditingController _searchController =
      TextEditingController();

  bool _searching = false;

  final NotificationService _notifications =
      NotificationService();

  final NotificationCountersService _counters =
      NotificationCountersService();

  static final RegExp _uidLikeRegex =
      RegExp(r'^[A-Za-z0-9_-]{20,}$');

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

    final isThix = normalized.startsWith('THIX-') &&
        ThixIdService.isValid(normalized);

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
        user =
            await userService.fetchUserByThixId(normalized);
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

      if (thix.isNotEmpty &&
          ThixIdService.isValid(thix)) {
        context.push(
          '${AppRoutes.publicProfile}?thixId=$thix',
        );
      } else {
        await ThixIdentitySheets.showVerifySheet(
          context,
          initialUidOrThixId: user.id,
        );
      }
    } catch (e) {
      if (!mounted) return;

      await FullScreenMessage.showError(
        context,
        title: 'Erreur',
        message: '$e',
      );
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  void _onProfileTap() {
    final auth = context.read<AuthController>();

    if (auth.isAuthenticated) {
      final t = auth.currentUser?.accountType;

      context.go(
        t == AccountType.enterprise
            ? AppRoutes.enterpriseDashboard
            : AppRoutes.userDashboard,
      );
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
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ===================================
              // HEADER PREMIUM
              // ===================================

              SliverToBoxAdapter(
                child: Container(
                  height: 430,

                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PremiumColors.primaryDark,
                        PremiumColors.primaryElectric,
                      ],
                    ),

                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(38),
                      bottomRight: Radius.circular(38),
                    ),
                  ),

                  child: Stack(
                    children: [
                      // Decorative circles

                      Positioned(
                        top: -40,
                        right: -20,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.05),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: -60,
                        left: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.03),
                          ),
                        ),
                      ),

                      // Fingerprint

                      Positioned(
                        right: -20,
                        bottom: -10,
                        child: Icon(
                          Icons.fingerprint,
                          size: 180,
                          color:
                              Colors.white.withOpacity(.06),
                        ),
                      ),

                      // diagonal white shape

                      Positioned(
                        top: 120,
                        right: -70,
                        child: Transform.rotate(
                          angle: -.35,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(.06),
                              borderRadius:
                                  BorderRadius.circular(40),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.only(
                          top: safeTop + 18,
                          left: 24,
                          right: 24,
                        ),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,

                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                  children: [
                                    const Text(
                                      'THIX ID',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -1,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      'Identité Sécurisée. Avenir de Confiance.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withOpacity(.75),
                                      ),
                                    ),
                                  ],
                                ),

                                GestureDetector(
                                  onTap: _onProfileTap,

                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(
                                            20),

                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 20,
                                        sigmaY: 20,
                                      ),

                                      child: Container(
                                        width: 50,
                                        height: 50,

                                        decoration:
                                            BoxDecoration(
                                          color: Colors.white
                                              .withOpacity(
                                                  .15),

                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      20),

                                          border: Border.all(
                                            color: Colors.white
                                                .withOpacity(
                                                    .2),
                                          ),
                                        ),

                                        child: const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 45),

                            const Text(
                              'Bienvenue !',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight:
                                    FontWeight.w800,
                                height: 1,
                                color: Colors.white,
                                letterSpacing: -1.5,
                              ),
                            ),

                            const SizedBox(height: 14),

                            Text(
                              'Que voulez-vous faire aujourd’hui ?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color:
                                    Colors.white.withOpacity(
                                        .92),
                              ),
                            ),

                            const SizedBox(height: 34),

                            // ===================================
                            // SEARCH BAR
                            // ===================================

                            Container(
                              height: 70,

                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),

                              decoration: BoxDecoration(
                                color: Colors.white,

                                borderRadius:
                                    BorderRadius.circular(
                                        35),

                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(.08),
                                    blurRadius: 30,
                                    offset:
                                        const Offset(0, 14),
                                  ),
                                ],
                              ),

                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: PremiumColors
                                        .textSecondary,
                                    size: 24,
                                  ),

                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _searchController,

                                      decoration:
                                          const InputDecoration(
                                        hintText:
                                            'Rechercher un THIX ID...',
                                        border:
                                            InputBorder.none,
                                      ),
                                    ),
                                  ),

                                  GestureDetector(
                                    onTap: _searching
                                        ? null
                                        : _handleSearch,

                                    child: Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 24,
                                        vertical: 14,
                                      ),

                                      decoration:
                                          BoxDecoration(
                                        gradient:
                                            const LinearGradient(
                                          colors: [
                                            PremiumColors
                                                .primaryElectric,
                                            PremiumColors
                                                .primaryDark,
                                          ],
                                        ),

                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    24),
                                      ),

                                      child: const Text(
                                        'Vérifier',
                                        style: TextStyle(
                                          color:
                                              Colors.white,
                                          fontWeight:
                                              FontWeight
                                                  .w700,
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

              const SliverToBoxAdapter(
                child: SizedBox(height: 28),
              ),

              // ===================================
              // ACTION CARDS
              // ===================================

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22),

                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          title: 'Scanner QR',
                          subtitle:
                              'Scannez un code sécurisé',
                          icon:
                              Icons.qr_code_scanner_rounded,
                          colors: [
                            PremiumColors.mint,
                            PremiumColors.white,
                          ],
                          iconColor:
                              PremiumColors.primaryDark,
                          onTap: () {
                            ThixIdentitySheets
                                .showQrScanSheet(
                              context,
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _ActionCard(
                          title: 'Lire NFC',
                          subtitle:
                              'Approchez votre appareil',
                          icon: Icons.nfc_rounded,
                          colors: [
                            PremiumColors.lavender,
                            PremiumColors.white,
                          ],
                          iconColor:
                              PremiumColors.primaryDark,
                          onTap: () {
                            ThixIdentitySheets
                                .showNfcScanSheet(
                              context,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 28),
              ),

              // ===================================
              // SERVICES
              // ===================================

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22),

                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Nos services',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 18),

                      StreamBuilder<SectionBadgeCounts>(
                        stream: badgeCountsStream,

                        builder: (context, snap) {
                          final counts =
                              snap.data ??
                                  SectionBadgeCounts.zero;

                          return GridView.count(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),

                            crossAxisCount: 2,

                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,

                            childAspectRatio: .95,

                            children: [
                              _ServiceCard(
                                title:
                                    'Demander un Compte',
                                icon:
                                    Icons.person_add_alt_1,

                                gradient: const [
                                  PremiumColors
                                      .primaryElectric,
                                  PremiumColors
                                      .primaryDark,
                                ],

                                iconColor: Colors.white,

                                onTap: () {},
                              ),

                              _ServiceCard(
                                title: 'Mon Compte',
                                icon:
                                    Icons.account_circle,

                                gradient: const [
                                  PremiumColors.mint,
                                  PremiumColors.white,
                                ],

                                onTap: _onProfileTap,
                              ),

                              _ServiceCard(
                                title: 'Formations',
                                icon: Icons.school_rounded,
                                badge:
                                    counts.formations,
                                onTap: () {
                                  context.push(
                                    AppRoutes
                                        .trainingHome,
                                  );
                                },
                              ),

                              _ServiceCard(
                                title: 'Emplois',
                                icon: Icons.work_rounded,
                                badge: counts.jobs,
                                onTap: () {
                                  context.push(
                                    AppRoutes.jobs,
                                  );
                                },
                              ),

                              _ServiceCard(
                                title: 'THIX INFO',
                                icon:
                                    Icons.newspaper_rounded,
                                badge: counts.info,
                                onTap: () {
                                  AlertInfoSheet.show(
                                      context);
                                },
                              ),

                              _ServiceCard(
                                title:
                                    'Opportunités',
                                icon:
                                    Icons.lightbulb_rounded,
                                badge:
                                    counts.opportunities,
                                onTap: () {
                                  context.push(
                                    AppRoutes
                                        .opportunities,
                                  );
                                },
                              ),

                              _ServiceCard(
                                title:
                                    'Événements',
                                icon:
                                    Icons.event_rounded,
                                badge:
                                    counts.events,
                                onTap: () {
                                  context.push(
                                    AppRoutes.events,
                                  );
                                },
                              ),

                              _ServiceCard(
                                title: 'Réseau Pro',
                                icon:
                                    Icons.groups_rounded,
                                onTap: () {
                                  context.push(
                                    AppRoutes.network,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 28),
              ),

              // ===================================
              // MISSION
              // ===================================

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22),

                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(24),

                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PremiumColors.primaryDark,
                          PremiumColors.primaryElectric,
                        ],
                      ),

                      borderRadius:
                          BorderRadius.circular(32),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),

                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [
                              Text(
                                'NOTRE MISSION',
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 1.5,
                                  color: Colors.white
                                      .withOpacity(.7),
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 12),

                              const Text(
                                'Construisons ensemble l’avenir de la jeunesse.',
                                style: TextStyle(
                                  fontSize: 22,
                                  height: 1.2,
                                  fontWeight:
                                      FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 18),

                        Container(
                          width: 82,
                          height: 82,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Colors.white.withOpacity(
                                    .12),
                          ),

                          child: const Icon(
                            Icons.diversity_3_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),

          if (_searching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(.25),

                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),

      // ===================================
      // FLOATING NAVBAR
      // ===================================

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),

        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),

          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20,
              sigmaY: 20,
            ),

            child: Container(
              height: 82,

              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.92),

                borderRadius:
                    BorderRadius.circular(34),

                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withOpacity(.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),

              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceAround,

                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    selected: true,
                    label: 'Accueil',
                    onTap: () {},
                  ),

                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Services',
                    onTap: () {},
                  ),

                  Container(
                    width: 62,
                    height: 62,

                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          PremiumColors.primaryElectric,
                          PremiumColors.primaryDark,
                        ],
                      ),

                      shape: BoxShape.circle,

                      boxShadow: [
                        BoxShadow(
                          color: PremiumColors
                              .primaryElectric
                              .withOpacity(.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),

                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  _NavItem(
                    icon: Icons.notifications_none,
                    label: 'Alertes',
                    onTap: () {
                      NotificationsSheet.show(
                        context,
                      );
                    },
                  ),

                  _NavItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                    onTap: _onProfileTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================
// ACTION CARD
// ===================================

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.all(22),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(28),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Container(
              padding: const EdgeInsets.all(14),

              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: colors),

                borderRadius:
                    BorderRadius.circular(20),
              ),

              child: Icon(
                icon,
                size: 30,
                color: iconColor,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color:
                    PremiumColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================
// SERVICE CARD
// ===================================

class _ServiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int badge;
  final List<Color> gradient;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.icon,
    this.badge = 0,
    this.gradient = const [
      Colors.white,
      Colors.white,
    ],
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(28),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Stack(
              clipBehavior: Clip.none,

              children: [
                Container(
                  padding:
                      const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(
                      colors: gradient,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                            20),
                  ),

                  child: Icon(
                    icon,
                    size: 30,
                    color: iconColor ??
                        PremiumColors
                            .primaryElectric,
                  ),
                ),

                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,

                    child: Container(
                      padding:
                          const EdgeInsets.all(
                              5),

                      decoration:
                          const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),

                      child: Text(
                        '$badge',
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Icon(
            icon,
            size: 25,
            color: selected
                ? PremiumColors.primaryElectric
                : PremiumColors.textSecondary,
          ),

          const SizedBox(height: 4),

          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: selected
                  ? PremiumColors.primaryElectric
                  : PremiumColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
