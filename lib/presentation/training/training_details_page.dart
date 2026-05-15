import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/training_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/training_service.dart';
import 'package:thix_id/theme.dart';

class TrainingDetailsPage extends StatefulWidget {
  final String trainingId;
  const TrainingDetailsPage({super.key, required this.trainingId});

  @override
  State<TrainingDetailsPage> createState() => _TrainingDetailsPageState();
}

class _TrainingDetailsPageState extends State<TrainingDetailsPage> {
  final _svc = TrainingService();
  final _docs = DocumentService();

  bool _loading = true;
  String? _error;
  TrainingItem? _training;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await _svc.fetchTraining(widget.trainingId);
      if (!mounted) return;
      setState(() => _training = t);
      if (t != null && (t.coverImageBucket ?? '').trim().isNotEmpty && (t.coverImagePath ?? '').trim().isNotEmpty) {
        final url = await _docs.createDownloadUrl(bucketName: t.coverImageBucket!.trim(), storagePath: t.coverImagePath!.trim(), expiresIn: const Duration(minutes: 20));
        if (!mounted) return;
        setState(() => _coverUrl = url);
      }
    } catch (e) {
      debugPrint('TrainingDetailsPage: load failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentUser;

    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: LearningCyberColors.black),
      child: Scaffold(
        body: Stack(
          children: [
            const _LearningBackground(),
            SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : (_error != null)
                      ? Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim)))
                      : (_training == null)
                          ? Center(child: Text('Training not found', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim)))
                          : CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                                    child: Row(
                                      children: [
                                        _GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.popOrGo(AppRoutes.trainingHome), tooltip: 'Back'),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text('Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                                        ),
                                        _GlassIconButton(
                                          icon: Icons.share_outlined,
                                          tooltip: 'Share',
                                          onTap: () {
                                            final t = _training!;
                                            Share.share('THIX Training: ${t.title}\nCategory: ${t.category}\nLevel: ${t.level}');
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(child: _TrainingHero(training: _training!, coverUrl: _coverUrl)),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _InstructorInstitutionRow(training: _training!),
                                        const SizedBox(height: AppSpacing.md),
                                        _ActionsRow(
                                          training: _training!,
                                          onRegister: () async {
                                            if (me == null) {
                                              context.push(AppRoutes.login);
                                              return;
                                            }
                                            try {
                                              final enrollment = await _svc.enroll(userId: me.id, trainingId: _training!.id);
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enrolled. Welcome to THIX Learning.')));
                                              context.push('${AppRoutes.lessonPlayer}/${Uri.encodeComponent(enrollment.id)}');
                                            } catch (e) {
                                              debugPrint('TrainingDetailsPage: enroll failed err=$e');
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enroll failed: $e')));
                                            }
                                          },
                                          onSave: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved (v2)'))),
                                          onContact: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mentor contact (v2)'))),
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        _GlassSection(title: 'Course description', child: Text(_training!.description ?? '—', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim, height: 1.55))),
                                        const SizedBox(height: AppSpacing.md),
                                        _GlassSection(title: 'Skills gained', child: _SkillWrap(skills: _training!.skills)),
                                        const SizedBox(height: AppSpacing.md),
                                        _GlassSection(title: 'Curriculum / Modules', child: const _CurriculumStub()),
                                        const SizedBox(height: AppSpacing.md),
                                        _GlassSection(title: 'Requirements', child: Text(_training!.requirements ?? '—', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim, height: 1.55))),
                                        const SizedBox(height: AppSpacing.md),
                                        _GlassSection(title: 'Student reviews', child: _ReviewsRow(rating: _training!.rating, reviews: _training!.reviewsCount)),
                                        const SizedBox(height: AppSpacing.md),
                                        _GlassSection(title: 'Completion rate', child: _CompletionBar(rate: _training!.completionRate)),
                                        const SizedBox(height: AppSpacing.xl),
                                        _GlassSection(
                                          title: 'Certification',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.verified_rounded, color: LearningCyberColors.neonCyan),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _training!.certificationIncluded ? 'Verified by THIX ID • QR / NFC ready' : 'No certificate for this training',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim, height: 1.4),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningBackground extends StatelessWidget {
  const _LearningBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: LearningCyberGradients.background()),
        child: Stack(
          children: [
            Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: Container(color: Colors.transparent))),
          ],
        ),
      ),
    );
  }
}

