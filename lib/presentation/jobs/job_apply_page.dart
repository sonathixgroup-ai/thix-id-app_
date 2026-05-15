import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/job_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/theme.dart';

class JobApplyPage extends StatefulWidget {
  final String jobId;
  const JobApplyPage({super.key, required this.jobId});

  @override
  State<JobApplyPage> createState() => _JobApplyPageState();
}

class _JobApplyPageState extends State<JobApplyPage> {
  final _jobService = JobService();
  final _profileService = ProfileService();
  final _docService = DocumentService();
  final _thixCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _portfolioCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  fp.PlatformFile? _resume;
  fp.PlatformFile? _video;
  List<fp.PlatformFile> _diplomas = const [];

  @override
  void dispose() {
    _thixCtrl.dispose();
    _messageCtrl.dispose();
    _portfolioCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    final thixId = auth.currentUser?.thixId ?? '';
    if (_thixCtrl.text.trim().isEmpty && thixId.trim().isNotEmpty) {
      _thixCtrl.text = thixId;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final canonical = ThixIdService.canonicalizeOrNull(_thixCtrl.text);
      if (canonical == null || !ThixIdService.isValid(canonical)) {
        setState(() => _error = 'THIX ID invalide. Exemple: ${ThixIdService.exampleV2}');
        return;
      }

      final profile = await _profileService.fetchPublicProfileByThixId(canonical);
      if (profile == null) {
        setState(() => _error = 'Aucun profil trouvé pour ce THIX ID. Vérifie l’ID ou contacte le support.');
        return;
      }

      final uid = context.read<AuthController>().currentUser?.id;
      String? resumeUrl;
      String? videoUrl;
      final diplomaUrls = <String>[];

      if (uid != null && uid.trim().isNotEmpty) {
        resumeUrl = await _tryUpload(uid: uid, file: _resume, kind: 'resume');
        videoUrl = await _tryUpload(uid: uid, file: _video, kind: 'video_intro');
        for (final f in _diplomas) {
          final u = await _tryUpload(uid: uid, file: f, kind: 'diploma');
          if (u != null) diplomaUrls.add(u);
        }
      }

      await _jobService.submitApplication(
        jobId: widget.jobId,
        applicantThixId: canonical,
        message: _messageCtrl.text,
        portfolioUrl: _portfolioCtrl.text.trim().isEmpty ? null : _portfolioCtrl.text.trim(),
        videoIntroUrl: videoUrl,
        resumeUrl: resumeUrl,
        diplomaUrls: diplomaUrls,
      );
      if (!mounted) return;
      context.go('/jobs/${widget.jobId}?applied=1');
    } catch (e) {
      debugPrint('JobApplyPage.submit failed err=$e');
      if (!mounted) return;
      setState(() => _error = 'Erreur lors de la candidature. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _tryUpload({required String uid, required fp.PlatformFile? file, required String kind}) async {
    if (file == null) return null;
    try {
      // Expected bucket: thix-job-applications (private or public).
      const bucket = 'thix-job-applications';
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'users/$uid/jobs/${widget.jobId}/$kind/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final uploadedPath = await _docService.uploadPickedFileToBucket(bucketName: bucket, uid: uid, objectPath: path, file: file);
      // Prefer signed URLs; fall back to public.
      try {
        return await _docService.createDownloadUrl(bucketName: bucket, storagePath: uploadedPath);
      } catch (_) {
        return Supabase.instance.client.storage.from(bucket).getPublicUrl(uploadedPath);
      }
    } on StorageException catch (e) {
      debugPrint('JobApplyPage._tryUpload storage err=${e.message}');
      if (DocumentService.isBucketNotFound(e)) {
        // Graceful fallback: do not block application.
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('JobApplyPage._tryUpload failed err=$e');
      return null;
    }
  }

  Future<void> _pickResume() async {
    final res = await fp.FilePicker.pickFiles(withData: kIsWeb, type: fp.FileType.custom, allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp']);
    if (res == null || res.files.isEmpty) return;
    setState(() => _resume = res.files.first);
  }

  Future<void> _pickVideo() async {
    final res = await fp.FilePicker.pickFiles(withData: kIsWeb, type: fp.FileType.video);
    if (res == null || res.files.isEmpty) return;
    setState(() => _video = res.files.first);
  }

  Future<void> _pickDiplomas() async {
    final res = await fp.FilePicker.pickFiles(withData: kIsWeb, allowMultiple: true, type: fp.FileType.custom, allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp']);
    if (res == null || res.files.isEmpty) return;
    setState(() => _diplomas = res.files);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentUser;

    return Scaffold(
      backgroundColor: LearningCyberColors.bg0,
      body: SafeArea(
        child: FutureBuilder(
          future: _jobService.fetchJob(widget.jobId),
          builder: (context, snap) {
            final job = snap.data;
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: LearningCyberColors.neonCyan));
            }
            if (job == null) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _TopBar(jobId: widget.jobId),
                    const Spacer(),
                    Text('Offre introuvable.', style: context.textStyles.titleMedium?.copyWith(color: LearningCyberColors.text)),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.popOrGo(AppRoutes.jobs),
                        child: const Text('Retour'),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(jobId: widget.jobId),
                  const SizedBox(height: AppSpacing.md),
                  Text('One‑click Apply', style: context.textStyles.titleLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(job.title, style: context.textStyles.titleMedium?.copyWith(color: LearningCyberColors.textDim, fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: LearningCyberColors.panel.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: LearningCyberColors.success),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text('Verification required', style: context.textStyles.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          me?.hasRealThixId == true
                              ? 'Nous avons pré-rempli ton THIX ID. Tu peux le modifier si nécessaire.'
                              : 'Entre ton THIX ID (il sera vérifié en base avant envoi).',
                          style: context.textStyles.bodyMedium?.copyWith(color: LearningCyberColors.textDim, height: 1.55),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _thixCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'THIX ID',
                            hintText: ThixIdService.exampleV2,
                            prefixIcon: const Icon(Icons.badge_rounded),
                            filled: true,
                            fillColor: LearningCyberColors.panelHi.withValues(alpha: 0.78),
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _messageCtrl,
                          minLines: 3,
                          maxLines: 7,
                          decoration: InputDecoration(
                            labelText: 'Message (optional)',
                            hintText: 'Introduce yourself in 2-3 lines…',
                            prefixIcon: const Icon(Icons.chat_bubble_rounded),
                            filled: true,
                            fillColor: LearningCyberColors.panelHi.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _portfolioCtrl,
                          decoration: InputDecoration(
                            labelText: 'Portfolio link (optional)',
                            hintText: 'https://…',
                            prefixIcon: const Icon(Icons.link_rounded),
                            filled: true,
                            fillColor: LearningCyberColors.panelHi.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Attachments', style: context.textStyles.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        _AttachmentRow(
                          label: _resume == null ? 'Resume (PDF/Image)' : 'Resume: ${_resume!.name}',
                          icon: Icons.picture_as_pdf_rounded,
                          onPick: _pickResume,
                          onClear: _resume == null ? null : () => setState(() => _resume = null),
                        ),
                        const SizedBox(height: 10),
                        _AttachmentRow(
                          label: _video == null ? 'Video introduction' : 'Video: ${_video!.name}',
                          icon: Icons.video_camera_front_rounded,
                          onPick: _pickVideo,
                          onClear: _video == null ? null : () => setState(() => _video = null),
                        ),
                        const SizedBox(height: 10),
                        _AttachmentRow(
                          label: _diplomas.isEmpty ? 'Verified diplomas (multi)' : 'Diplomas: ${_diplomas.length} file(s)',
                          icon: Icons.workspace_premium_rounded,
                          onPick: _pickDiplomas,
                          onClear: _diplomas.isEmpty ? null : () => setState(() => _diplomas = const []),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(_error!, style: context.textStyles.bodyMedium?.copyWith(color: LearningCyberColors.danger, fontWeight: FontWeight.w900)),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(backgroundColor: LearningCyberColors.neonCyan, foregroundColor: LearningCyberColors.black),
                            icon: _loading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: LearningCyberColors.black))
                                : const Icon(Icons.send_rounded),
                            label: Text(_loading ? 'Sending…' : 'Submit application'),
                          ),
                        ),
                      ],
                    ),
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

class _TopBar extends StatelessWidget {
  final String jobId;
  const _TopBar({required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.popOrGo('/jobs/$jobId'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: LearningCyberColors.text),
        ),
        Expanded(
          child: Text('THIX Apply', style: context.textStyles.titleLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  const _AttachmentRow({required this.label, required this.icon, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: LearningCyberColors.panelHi.withValues(alpha: 0.78),
        border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Icon(icon, color: LearningCyberColors.neonCyan),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: context.textStyles.bodyMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onPick,
            style: TextButton.styleFrom(foregroundColor: LearningCyberColors.neonCyan),
            child: const Text('Pick'),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, color: LearningCyberColors.textDim),
            ),
        ],
      ),
    );
  }
}

extension _ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
}
