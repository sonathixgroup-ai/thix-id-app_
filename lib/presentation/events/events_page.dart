import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/event_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/event_service.dart';
import 'package:thix_id/theme.dart';

/// Ultra-premium Events Home (mobile-first) inspired by Apple Events / LinkedIn Events.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _svc = EventService();
  final _search = TextEditingController();

  String _filter = 'Tous';
  bool _onlyOnline = false;
  bool _onlyPhysical = false;
  bool _onlyFree = false;
  bool _onlyPaid = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventsCyberColors.bg0,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: EventsCyberGradients.background()),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _EventsTopBar(onOpenMyEvents: () => context.push('/events/me'))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      _SearchBar(
                        controller: _search,
                        onOpenFilters: _openFilters,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _FilterRow(
                        selected: _filter,
                        onChanged: (v) => setState(() => _filter = v),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  child: _FeaturedSection(
                    service: _svc,
                    onOpen: (e) => context.push('/events/${e.id}'),
                    onRegister: (e) => context.push('/events/${e.id}/register'),
                    onJoinLive: (e) {
                      final link = (e.meetingLink ?? '').trim();
                      if (link.isEmpty) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Livestream: lien disponible sur la page détails.')));
                      context.push('/events/${e.id}');
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: Text('Explorer', style: context.textStyles.titleLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                  child: FutureBuilder<List<EventItem>>(
                    future: _svc.listEvents(),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const _LoadingGrid();
                      }
                      final all = snap.data ?? const <EventItem>[];
                      final filtered = _applyFilters(all);
                      if (filtered.isEmpty) return const _EmptyState();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EventsSectionGrid(title: 'À venir', subtitle: 'Prochains événements premium', events: filtered.where((e) => e.startsAt.isAfter(DateTime.now().subtract(const Duration(hours: 1)))).toList(growable: false), onOpen: (e) => context.push('/events/${e.id}')),
                          const SizedBox(height: AppSpacing.xl),
                          _EventsSectionGrid(title: 'Trending', subtitle: 'Ce qui cartonne en ce moment', events: filtered.take(6).toList(growable: false), onOpen: (e) => context.push('/events/${e.id}')),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<EventItem> _applyFilters(List<EventItem> input) {
    final q = _search.text.trim().toLowerCase();
    bool matchesQuery(EventItem e) {
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) || e.location.toLowerCase().contains(q) || e.category.toLowerCase().contains(q);
    }

    bool matchesCategory(EventItem e) {
      if (_filter == 'Tous') return true;
      return e.category.toLowerCase().contains(_filter.toLowerCase());
    }

    bool matchesToggles(EventItem e) {
      if (_onlyOnline && e.eventType.toLowerCase() != 'online') return false;
      if (_onlyPhysical && e.eventType.toLowerCase() != 'physical') return false;
      if (_onlyFree && !e.isFree) return false;
      if (_onlyPaid && e.isFree) return false;
      return true;
    }

    final list = input.where((e) => matchesQuery(e) && matchesCategory(e) && matchesToggles(e) && e.status == 'published').toList(growable: false);
    list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  Future<void> _openFilters() async {
    final res = await showModalBottomSheet<_FiltersResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FiltersSheet(
        initial: _FiltersResult(onlyOnline: _onlyOnline, onlyPhysical: _onlyPhysical, onlyFree: _onlyFree, onlyPaid: _onlyPaid),
      ),
    );
    if (res == null) return;
    setState(() {
      _onlyOnline = res.onlyOnline;
      _onlyPhysical = res.onlyPhysical;
      _onlyFree = res.onlyFree;
      _onlyPaid = res.onlyPaid;
    });
  }
}

class _EventsTopBar extends StatelessWidget {
  final VoidCallback onOpenMyEvents;
  const _EventsTopBar({required this.onOpenMyEvents});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EventsCyberColors.panel.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.event_available_rounded, color: EventsCyberColors.neonCyan),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THIX ID', style: context.textStyles.labelSmall?.copyWith(color: EventsCyberColors.textDim, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                Text('EVENTS', style: context.textStyles.titleLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900, height: 1.05)),
              ],
            ),
          ),
          _TopIconButton(icon: Icons.dashboard_customize_rounded, tooltip: 'Mon dashboard', onPressed: onOpenMyEvents),
          const SizedBox(width: AppSpacing.sm),
          _TopIconButton(
            icon: Icons.notifications_active_rounded,
            tooltip: 'Notifications',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications événementielles: bientôt.'))),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _TopIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: EventsCyberColors.panel.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: EventsCyberColors.text),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onOpenFilters;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onOpenFilters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: EventsCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: EventsCyberColors.neonCyan),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.text),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Search events, speakers, cities…',
                hintStyle: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onOpenFilters,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: EventsCyberGradients.glowBlue(),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterRow({required this.selected, required this.onChanged});

  static const _values = ['Tous', 'Tech', 'Business', 'Education', 'Government', 'Networking'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _values.map((v) {
          final active = v == selected;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: () => onChanged(v),
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? EventsCyberColors.electricBlue.withValues(alpha: 0.22) : EventsCyberColors.panel.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: active ? EventsCyberColors.neonCyan : EventsCyberColors.stroke.withValues(alpha: 0.9)),
                ),
                child: Text(v, style: context.textStyles.labelLarge?.copyWith(color: active ? EventsCyberColors.text : EventsCyberColors.textDim, fontWeight: FontWeight.w800)),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  final EventService service;
  final ValueChanged<EventItem> onOpen;
  final ValueChanged<EventItem> onRegister;
  final ValueChanged<EventItem> onJoinLive;
  const _FeaturedSection({required this.service, required this.onOpen, required this.onRegister, required this.onJoinLive});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('🔥 ', style: TextStyle(fontSize: 18)),
            Expanded(
              child: Text('À LA UNE', style: context.textStyles.titleMedium?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<EventItem>>(
          future: service.listFeaturedEvents(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const _FeaturedLoading();
            final list = (snap.data ?? const <EventItem>[]).where((e) => e.status == 'published').toList(growable: false);
            if (list.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: EventsCyberColors.panel.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
                ),
                child: Text('Aucun événement “à la une” pour le moment.', style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim)),
              );
            }
            return ThixFeaturedEventsCarousel(events: list, onOpen: onOpen, onRegister: onRegister, onJoinLive: onJoinLive);
          },
        ),
      ],
    );
  }
}

