import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/training_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/training_service.dart';
import 'package:thix_id/theme.dart';

class TrainingHomePage extends StatefulWidget {
  const TrainingHomePage({super.key});

  @override
  State<TrainingHomePage> createState() => _TrainingHomePageState();
}

class _TrainingHomePageState extends State<TrainingHomePage> {
  final _svc = TrainingService();
  final _search = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<TrainingItem> _all = const [];

  // Filters
  bool? _freeOnly; // null = all
  String? _level;
  String? _delivery;
  bool? _certIncluded;
  String? _language;

  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];
  static const _deliveryModes = ['online', 'physical', 'hybrid'];
  static const _languages = ['FR', 'EN'];
  static const _categories = [
    'Cybersecurity',
    'AI & Data',
    'Software Development',
    'Business',
    'Entrepreneurship',
    'Marketing',
    'Design',
    'Finance',
    'Leadership',
    'Public Administration',
    'Mining & Industry',
    'Agriculture',
    'Soft Skills',
  ];

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
    _load();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listPublishedTrainings();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      debugPrint('TrainingHomePage: load failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TrainingItem> _applyFilters(List<TrainingItem> list) {
    final q = _search.text.trim().toLowerCase();
    return list.where((t) {
      if (q.isNotEmpty) {
        final hay = [t.title, t.tagline ?? '', t.category, t.instructorName ?? ''].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_freeOnly == true && !t.isFree) return false;
      if (_level != null && t.level.toLowerCase() != _level!.toLowerCase()) return false;
      if (_delivery != null && t.deliveryMode.toLowerCase() != _delivery!.toLowerCase()) return false;
      if (_certIncluded == true && !t.certificationIncluded) return false;
      if (_language != null && t.language.toLowerCase() != _language!.toLowerCase()) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isAuthed = auth.currentUser != null;
    final filtered = _applyFilters(_all);
    final featured = filtered.where((e) => e.isFeatured).toList(growable: false);
    final trending = filtered.where((e) => e.rating >= 4.7).toList(growable: false);
    final certifications = filtered.where((e) => e.certificationIncluded).toList(growable: false);

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
                        _GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.popOrGo(AppRoutes.home), tooltip: 'Back'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('THIX Learning', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text('Trainings • Certifications • Mentors', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
                            ],
                          ),
                        ),
                        if (isAuthed)
                          _NeonPillButton(
                            icon: Icons.auto_graph_rounded,
                            label: 'Dashboard',
                            onTap: () => context.push(AppRoutes.learningDashboard),
                          )
                        else
                          _NeonPillButton(
                            icon: Icons.lock_open_rounded,
                            label: 'Sign in',
                            onTap: () => context.push(AppRoutes.login),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : (_error != null)
                            ? Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim)))
                            : RefreshIndicator(
                                color: LearningCyberColors.neonCyan,
                                backgroundColor: LearningCyberColors.panel,
                                onRefresh: _load,
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                                  children: [
                                    const SizedBox(height: 6),
                                    _HeroBanner(onOpenFeatured: featured.isEmpty ? null : () => _openTraining(context, featured.first)),
                                    const SizedBox(height: AppSpacing.md),
                                    _GlassSearchBar(controller: _search),
                                    const SizedBox(height: AppSpacing.md),
                                    _FilterRow(
                                      freeOnly: _freeOnly,
                                      onToggleFree: () => setState(() => _freeOnly = (_freeOnly == true) ? null : true),
                                      level: _level,
                                      onPickLevel: (v) => setState(() => _level = v),
                                      delivery: _delivery,
                                      onPickDelivery: (v) => setState(() => _delivery = v),
                                      certIncluded: _certIncluded,
                                      onToggleCert: () => setState(() => _certIncluded = (_certIncluded == true) ? null : true),
                                      language: _language,
                                      onPickLanguage: (v) => setState(() => _language = v),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    _CategoryScroller(
                                      categories: _categories,
                                      onTap: (c) => setState(() {
                                        // category is a search accelerator
                                        _search.text = c;
                                        _search.selection = TextSelection.fromPosition(TextPosition(offset: _search.text.length));
                                      }),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    _SectionHeader(title: 'Recommended for you', subtitle: 'AI-driven picks (v1 smart matching)'),
                                    const SizedBox(height: AppSpacing.sm),
                                    _TrainingHorizontalList(items: _aiRecommend(filtered), onOpen: (t) => _openTraining(context, t)),
                                    const SizedBox(height: AppSpacing.lg),

                                    _SectionHeader(title: 'Trending formations', subtitle: 'Top rated • high completion'),
                                    const SizedBox(height: AppSpacing.sm),
                                    _TrainingHorizontalList(items: trending, onOpen: (t) => _openTraining(context, t)),
                                    const SizedBox(height: AppSpacing.lg),

                                    _SectionHeader(title: 'New certifications', subtitle: 'Verified by THIX ID'),
                                    const SizedBox(height: AppSpacing.sm),
                                    _TrainingHorizontalList(items: certifications, onOpen: (t) => _openTraining(context, t)),
                                    const SizedBox(height: AppSpacing.lg),

                                    _GlassCalloutCard(
                                      title: 'AI Recommended learning paths',
                                      subtitle: '3 paths generated from your profile (skills, goals, verification)',
                                      icon: Icons.hub_rounded,
                                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Learning paths (v2)'))),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _GlassCalloutCard(
                                      title: 'Continue learning',
                                      subtitle: isAuthed ? 'Resume your last lesson instantly.' : 'Sign in to save progress and resume.',
                                      icon: Icons.play_circle_outline_rounded,
                                      onTap: () => context.push(isAuthed ? AppRoutes.learningDashboard : AppRoutes.login),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    _SectionHeader(title: 'Upcoming live sessions', subtitle: 'Mentor-led • attendance tracked'),
                                    const SizedBox(height: AppSpacing.sm),
                                    const _EmptyGlassState(
                                      icon: Icons.videocam_rounded,
                                      title: 'No live sessions yet',
                                      subtitle: 'Admins can schedule live classes (Zoom/Meet) in the dashboard.',
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    _SectionHeader(title: 'Mentors spotlight', subtitle: 'Verified instructors & performance'),
                                    const SizedBox(height: AppSpacing.sm),
                                    const _MentorSpotlightRow(),
                                    const SizedBox(height: AppSpacing.lg),

                                    _SectionHeader(title: 'Scholarship opportunities', subtitle: 'Apply • get sponsored certification'),
                                    const SizedBox(height: AppSpacing.sm),
                                    const _EmptyGlassState(
                                      icon: Icons.workspace_premium_rounded,
                                      title: 'Scholarships coming soon',
                                      subtitle: 'We will publish sponsored trainings via Opportunities & Campaigns.',
                                    ),
                                    const SizedBox(height: AppSpacing.xxl),
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

  void _openTraining(BuildContext context, TrainingItem t) => context.push('${AppRoutes.trainingDetails}/${Uri.encodeComponent(t.id)}');

  List<TrainingItem> _aiRecommend(List<TrainingItem> list) {
    // v1 heuristic recommender: prioritize featured + cybersecurity + verified certificate.
    // Later: replace with OpenAI-based skill-gap analysis.
    final scored = list
        .map((t) {
          var s = 0.0;
          if (t.isFeatured) s += 3;
          if (t.certificationIncluded) s += 2;
          if (t.category.toLowerCase().contains('cyber')) s += 1.5;
          s += t.rating;
          return (t: t, s: s);
        })
        .toList(growable: false)
      ..sort((a, b) => b.s.compareTo(a.s));
    return scored.take(10).map((e) => e.t).toList(growable: false);
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
            const _GlowBlob(color: LearningCyberColors.electricBlue, size: 520, left: -240, top: -120),
            const _GlowBlob(color: LearningCyberColors.neonCyan, size: 340, right: -160, top: 180),
            const _GlowBlob(color: LearningCyberColors.neonViolet, size: 520, right: -240, bottom: -160),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  const _GlowBlob({required this.color, required this.size, this.left, this.right, this.top, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)]),
          ),
        ),
      ),
    );
  }
}

