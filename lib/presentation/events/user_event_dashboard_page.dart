import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/event_item.dart';
import 'package:thix_id/models/event_registration.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/event_service.dart';
import 'package:thix_id/theme.dart';

/// User-side “My Events” dashboard: registrations, saved events, history.
class UserEventDashboardPage extends StatefulWidget {
  const UserEventDashboardPage({super.key});

  @override
  State<UserEventDashboardPage> createState() => _UserEventDashboardPageState();
}

class _UserEventDashboardPageState extends State<UserEventDashboardPage> {
  final _svc = EventService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventsCyberColors.bg0,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: EventsCyberGradients.background()),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.popOrGo(AppRoutes.events),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EventsCyberColors.text),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text('My Events', style: context.textStyles.titleLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900))),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: EventsCyberColors.panel.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
                          ),
                          child: TabBar(
                            indicator: BoxDecoration(
                              gradient: EventsCyberGradients.glowBlue(),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor: EventsCyberColors.textDim,
                            labelStyle: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                            tabs: const [
                              Tab(text: 'Registered'),
                              Tab(text: 'Saved'),
                              Tab(text: 'History'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _RegisteredTab(service: _svc),
                              _SavedTab(service: _svc),
                              _HistoryTab(service: _svc),
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
        ),
      ),
    );
  }
}

class _RegisteredTab extends StatelessWidget {
  final EventService service;
  const _RegisteredTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventRegistration>>(
      future: service.listMyRegistrations(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: EventsCyberColors.neonCyan));
        }
        final regs = snap.data ?? const <EventRegistration>[];
        if (regs.isEmpty) return const _DashEmpty(label: 'No registrations yet.');
        return ListView.separated(
          itemCount: regs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _RegistrationTile(reg: regs[i]),
        );
      },
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  final EventRegistration reg;
  const _RegistrationTile({required this.reg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EventsCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: EventsCyberGradients.glowBlue(), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: const Icon(Icons.confirmation_number_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ticket • ${reg.status}', style: context.textStyles.labelLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Event: ${reg.eventId}', style: context.textStyles.bodySmall?.copyWith(color: EventsCyberColors.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
              foregroundColor: EventsCyberColors.text,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: () => context.push('/events/${reg.eventId}/ticket/${reg.id}'),
            icon: const Icon(Icons.qr_code_rounded, color: EventsCyberColors.neonCyan),
            label: const Text('Pass'),
          ),
        ],
      ),
    );
  }
}

class _SavedTab extends StatefulWidget {
  final EventService service;
  const _SavedTab({required this.service});

  @override
  State<_SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<_SavedTab> {

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<EventItem> events, Set<String> savedIds})>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: EventsCyberColors.neonCyan));
        }
        final data = snap.data;
        if (data == null) return const _DashEmpty(label: 'No saved events.');
        final savedEvents = data.events.where((e) => data.savedIds.contains(e.id)).toList(growable: false);
        if (savedEvents.isEmpty) return const _DashEmpty(label: 'No saved events.');

        return ListView.separated(
          itemCount: savedEvents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final e = savedEvents[i];
            return _EventMiniTile(
              event: e,
              trailing: IconButton(
                onPressed: () async {
                  await widget.service.toggleSaveEvent(eventId: e.id, saved: false);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.bookmark_remove_rounded, color: EventsCyberColors.neonCyan),
              ),
              onTap: () => context.push('/events/${e.id}'),
            );
          },
        );
      },
    );
  }

  Future<({List<EventItem> events, Set<String> savedIds})> _load() async {
    final results = await Future.wait([
      widget.service.listEvents(),
      widget.service.listSavedEventIds(),
    ]);
    return (events: results[0] as List<EventItem>, savedIds: results[1] as Set<String>);
  }
}

class _HistoryTab extends StatelessWidget {
  final EventService service;
  const _HistoryTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventRegistration>>(
      future: service.listMyRegistrations(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: EventsCyberColors.neonCyan));
        }
        final regs = (snap.data ?? const <EventRegistration>[]).where((r) => r.status != 'registered').toList(growable: false);
        if (regs.isEmpty) return const _DashEmpty(label: 'History will appear after attendance scans.');
        return ListView.separated(
          itemCount: regs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _RegistrationTile(reg: regs[i]),
        );
      },
    );
  }
}

class _EventMiniTile extends StatelessWidget {
  final EventItem event;
  final Widget trailing;
  final VoidCallback onTap;
  const _EventMiniTile({required this.event, required this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EventsCyberColors.panel.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: event.imageAssetPath == null ? Container(decoration: BoxDecoration(gradient: EventsCyberGradients.glowBlue())) : Image.asset(event.imageAssetPath!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleSmall?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('${event.dateLabel} • ${event.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodySmall?.copyWith(color: EventsCyberColors.textDim)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _DashEmpty extends StatelessWidget {
  final String label;
  const _DashEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: EventsCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Text(label, style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.textDim, height: 1.45)),
    );
  }
}
