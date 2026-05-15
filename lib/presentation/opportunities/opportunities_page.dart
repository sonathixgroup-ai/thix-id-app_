import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/opportunity_service.dart';
import 'package:thix_id/theme.dart';

class OpportunitiesPage extends StatelessWidget {
  const OpportunitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = OpportunityService();
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: 'Opportunités',
                subtitle: 'Bourses, subventions, concours',
                onBack: () => context.popOrGo(AppRoutes.home),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FutureBuilder(
                  future: service.listOpportunities(),
                  builder: (context, snap) {
                    final list = snap.data ?? const <OpportunityItem>[];
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: Padding(padding: EdgeInsets.only(top: AppSpacing.xl), child: CircularProgressIndicator()));
                    }
                    if (list.isEmpty) {
                      return Text('Aucune opportunité pour le moment.', style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText));
                    }

                    final featured = list.take(5).toList(growable: false);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('À la une', style: context.textStyles.titleMedium?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
                        const SizedBox(height: AppSpacing.md),
                        FeaturedOpportunitiesCarousel(
                          opportunities: featured,
                          onOpen: (o) => context.push('/opportunities/${o.id}'),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Toutes les opportunités', style: context.textStyles.titleMedium?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
                        const SizedBox(height: AppSpacing.md),
                        ...list.map(
                          (o) => _OpportunityCard(
                            item: o,
                            onOpen: () => context.push('/opportunities/${o.id}'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  const _Header({required this.title, required this.subtitle, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.primary,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(AppRadius.xl), bottomRight: Radius.circular(AppRadius.xl)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textStyles.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: context.textStyles.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
            alignment: Alignment.center,
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final OpportunityItem item;
  final VoidCallback onOpen;
  const _OpportunityCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final img = item.imageAssetPath;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: LightModeColors.accent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (img != null)
                    (img.startsWith('http') ? Image.network(img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover))
                  else
                    Container(color: LightModeColors.hint),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
                      child: Text(item.category, style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(color: LightModeColors.accent, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Text(item.rewardLabel, style: context.textStyles.labelSmall?.copyWith(color: const Color(0xFF0A2F5C), fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.textStyles.titleMedium?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 18, color: LightModeColors.accent),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(item.organizer, style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18, color: LightModeColors.accent),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(item.deadlineLabel, style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Voir détails'),
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

class FeaturedOpportunitiesCarousel extends StatefulWidget {
  final List<OpportunityItem> opportunities;
  final ValueChanged<OpportunityItem> onOpen;

  const FeaturedOpportunitiesCarousel({super.key, required this.opportunities, required this.onOpen});

  @override
  State<FeaturedOpportunitiesCarousel> createState() => _FeaturedOpportunitiesCarouselState();
}

class _FeaturedOpportunitiesCarouselState extends State<FeaturedOpportunitiesCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.opportunities.isEmpty) return;
      final next = (_index + 1) % widget.opportunities.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opportunities.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 210,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.opportunities.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final o = widget.opportunities[i];
                return Padding(
                  padding: EdgeInsets.only(right: i == widget.opportunities.length - 1 ? 0 : AppSpacing.md),
                  child: _FeaturedOpportunityCard(opportunity: o, onTap: () => widget.onOpen(o)),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.opportunities.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active ? LightModeColors.accent : context.theme.dividerColor,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FeaturedOpportunityCard extends StatelessWidget {
  final OpportunityItem opportunity;
  final VoidCallback onTap;
  const _FeaturedOpportunityCard({required this.opportunity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = opportunity.imageAssetPath;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: LightModeColors.accent, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              (img.startsWith('http') ? Image.network(img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover))
            else
              Container(color: LightModeColors.hint),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [context.theme.colorScheme.primary, context.theme.colorScheme.primary.withValues(alpha: 0.6), Colors.transparent],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: LightModeColors.accent, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text('À LA UNE', style: context.textStyles.labelSmall?.copyWith(color: const Color(0xFF0A2F5C), fontWeight: FontWeight.w900)),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                child: Text(opportunity.rewardLabel, style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opportunity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 18, color: LightModeColors.accent),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          opportunity.organizer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.labelLarge?.copyWith(color: LightModeColors.accent, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
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

extension _ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