class _GlassSearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _GlassSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: controller,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.text),
            decoration: InputDecoration(
              hintText: 'Search training, skill, mentor…',
              hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim),
              prefixIcon: const Icon(Icons.search_rounded, color: LearningCyberColors.neonCyan),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final bool? freeOnly;
  final VoidCallback onToggleFree;
  final String? level;
  final ValueChanged<String?> onPickLevel;
  final String? delivery;
  final ValueChanged<String?> onPickDelivery;
  final bool? certIncluded;
  final VoidCallback onToggleCert;
  final String? language;
  final ValueChanged<String?> onPickLanguage;

  const _FilterRow({
    required this.freeOnly,
    required this.onToggleFree,
    required this.level,
    required this.onPickLevel,
    required this.delivery,
    required this.onPickDelivery,
    required this.certIncluded,
    required this.onToggleCert,
    required this.language,
    required this.onPickLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _NeonChip(label: (freeOnly == true) ? 'Free ✓' : 'Free', selected: freeOnly == true, onTap: onToggleFree),
          const SizedBox(width: 10),
          _NeonMenuChip(
            label: level == null ? 'Level' : level!,
            selected: level != null,
            icon: Icons.stacked_bar_chart_rounded,
            items: const ['Beginner', 'Intermediate', 'Advanced'],
            onSelected: onPickLevel,
            onClear: () => onPickLevel(null),
          ),
          const SizedBox(width: 10),
          _NeonMenuChip(
            label: delivery == null ? 'Mode' : delivery!,
            selected: delivery != null,
            icon: Icons.public_rounded,
            items: const ['online', 'physical', 'hybrid'],
            onSelected: onPickDelivery,
            onClear: () => onPickDelivery(null),
          ),
          const SizedBox(width: 10),
          _NeonChip(label: (certIncluded == true) ? 'Certificate ✓' : 'Certificate', selected: certIncluded == true, onTap: onToggleCert),
          const SizedBox(width: 10),
          _NeonMenuChip(
            label: language == null ? 'Lang' : language!,
            selected: language != null,
            icon: Icons.translate_rounded,
            items: const ['FR', 'EN'],
            onSelected: onPickLanguage,
            onClear: () => onPickLanguage(null),
          ),
        ],
      ),
    );
  }
}

