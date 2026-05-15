import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/emergency/emergency_overlay.dart';
import 'package:thix_id/theme.dart';

class EmergencyFab extends StatefulWidget {
  const EmergencyFab({super.key});

  @override
  State<EmergencyFab> createState() => _EmergencyFabState();
}

class _EmergencyFabState extends State<EmergencyFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  Future<void> _handleTap() async {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      await EmergencyOverlay.show(context);
      return;
    }

    if (!mounted) return;
    final goLogin = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Container(
                decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border.all(color: theme.dividerColor)),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: theme.colorScheme.primary.withValues(alpha: 0.10),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
                          ),
                          child: Icon(Icons.lock_rounded, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text('Connexion requise', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                        IconButton(onPressed: () => context.pop(false), icon: Icon(Icons.close_rounded, color: theme.hintColor))
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Pour accéder aux fonctionnalités URGENCE (GPS, preuves, contacts), vous devez être connecté.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.pop(false),
                            child: Text(context.loc.t('later')),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => context.pop(true),
                            icon: const Icon(Icons.login_rounded, color: Colors.white),
                            label: Text(context.loc.t('login'), style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (goLogin == true && mounted) context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context);
    // Per requirement: the URGENCE button must always stay red.
    final red = scheme.brightness == Brightness.dark ? DarkModeColors.emergencyRed : LightModeColors.emergencyRed;
    final scale = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    final glow = Tween<double>(begin: 0.20, end: 0.42).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Transform.scale(
          scale: scale.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
               onTap: _handleTap,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: red,
                  boxShadow: [BoxShadow(color: red.withValues(alpha: glow.value), blurRadius: 26, spreadRadius: 5)],
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: red, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.28))),
                    alignment: Alignment.center,
                    child: const Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
