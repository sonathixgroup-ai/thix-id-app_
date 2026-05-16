import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';

import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/alert_info_sheet.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';

import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/thix_id_service.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController =
      TextEditingController();

  bool _searching = false;

  final _notifications = NotificationService();
  final _counters = NotificationCountersService();

  static final RegExp _uidLikeRegex =
      RegExp(r'^[A-Za-z0-9_-]{20,}$');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleHomeSearchVerify() async {
    final raw = _searchController.text.trim();

    if (raw.isEmpty) {
      await FullScreenMessage.showError(
        context,
        title: 'Identifiant requis',
        message:
            "Saisissez un THIX ID puis appuyez sur Vérifier.",
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
        message:
            'Format THIX ID incorrect.',
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
          title: 'Profil introuvable',
          message:
              "Aucun profil trouvé.",
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
        message:
            "Impossible d'effectuer la vérification.",
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

  void _onMessagesTap() {
    final auth = context.read<AuthController>();

    if (auth.isAuthenticated) {
      context.push(AppRoutes.chat);
    } else {
      context.push(AppRoutes.login);
    }
  }

  Future<void> _handleRequestAccount(
      BuildContext context) async {
    final auth = context.read<AuthController>();

    final res =
        await showModalBottomSheet<_AccountRequestChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AccountRequestSheet(),
    );

    switch (res) {
      case _AccountRequestChoice.personal:
        if (auth.isAuthenticated) {
          await auth.signOut();
        }

        if (context.mounted) {
          context.push(AppRoutes.personalReg);
        }

        return;

      case _AccountRequestChoice.enterprise:
        if (auth.isAuthenticated) {
          await auth.signOut();
        }

        if (context.mounted) {
          context.push(AppRoutes.enterpriseReg);
        }

        return;

      case null:
        return;
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
      backgroundColor: PremiumColors.backgroundLight,

      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 365,
                      width: double.infinity,
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
                          bottomLeft: Radius.circular(42),
                          bottomRight: Radius.circular(42),
                        ),
                      ),
                    ),

                    Positioned(
                      right: -60,
                      top: 40,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),

                    Positioned(
                      left: -40,
                      bottom: -50,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),

                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 180,
                        color:
                            Colors.white.withOpacity(0.05),
                      ),
                    ),

                    Positioned(
                      top: 90,
                      right: 80,
                      child: Column(
                        children: List.generate(
                          8,
                          (index) => Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white
                                    .withOpacity(0.2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        safeTop + 18,
                        22,
                        0,
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
                              Row(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius
                                              .circular(18),
                                      border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.6),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons
                                          .fingerprint_rounded,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      const Text(
                                        'THIX ID',
                                        style: TextStyle(
                                          color:
                                              Colors.white,
                                          fontSize: 24,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                        ),
                                      ),

                                      Text(
                                        'Identité Sécurisée.\nAvenir de Confiance.',
                                        style: TextStyle(
                                          color: Colors
                                              .white
                                              .withOpacity(
                                                  0.85),
                                          fontSize: 11,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              GestureDetector(
                                onTap: _onProfileTap,
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(
                                                0.12),
                                        blurRadius: 12,
                                        offset:
                                            const Offset(
                                          0,
                                          6,
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: PremiumColors
                                        .primaryDark,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 36),

                          const Text(
                            'Bienvenue !',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Que voulez-vous faire aujourd’hui ?',
                            style: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.9),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: -34,
                      child: Container(
                        height: 72,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(34),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(
                                0.08,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 10),

                            const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF9094A6),
                              size: 26,
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: TextField(
                                controller:
                                    _searchController,
                                decoration:
                                    const InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      'Rechercher un THIX ID...',
                                  hintStyle: TextStyle(
                                    color:
                                        Color(0xFF9AA0B5),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),

                            GestureDetector(
                              onTap: _searching
                                  ? null
                                  : _handleHomeSearchVerify,
                              child: Container(
                                height: 54,
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                decoration:
                                    BoxDecoration(
                                  borderRadius:
                                      BorderRadius
                                          .circular(28),
                                  gradient:
                                      const LinearGradient(
                                    colors: [
                                      PremiumColors
                                          .primaryElectric,
                                      PremiumColors
                                          .primaryDark,
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: const [
                                    Text(
                                      'Vérifier',
                                      style: TextStyle(
                                        color:
                                            Colors.white,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons
                                          .arrow_forward_rounded,
                                      color:
                                          Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 58),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickCard(
                          title: 'Scanner un QR',
                          subtitle:
                              'Scannez un code\nen toute sécurité',
                          icon:
                              Icons.qr_code_scanner_rounded,
                          bg: PremiumColors.lavenderLight,
                          actionColor:
                              PremiumColors.primaryElectric,
                          onTap: () {
                            ThixIdentitySheets
                                .showQrScanSheet(context);
                          },
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _QuickCard(
                          title: 'Lire via NFC',
                          subtitle:
                              'Approchez votre\nappareil',
                          icon: Icons.fingerprint_rounded,
                          bg: PremiumColors.mintLight,
                          actionColor: Colors.green,
                          onTap: () {
                            ThixIdentitySheets
                                .showNfcScanSheet(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _NotificationPreviewCard(
                    onTap: () {
                      if (!auth.isAuthenticated) {
                        context.push(AppRoutes.login);
                        return;
                      }

                      NotificationsSheet.show(context);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 26),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Nos services',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color:
                              PremiumColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Tout voir',
                        style: TextStyle(
                          color: PremiumColors
                              .primaryElectric,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 18),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                sliver: StreamBuilder<SectionBadgeCounts>(
                  stream: badgeCountsStream,
                  builder: (context, snap) {
                    final counts =
                        snap.data ?? SectionBadgeCounts.zero;

                    return SliverGrid(
                      delegate:
                          SliverChildListDelegate(
                        [
                          _ServiceCard(
                            icon:
                                Icons.person_add_alt_1,
                            title:
                                'Demander un\nCompte',
                            iconBg:
                                const Color(0xFFF0F4FF),
                            iconColor:
                                PremiumColors
                                    .primaryElectric,
                            onTap: () =>
                                _handleRequestAccount(
                                    context),
                          ),

                          _ServiceCard(
                            icon:
                                Icons.account_circle,
                            title: 'Mon\nCompte',
                            iconBg:
                                const Color(0xFFF5ECFF),
                            iconColor: Colors.purple,
                            onTap: _onProfileTap,
                          ),

                          _ServiceCard(
                            icon: Icons.school,
                            title: 'Formations',
                            iconBg:
                                const Color(0xFFE8FFF5),
                            iconColor: Colors.green,
                            badgeCount:
                                counts.formations,
                            onTap: () {
                              context.push(
                                  AppRoutes.trainingHome);
                            },
                          ),

                          _ServiceCard(
                            icon: Icons.work,
                            title: 'Emplois',
                            iconBg:
                                const Color(0xFFFFF4E9),
                            iconColor: Colors.orange,
                            badgeCount: counts.jobs,
                            onTap: () {
                              context.push(
                                  AppRoutes.jobs);
                            },
                          ),

                          _ServiceCard(
                            icon: Icons.newspaper,
                            title: 'THIX\nINFO',
                            iconBg:
                                const Color(0xFFEFF3FF),
                            iconColor:
                                PremiumColors
                                    .primaryElectric,
                            badgeCount: counts.info,
                            onTap: () {
                              AlertInfoSheet.show(
                                  context);
                            },
                          ),

                          _ServiceCard(
                            icon:
                                Icons.lightbulb_rounded,
                            title:
                                'Opportunités',
                            iconBg:
                                const Color(0xFFFFF8E8),
                            iconColor: Colors.amber,
                            badgeCount:
                                counts.opportunities,
                            onTap: () {
                              context.push(
                                  AppRoutes
                                      .opportunities);
                            },
                          ),

                          _ServiceCard(
                            icon: Icons.event,
                            title:
                                'Événements',
                            iconBg:
                                const Color(0xFFF8ECFF),
                            iconColor: Colors.purple,
                            badgeCount:
                                counts.events,
                            onTap: () {
                              context.push(
                                  AppRoutes.events);
                            },
                          ),

                          _ServiceCard(
                            icon: Icons.groups,
                            title: 'Réseau\nPro',
                            iconBg:
                                const Color(0xFFFFEEF5),
                            iconColor: Colors.pink,
                            onTap: () {
                              context.push(
                                  AppRoutes.network);
                            },
                          ),
                        ],
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.78,
                      ),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 28),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PremiumColors.primaryDark,
                          PremiumColors.primaryElectric,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          right: -10,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withOpacity(0.08),
                            ),
                          ),
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.all(22),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Text(
                                      'NOTRE MISSION',
                                      style: TextStyle(
                                        color: Colors
                                            .white
                                            .withOpacity(
                                                0.7),
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                        letterSpacing:
                                            1.2,
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 10),

                                    const Text(
                                      'Construisons ensemble\nl’avenir de la jeunesse.',
                                      style: TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize: 26,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        height: 1.15,
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 10),

                                    Text(
                                      'Accédez à des opportunités,\ndes ressources et un réseau engagé.',
                                      style: TextStyle(
                                        color: Colors
                                            .white
                                            .withOpacity(
                                                0.9),
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              const Icon(
                                Icons.groups_rounded,
                                size: 86,
                                color: Colors.white,
                              ),
                            ],
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
                color: Colors.black.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 14,
              sigmaY: 14,
            ),
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color:
                    Colors.white.withOpacity(0.92),
                borderRadius:
                    BorderRadius.circular(34),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withOpacity(0.08),
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
                    icon: Icons.home_filled,
                    label: 'Accueil',
                    active: true,
                    onTap: () {},
                  ),

                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Services',
                    onTap: () {},
                  ),

                  GestureDetector(
                    onTap: () {
                      ThixIdentitySheets
                          .showQrScanSheet(context);
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            PremiumColors
                                .primaryElectric,
                            PremiumColors.primaryDark,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),

                  _NavItem(
                    icon:
                        Icons.chat_bubble_outline,
                    label: 'Messages',
                    onTap: _onMessagesTap,
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

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bg;
  final Color actionColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.actionColor,
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
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color:
                        PremiumColors.primaryDark,
                  ),
                ),

                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: actionColor,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

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
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPreviewCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _NotificationPreviewCard({
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        PremiumColors
                            .primaryElectric,
                        PremiumColors.primaryDark,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications,
                    color: Colors.white,
                  ),
                ),

                Positioned(
                  right: 2,
                  top: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    'Restez informé de vos activités\net mises à jour.',
                    style: TextStyle(
                      color: PremiumColors
                          .textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            Column(
              children: const [
                Text(
                  'Voir tout',
                  style: TextStyle(
                    color: PremiumColors
                        .primaryDark,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                SizedBox(height: 8),

                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color:
                      PremiumColors.primaryDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;
  final int badgeCount;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 28,
                  ),
                ),

                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -2,
                    child: Container(
                      padding:
                          const EdgeInsets.all(4),
                      decoration:
                          const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
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
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
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
            color: active
                ? PremiumColors.primaryElectric
                : Colors.grey.shade500,
            size: 26,
          ),

          const SizedBox(height: 4),

          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active
                  ? PremiumColors.primaryElectric
                  : Colors.grey.shade500,
            ),
          ),

          if (active)
            Container(
              margin: const EdgeInsets.only(top: 5),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color:
                    PremiumColors.primaryElectric,
              ),
            ),
        ],
      ),
    );
  }
}

enum _AccountRequestChoice {
  personal,
  enterprise
}

class AccountRequestSheet
    extends StatelessWidget {
  const AccountRequestSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(34),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Demander un compte',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choisissez le type de compte.',
                style: TextStyle(
                  color:
                      PremiumColors.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              _AccountChoiceTile(
                icon: Icons.person_outline,
                title: 'Compte Personnel',
                subtitle:
                    'Pour étudiants et citoyens',
                onTap: () => context.pop(
                  _AccountRequestChoice.personal,
                ),
              ),

              const SizedBox(height: 16),

              _AccountChoiceTile(
                icon: Icons.business_outlined,
                title: 'Compte Entreprise',
                subtitle:
                    'Pour sociétés et institutions',
                onTap: () => context.pop(
                  _AccountRequestChoice.enterprise,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChoiceTile
    extends StatelessWidget {
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PremiumColors.backgroundLight,
          borderRadius:
              BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color:
                    PremiumColors.primaryElectric,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: PremiumColors
                          .textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