class _TrainingHero extends StatelessWidget {
  final TrainingItem training;
  final String? coverUrl;
  const _TrainingHero({required this.training, required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final meta = [training.category, training.level, training.language, training.deliveryMode].where((e) => e.trim().isNotEmpty).join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.95)),
              gradient: LearningCyberGradients.glowBlue(),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: coverUrl == null
                      ? Opacity(opacity: 0.16, child: Image.asset('assets/images/Senior_professional_man_grayscale_1775573975687.jpg', fit: BoxFit.cover))
                      : Opacity(opacity: 0.62, child: Image.network(coverUrl!, fit: BoxFit.cover)),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [LearningCyberColors.black.withValues(alpha: 0.72), Colors.transparent],
                        stops: const [0, 0.72],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _MetaPill(label: training.certificationIncluded ? 'THIX Verified' : 'Training', glow: true),
                          const SizedBox(width: 10),
                          if (training.isFeatured) const _MetaPill(label: 'Premium', glow: true),
                        ],
                      ),
                      const Spacer(),
                      Text(training.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.12)),
                      const SizedBox(height: 6),
                      Text(training.tagline ?? meta, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim, height: 1.4)),
                      const SizedBox(height: 10),
                      Text(meta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
                    ],
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

class _InstructorInstitutionRow extends StatelessWidget {
  final TrainingItem training;
  const _InstructorInstitutionRow({required this.training});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GlassInfoTile(
            icon: Icons.person_rounded,
            title: training.instructorName ?? 'Instructor',
            subtitle: training.instructorTitle ?? 'Verified mentor',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassInfoTile(
            icon: Icons.account_balance_rounded,
            title: training.institutionName ?? 'Institution',
            subtitle: 'Partner',
          ),
        ),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final TrainingItem training;
  final VoidCallback onRegister;
  final VoidCallback onSave;
  final VoidCallback onContact;
  const _ActionsRow({required this.training, required this.onRegister, required this.onSave, required this.onContact});

  @override
  Widget build(BuildContext context) {
    final price = training.isFree ? 'Register (Free)' : 'Register (${training.priceAmount ?? ''} ${training.currency})'.trim();
    return Row(
      children: [
        Expanded(child: _NeonPrimaryButton(icon: Icons.how_to_reg_rounded, label: price, onTap: onRegister)),
        const SizedBox(width: 12),
        _GlassIconButton(icon: Icons.bookmark_outline_rounded, tooltip: 'Save', onTap: onSave),
        const SizedBox(width: 10),
        _GlassIconButton(icon: Icons.chat_bubble_outline_rounded, tooltip: 'Contact mentor', onTap: onContact),
      ],
    );
  }
}

class _NeonPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NeonPrimaryButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LearningCyberGradients.glowBlue(),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _GlassSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.92)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillWrap extends StatelessWidget {
  final List<String> skills;
  const _SkillWrap({required this.skills});

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) {
      return Text('—', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: skills
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: LearningCyberColors.panelHi.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: LearningCyberColors.stroke),
              ),
              child: Text(s, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w800)),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CurriculumStub extends StatelessWidget {
  const _CurriculumStub();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _CurriculumRow(index: 1, title: 'Module 1 — Foundations', subtitle: 'Threats, identity, trust primitives'),
        SizedBox(height: 10),
        _CurriculumRow(index: 2, title: 'Module 2 — Hands-on Lab', subtitle: 'Simulated incidents + playbooks'),
        SizedBox(height: 10),
        _CurriculumRow(index: 3, title: 'Module 3 — THIX Verified Exam', subtitle: 'Quiz + certificate generation'),
      ],
    );
  }
}

class _CurriculumRow extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  const _CurriculumRow({required this.index, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(gradient: LearningCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text('$index', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewsRow extends StatelessWidget {
  final double rating;
  final int reviews;
  const _ReviewsRow({required this.rating, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: LearningCyberColors.neonCyan),
        const SizedBox(width: 8),
        Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Text('$reviews reviews', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
        const Spacer(),
        const Icon(Icons.people_alt_rounded, size: 18, color: LearningCyberColors.textDim),
        const SizedBox(width: 8),
        Text('Students', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
      ],
    );
  }
}

class _CompletionBar extends StatelessWidget {
  final double rate;
  const _CompletionBar({required this.rate});

  @override
  Widget build(BuildContext context) {
    final r = rate.clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${(r * 100).round()}%', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
            const SizedBox(width: 10),
            Text('avg completion', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: r,
            backgroundColor: LearningCyberColors.panelHi.withValues(alpha: 0.7),
            valueColor: const AlwaysStoppedAnimation(LearningCyberColors.neonCyan),
          ),
        ),
      ],
    );
  }
}

class _GlassInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _GlassInfoTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.92)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: LearningCyberColors.panelHi.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(14), border: Border.all(color: LearningCyberColors.stroke)),
                child: Icon(icon, color: LearningCyberColors.neonCyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
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

class _MetaPill extends StatelessWidget {
  final String label;
  final bool glow;
  const _MetaPill({required this.label, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (glow ? LearningCyberColors.neonCyan : LearningCyberColors.panel).withValues(alpha: glow ? 0.22 : 0.62),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: glow ? LearningCyberColors.neonCyan : LearningCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: LearningCyberColors.panel.withValues(alpha: 0.55),
                border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.95)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: LearningCyberColors.text),
            ),
          ),
        ),
      ),
    );
  }
}
