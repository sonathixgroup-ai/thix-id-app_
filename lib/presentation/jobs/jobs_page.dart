import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/job_posting.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/job_service.dart';
import 'package:thix_id/theme.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _service = JobService();
  final _searchCtrl = TextEditingController();
  final _featuredCtrl = ScrollController();
  final _suggestCtrl = ScrollController();
  bool _loading = true;
  String? _error;
  List<JobPosting> _jobs = const [];
  Set<String> _saved = const {};

  int _featuredIndex = 0;
  bool _featuredAutoplayStarted = false;

  int _suggestIndex = 0;
  bool _suggestAutoplayStarted = false;

  // Filters (kept intentionally simple)
  final Set<String> _typeFilters = {};
  final Set<String> _workModeFilters = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _featuredCtrl.dispose();
    _suggestCtrl.dispose();
    super.dispose();
  }

  void _ensureFeaturedAutoplayStarted() {
    if (_featuredAutoplayStarted) return;
    _featuredAutoplayStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFeaturedAutoplay());
  }

  void _ensureSuggestAutoplayStarted() {
    if (_suggestAutoplayStarted) return;
    _suggestAutoplayStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSuggestAutoplay());
  }

  void _startFeaturedAutoplay() {
    if (!mounted) return;
    if (!_featuredCtrl.hasClients) {
      Future<void>.delayed(const Duration(milliseconds: 250), _startFeaturedAutoplay);
      return;
    }
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (!_featuredCtrl.hasClients) return;
      final featured = _featured;
      if (featured.length <= 1) {
        _featuredIndex = 0;
        _startFeaturedAutoplay();
        return;
      }
      _featuredIndex = (_featuredIndex + 1) % featured.length;
      final target = _featuredIndex * _FeaturedJobsRow.cardWidth;
      _featuredCtrl.animateTo(target, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
      _startFeaturedAutoplay();
    });
  }

  void _startSuggestAutoplay() {
    if (!mounted) return;
    if (!_suggestCtrl.hasClients) {
      Future<void>.delayed(const Duration(milliseconds: 250), _startSuggestAutoplay);
      return;
    }
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (!_suggestCtrl.hasClients) return;
      final list = _suggestions;
      if (list.length <= 1) {
        _suggestIndex = 0;
        _startSuggestAutoplay();
        return;
      }
      _suggestIndex = (_suggestIndex + 1) % list.length;
      final target = _suggestIndex * _SuggestedJobsRow.cardWidth;
      _suggestCtrl.animateTo(target, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
      _startSuggestAutoplay();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await _service.listJobs();
      final saved = await _service.getSavedJobIdsRemote();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _saved = saved;
      });
    } catch (e) {
      debugPrint('JobsPage.load failed err=$e');
      if (mounted) setState(() => _error = 'Erreur de chargement.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<JobPosting> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _jobs.where((j) {
      if (q.isNotEmpty) {
        final hay = '${j.title} ${j.company} ${j.location} ${j.description} ${j.skills.join(' ')}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_typeFilters.isNotEmpty && !_typeFilters.contains(j.type.toLowerCase())) return false;
      final wm = (j.workMode ?? '').trim().toLowerCase();
      if (_workModeFilters.isNotEmpty && (wm.isEmpty || !_workModeFilters.contains(wm))) return false;
      // Only show approved when status exists.
      final st = (j.status ?? '').trim().toLowerCase();
      if (st.isNotEmpty && st != 'approved') return false;
      return true;
    }).toList(growable: false);
  }

  List<JobPosting> get _featured => _filtered.where((j) => j.isFeatured).toList(growable: false);

  List<JobPosting> get _suggestions {
    final approved = _filtered;
    final tagged = approved.where((j) => j.isSuggested).toList(growable: true);
    if (tagged.length < 3) {
      for (final j in approved) {
        if (tagged.length >= 3) break;
        if (tagged.any((e) => e.id == j.id)) continue;
        if (j.isFeatured) continue;
        tagged.add(j);
      }
    }
    return tagged.take(3).toList(growable: false);
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JobsFilterSheet(typeFilters: _typeFilters, workModeFilters: _workModeFilters),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _openJob(JobPosting j) => context.push('/jobs/${j.id}');

  Future<void> _toggleSave(JobPosting j) async {
    final id = j.id;
    final shouldSave = !_saved.contains(id);
    setState(() {
      final next = _saved.toSet();
      if (shouldSave) {
        next.add(id);
      } else {
        next.remove(id);
      }
      _saved = next;
    });
    await _service.toggleSavedRemote(jobId: id, save: shouldSave);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _filtered;
    final suggestions = _suggestions;
    final featured = _featured;
    final featuredIds = featured.map((e) => e.id).toSet();
    final suggestionIds = suggestions.map((e) => e.id).toSet();
    final otherJobs = jobs.where((j) => !featuredIds.contains(j.id) && !suggestionIds.contains(j.id)).toList(growable: false);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? InstitutionalColors.civicBlueSoft : InstitutionalColors.civicBlue;
    final divider = isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider;

    if (featured.isNotEmpty) _ensureFeaturedAutoplayStarted();
    if (suggestions.isNotEmpty) _ensureSuggestAutoplayStarted();

    return Scaffold(
      backgroundColor: isDark ? DarkModeColors.cyberDarkBlue : LightModeColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            _ThixInfoBackground(isDark: isDark),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.popOrGo(AppRoutes.home),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface),
                          ),
                          Expanded(
                            child: Text('Emploi', style: context.textStyles.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900)),
                          ),
                            _ThixIconButton(icon: Icons.dashboard_rounded, tooltip: 'Dashboard', onTap: () => context.push(AppRoutes.jobDashboard), accent: accent, divider: divider),
                          const SizedBox(width: 10),
                            _ThixIconButton(icon: Icons.tune_rounded, tooltip: 'Filtres', onTap: _openFilters, accent: accent, divider: divider),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ThixSearchBar(
                        controller: _searchCtrl,
                        hint: 'Rechercher: titre, entreprise, compétences, ville…',
                        onChanged: (_) => setState(() {}),
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        accent: accent,
                        divider: divider,
                        surface: cs.surface,
                        onSurface: cs.onSurface,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SimpleActiveFiltersRow(
                        typeFilters: _typeFilters,
                        workModeFilters: _workModeFilters,
                        onClearAll: () => setState(() {
                          _typeFilters.clear();
                          _workModeFilters.clear();
                        }),
                        accent: accent,
                        divider: divider,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: accent))
                      : (_error != null)
                          ? Center(child: Text(_error!, style: context.textStyles.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.72))))
                          : RefreshIndicator(
                              color: accent,
                              onRefresh: _load,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                    child: Row(
                                      children: [
                                        Icon(Icons.shield_rounded, size: 18, color: accent),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Offres vérifiées, parcours clair, candidature sécurisée.',
                                            style: context.textStyles.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.4),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(AppRadius.full),
                                            border: Border.all(color: divider),
                                            color: cs.surface.withValues(alpha: isDark ? 0.60 : 0.92),
                                          ),
                                          child: Text('${jobs.length}', style: context.textStyles.labelLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.85), fontWeight: FontWeight.w900)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (featured.isNotEmpty) ...[
                                    _SectionHeader(title: 'À la une', subtitle: 'Les opportunités mises en avant', accent: accent, onSurface: cs.onSurface),
                                    const SizedBox(height: 10),
                                    _FeaturedJobsRow(
                                      controller: _featuredCtrl,
                                      jobs: featured,
                                      onOpen: _openJob,
                                      accent: accent,
                                      divider: divider,
                                      surface: cs.surface,
                                      onSurface: cs.onSurface,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                  if (suggestions.isNotEmpty) ...[
                                    _SectionHeader(title: 'Suggestions pour vous', subtitle: '3 offres sélectionnées', accent: accent, onSurface: cs.onSurface),
                                    const SizedBox(height: 10),
                                    _SuggestedJobsRow(
                                      controller: _suggestCtrl,
                                      jobs: suggestions,
                                      onOpen: _openJob,
                                      accent: accent,
                                      divider: divider,
                                      surface: cs.surface,
                                      onSurface: cs.onSurface,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                  if (jobs.isEmpty)
                                    _ThixEmptyState(
                                      onClear: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                      accent: accent,
                                      divider: divider,
                                      surface: cs.surface,
                                      onSurface: cs.onSurface,
                                    )
                                  else
                                    if (otherJobs.isEmpty)
                                      _NoOtherOffersCard(accent: accent, divider: divider, surface: cs.surface, onSurface: cs.onSurface)
                                    else
                                      ...otherJobs.take(50).map(
                                            (j) => Padding(
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: _ThixJobTile(
                                                job: j,
                                                saved: _saved.contains(j.id),
                                                onSave: () => _toggleSave(j),
                                                onOpen: () => _openJob(j),
                                                accent: accent,
                                                divider: divider,
                                                surface: cs.surface,
                                                onSurface: cs.onSurface,
                                              ),
                                            ),
                                          ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThixInfoBackground extends StatelessWidget {
  final bool isDark;
  const _ThixInfoBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final navy = isDark ? DarkModeColors.primary : InstitutionalColors.navy;
    final navy2 = isDark ? DarkModeColors.cyberDarkBlue : InstitutionalColors.navy2;
    final accent = isDark ? InstitutionalColors.civicBlueSoft : InstitutionalColors.civicBlue;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy.withValues(alpha: 0.98), navy2.withValues(alpha: 0.94), accent.withValues(alpha: 0.10)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ThixSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Color accent;
  final Color divider;
  final Color surface;
  final Color onSurface;

  const _ThixSearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    required this.accent,
    required this.divider,
    required this.surface,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.55 : 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: divider),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: context.textStyles.bodyMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: context.textStyles.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.60)),
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, color: onSurface.withValues(alpha: 0.65)),
            ),
        ],
      ),
    );
  }
}

