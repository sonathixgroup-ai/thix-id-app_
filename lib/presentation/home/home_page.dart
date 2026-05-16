import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/alert_info_sheet.dart';
import 'package:thix_id/presentation/emergency/emergency_fab.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import '../../theme.dart';
import '../../nav.dart';

class PremiumGridCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool filled;
  final String? imageAssetPath;
  final int badgeCount;

  const PremiumGridCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.filled = false,
    this.imageAssetPath,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder =
        (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold)
            .withValues(alpha: 0.55);
    final fillGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        LightModeColors.accent,
        LightModeColors.metalGold,
        LightModeColors.metalGoldDeep.withValues(alpha: 0.85)
      ],
    );
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, c) {
            final tight = (c.maxHeight.isFinite && c.maxHeight < 92) || compact;
            final iconSize = tight ? 18.0 : 24.0;
            final chipSize = tight ? 34.0 : 44.0;
            final gap = tight ? 6.0 : AppSpacing.sm;
            final padding = tight ? const EdgeInsets.all(10) : AppSpacing.paddingMd;
            final cs = context.theme.colorScheme;

            final textStyle = (tight ? context.textStyles.labelSmall : context.textStyles.labelMedium)?.copyWith(
              color: filled ? const Color(0xFF0A2F5C) : cs.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.2,
            );

            final hasImage = (imageAssetPath ?? '').trim().isNotEmpty;

            return Container(
              decoration: BoxDecoration(
                color: filled ? null : cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
                border: Border.all(color: filled ? Colors.transparent : goldBorder),
                gradient: filled ? fillGradient : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (hasImage && !filled)
                    Positioned.fill(
                      child: Image.asset(
                        imageAssetPath!,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
                        colorBlendMode: BlendMode.darken,
                      ),
                    ),
                  if (hasImage && !filled)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: isDark ? 0.05 : 0.0),
                              cs.surface.withValues(alpha: isDark ? 0.35 : 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: padding,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: chipSize,
                          height: chipSize,
                          decoration: BoxDecoration(
                            color: (filled ? Colors.white : LightModeColors.accent).withValues(alpha: filled ? 0.35 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            icon,
                            color: filled ? const Color(0xFF0A2F5C) : LightModeColors.accent,
                            size: iconSize,
                          ),
                        ),
                        SizedBox(height: gap),
                        Flexible(
                          child: Text(
                            label,
                            style: textStyle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _NotificationBadge(count: badgeCount),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final int count;
  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: LightModeColors.error,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.surface, width: 2),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.0),
      ),
    );
  }
}

class RichGoldAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const RichGoldAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 4),
              )
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                LightModeColors.accent,
                LightModeColors.metalGold,
                LightModeColors.metalGoldDeep
              ],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [LightModeColors.accent, LightModeColors.metalGold],
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF0A2F5C), size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: context.textStyles.labelLarge?.copyWith(
                    color: const Color(0xFF0A2F5C),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
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

  static final RegExp _uidLikeRegex = RegExp(r'^[A-Za-z0-9_\-]{20,}$');

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
            "Saisissez un THIX ID (ex: ${ThixIdService.exampleV2}) ou un UID, puis appuyez sur 'Vérifier'.",
      );
      return;
    }

    final normalized = ThixIdService.normalize(raw);
    final isThix =
        normalized.startsWith('THIX-') && ThixIdService.isValid(normalized);
    final isUid = _uidLikeRegex.hasMatch(raw);
    if (!isThix && !isUid) {
      await FullScreenMessage.showError(
        context,
        title: 'Identifiant invalide',
        message:
            'Format attendu: ${ThixIdService.exampleV2} (recommandé) ou ${ThixIdService.exampleV1} ou UID (identifiant long alphanumérique).',
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
          message:
              "Aucun profil n'a été trouvé pour l'identifiant: ${normalized.toUpperCase()}.",
        );
        return;
      }

      final thix = user.thixId.trim().toUpperCase();
      if (thix.isNotEmpty && ThixIdService.isValid(thix)) {
        context.push('${AppRoutes.publicProfile}?thixId=$thix');
      } else {
        await ThixIdentitySheets.showVerifySheet(context,
            initialUidOrThixId: user.id);
      }
    } catch (e) {
      if (!mounted) return;
      await FullScreenMessage.showError(
        context,
        title: 'Erreur de recherche',
        message:
            "Impossible d'exécuter la vérification. Réessayez.\n\nDétail: $e",
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final unreadStream = auth.currentUser == null ? Stream<int>.value(0) : _notifications.streamUnreadCount(auth.currentUser!.id);
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder =
        (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold)
            .withValues(alpha: 0.6);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final safeTop = MediaQuery.paddingOf(context).top;
    final w = MediaQuery.sizeOf(context).width;
    final isCompact = w < 380;
    // Reserve space so the last row (Opportunités / Événements / Réseau Pro)
    // is never hidden under the floating Urgence/Chat buttons.
    final bottomReservedSpace = safeBottom + 120.0;
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              children: [
                // FIXED area (header + quick actions + notifications)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: double.infinity,
                          height: (isCompact ? 206 : 220) + safeTop,
                          padding: EdgeInsets.only(top: safeTop),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF0A2F5C), Color(0xFF0F2B4A)]),
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(32),
                                bottomRight: Radius.circular(32)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned(
                                  right: -100,
                                  bottom: -50,
                                  child: Icon(Icons.fingerprint,
                                      size: 400,
                                      color: LightModeColors.accent
                                          .withValues(alpha: 0.05))),
                              Positioned(
                                  left: -80,
                                  top: -20,
                                  child: Icon(Icons.security,
                                      size: 200,
                                      color: LightModeColors.accent
                                          .withValues(alpha: 0.03))),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                              top: safeTop + (isCompact ? 70 : 86)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      border: Border.all(
                                          color: LightModeColors.accent,
                                          width: 2),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.lg),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1))
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.fingerprint,
                                        color: LightModeColors.accent,
                                        size: 32),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('THIX ID',
                                            style: context
                                                .textStyles.headlineMedium
                                                ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.5)),
                                        Text(
                                            'Identité Sécurisée. Avenir de Confiance.',
                                            style: context.textStyles.labelSmall
                                                ?.copyWith(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    fontWeight:
                                                        FontWeight.w300)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(
                              top: safeTop + (isCompact ? 150 : 168)),
                          width: w * (isCompact ? 0.94 : 0.92),
                          height: 56,
                          decoration: BoxDecoration(
                            color: context.theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 10))
                            ],
                            border: Border.all(color: goldBorder),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 4, 4, 4),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  color: LightModeColors.hint, size: 22),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _searching
                                      ? null
                                      : _handleHomeSearchVerify(),
                                  decoration: InputDecoration(
                                      hintText: 'Rechercher un THIX ID...',
                                      hintStyle: context.textStyles.bodyMedium
                                          ?.copyWith(
                                              color: LightModeColors.hint),
                                      border: InputBorder.none,
                                      isDense: true),
                                ),
                              ),
                              GestureDetector(
                                onTap:
                                    _searching ? null : _handleHomeSearchVerify,
                                child: Container(
                                  height: 48,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isCompact
                                          ? AppSpacing.md
                                          : AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.1),
                                          blurRadius: 6,
                                          offset: const Offset(0, 4))
                                    ],
                                    gradient: const LinearGradient(colors: [
                                      LightModeColors.accent,
                                      LightModeColors.metalGold
                                    ]),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('Vérifier',
                                      style: context.textStyles.labelLarge
                                          ?.copyWith(
                                              color: const Color(0xFF0A2F5C),
                                              fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                      child: Row(
                        children: [
                          RichGoldAction(icon: Icons.qr_code_scanner_rounded, label: 'Scanner QR', onTap: () => ThixIdentitySheets.showQrScanSheet(context)),
                          const SizedBox(width: AppSpacing.md),
                          RichGoldAction(icon: Icons.nfc_rounded, label: 'Lire via NFC', onTap: () => ThixIdentitySheets.showNfcScanSheet(context)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                      child: _NotificationsPanel(
                        isAuthenticated: auth.isAuthenticated,
                        notifications: auth.currentUser == null
                            ? null
                            : _notifications
                                .streamForUser(auth.currentUser!.id),
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
                          _notifications.markRead(
                              uid: me.id, notificationId: notificationId);
                        },
                      ),
                    ),
                  ],
                ),
                // MOBILE area (everything below notifications)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final stackVertically = c.maxWidth < 360;
                              return StreamBuilder<int>(
                                stream: unreadStream,
                                builder: (context, unreadSnap) {
                                  final badge = unreadSnap.data ?? 0;

                                  final requestButton = PremiumGridCard(
                                    icon: Icons.person_add_alt_1_rounded,
                                    label: 'Demander un\nCompte',
                                    compact: true,
                                    badgeCount: badge,
                                    onTap: () => _handleRequestAccount(context),
                                  );

                                  final accountButton = PremiumGridCard(
                                    icon: Icons.account_circle_rounded,
                                    label: 'Mon\nCompte',
                                    compact: true,
                                    badgeCount: badge,
                                    onTap: () {
                                      if (auth.isAuthenticated) {
                                        final t = auth.currentUser?.accountType;
                                        context.go(t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard);
                                        return;
                                      }
                                      context.push(AppRoutes.login);
                                    },
                                  );

                                  if (!stackVertically) {
                                    return SizedBox(
                                      height: 92,
                                      child: Row(
                                        children: [
                                          requestButton,
                                          const SizedBox(width: AppSpacing.md),
                                          accountButton,
                                        ],
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      SizedBox(height: 92, child: Row(children: [requestButton])),
                                      const SizedBox(height: AppSpacing.md),
                                      SizedBox(height: 92, child: Row(children: [accountButton])),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(
                              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                LightModeColors.metalGold,
                                LightModeColors.accent,
                                LightModeColors.metalGoldSoft,
                                LightModeColors.metalGold,
                                LightModeColors.metalGoldDeep
                              ],
                              stops: [0, 0.3, 0.5, 0.7, 1],
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10))
                            ],
                          ),
                          child: StreamBuilder<int>(
                            stream: unreadStream,
                            builder: (context, unreadSnap) {
                              final badge = unreadSnap.data ?? 0;
                              return Container(
                            decoration: BoxDecoration(
                                color: context.theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(22)),
                            clipBehavior: Clip.antiAlias,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    PremiumGridCard(
                                      icon: Icons.school_rounded,
                                      label: 'Formations',
                                      badgeCount: badge,
                                      onTap: () =>
                                          context.push(AppRoutes.education),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    PremiumGridCard(
                                      icon: Icons.work_rounded,
                                      label: 'Emploi',
                                      badgeCount: badge,
                                      onTap: () => context.push(AppRoutes.jobs),
                                    ),
                                    PremiumGridCard(
                                      icon: Icons.newspaper_rounded,
                                      label: 'THIX\nINFO',
                                      filled: true,
                                      badgeCount: badge,
                                      onTap: () => AlertInfoSheet.show(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    PremiumGridCard(
                                        icon: Icons.lightbulb_rounded,
                                        label: 'Opportunités',
                                        badgeCount: badge,
                                        imageAssetPath: 'assets/images/Office_team_grayscale_1775574009745.jpg',
                                        onTap: () =>
                                            context.push(AppRoutes.opportunities)),
                                    const SizedBox(width: AppSpacing.md),
                                    PremiumGridCard(
                                        icon: Icons.event_available_rounded,
                                        label: 'Événements',
                                        badgeCount: badge,
                                        imageAssetPath: 'assets/images/Senior_professional_man_grayscale_1775573975687.jpg',
                                        onTap: () =>
                                            context.push(AppRoutes.events)),
                                    const SizedBox(width: AppSpacing.md),
                                    PremiumGridCard(
                                        icon: Icons.groups_rounded,
                                        label: 'Réseau Pro',
                                        badgeCount: badge,
                                        onTap: () =>
                                            context.push(AppRoutes.network)),
                                  ],
                                ),
                              ],
                            ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: bottomReservedSpace),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Removed duplicate emergency button on Home page.
          // The animated EmergencyFab lives only on Home page.
          Positioned(
            bottom: safeBottom + 16,
            left: 24,
            child: const EmergencyFab(),
          ),
          Positioned(
            bottom: safeBottom + 16,
            right: 24,
            child: GestureDetector(
              onTap: () {
                if (auth.isAuthenticated) {
                  context.push(AppRoutes.chat);
                  return;
                }
                context.push(AppRoutes.login);
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    )
                  ],
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFD4AF37), Color(0xFFF9C74F)],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: LightModeColors.accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.forum_rounded,
                        color: Color(0xFF0A2F5C), size: 26),
                  ),
                ),
              ),
            ),
          ),
          if (_searching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3)),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  final bool isAuthenticated;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final VoidCallback onSeeMore;
  final void Function(String notificationId) onMarkRead;

  static final AccessRequestService _access = AccessRequestService();

  const _NotificationsPanel(
      {required this.isAuthenticated,
      required this.notifications,
      required this.onSeeMore,
      required this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder =
        (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold)
            .withValues(alpha: 0.55);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: goldBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10))
        ],
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: LightModeColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                alignment: Alignment.center,
                child: const Icon(Icons.notifications_rounded,
                    color: LightModeColors.accent, size: 17),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Notifications',
                    style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: cs.onSurface)),
              ),
              TextButton(
                onPressed: onSeeMore,
                style: TextButton.styleFrom(
                    foregroundColor: LightModeColors.accent,
                    padding: EdgeInsets.zero),
                child: Text('Voir plus  ›',
                    style: context.textStyles.labelLarge?.copyWith(
                        color: LightModeColors.accent,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!isAuthenticated)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
              child: Text('Connectez-vous pour voir vos notifications.',
                  style: context.textStyles.bodySmall?.copyWith(
                      color: LightModeColors.secondaryText, height: 1.4)),
            )
          else
            _HomeReceptionPreview(
              pendingAccessCount: _access.streamIncomingPendingCount(ownerId: context.read<AuthController>().currentUser?.id ?? ''),
              notifications: notifications,
              onSeeMore: onSeeMore,
              onMarkRead: onMarkRead,
              goldBorder: goldBorder,
            ),
        ],
      ),
    );
  }
}

