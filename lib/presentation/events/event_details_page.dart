import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/event_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/event_service.dart';
import 'package:thix_id/theme.dart';

class EventDetailsPage extends StatefulWidget {
  final String eventId;
  final bool registered;
  const EventDetailsPage({super.key, required this.eventId, this.registered = false});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final _svc = EventService();
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
    return Scaffold(
      backgroundColor: EventsCyberColors.bg0,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: EventsCyberGradients.background()),
        child: SafeArea(
          child: FutureBuilder<EventItem?>(
            future: _svc.fetchEvent(widget.eventId),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: EventsCyberColors.neonCyan));
              }
              final event = snap.data;
              if (event == null) return const _NotFound();

              final countdown = _countdown(event.startsAt);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(event: event),
                          const SizedBox(height: AppSpacing.md),
                          if (widget.registered) ...[
                            _RegisteredBanner(onOpenTicket: () async {
                              final regs = await _svc.listMyRegistrations();
                              final r = regs.where((e) => e.eventId == event.id).toList();
                              if (!mounted) return;
                              if (r.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Billet non trouvé.')));
                                return;
                              }
                              context.push('/events/${event.id}/ticket/${r.first.id}');
                            }),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          _HeroBanner(event: event),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              _Pill(icon: Icons.timer_rounded, label: countdown, color: EventsCyberColors.neonCyan),
                              _Pill(icon: Icons.event_available_rounded, label: event.dateLabel, color: EventsCyberColors.textDim),
                              _Pill(icon: Icons.location_on_rounded, label: event.location, color: EventsCyberColors.textDim),
                              _Pill(icon: Icons.payments_rounded, label: event.priceLabel, color: EventsCyberColors.textDim),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _PrimaryActions(event: event),
                          const SizedBox(height: AppSpacing.lg),
                          _Section(title: 'About', icon: Icons.info_outline_rounded, child: Text(event.description, style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim, height: 1.6))),
                          const SizedBox(height: AppSpacing.lg),
                          if (event.speakers.isNotEmpty) ...[
                            _Section(title: 'Speakers', icon: Icons.record_voice_over_rounded, child: _SpeakersList(speakers: event.speakers)),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (event.agenda.isNotEmpty) ...[
                            _Section(title: 'Agenda', icon: Icons.view_agenda_rounded, child: _AgendaList(items: event.agenda)),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _Section(
                            title: 'Highlights',
                            icon: Icons.auto_awesome_rounded,
                            child: Column(
                              children: event.highlights.isEmpty
                                  ? [Text('No highlights provided yet.', style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim))]
                                  : event.highlights
                                      .map((h) => Padding(
                                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.bolt_rounded, size: 18, color: EventsCyberColors.neonCyan)),
                                                const SizedBox(width: 10),
                                                Expanded(child: Text(h, style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim, height: 1.5))),
                                              ],
                                            ),
                                          ))
                                      .toList(growable: false),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (event.sponsors.isNotEmpty) ...[
                            _Section(title: 'Sponsors', icon: Icons.handshake_rounded, child: _SponsorsRow(sponsors: event.sponsors)),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _Section(
                            title: 'Livestream',
                            icon: Icons.live_tv_rounded,
                            child: (event.meetingLink ?? '').trim().isEmpty
                                ? Text('No livestream link for this event.', style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text('Secure link available for verified attendees.', style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim, height: 1.5)),
                                      const SizedBox(height: AppSpacing.md),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(backgroundColor: EventsCyberColors.electricBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouvre le lien depuis le navigateur / app (MVP).'))),
                                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                        label: const Text('Join livestream', style: TextStyle(fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 84),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _countdown(DateTime startsAt) {
    final d = startsAt.difference(DateTime.now());
    if (d.isNegative) return 'Live / En cours';
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    if (days > 0) return '${days}j ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _TopBar extends StatelessWidget {
  final EventItem event;
  const _TopBar({required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.popOrGo(AppRoutes.events),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EventsCyberColors.text),
        ),
        Expanded(child: Text('Event', style: context.textStyles.titleLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900))),
        IconButton(
          tooltip: 'Share',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share: bientôt (deep links).'))),
          icon: const Icon(Icons.ios_share_rounded, color: EventsCyberColors.text),
        ),
      ],
    );
  }
}