class _ThixIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color accent;
  final Color divider;
  const _ThixIconButton({required this.icon, required this.tooltip, required this.onTap, required this.accent, required this.divider});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.92),
            border: Border.all(color: divider),
          ),
          child: Icon(icon, color: accent),
        ),
      ),
    );
  }
}

class _ThixJobTile extends StatelessWidget {
  final JobPosting job;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;
  final Color accent;
  final Color divider;
  final Color surface;
  final Color onSurface;

  const _ThixJobTile({
    required this.job,
    required this.saved,
    required this.onSave,
    required this.onOpen,
    required this.accent,
    required this.divider,
    required this.surface,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = job.isVerifiedEmployer ? accent : divider;
    final hasPhoto = (job.companyLogoUrl ?? '').trim().startsWith('http');
    return InkWell(
      onTap: onOpen,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: surface.withValues(alpha: isDark ? 0.55 : 0.92),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: border.withValues(alpha: 0.65)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? Image.network(job.companyLogoUrl!, fit: BoxFit.cover)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accent.withValues(alpha: 0.95), Theme.of(context).colorScheme.primary.withValues(alpha: 0.90)],
                        ),
                      ),
                      child: Center(child: Icon(job.isVerifiedEmployer ? Icons.verified_rounded : Icons.business_rounded, color: Colors.white)),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title, style: context.textStyles.titleMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${job.company} • ${job.location}', style: context.textStyles.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.70)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ThixMetaPill(icon: Icons.payments_rounded, label: job.salary, divider: divider, surface: surface, onSurface: onSurface),
                      _ThixMetaPill(icon: Icons.category_rounded, label: job.type, divider: divider, surface: surface, onSurface: onSurface),
                      if (job.isSuggested) _ThixMetaPill(icon: Icons.auto_awesome_rounded, label: 'Suggestion', divider: divider, surface: surface, onSurface: onSurface),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: onSave,
              icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, color: saved ? accent : onSurface.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThixMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color divider;
  final Color surface;
  final Color onSurface;
  const _ThixMetaPill({required this.icon, required this.label, required this.divider, required this.surface, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        color: surface.withValues(alpha: isDark ? 0.40 : 0.85),
        border: Border.all(color: divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(label, style: context.textStyles.labelMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _NoOtherOffersCard extends StatelessWidget {
  final Color accent;
  final Color divider;
  final Color surface;
  final Color onSurface;
  const _NoOtherOffersCard({required this.accent, required this.divider, required this.surface, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.55 : 0.92),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: divider),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text("Pas d'autres offres pour l'instant.", style: context.textStyles.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.80), fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _ThixEmptyState extends StatelessWidget {
  final VoidCallback? onClear;
  final Color accent;
  final Color divider;
  final Color surface;
  final Color onSurface;
  const _ThixEmptyState({required this.onClear, required this.accent, required this.divider, required this.surface, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.55 : 0.92),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: divider),
      ),
      child: Row(
        children: [
          Icon(Icons.search_off_rounded, color: onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Aucun résultat. Essaie une autre recherche.', style: context.textStyles.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.70)))),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(foregroundColor: accent),
              child: const Text('Effacer'),
            ),
        ],
      ),
    );
  }
}

class _SimpleActiveFiltersRow extends StatelessWidget {
  final Set<String> typeFilters;
  final Set<String> workModeFilters;
  final VoidCallback onClearAll;
  final Color accent;
  final Color divider;
  const _SimpleActiveFiltersRow({required this.typeFilters, required this.workModeFilters, required this.onClearAll, required this.accent, required this.divider});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chips = <String>[...typeFilters, ...workModeFilters];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: divider),
                  color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.92),
                ),
                child: Text(chips[i], style: context.textStyles.labelMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ThixIconButton(icon: Icons.delete_sweep_rounded, tooltip: 'Tout effacer', onTap: onClearAll, accent: accent, divider: divider),
      ],
    );
  }
}

