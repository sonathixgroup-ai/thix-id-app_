import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/training_certificate.dart';
import 'package:thix_id/models/training_enrollment.dart';
import 'package:thix_id/models/training_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/training_service.dart';
import 'package:thix_id/theme.dart';

class LearningDashboardPage extends StatefulWidget {
  const LearningDashboardPage({super.key});

  @override
  State<LearningDashboardPage> createState() => _LearningDashboardPageState();
}

class _LearningDashboardPageState extends State<LearningDashboardPage> {
  final _svc = TrainingService();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentUser;
    if (me == null) {
      return Theme(
        data: Theme.of(context).copyWith(scaffoldBackgroundColor: LearningCyberColors.black),
        child: Scaffold(
          body: Stack(
            children: [
              const _LearningBackground(),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, color: LearningCyberColors.neonCyan, size: 42),
                        const SizedBox(height: 12),
                        Text('Sign in required', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('Your progress, certificates and mentor messages are linked to your account.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim, height: 1.4)),
                        const SizedBox(height: 16),
                        _NeonPrimaryButton(icon: Icons.login_rounded, label: 'Open Login', onTap: () => context.push(AppRoutes.login)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final uid = me.id;
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: LearningCyberColors.black),
      child: Scaffold(
        body: Stack(
          children: [
            const _LearningBackground(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                    child: Row(
                      children: [
                        _GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.popOrGo(AppRoutes.trainingHome), tooltip: 'Back'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Learning Dashboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text('Progress • Certificates • Analytics', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
                            ],
                          ),
                        ),
                        _GlassIconButton(
                          icon: Icons.notifications_none_rounded,
                          tooltip: 'Notifications',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Learning notifications (v2)'))),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<TrainingEnrollment>>(
                      stream: _svc.streamMyEnrollments(uid),
                      builder: (context, snap) {
                        final enrollments = snap.data ?? const [];
                        return StreamBuilder<List<TrainingCertificate>>(
                          stream: _svc.streamMyCertificates(uid),
                          builder: (context, certSnap) {
                            final certs = certSnap.data ?? const [];
                            return ListView(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                              children: [
                                _AnalyticsHeader(enrollments: enrollments, certificates: certs),
                                const SizedBox(height: AppSpacing.md),
                                _SectionHeader(title: 'Courses enrolled', subtitle: '${enrollments.length} active / completed'),
                                const SizedBox(height: 10),
                                if (enrollments.isEmpty)
                                  const _EmptyGlassState(icon: Icons.school_rounded, title: 'No enrollments yet', subtitle: 'Open Trainings and tap Register to start learning.')
                                else
                                  _EnrollmentsList(enrollments: enrollments),
                                const SizedBox(height: AppSpacing.lg),
                                _SectionHeader(title: 'Certificates earned', subtitle: 'Verified by THIX ID'),
                                const SizedBox(height: 10),
                                if (certs.isEmpty)
                                  const _EmptyGlassState(icon: Icons.verified_rounded, title: 'No certificates yet', subtitle: 'Complete a training to generate your THIX Verified certificate.')
                                else
                                  _CertificatesList(items: certs),
                                const SizedBox(height: AppSpacing.lg),
                                _SectionHeader(title: 'Weekly learning activity', subtitle: 'Streaks • hours • competency score'),
                                const SizedBox(height: 10),
                                const _LearningActivityStub(),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _QuickActionsFab(onContinue: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Continue learning (v2 auto-resume)'))), onDownload: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download certificate (v2)')))),
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
        child: Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: Container(color: Colors.transparent))),
      ),
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  final List<TrainingEnrollment> enrollments;
  final List<TrainingCertificate> certificates;
  const _AnalyticsHeader({required this.enrollments, required this.certificates});

  @override
  Widget build(BuildContext context) {
    final active = enrollments.where((e) => e.status != 'completed').length;
    final completed = enrollments.where((e) => e.status == 'completed').length;
    final minutes = enrollments.fold<int>(0, (acc, e) => acc + e.learningMinutes);
    final hours = (minutes / 60).toStringAsFixed(1);
    final avgProgress = enrollments.isEmpty ? 0 : (enrollments.fold<double>(0, (acc, e) => acc + e.progressPercent) / enrollments.length).clamp(0, 100);

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
              Text('Your learning analytics', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniStat(label: 'Active', value: '$active')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: 'Completed', value: '$completed')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: 'Hours', value: hours)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MiniStat(label: 'Certificates', value: '${certificates.length}')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: 'Avg progress', value: '${avgProgress.round()}%')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LearningCyberColors.panelHi.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LearningCyberColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EnrollmentsList extends StatelessWidget {
  final List<TrainingEnrollment> enrollments;
  const _EnrollmentsList({required this.enrollments});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: enrollments
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EnrollmentTile(enrollment: e),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EnrollmentTile extends StatelessWidget {
  final TrainingEnrollment enrollment;
  const _EnrollmentTile({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final progress = (enrollment.progressPercent / 100).clamp(0, 1).toDouble();
    return InkWell(
      onTap: () => context.push('${AppRoutes.lessonPlayer}/${Uri.encodeComponent(enrollment.id)}'),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LearningCyberColors.panel.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.92)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(gradient: LearningCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Training: ${enrollment.trainingId}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('Status: ${enrollment.status}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: LearningCyberColors.neonCyan),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: progress,
                    backgroundColor: LearningCyberColors.panelHi.withValues(alpha: 0.7),
                    valueColor: const AlwaysStoppedAnimation(LearningCyberColors.neonCyan),
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

class _CertificatesList extends StatelessWidget {
  final List<TrainingCertificate> items;
  const _CertificatesList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CertificateTile(certificate: c),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CertificateTile extends StatelessWidget {
  final TrainingCertificate certificate;
  const _CertificateTile({required this.certificate});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.92)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: LearningCyberColors.panelHi.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14), border: Border.all(color: LearningCyberColors.neonCyan.withValues(alpha: 0.55))),
                child: const Icon(Icons.verified_rounded, color: LearningCyberColors.neonCyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THIX Verified Certificate', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('Verification ID: ${certificate.verificationId}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download PDF (v2)'))),
                icon: const Icon(Icons.download_rounded, color: LearningCyberColors.neonCyan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningActivityStub extends StatelessWidget {
  const _LearningActivityStub();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.92)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly activity (placeholder)', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('We will plug real charts once lesson progress is tracked per module/lesson.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim, height: 1.4)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: 0.36,
                  backgroundColor: LearningCyberColors.panelHi.withValues(alpha: 0.7),
                  valueColor: const AlwaysStoppedAnimation(LearningCyberColors.neonViolet),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsFab extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onDownload;
  const _QuickActionsFab({required this.onContinue, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'learn_continue',
          backgroundColor: LearningCyberColors.neonCyan,
          onPressed: onContinue,
          child: const Icon(Icons.play_arrow_rounded, color: Colors.black),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'learn_download',
          backgroundColor: LearningCyberColors.electricBlue,
          onPressed: onDownload,
          child: const Icon(Icons.download_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
      ],
    );
  }
}

class _EmptyGlassState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyGlassState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: LearningCyberColors.panelHi.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(14), border: Border.all(color: LearningCyberColors.stroke)),
                child: Icon(icon, color: LearningCyberColors.neonCyan),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim, height: 1.4)),
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
        decoration: BoxDecoration(gradient: LearningCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(AppRadius.full)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
