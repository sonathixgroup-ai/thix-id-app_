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

// ==================== ANCIENS WIDGETS (conservés pour compatibilité) ====================

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

// ==================== NOUVEAUX WIDGETS POUR LE DESIGN ====================

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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
          border: Border.all(color: selected ? LightModeColors.metalGold : cs.outlineVariant.withAlpha(102)),
          color: selected ? LightModeColors.metalGold.withAlpha(20) : cs.surface,
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
                  : Icon(Icons.circle_outlined, key: const ValueKey('off'), color: cs.onSurface.withAlpha(89)),
            ),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldBorder = (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold).withAlpha(140);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: goldBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 30, offset: const Offset(0, 18))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                    color: cs.onSurface.withAlpha(30),
                    borderRadius: BorderRadius.circular(999)),
              ),
              Text('Demande de compte',
                  style: context.textStyles.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choisissez le profil à créer. Vous pourrez compléter les informations et finaliser le dossier ensuite.',
                style: context.textStyles.bodyMedium?.copyWith(
                    color: cs.onSurface.withAlpha(199), height: 1.5),
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
                      foregroundColor: cs.onSurface.withAlpha(204)),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldBorder = (isDark ? DarkModeColors.metalGold : LightModeColors.metalGold).withAlpha(115);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withAlpha(89),
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
                color: LightModeColors.accent.withAlpha(30),
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
                        color: cs.onSurface.withAlpha(184),
                        height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.arrow_forward_rounded,
                color: cs.onSurface.withAlpha(140), size: 18),
          ],
        ),
      ),
    );
  }
}

// ==================== PAGE HOME PRINCIPALE ====================

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

  void _onServicesTap() {
    // Fait défiler jusqu'à la section "Nos services" – pour l'instant un snackbar
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

    const double fabSpace = 80.0;

    return Scaffold(
      backgroundColor: isDark ? context.theme.scaffoldBackgroundColor : LightModeColors.surface,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête THIX ID
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
                          const Text(
                            'Bienvenue ! Que voulez-vous faire aujourd’hui ?',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
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
                                    child: const Text(
                                      'Vérifier',
                                      style: TextStyle(color: Color(0xFF0A2F5C), fontWeight: FontWeight.w800, fontSize: 14),
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

                // Actions rapides : Scanner QR & Lire via NFC
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

                // Notifications
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

                // Nos services (grille 8 cartes)
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
                            onPressed: () {},
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

                // Notre mission
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
                SizedBox(height: fabSpace + 20),
              ],
            ),
          ),

          // FAB Urgence
          Positioned(
            bottom: safeBottom + 16,
            left: 24,
            child: const EmergencyFab(),
          ),
          // FAB Chat
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        selectedItemColor: LightModeColors.accent,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
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

// ==================== EXTENSION THEME HELPER ====================

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
