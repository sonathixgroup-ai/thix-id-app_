import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thix_id/models/training_enrollment.dart';
import 'package:thix_id/models/training_lesson.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/training_service.dart';
import 'package:thix_id/theme.dart';
import 'package:video_player/video_player.dart';

/// Ultra-premium lesson player:
/// - Video player
/// - Notes
/// - Downloadable resources (stub)
/// - Quiz system (stub)
/// - Progress autosave
class LessonPlayerPage extends StatefulWidget {
  final String enrollmentId;
  const LessonPlayerPage({super.key, required this.enrollmentId});

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

class _LessonPlayerPageState extends State<LessonPlayerPage> {
  final _svc = TrainingService();
  bool _loading = true;
  String? _error;

  TrainingEnrollment? _enrollment;
  TrainingLesson? _lesson;

  VideoPlayerController? _video;
  bool _videoReady = false;

  final _notes = TextEditingController();
  Timer? _notesDebounce;
  Timer? _progressTimer;

  String get _notesKey => 'thix_learning_notes:${widget.enrollmentId}:${_lesson?.id ?? 'unknown'}';

  @override
  void initState() {
    super.initState();
    _load();
    _notes.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _progressTimer?.cancel();
    _notes.removeListener(_onNotesChanged);
    _notes.dispose();
    unawaited(_video?.dispose());
    super.dispose();
  }

  void _onNotesChanged() {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 400), () => unawaited(_saveNotes()));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final enrollment = await _svc.fetchEnrollmentById(widget.enrollmentId);
      if (enrollment == null) throw Exception('Enrollment not found');
      final lessons = await _svc.listLessons(enrollment.trainingId);
      final lesson = lessons.isNotEmpty ? lessons.first : null;
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _lesson = lesson;
      });

      await _loadNotes();
      await _initVideo();
      _startProgressAutosave();
    } catch (e) {
      debugPrint('LessonPlayerPage: load failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_notesKey) ?? '';
      if (!mounted) return;
      _notes.text = v;
    } catch (e) {
      debugPrint('LessonPlayerPage: loadNotes failed err=$e');
    }
  }

  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notesKey, _notes.text);
    } catch (e) {
      debugPrint('LessonPlayerPage: saveNotes failed err=$e');
    }
  }

  Future<void> _initVideo() async {
    final url = _lesson?.videoUrl;
    if (url == null || url.trim().isEmpty) return;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      controller.setLooping(false);
      if (!mounted) return;
      setState(() {
        _video = controller;
        _videoReady = true;
      });
    } catch (e) {
      debugPrint('LessonPlayerPage: video init failed url=$url err=$e');
    }
  }

  void _startProgressAutosave() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      final enrollmentId = _enrollment?.id;
      if (enrollmentId == null) return;
      // v1: progress is approximated. Later we’ll track per-lesson completion.
      final current = (_enrollment?.progressPercent ?? 0).clamp(0, 100).toDouble();
      final next = (current + 1.0).clamp(0, 100).toDouble();
      unawaited(_svc.saveProgress(enrollmentId: enrollmentId, progressPercent: next, lastActivityAt: DateTime.now().toUtc()));
      _enrollment = _enrollment?.copyWith(progressPercent: next, updatedAt: DateTime.now().toUtc());
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                              child: Row(
                                children: [
                                  _GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: 'Back', onTap: () => context.popOrGo(AppRoutes.learningDashboard)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_lesson?.title ?? 'Lesson', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 2),
                                        Text('Progress: ${(_enrollment?.progressPercent ?? 0).round()}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
                                      ],
                                    ),
                                  ),
                                  _GlassIconButton(
                                    icon: Icons.picture_in_picture_alt_rounded,
                                    tooltip: 'Mini player',
                                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mini-player (v2)'))),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                                children: [
                                  _VideoPanel(controller: _video, ready: _videoReady),
                                  const SizedBox(height: AppSpacing.md),
                                  _TabShell(notesController: _notes),
                                ],
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
  Widget build(BuildContext context) => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: LearningCyberGradients.background()),
          child: Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: Container(color: Colors.transparent))),
        ),
      );
}

class _VideoPanel extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool ready;
  const _VideoPanel({required this.controller, required this.ready});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.92)),
          ),
          child: AspectRatio(
            aspectRatio: (ready && controller != null) ? controller!.value.aspectRatio : (16 / 9),
            child: ready && controller != null
                ? Stack(
                    children: [
                      Positioned.fill(child: VideoPlayer(controller!)),
                      const Positioned.fill(child: _VideoOverlayChrome()),
                    ],
                  )
                : const _VideoPlaceholder(),
          ),
        ),
      ),
    );
  }
}