class _NeonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NeonChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (selected ? LearningCyberColors.electricBlue : LearningCyberColors.panel).withValues(alpha: selected ? 0.28 : 0.50),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? LearningCyberColors.neonCyan : LearningCyberColors.stroke),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _NeonMenuChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  const _NeonMenuChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.items,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      color: LearningCyberColors.panelHi,
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          ...items.map((e) => PopupMenuItem(value: e, child: Text(e, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.text)))),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: '__clear__',
            enabled: false,
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop();
                onClear();
              },
              child: Row(
                children: [
                  const Icon(Icons.backspace_outlined, size: 18, color: LearningCyberColors.textDim),
                  const SizedBox(width: 10),
                  Text('Clear', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LearningCyberColors.textDim)),
                ],
              ),
            ),
          ),
        ];
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (selected ? LearningCyberColors.neonCyan : LearningCyberColors.panel).withValues(alpha: selected ? 0.16 : 0.50),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? LearningCyberColors.neonCyan : LearningCyberColors.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? LearningCyberColors.neonCyan : LearningCyberColors.textDim),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded, color: LearningCyberColors.textDim, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CategoryScroller extends StatelessWidget {
  final List<String> categories;
  final ValueChanged<String> onTap;
  const _CategoryScroller({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categories', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories
                .map((c) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _NeonChip(label: c, selected: false, onTap: () => onTap(c)),
                    ))
                .toList(growable: false),
          ),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrainingHorizontalList extends StatelessWidget {
  final List<TrainingItem> items;
  final ValueChanged<TrainingItem> onOpen;
  const _TrainingHorizontalList({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyGlassState(icon: Icons.school_rounded, title: 'No trainings yet', subtitle: 'Once Admin publishes trainings, they appear here in real-time.');
    }

    return SizedBox(
      height: 226,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length.clamp(0, 12),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _TrainingCard(item: items[i], onTap: () => onOpen(items[i])),
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  final TrainingItem item;
  final VoidCallback onTap;
  const _TrainingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = item.isFree ? 'Free' : '${item.priceAmount ?? ''} ${item.currency}'.trim();
    final meta = [item.level, item.language, item.deliveryMode].where((e) => e.trim().isNotEmpty).join(' • ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 260,
            decoration: BoxDecoration(
              color: LearningCyberColors.panel.withValues(alpha: 0.55),
              border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.95)),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _TrainingCoverStub(title: item.title, category: item.category)),
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: Row(
                          children: [
                            _MetaPill(label: item.category),
                            const Spacer(),
                            if (item.isFeatured) const _MetaPill(label: 'Premium', glow: true),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _MetaPill(label: price, glow: true),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: LearningCyberColors.neonCyan),
                          const SizedBox(width: 6),
                          Text(item.rating.toStringAsFixed(1), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 8),
                          Text('(${item.reviewsCount})', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
                        ],
                      ),
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

class _TrainingCoverStub extends StatelessWidget {
  final String title;
  final String category;
  const _TrainingCoverStub({required this.title, required this.category});

  @override
  Widget build(BuildContext context) {
    // Placeholder art (until covers are uploaded in Admin). This still looks premium.
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LearningCyberGradients.glowBlue()),
      child: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.18, child: Image.asset('assets/images/tech_conference_stage_audience_grayscale_1778649599691.jpg', fit: BoxFit.cover))),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Text(
              category.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
          ),
        ],
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

class _GlassCalloutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _GlassCalloutCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: LearningCyberColors.panel.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.95)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(gradient: LearningCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: Colors.white),
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
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: LearningCyberColors.neonCyan),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final VoidCallback? onOpenFeatured;
  const _HeroBanner({required this.onOpenFeatured});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.95)),
            gradient: LearningCyberGradients.glowBlue(),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: Opacity(opacity: 0.20, child: Image.asset('assets/images/Office_team_grayscale_1775574009745.jpg', fit: BoxFit.cover))),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MetaPill(label: 'FUTURISTIC AFRICAN LEARNING', glow: true),
                    const Spacer(),
                    Text('Build verified skills.\nEarn THIX Certificates.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.1)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _NeonPillButton(icon: Icons.play_arrow_rounded, label: 'Start now', onTap: onOpenFeatured),
                        const SizedBox(width: 10),
                        _NeonPillButton(
                          icon: Icons.shield_rounded,
                          label: 'Verified by THIX',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Certificate verification (v2)'))),
                          variant: _NeonPillVariant.outline,
                        ),
                      ],
                    )
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

class _MentorSpotlightRow extends StatelessWidget {
  const _MentorSpotlightRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => const _MentorCard(),
      ),
    );
  }
}

class _MentorCard extends StatelessWidget {
  const _MentorCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LearningCyberColors.panel.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LearningCyberColors.stroke.withValues(alpha: 0.9)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: LearningCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Mentor Verified', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('Cyber • AI • Career', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LearningCyberColors.textDim)),
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

enum _NeonPillVariant { solid, outline }

class _NeonPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final _NeonPillVariant variant;
  const _NeonPillButton({required this.icon, required this.label, required this.onTap, this.variant = _NeonPillVariant.solid});

  @override
  Widget build(BuildContext context) {
    final isSolid = variant == _NeonPillVariant.solid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSolid ? LearningCyberColors.neonCyan.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: isSolid ? LearningCyberColors.neonCyan : LearningCyberColors.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: LearningCyberColors.neonCyan),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: LearningCyberColors.text, fontWeight: FontWeight.w900)),
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