class ThixFeaturedEventsCarousel extends StatefulWidget {
  final List<EventItem> events;
  final ValueChanged<EventItem> onOpen;
  final ValueChanged<EventItem> onRegister;
  final ValueChanged<EventItem> onJoinLive;
  const ThixFeaturedEventsCarousel({super.key, required this.events, required this.onOpen, required this.onRegister, required this.onJoinLive});

  @override
  State<ThixFeaturedEventsCarousel> createState() => _ThixFeaturedEventsCarouselState();
}

class _ThixFeaturedEventsCarouselState extends State<ThixFeaturedEventsCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.90);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.events.isEmpty) return;
      final next = (_index + 1) % widget.events.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic);
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
    return SizedBox(
      height: 320,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.events.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final e = widget.events[i];
                return Padding(
                  padding: EdgeInsets.only(right: i == widget.events.length - 1 ? 0 : AppSpacing.md),
                  child: ThixFeaturedEventCard(event: e, onOpen: () => widget.onOpen(e), onRegister: () => widget.onRegister(e), onJoinLive: () => widget.onJoinLive(e)),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.events.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active ? EventsCyberColors.neonCyan : EventsCyberColors.stroke.withValues(alpha: 0.9),
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

class ThixFeaturedEventCard extends StatefulWidget {
  final EventItem event;
  final VoidCallback onOpen;
  final VoidCallback onRegister;
  final VoidCallback onJoinLive;
  const ThixFeaturedEventCard({super.key, required this.event, required this.onOpen, required this.onRegister, required this.onJoinLive});

  @override
  State<ThixFeaturedEventCard> createState() => _ThixFeaturedEventCardState();
}

class _ThixFeaturedEventCardState extends State<ThixFeaturedEventCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final remaining = e.startsAt.difference(DateTime.now());
    final countdown = remaining.isNegative ? 'Live / En cours' : _formatCountdown(remaining);

    return InkWell(
      onTap: widget.onOpen,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(color: EventsCyberColors.neonCyan.withValues(alpha: 0.10), blurRadius: 26, offset: const Offset(0, 14)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _EventCinematicImage(event: e),
            Container(decoration: BoxDecoration(gradient: EventsCyberGradients.cinematicScrim())),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: _Badge(label: 'THIX VERIFIED', icon: Icons.verified_rounded, color: EventsCyberColors.success),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: _Badge(label: countdown, icon: Icons.timer_rounded, color: EventsCyberColors.neonCyan),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.12),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: EventsCyberColors.neonCyan),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                        ),
                        child: Text(e.priceLabel, style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  if ((e.quickHook ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(e.quickHook!, style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim, height: 1.35)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _CtaButton(
                          label: 'View details',
                          icon: Icons.visibility_rounded,
                          filled: false,
                          onPressed: widget.onOpen,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CtaButton(
                          label: 'Register',
                          icon: Icons.confirmation_number_rounded,
                          filled: true,
                          onPressed: widget.onRegister,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CtaButton(
                          label: 'Live',
                          icon: Icons.live_tv_rounded,
                          filled: false,
                          onPressed: (e.meetingLink ?? '').trim().isEmpty ? null : widget.onJoinLive,
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

  static String _formatCountdown(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    if (days > 0) return '${days}j ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;
  const _CtaButton({required this.label, required this.icon, required this.filled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = filled ? EventsCyberGradients.glowBlue() : null;
    final border = filled ? null : Border.all(color: Colors.white.withValues(alpha: 0.18));
    final fg = filled ? Colors.white : (enabled ? Colors.white : EventsCyberColors.textDim);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            gradient: bg,
            color: filled ? null : Colors.black.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(16),
            border: border,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis, style: context.textStyles.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _EventCinematicImage extends StatelessWidget {
  final EventItem event;
  const _EventCinematicImage({required this.event});

  @override
  Widget build(BuildContext context) {
    // For now: use local cinematic assets; when cover_image_path exists,
    // details page will resolve real Storage URLs.
    final a = event.imageAssetPath;
    if (a != null && a.trim().isNotEmpty) return Image.asset(a, fit: BoxFit.cover);
    return Container(decoration: BoxDecoration(gradient: EventsCyberGradients.glowBlue()));
  }
}

class _EventsSectionGrid extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<EventItem> events;
  final ValueChanged<EventItem> onOpen;
  const _EventsSectionGrid({required this.title, required this.subtitle, required this.events, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final w = MediaQuery.sizeOf(context).width;
    final crossAxisCount = w >= 940 ? 3 : (w >= 560 ? 2 : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.textStyles.titleMedium?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: EventsCyberColors.textDim)),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.16,
          ),
          itemCount: events.length,
          itemBuilder: (context, i) => ThixEventPosterTile(event: events[i], onTap: () => onOpen(events[i])),
        ),
      ],
    );
  }
}

class ThixEventPosterTile extends StatelessWidget {
  final EventItem event;
  final VoidCallback onTap;
  const ThixEventPosterTile({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          color: EventsCyberColors.panel.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (event.imageAssetPath != null) Image.asset(event.imageAssetPath!, fit: BoxFit.cover) else Container(decoration: BoxDecoration(gradient: EventsCyberGradients.glowBlue())),
            Container(decoration: BoxDecoration(gradient: EventsCyberGradients.cinematicScrim())),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: _Badge(label: event.category, icon: Icons.category_rounded, color: EventsCyberColors.neonViolet),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.textStyles.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.12)),
                  const SizedBox(height: 6),
                  Text(event.dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.labelLarge?.copyWith(color: EventsCyberColors.neonCyan, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.88))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  final _FiltersResult initial;
  const _FiltersSheet({required this.initial});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late bool _onlyOnline;
  late bool _onlyPhysical;
  late bool _onlyFree;
  late bool _onlyPaid;

  @override
  void initState() {
    super.initState();
    _onlyOnline = widget.initial.onlyOnline;
    _onlyPhysical = widget.initial.onlyPhysical;
    _onlyFree = widget.initial.onlyFree;
    _onlyPaid = widget.initial.onlyPaid;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
          decoration: BoxDecoration(
            color: EventsCyberColors.panelHi,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Filters', style: context.textStyles.titleLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: EventsCyberColors.textDim)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _SwitchRow(label: 'Online', value: _onlyOnline, onChanged: (v) => setState(() => _onlyOnline = v), icon: Icons.public_rounded),
              const SizedBox(height: AppSpacing.sm),
              _SwitchRow(label: 'Physical', value: _onlyPhysical, onChanged: (v) => setState(() => _onlyPhysical = v), icon: Icons.location_city_rounded),
              const SizedBox(height: AppSpacing.sm),
              _SwitchRow(label: 'Free', value: _onlyFree, onChanged: (v) => setState(() => _onlyFree = v), icon: Icons.money_off_rounded),
              const SizedBox(height: AppSpacing.sm),
              _SwitchRow(label: 'Paid', value: _onlyPaid, onChanged: (v) => setState(() => _onlyPaid = v), icon: Icons.payments_rounded),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: EventsCyberColors.electricBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => context.pop(_FiltersResult(onlyOnline: _onlyOnline, onlyPhysical: _onlyPhysical, onlyFree: _onlyFree, onlyPaid: _onlyPaid)),
                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  const _SwitchRow({required this.label, required this.value, required this.onChanged, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: EventsCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Icon(icon, color: EventsCyberColors.neonCyan),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w800))),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: EventsCyberColors.neonCyan),
        ],
      ),
    );
  }
}

class _FiltersResult {
  final bool onlyOnline;
  final bool onlyPhysical;
  final bool onlyFree;
  final bool onlyPaid;
  const _FiltersResult({required this.onlyOnline, required this.onlyPhysical, required this.onlyFree, required this.onlyPaid});
}

class _FeaturedLoading extends StatelessWidget {
  const _FeaturedLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: EventsCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: EventsCyberColors.neonCyan),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          height: 120,
          margin: EdgeInsets.only(bottom: i == 2 ? 0 : AppSpacing.md),
          decoration: BoxDecoration(
            color: EventsCyberColors.panel.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: EventsCyberColors.neonCyan),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: EventsCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aucun résultat', style: context.textStyles.titleMedium?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Essaie un autre mot-clé ou enlève des filtres.', style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim, height: 1.45)),
        ],
      ),
    );
  }
}

extension _ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
}
