import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import '../../theme.dart';

class EduCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;

  const EduCategoryChip({
    super.key,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: selected ? LightModeColors.accent : context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? Colors.transparent : context.theme.dividerColor,
        ),
      ),
      child: Text(
        label,
        style: context.textStyles.labelMedium?.copyWith(
          color: selected ? const Color(0xFF0A2F5C) : LightModeColors.secondaryText,
        ),
      ),
    );
  }
}

class FormationCard extends StatelessWidget {
  final String title;
  final String instructor;
  final String rating;
  final String reviews;
  final String price;
  final String tag;
  final String imgDesc;

  const FormationCard({
    super.key,
    required this.title,
    required this.instructor,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.tag,
    required this.imgDesc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: Stack(
              children: [
                Container(color: LightModeColors.hint), // placeholder image
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: LightModeColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: Text(
                      tag,
                      style: context.textStyles.labelSmall?.copyWith(
                        color: const Color(0xFF0A2F5C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textStyles.titleMedium?.copyWith(
                    color: context.theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: LightModeColors.secondaryText),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      instructor,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: LightModeColors.accent),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          rating,
                          style: context.textStyles.labelMedium?.copyWith(
                            color: context.theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          "($reviews)",
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.hint,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9C74F).withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        price,
                        style: context.textStyles.titleSmall?.copyWith(
                          color: context.theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EducationPage extends StatelessWidget {
  const EducationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: const BoxDecoration(
                color: Color(0xFF0A3D62),
                border: Border(bottom: BorderSide(color: LightModeColors.accent, width: 2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                        onPressed: () => context.popOrGo(AppRoutes.home),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        "Formations Premium",
                        style: context.textStyles.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search_rounded, size: 24, color: LightModeColors.accent),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined, size: 24, color: Colors.white),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: context.theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: context.theme.dividerColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              )
                            ],
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Rechercher une formation certifiée...",
                              prefixIcon: const Icon(Icons.search, color: LightModeColors.hint),
                              border: InputBorder.none,
                              hintStyle: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.hint),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              EduCategoryChip(label: "Tous les cours", selected: true),
                              EduCategoryChip(label: "Cybersécurité", selected: false),
                              EduCategoryChip(label: "Blockchain ID", selected: false),
                              EduCategoryChip(label: "Leadership", selected: false),
                              EduCategoryChip(label: "Fintech", selected: false),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Certifications THIX ID Gold",
                              style: context.textStyles.titleMedium?.copyWith(
                                color: context.theme.colorScheme.onSurface,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                "Tout voir",
                                style: context.textStyles.labelLarge?.copyWith(
                                  color: LightModeColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(color: LightModeColors.accent),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(color: LightModeColors.secondary), // placeholder
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Color(0xF20A3D62), Color(0xAA0A3D62), Colors.transparent],
                                    stops: [0, 0.6, 1],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                      decoration: BoxDecoration(
                                        color: LightModeColors.accent,
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          )
                                        ],
                                      ),
                                      child: Text(
                                        "OFFRE INSTITUTIONNELLE",
                                        style: context.textStyles.labelSmall?.copyWith(
                                          color: const Color(0xFF0A2F5C),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Expert en Souveraineté\nNumérique",
                                          style: context.textStyles.headlineMedium?.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          "Certification d'État Niveau 1",
                                          style: context.textStyles.bodySmall?.copyWith(
                                            color: LightModeColors.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final me = context.read<AuthController>().currentUser;
                                        if (me == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connexion requise.')));
                                          return;
                                        }
                                        final confirmed = await showModalBottomSheet<bool>(
                                          context: context,
                                          backgroundColor: Colors.transparent,
                                          isScrollControlled: true,
                                          builder: (_) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: context.theme.colorScheme.surface,
                                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl)),
                                                border: Border.all(color: context.theme.dividerColor),
                                              ),
                                              padding: const EdgeInsets.all(AppSpacing.lg),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(child: Text('Inscription formation', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                                                      IconButton(onPressed: () => context.pop(false), icon: const Icon(Icons.close_rounded)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: AppSpacing.sm),
                                                  Text('Inscription à une formation officielle (paiement simulé). Elle apparaîtra dans votre Dashboard.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4)),
                                                  const SizedBox(height: AppSpacing.lg),
                                                  SizedBox(
                                                    height: 52,
                                                    child: ElevatedButton.icon(
                                                      onPressed: () => context.pop(true),
                                                      icon: const Icon(Icons.school_rounded, color: Color(0xFF0A2F5C)),
                                                      label: Text("Confirmer (45 USD)", style: context.textStyles.labelLarge?.copyWith(color: const Color(0xFF0A2F5C), fontWeight: FontWeight.w900)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: LightModeColors.accent,
                                                        foregroundColor: const Color(0xFF0A2F5C),
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: AppSpacing.sm),
                                                  TextButton(onPressed: () => context.pop(false), child: const Text('Annuler')),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                        if (confirmed != true) return;

                                        final users = FirestoreUserService();
                                        try {
                                          final current = await users.fetchUserByUid(me.id);
                                          final existing = current?.enrollments ?? const [];
                                          final next = [...existing];
                                          final exists = next.any((e) => ((e['title'] as String?) ?? '').toLowerCase().contains('souveraineté'));
                                          if (!exists) {
                                            next.add({'title': 'Expert en Souveraineté Numérique', 'provider': 'Cabinet du Numérique', 'progress': 0, 'status': 'En cours'});
                                            await users.updateProfile(uid: me.id, enrollments: next);
                                          }
                                          await users.addPaymentTransaction(uid: me.id, title: 'Inscription formation', amount: 45, currency: 'USD', method: 'Simulé', status: 'paid', meta: {'formation': 'Expert en Souveraineté Numérique'});
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inscription enregistrée.')));
                                        } catch (e) {
                                          debugPrint('EducationPage: enroll failed err=$e');
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inscription impossible.')));
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: LightModeColors.accent,
                                        foregroundColor: const Color(0xFF0A2F5C),
                                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                                      ),
                                      child: Text(
                                        "S'inscrire - 45 USD",
                                        style: context.textStyles.labelLarge?.copyWith(
                                          color: const Color(0xFF0A2F5C),
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
                    const SizedBox(height: AppSpacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Programmes Recommandés",
                          style: context.textStyles.titleMedium?.copyWith(
                            color: context.theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const FormationCard(title: "Cadre Légal de l'Identité Numérique (RDC)", instructor: "Cabinet du Numérique", rating: "5.0", reviews: "450", price: "25 USD", tag: "Officiel", imgDesc: "legal documents gavel"),
                        const FormationCard(title: "Intégration API THIX pour Entreprises", instructor: "THIX Dev Team", rating: "4.9", reviews: "890", price: "60 USD", tag: "Technique", imgDesc: "software architecture diagram"),
                        const FormationCard(title: "Éthique et Gouvernance des Données", instructor: "Prof. Albertine Mwamba", rating: "4.8", reviews: "320", price: "Gratuit", tag: "Gouvernement", imgDesc: "ethics abstract concept"),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0A3D62), Color(0xFF1E5F8C)],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: const Color(0xFFF9C74F).withValues(alpha: 0.26)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9C74F).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: LightModeColors.accent),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.school_rounded, color: LightModeColors.accent, size: 32),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Tableau de Bord Étudiant",
                                  style: context.textStyles.labelLarge?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  "3 Modules en attente d'examen",
                                  style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: const BoxDecoration(
                              color: LightModeColors.accent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0A2F5C), size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}