class _HomeReceptionPreview extends StatelessWidget {
  final Stream<int> pendingAccessCount;
  final Stream<List<Map<String, dynamic>>>? notifications;
  final VoidCallback onSeeMore;
  final void Function(String notificationId) onMarkRead;
  final Color goldBorder;

  const _HomeReceptionPreview({required this.pendingAccessCount, required this.notifications, required this.onSeeMore, required this.onMarkRead, required this.goldBorder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: pendingAccessCount,
      builder: (context, accessSnap) {
        final pending = accessSnap.data ?? 0;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: notifications,
          builder: (context, snap) {
            final rows = snap.data ?? const <Map<String, dynamic>>[];
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }

            if (pending > 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 4),
                child: Text('Vous avez $pending demande(s) d\'accès en attente. Touchez « Voir plus » pour approuver.',
                    style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4)),
              );
            }

            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 4),
                child: Text('Aucune notification.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4)),
              );
            }

            final shown = rows.take(2).toList(growable: false);
            return Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  _HomeNotificationTile(
                    title: (shown[i]['title'] as String?) ?? 'Notification',
                    subtitle: (shown[i]['body'] as String?) ?? '',
                    read: (shown[i]['read'] as bool?) ?? false,
                    onTap: () {
                      final id = (shown[i]['id'] ?? '').toString();
                      if (id.isEmpty) return;
                      onMarkRead(id);
                    },
                  ),
                  if (i != shown.length - 1) Divider(color: goldBorder.withValues(alpha: 0.35), height: 10),
                ]
              ],
            );
          },
        );
      },
    );
  }
}