class _RegisteredBanner extends StatelessWidget {
  final VoidCallback onOpenTicket;
  const _RegisteredBanner({required this.onOpenTicket});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: EventsCyberColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: EventsCyberColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: EventsCyberColors.success),
          const SizedBox(width: 10),
          Expanded(child: Text('Registration confirmed. Your THIX Event Pass is ready.', style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: EventsCyberColors.success.withValues(alpha: 0.6)),
              foregroundColor: EventsCyberColors.text,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onOpenTicket,
            child: const Text('Open pass'),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final EventItem event;
  const _HeroBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
        boxShadow: [BoxShadow(color: EventsCyberColors.neonCyan.withValues(alpha: 0.10), blurRadius: 26, offset: const Offset(0, 16))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _EventCoverImage(event: event),
          Container(decoration: BoxDecoration(gradient: EventsCyberGradients.cinematicScrim())),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.36), borderRadius: BorderRadius.circular(999), border: Border.all(color: EventsCyberColors.success.withValues(alpha: 0.55))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: EventsCyberColors.success),
                      const SizedBox(width: 6),
                      Text('THIX Verified Event', style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.textStyles.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.12)),
                const SizedBox(height: 6),
                Text(event.category, style: context.textStyles.labelLarge?.copyWith(color: EventsCyberColors.neonCyan, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCoverImage extends StatefulWidget {
  final EventItem event;
  const _EventCoverImage({required this.event});

  @override
  State<_EventCoverImage> createState() => _EventCoverImageState();
}

class _EventCoverImageState extends State<_EventCoverImage> {
  final _docs = DocumentService();
  String? _url;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(covariant _EventCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.coverImagePath != widget.event.coverImagePath || oldWidget.event.coverImageBucket != widget.event.coverImageBucket) {
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    final path = (widget.event.coverImagePath ?? '').trim();
    final bucket = (widget.event.coverImageBucket ?? '').trim();
    if (path.isEmpty || bucket.isEmpty) {
      if (mounted) setState(() => _url = null);
      return;
    }
    try {
      final url = await _docs.createDownloadUrl(storagePath: path, bucketName: bucket);
      if (!mounted) return;
      setState(() => _url = url);
    } catch (e) {
      debugPrint('_EventCoverImage resolve failed err=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_url != null) {
      return Image.network(_url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() {
    final a = widget.event.imageAssetPath;
    if (a != null && a.trim().isNotEmpty) return Image.asset(a, fit: BoxFit.cover);
    return Container(decoration: BoxDecoration(gradient: EventsCyberGradients.glowBlue()));
  }
}

class _PrimaryActions extends StatefulWidget {
  final EventItem event;
  const _PrimaryActions({required this.event});

  @override
  State<_PrimaryActions> createState() => _PrimaryActionsState();
}

class _PrimaryActionsState extends State<_PrimaryActions> {
  final _svc = EventService();
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSaved());
  }

  Future<void> _loadSaved() async {
    try {
      final ids = await _svc.listSavedEventIds();
      if (!mounted) return;
      setState(() => _saved = ids.contains(widget.event.id));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: EventsCyberColors.electricBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () => context.push('/events/${widget.event.id}/register'),
          icon: const Icon(Icons.confirmation_number_rounded, color: Colors.white),
          label: const Text('Register now', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
                  foregroundColor: EventsCyberColors.text,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          final next = !_saved;
                          await _svc.toggleSaveEvent(eventId: widget.event.id, saved: next);
                          if (!mounted) return;
                          setState(() => _saved = next);
                        } catch (e) {
                          debugPrint('EventDetails save failed err=$e');
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                icon: Icon(_saved ? Icons.bookmark_added_rounded : Icons.bookmark_add_rounded, color: EventsCyberColors.neonCyan),
                label: Text(_saved ? 'Saved' : 'Save event'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
                  foregroundColor: EventsCyberColors.text,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add to calendar: bientôt (ICS export).'))),
                icon: const Icon(Icons.event_repeat_rounded, color: EventsCyberColors.neonCyan),
                label: const Text('Add to calendar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({required this.title, required this.icon, required this.child});

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: EventsCyberColors.neonCyan),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: context.textStyles.titleMedium?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EventsCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: context.textStyles.labelLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SpeakersList extends StatelessWidget {
  final List<Map<String, dynamic>> speakers;
  const _SpeakersList({required this.speakers});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: speakers.map((s) {
        final name = (s['name'] ?? '—').toString();
        final title = (s['title'] ?? '').toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: EventsCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.textStyles.titleSmall?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
                    if (title.trim().isNotEmpty) Text(title, style: context.textStyles.bodySmall?.copyWith(color: EventsCyberColors.textDim, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _AgendaList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _AgendaList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((a) {
        final t = (a['time'] ?? '').toString();
        final title = (a['title'] ?? a['label'] ?? '').toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 68,
                child: Text(t.isEmpty ? '—' : t, style: context.textStyles.labelLarge?.copyWith(color: EventsCyberColors.neonCyan, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title.isEmpty ? '—' : title, style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim, height: 1.5))),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _SponsorsRow extends StatelessWidget {
  final List<Map<String, dynamic>> sponsors;
  const _SponsorsRow({required this.sponsors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: sponsors.map((s) {
        final name = (s['name'] ?? '—').toString();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
          ),
          child: Text(name, style: context.textStyles.labelLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w800)),
        );
      }).toList(growable: false),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => context.popOrGo(AppRoutes.events), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EventsCyberColors.text)),
              Expanded(child: Text('Event', style: context.textStyles.titleLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900))),
            ],
          ),
          const Spacer(),
          Text('Événement introuvable.', style: context.textStyles.titleMedium?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EventsCyberColors.electricBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () => context.go(AppRoutes.events),
            child: const Text('Retour', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