class _VideoOverlayChrome extends StatefulWidget {
  const _VideoOverlayChrome();

  @override
  State<_VideoOverlayChrome> createState() => _VideoOverlayChromeState();
}

class _VideoOverlayChromeState extends State<_VideoOverlayChrome> {
  bool _visible = true;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _kickHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.findAncestorStateOfType<_LessonPlayerPageState>()?._video;
    if (vp == null) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _visible = !_visible);
        if (_visible) _kickHide();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: _visible ? 1 : 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
              stops: const [0, 0.72],
            ),
          ),
          child: Column(
            children: [
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _OverlayButton(
                    icon: Icons.replay_10_rounded,
                    onTap: () {
                      final pos = vp.value.position;
                      vp.seekTo(pos - const Duration(seconds: 10));
                    },
                  ),
                  const SizedBox(width: 12),
                  _OverlayButton(
                    icon: vp.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    size: 58,
                    onTap: () {
                      if (vp.value.isPlaying) {
                        vp.pause();
                      } else {
                        vp.play();
                        _kickHide();
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 12),
                  _OverlayButton(
                    icon: Icons.forward_10_rounded,
                    onTap: () {
                      final pos = vp.value.position;
                      vp.seekTo(pos + const Duration(seconds: 10));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: VideoProgressIndicator(
                  vp,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(playedColor: LearningCyberColors.neonCyan, bufferedColor: LearningCyberColors.stroke, backgroundColor: Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _OverlayButton({required this.icon, required this.onTap, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LearningCyberColors.panel.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9)),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.6),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LearningCyberGradients.glowBlue()),
      child: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.22, child: Image.asset('assets/images/tech_conference_stage_audience_grayscale_1778649599691.jpg', fit: BoxFit.cover))),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: LearningCyberColors.neonCyan.withValues(alpha: 0.6))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Video coming soon', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabShell extends StatefulWidget {
  final TextEditingController notesController;
  const _TabShell({required this.notesController});

  @override
  State<_TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<_TabShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.92)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: _TabChip(label: 'Notes', selected: _index == 0, onTap: () => setState(() => _index = 0))),
                    const SizedBox(width: 10),
                    Expanded(child: _TabChip(label: 'Resources', selected: _index == 1, onTap: () => setState(() => _index = 1))),
                    const SizedBox(width: 10),
                    Expanded(child: _TabChip(label: 'Quiz', selected: _index == 2, onTap: () => setState(() => _index = 2))),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Padding(
                  key: ValueKey(_index),
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: switch (_index) {
                    0 => _NotesPanel(controller: widget.notesController),
                    1 => const _ResourcesPanel(),
                    _ => const _QuizPanel(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (selected ? LearningCyberColors.neonCyan : LearningCyberColors.panelHi).withValues(alpha: selected ? 0.18 : 0.6),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? LearningCyberColors.neonCyan : LearningCyberColors.stroke.withValues(alpha: 0.9)),
        ),
        child: Center(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  final TextEditingController controller;
  const _NotesPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 8,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.text),
      decoration: InputDecoration(
        hintText: 'Write notes… (autosaved)',
        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim),
        filled: true,
        fillColor: LearningCyberColors.panelHi.withValues(alpha: 0.55),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: LearningCyberColors.stroke.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: LearningCyberColors.neonCyan, width: 1.2)),
      ),
    );
  }
}

class _ResourcesPanel extends StatelessWidget {
  const _ResourcesPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Download resources', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text('Admins can upload PDFs, templates, and datasets per lesson.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim, height: 1.4)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: LearningCyberColors.panelHi.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9))),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: LearningCyberColors.neonCyan),
              const SizedBox(width: 10),
              Expanded(child: Text('Resource pack (stub)', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900))),
              TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download (v2)'))), child: const Text('Download')),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizPanel extends StatelessWidget {
  const _QuizPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quiz', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text('Quizzes are configured in Admin: questions, choices, and grading.\n\nThis is the v1 UI shell.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim, height: 1.4)),
        const SizedBox(height: 12),
        _NeonActionButton(label: 'Start quiz', icon: Icons.quiz_rounded, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz engine (v2)')))),
      ],
    );
  }
}

class _NeonActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _NeonActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        height: 46,
        decoration: BoxDecoration(gradient: LearningCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(AppRadius.full)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
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

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onTap});

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