class _HomeNotificationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool read;
  final VoidCallback onTap;

  const _HomeNotificationTile(
      {required this.title,
      required this.subtitle,
      required this.read,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder =
        (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold)
            .withValues(alpha: 0.45);
    return InkWell(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: read
                    ? context.theme.scaffoldBackgroundColor
                    : LightModeColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: goldBorder),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.notifications_rounded,
                  color: read ? cs.primary : LightModeColors.accent, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.textStyles.bodyMedium?.copyWith(
                          fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                          height: 1.15)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: context.textStyles.bodySmall?.copyWith(
                          color: LightModeColors.secondaryText, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (!read)
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: LightModeColors.accent, shape: BoxShape.circle))
            else
              const SizedBox(width: 8, height: 8),
          ],
        ),
      ),
    );
  }
}

enum _AccountRequestChoice { personal, enterprise }

/// Bottom sheet allowing the user to choose what type of account to request.
class AccountRequestSheet extends StatelessWidget {
  const AccountRequestSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder =
        (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold)
            .withValues(alpha: 0.55);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: goldBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 18))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999)),
              ),
              Text('Demande de compte',
                  style: context.textStyles.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choisissez le profil à créer. Vous pourrez compléter les informations et finaliser le dossier ensuite.',
                style: context.textStyles.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.78), height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              _AccountChoiceTile(
                icon: Icons.person_rounded,
                title: 'Compte Personnel',
                subtitle: 'Citoyen / résident / étudiant',
                onTap: () => context.pop(_AccountRequestChoice.personal),
              ),
              const SizedBox(height: AppSpacing.md),
              _AccountChoiceTile(
                icon: Icons.domain_rounded,
                title: 'Compte Entreprise',
                subtitle: 'Institution, société, ONG, établissement',
                onTap: () => context.pop(_AccountRequestChoice.enterprise),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(
                      foregroundColor: cs.onSurface.withValues(alpha: 0.8)),
                  child: const Text('Annuler'),
                ),
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
    final cs = context.theme.colorScheme;
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder =
        (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold)
            .withValues(alpha: 0.45);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: goldBorder),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LightModeColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: LightModeColors.accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.textStyles.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.72),
                        height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.arrow_forward_rounded,
                color: cs.onSurface.withValues(alpha: 0.55), size: 18),
          ],
        ),
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
