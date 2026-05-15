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
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, c) {
          // Home cards should stay compact and consistent across device sizes.
          // NOTE: Parent (grid) controls the final size; we only adapt internal spacing.
          final tight = (c.maxHeight.isFinite && c.maxHeight <= 98) || compact;
          final iconSize = tight ? 16.0 : 22.0;
          final chipSize = tight ? 32.0 : 42.0;
          final gap = tight ? 6.0 : AppSpacing.sm;
          final padding = tight ? const EdgeInsets.all(10) : AppSpacing.paddingMd;
          final cs = context.theme.colorScheme;

          final textStyle = (tight ? context.textStyles.labelSmall : context.textStyles.labelMedium)?.copyWith(
            color: filled ? const Color(0xFF0A2F5C) : cs.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.15,
          );

          final hasImage = (imageAssetPath ?? '').trim().isNotEmpty;

          return Container(
            decoration: BoxDecoration(
              color: filled ? null : cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
                    children: [
                      Container(
                        width: chipSize,
                        height: chipSize,
                        decoration: BoxDecoration(
                          color: (filled ? Colors.white : LightModeColors.accent).withValues(alpha: filled ? 0.35 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: filled ? const Color(0xFF0A2F5C) : LightModeColors.accent, size: iconSize),
                      ),
                      SizedBox(height: gap),
                      Text(
                        label,
                        style: textStyle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (badgeCount > 0) Positioned(top: 8, right: 8, child: _NotificationBadge(count: badgeCount)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The 3x2 quick access grid on Home.
///
/// This enforces identical button sizes (fixed aspect ratio) across all 6 items.
class HomeQuickAccessGrid extends StatelessWidget {
  final bool isTiny;
  final SectionBadgeCounts counts;
  final AuthController auth;
  final NotificationCountersService counters;

  const HomeQuickAccessGrid({
    super.key,
    required this.isTiny,
    required this.counts,
    required this.auth,
    required this.counters,
  });

  @override
  Widget build(BuildContext context) {
    final gap = isTiny ? AppSpacing.sm : AppSpacing.md;
    // Slightly wider than tall for a premium “panel button” look.
    final ratio = isTiny ? 1.05 : 1.12;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: gap,
      crossAxisSpacing: gap,
      childAspectRatio: ratio,
      children: [
        PremiumGridCard(
          icon: Icons.school_rounded,
          label: 'Formations',
          badgeCount: counts.formations,
          onTap: () async {
            final me = auth.currentUser;
            if (me != null) await counters.markSectionSeen(uid: me.id, section: ThixSection.formations);
            if (context.mounted) context.push(AppRoutes.trainingHome);
          },
        ),
        PremiumGridCard(
          icon: Icons.work_rounded,
          label: 'Emploi',
          badgeCount: counts.jobs,
          onTap: () async {
            final me = auth.currentUser;
            if (me != null) await counters.markSectionSeen(uid: me.id, section: ThixSection.jobs);
            if (context.mounted) context.push(AppRoutes.jobs);
          },
        ),
        PremiumGridCard(
          icon: Icons.newspaper_rounded,
          label: 'THIX\nINFO',
          filled: true,
          badgeCount: counts.info,
          onTap: () async {
            final me = auth.currentUser;
            if (me != null) await counters.markSectionSeen(uid: me.id, section: ThixSection.info);
            if (context.mounted) AlertInfoSheet.show(context);
          },
        ),
        PremiumGridCard(
          icon: Icons.lightbulb_rounded,
          label: 'Opportunités',
          badgeCount: counts.opportunities,
          imageAssetPath: 'assets/images/Office_team_grayscale_1775574009745.jpg',
          onTap: () async {
            final me = auth.currentUser;
            if (me != null) await counters.markSectionSeen(uid: me.id, section: ThixSection.opportunities);
            if (context.mounted) context.push(AppRoutes.opportunities);
          },
        ),
        PremiumGridCard(
          icon: Icons.event_available_rounded,
          label: 'Événements',
          badgeCount: counts.events,
          imageAssetPath: 'assets/images/Senior_professional_man_grayscale_1775573975687.jpg',
          onTap: () async {
            final me = auth.currentUser;
            if (me != null) await counters.markSectionSeen(uid: me.id, section: ThixSection.events);
            if (context.mounted) context.push(AppRoutes.events);
          },
        ),
        PremiumGridCard(
          icon: Icons.groups_rounded,
          label: 'Réseau Pro',
          badgeCount: 0,
          onTap: () => context.push(AppRoutes.network),
        ),
      ],
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
          height: 48,
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
                Icon(icon, color: const Color(0xFF0A2F5C), size: 16),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: context.textStyles.labelMedium?.copyWith(
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

/// Compact premium action used on Home for the two primary actions:
/// - Demander un compte
/// - Mon compte
///
/// Requirements (user request): smaller size, horizontal, white text, golden metal band.
class HomeGoldBandAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const HomeGoldBandAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final gold = (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold);
    final goldDeep = (isDark ? DarkModeColors.metalGoldDeep : LightModeColors.metalGoldDeep);
    final bg = isDark ? context.theme.colorScheme.surface : LightModeColors.primary;

    return Expanded(
      child: InkWell(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gold, LightModeColors.metalGoldSoft, goldDeep],
              stops: const [0, 0.55, 1],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 8))
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg - 1.5),
              color: bg,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.textStyles.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.05),
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _NotificationBadge(count: badgeCount),
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

class _LanguageTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? LightModeColors.metalGold : cs.outlineVariant.withValues(alpha: 0.4)),
          color: selected ? LightModeColors.metalGold.withValues(alpha: 0.08) : cs.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: selected
                  ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: LightModeColors.metalGold)
                  : Icon(Icons.circle_outlined, key: const ValueKey('off'), color: cs.onSurface.withValues(alpha: 0.35)),
            ),
          ],
        ),
      ),
    );
  }
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
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: LightModeColors.metalGold.withValues(alpha: 0.35)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 12))],
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
                        gradient: const LinearGradient(colors: [LightModeColors.accent, LightModeColors.metalGold]),
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
    final badgeCountsStream = auth.currentUser == null ? Stream<SectionBadgeCounts>.value(SectionBadgeCounts.zero) : _counters.streamCounts(auth.currentUser!.id);
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder =
        (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold)
            .withValues(alpha: 0.6);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final safeTop = MediaQuery.paddingOf(context).top;
    final w = MediaQuery.sizeOf(context).width;
    final isCompact = w < 380;
    final isTiny = w < 340;
    // Reserve space so the last row (Opportunités / Événements / Réseau Pro)
    // is never hidden under the floating Urgence/Chat buttons.
    final bottomReservedSpace = safeBottom + 120.0;
    return Scaffold(
      // User request: Home background should be light/white (keep top header unchanged).
      backgroundColor: isDark ? context.theme.scaffoldBackgroundColor : LightModeColors.surface,
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
                                    IconButton(
                                      onPressed: _showLanguagePicker,
                                      style: const ButtonStyle(overlayColor: WidgetStatePropertyAll(Colors.transparent)),
                                      icon: const Icon(Icons.language_rounded, color: Colors.white),
                                      tooltip: context.loc.t('language'),
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
                          _notifications.markRead(
                              uid: me.id, notificationId: notificationId);
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
                  ],
                ),
                // MOBILE area (everything below notifications)
                Expanded(
                  child: Container(
                    // Light/white content background (not affecting header above).
                    color: isDark ? context.theme.scaffoldBackgroundColor : LightModeColors.surface,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                // Keep these two primary actions lateral on most screens.
                                // Only stack when extremely narrow.
                                final stackVertically = c.maxWidth < 285;
                                return StreamBuilder<int>(
                                  stream: unreadStream,
                                  builder: (context, unreadSnap) {
                                    final badge = unreadSnap.data ?? 0;

                                    final requestButton = HomeGoldBandAction(
                                      icon: Icons.person_add_alt_1_rounded,
                                      label: context.loc.t('request_account'),
                                      badgeCount: badge,
                                      onTap: () => _handleRequestAccount(context),
                                    );

                                    final accountButton = HomeGoldBandAction(
                                      icon: Icons.account_circle_rounded,
                                      label: context.loc.t('my_account'),
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
                                      return Row(
                                        children: [
                                          requestButton,
                                          SizedBox(width: isTiny ? AppSpacing.sm : AppSpacing.md),
                                          accountButton,
                                        ],
                                      );
                                    }

                                    return Column(
                                      children: [
                                        Row(children: [requestButton]),
                                        const SizedBox(height: AppSpacing.sm),
                                        Row(children: [accountButton]),
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
                          child: StreamBuilder<SectionBadgeCounts>(
                            stream: badgeCountsStream,
                            builder: (context, badgeSnap) {
                              final counts = badgeSnap.data ?? SectionBadgeCounts.zero;
                              return Container(
                                constraints: const BoxConstraints(minHeight: 248),
                                decoration: BoxDecoration(
                                  color: isDark ? context.theme.colorScheme.surface : LightModeColors.surface,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                clipBehavior: Clip.antiAlias,
                                padding: EdgeInsets.fromLTRB(
                                  isTiny ? AppSpacing.sm : AppSpacing.md,
                                  isTiny ? AppSpacing.md : AppSpacing.lg,
                                  isTiny ? AppSpacing.sm : AppSpacing.md,
                                  isTiny ? AppSpacing.md : AppSpacing.lg,
                                ),
                                child: HomeQuickAccessGrid(
                                  isTiny: isTiny,
                                  counts: counts,
                                  auth: auth,
                                  counters: _counters,
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
                  final me = auth.currentUser;
                  if (me != null) {
                    unawaited(_counters.markSectionSeen(uid: me.id, section: ThixSection.messages));
                  }
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
  final void Function(Map<String, dynamic> row)? onOpen;

  static final AccessRequestService _access = AccessRequestService();

  const _NotificationsPanel(
      {required this.isAuthenticated,
      required this.notifications,
      required this.onSeeMore,
      required this.onMarkRead,
      this.onOpen});

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
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Text(
                'Annonces officielles THIX ID. Connectez-vous pour recevoir aussi vos notifications personnelles.',
                style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4),
              ),
            ),
          _HomeReceptionPreview(
            pendingAccessCount: isAuthenticated
                ? _access.streamIncomingPendingCount(ownerId: context.read<AuthController>().currentUser?.id ?? '')
                : Stream<int>.value(0),
            notifications: notifications,
            onSeeMore: onSeeMore,
            onMarkRead: onMarkRead,
            onOpen: onOpen,
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
  final void Function(Map<String, dynamic> row)? onOpen;
  final Color goldBorder;

  const _HomeReceptionPreview({required this.pendingAccessCount, required this.notifications, required this.onSeeMore, required this.onMarkRead, required this.onOpen, required this.goldBorder});

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

            final shown = rows.take(3).toList(growable: false);
            return Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  _HomeNotificationTile(
                    title: (shown[i]['title'] as String?) ?? 'Notification',
                    subtitle: (shown[i]['body'] as String?) ?? '',
                    read: (shown[i]['read'] as bool?) ?? false,
                    type: (shown[i]['type'] as String?) ?? 'generic',
                    createdAtRaw: shown[i]['created_at'],
                    onTap: () {
                      final id = (shown[i]['id'] ?? '').toString();
                      if (id.isNotEmpty) onMarkRead(id);
                      final handler = onOpen;
                      if (handler != null) handler(shown[i]);
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
  final String type;
  final Object? createdAtRaw;
  final VoidCallback onTap;

  const _HomeNotificationTile(
      {required this.title,
      required this.subtitle,
      required this.read,
      required this.type,
      required this.createdAtRaw,
      required this.onTap});

  DateTime? _tryParseDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  String _formatWhen(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final other = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(other).inDays;
    if (diffDays == 0) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    if (diffDays == 1) return 'Hier';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  IconData _iconForType(String type) {
    final t = type.trim().toLowerCase();
    if (t.contains('message') || t.contains('chat')) return Icons.mark_chat_unread_rounded;
    if (t.contains('opportun')) return Icons.lightbulb_rounded;
    if (t.contains('job') || t.contains('emploi') || t.contains('offer')) return Icons.work_rounded;
    if (t.contains('event') || t.contains('événement') || t.contains('evenement')) return Icons.event_available_rounded;
    if (t.contains('access')) return Icons.badge_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final isDark = context.theme.brightness == Brightness.dark;
    final goldBorder =
        (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold)
            .withValues(alpha: 0.45);
    return InkWell(
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
              child: Icon(_iconForType(type), color: read ? cs.primary : LightModeColors.accent, size: 18),
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
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatWhen(_tryParseDate(createdAtRaw)),
                style: context.textStyles.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.55), fontWeight: FontWeight.w700),
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
