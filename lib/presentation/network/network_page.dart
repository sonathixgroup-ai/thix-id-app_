import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/nav.dart';
import '../../theme.dart';

class SuggestionCard extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final String job;
  final VoidCallback? onTap;

  const SuggestionCard({
    super.key,
    this.photoUrl,
    required this.name,
    required this.job,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = photoUrl?.trim().isNotEmpty == true
        ? CircleAvatar(backgroundImage: NetworkImage(photoUrl!), backgroundColor: Colors.transparent)
        : const CircleAvatar(backgroundColor: LightModeColors.background, child: Icon(Icons.person, color: LightModeColors.hint));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.theme.dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.theme.colorScheme.primary, width: 2)),
                  child: avatar,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: LightModeColors.success, shape: BoxShape.circle, border: Border.all(color: context.theme.colorScheme.surface, width: 2)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.verified, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(name, style: context.textStyles.labelLarge?.copyWith(color: context.theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(job, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(color: LightModeColors.accent, borderRadius: BorderRadius.circular(AppRadius.md)),
              alignment: Alignment.center,
              child: Text('Voir profil', style: context.textStyles.labelSmall?.copyWith(color: const Color(0xFF0A2F5C))),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionItem extends StatelessWidget {
  final String name;
  final String job;
  final bool verified;
  final String status;
  final Color statusBg;
  final Color statusText;
  final String photoDesc;

  const ConnectionItem({
    super.key,
    required this.name,
    required this.job,
    required this.verified,
    required this.status,
    required this.statusBg,
    required this.statusText,
    required this.photoDesc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              color: LightModeColors.background,
            ),
            child: const Icon(Icons.person, color: LightModeColors.hint),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: context.textStyles.titleMedium?.copyWith(
                        color: context.theme.colorScheme.onSurface,
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.verified, size: 16, color: LightModeColors.success),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  job,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: LightModeColors.secondaryText,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    status,
                    style: context.textStyles.labelSmall?.copyWith(color: statusText),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: context.theme.colorScheme.primary,
              side: BorderSide(color: context.theme.colorScheme.primary),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text("Profil"),
          ),
        ],
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const QuickAction({
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
        child: Column(
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: LightModeColors.accent,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF0A2F5C), size: 28),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: context.textStyles.labelMedium?.copyWith(
                color: const Color(0xFF0A2F5C),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  final _profiles = ProfileService();
  late Future<List<ThixProfile>> _suggestions;

  @override
  void initState() {
    super.initState();
    _suggestions = _profiles.fetchPublicSuggestions(limit: 12);
  }

  void _openInvite(BuildContext context) {
    final auth = context.read<AuthController>();
    final me = auth.currentUser;
    if (me == null) {
      context.push(AppRoutes.login);
      return;
    }
    ThixIdentitySheets.showInviteSheet(context, thixId: me.thixId, displayName: me.displayName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A3D62), Color(0xFF1E5F8C)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.xl),
                    bottomRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Réseau Pro",
                              style: context.textStyles.headlineMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              "Identité Vérifiée • Réseau Sécurisé",
                              style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.accent,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          alignment: Alignment.center,
                          child: Badge(
                            label: const Text('3'),
                            backgroundColor: LightModeColors.error,
                            textColor: Colors.white,
                            child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: LightModeColors.hint),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Rechercher un professionnel (THIX ID)...",
                                border: InputBorder.none,
                                hintStyle: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.hint),
                              ),
                            ),
                          ),
                          Icon(Icons.tune_rounded, color: context.theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    QuickAction(icon: Icons.qr_code_scanner_rounded, label: "Scanner QR", onTap: () => ThixIdentitySheets.showQrScanSheet(context)),
                    const SizedBox(width: AppSpacing.md),
                    QuickAction(
                      icon: Icons.person_add_alt_1_rounded,
                      label: "Ajouter ID",
                      onTap: () => ThixIdentitySheets.showVerifySheet(context),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    QuickAction(
                      icon: Icons.share_rounded,
                      label: "Inviter",
                      onTap: () => _openInvite(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Suggestions pour vous",
                            style: context.textStyles.titleLarge?.copyWith(
                              color: context.theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            "Voir tout",
                            style: context.textStyles.labelLarge?.copyWith(
                              color: context.theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: FutureBuilder<List<ThixProfile>>(
                        future: _suggestions,
                        builder: (context, snap) {
                          final data = snap.data;
                          if (snap.connectionState != ConnectionState.done) {
                            return Row(
                              children: List.generate(3, (i) {
                                return Container(
                                  width: 160,
                                  height: 190,
                                  margin: const EdgeInsets.only(right: AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: context.theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(color: context.theme.dividerColor),
                                  ),
                                );
                              }),
                            );
                          }
                          if (data == null || data.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: context.theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(color: context.theme.dividerColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.people_alt_rounded, color: context.theme.colorScheme.primary),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: Text('Aucune suggestion disponible pour le moment.', style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurface))),
                                ],
                              ),
                            );
                          }
                          return Row(
                            children: data
                                .map(
                                  (p) => SuggestionCard(
                                    name: p.displayName.trim().isEmpty ? ((p.thixId ?? '').trim().toUpperCase()) : p.displayName,
                                    job: (p.occupation ?? '').trim().isEmpty ? 'Professionnel vérifié' : (p.occupation ?? '').trim(),
                                    photoUrl: p.photoUrl,
                                    onTap: () {
                                      final thix = (p.thixId ?? '').trim().toUpperCase();
                                      if (thix.isEmpty) return;
                                      context.push('${AppRoutes.publicProfile}?thixId=$thix');
                                    },
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Mes Connexions",
                          style: context.textStyles.titleLarge?.copyWith(
                            color: context.theme.colorScheme.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            "128",
                            style: context.textStyles.labelSmall?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: context.theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded, color: context.theme.colorScheme.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Aucune connexion pour le moment. Utilisez “Scanner QR” ou “Ajouter ID” pour créer votre réseau.',
                              style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A3D62).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: context.theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, color: context.theme.colorScheme.primary, size: 32),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Confidentialité THIX ID",
                            style: context.textStyles.labelLarge?.copyWith(
                              color: context.theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            "Toutes les connexions sont cryptées de bout en bout via THIX CHAT.",
                            style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.secondaryText,
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
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}