class _JobsFilterSheet extends StatefulWidget {
  final Set<String> typeFilters;
  final Set<String> workModeFilters;
  const _JobsFilterSheet({required this.typeFilters, required this.workModeFilters});

  @override
  State<_JobsFilterSheet> createState() => _JobsFilterSheetState();
}

class _JobsFilterSheetState extends State<_JobsFilterSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? InstitutionalColors.civicBlueSoft : InstitutionalColors.civicBlue;
    final divider = isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: isDark ? 0.92 : 0.96),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          border: Border.all(color: divider),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Filtres', style: context.textStyles.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900))),
                      IconButton(onPressed: () => context.pop(), icon: Icon(Icons.close_rounded, color: cs.onSurface.withValues(alpha: 0.70))),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FilterGroupTitle(title: 'Type de contrat', onSurface: cs.onSurface),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _chip(value: 'full_time', label: 'Full-time', accent: accent, divider: divider, onSurface: cs.onSurface),
                      _chip(value: 'part_time', label: 'Part-time', accent: accent, divider: divider, onSurface: cs.onSurface),
                      _chip(value: 'internship', label: 'Internship', accent: accent, divider: divider, onSurface: cs.onSurface),
                      _chip(value: 'freelance', label: 'Freelance', accent: accent, divider: divider, onSurface: cs.onSurface),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FilterGroupTitle(title: 'Mode de travail', onSurface: cs.onSurface),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _chipWorkMode(value: 'remote', label: 'Remote', accent: accent, divider: divider, onSurface: cs.onSurface),
                      _chipWorkMode(value: 'hybrid', label: 'Hybrid', accent: accent, divider: divider, onSurface: cs.onSurface),
                      _chipWorkMode(value: 'on_site', label: 'On-site', accent: accent, divider: divider, onSurface: cs.onSurface),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            widget.typeFilters.clear();
                            widget.workModeFilters.clear();
                            setState(() {});
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: cs.onSurface, side: BorderSide(color: divider), padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => context.pop(),
                          style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({required String value, required String label, required Color accent, required Color divider, required Color onSurface}) {
    final selected = widget.typeFilters.contains(value);
    return _chipValue(
      label: label,
      selected: selected,
      onTap: () => setState(() {
        if (selected) {
          widget.typeFilters.remove(value);
        } else {
          widget.typeFilters.add(value);
        }
      }),
      accent: accent,
      divider: divider,
      onSurface: onSurface,
    );
  }

  Widget _chipWorkMode({required String value, required String label, required Color accent, required Color divider, required Color onSurface}) {
    final selected = widget.workModeFilters.contains(value);
    return _chipValue(
      label: label,
      selected: selected,
      onTap: () => setState(() {
        if (selected) {
          widget.workModeFilters.remove(value);
        } else {
          widget.workModeFilters.add(value);
        }
      }),
      accent: accent,
      divider: divider,
      onSurface: onSurface,
    );
  }

  Widget _chipValue({required String label, required bool selected, required VoidCallback onTap, required Color accent, required Color divider, required Color onSurface}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          color: selected ? accent.withValues(alpha: isDark ? 0.18 : 0.14) : Theme.of(context).colorScheme.surface.withValues(alpha: isDark ? 0.65 : 0.92),
          border: Border.all(color: selected ? accent.withValues(alpha: 0.65) : divider),
        ),
        child: Text(label, style: context.textStyles.labelLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _FilterGroupTitle extends StatelessWidget {
  final String title;
  final Color onSurface;
  const _FilterGroupTitle({required this.title, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: context.textStyles.titleSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w900));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Color onSurface;
  const _SectionHeader({required this.title, required this.subtitle, required this.accent, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textStyles.titleMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.70), height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedJobsRow extends StatelessWidget {
  static const double cardWidth = 292;
  final ScrollController controller;
  final List<JobPosting> jobs;
  final ValueChanged<JobPosting> onOpen;
  final Color accent;
  final Color divider;
  final Color surface;
  final Color onSurface;

  const _FeaturedJobsRow({
    required this.controller,
    required this.jobs,
    required this.onOpen,
    required this.accent,
    required this.divider,
    required this.surface,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 172,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final j = jobs[i];
          final hasPhoto = (j.companyLogoUrl ?? '').trim().startsWith('http');
          return InkWell(
            onTap: () => onOpen(j),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
                color: surface.withValues(alpha: isDark ? 0.55 : 0.92),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: SizedBox(
                      width: 86,
                      height: double.infinity,
                      child: hasPhoto
                          ? Image.network(j.companyLogoUrl!, fit: BoxFit.cover)
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [accent.withValues(alpha: 0.92), InstitutionalColors.navy.withValues(alpha: 0.95)],
                                ),
                              ),
                              child: Center(child: Icon(Icons.work_rounded, color: Colors.white.withValues(alpha: 0.95))),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            color: accent.withValues(alpha: isDark ? 0.14 : 0.12),
                            border: Border.all(color: divider),
                          ),
                          child: Text('À la une', style: context.textStyles.labelSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 10),
                        Text(j.title, style: context.textStyles.titleSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(j.company, style: context.textStyles.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.72)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.place_rounded, size: 16, color: onSurface.withValues(alpha: 0.60)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(j.location, style: context.textStyles.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.70)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SuggestedJobsRow extends StatelessWidget {
  static const double cardWidth = 320;
  final ScrollController controller;
  final List<JobPosting> jobs;
  final ValueChanged<JobPosting> onOpen;
  final Color accent;
  final Color divider;
  final Color surface;
  final Color onSurface;

  const _SuggestedJobsRow({
    required this.controller,
    required this.jobs,
    required this.onOpen,
    required this.accent,
    required this.divider,
    required this.surface,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 196,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final j = jobs[i];
          final hasPhoto = (j.companyLogoUrl ?? '').trim().startsWith('http');
          return InkWell(
            onTap: () => onOpen(j),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: divider),
                color: surface.withValues(alpha: isDark ? 0.55 : 0.92),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: SizedBox(
                      height: 92,
                      width: double.infinity,
                      child: hasPhoto
                          ? Image.network(j.companyLogoUrl!, fit: BoxFit.cover)
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [accent.withValues(alpha: 0.90), InstitutionalColors.navy.withValues(alpha: 0.92)],
                                ),
                              ),
                              child: Center(child: Icon(Icons.auto_awesome_rounded, color: Colors.white.withValues(alpha: 0.95))),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          color: accent.withValues(alpha: isDark ? 0.14 : 0.12),
                          border: Border.all(color: divider),
                        ),
                        child: Text('Suggestion', style: context.textStyles.labelSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(j.company, style: context.textStyles.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.72)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(j.title, style: context.textStyles.titleSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 16, color: onSurface.withValues(alpha: 0.60)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(j.location, style: context.textStyles.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.70)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
