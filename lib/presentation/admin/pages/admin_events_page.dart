import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/admin_event_service.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/theme.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  final _svc = AdminEventService();
  final _docs = DocumentService();
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = const [];

  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _load();
    _subscribeRealtime();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listEvents();
      if (!mounted) return;
      setState(() {
        _events = list;
      });
    } catch (e) {
      debugPrint('AdminEventsPage: load failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    try {
      _channel = SupabaseConfig.client.channel('admin:events');
      _channel!
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AdminEventService.eventsTable, callback: (_) => unawaited(_load()))
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AdminEventService.registrationsTable, callback: (_) => unawaited(_load()))
          .subscribe();
    } catch (e) {
      debugPrint('AdminEventsPage: realtime subscribe failed: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    try {
      if (_channel != null) SupabaseConfig.client.removeChannel(_channel!);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _events
        : _events.where((e) {
            final title = (e['title'] ?? '').toString().toLowerCase();
            final place = (e['place'] ?? '').toString().toLowerCase();
            final id = (e['id'] ?? '').toString().toLowerCase();
            return title.contains(q) || place.contains(q) || id.contains(q);
          }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Events', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AdminCyberColors.text)),
                  const SizedBox(height: 4),
                  Text('Publier des événements officiels • ${filtered.length} event(s)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                ],
              ),
            ),
            SizedBox(
              width: 340,
              child: TextField(
                controller: _search,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
                decoration: InputDecoration(
                  hintText: 'Search title, place…',
                  hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminCyberColors.neonCyan),
                  filled: true,
                  fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                foregroundColor: AdminCyberColors.text,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
              label: const Text('Fetch Data'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.electricBlue, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => _openEditor(context, null),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : (_error != null)
                  ? Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)))
                  : (filtered.isEmpty)
                      ? Center(child: Text('Aucun événement.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _EventTile(
                            row: filtered[i],
                              documents: _docs,
                            onEdit: () => _openEditor(context, filtered[i]),
                            onDelete: () => _delete(context, filtered[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> row) async {
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminCyberColors.panel,
        title: Text('Supprimer', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
        content: Text('Supprimer cet événement ?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => context.pop(true), style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.danger, elevation: 0), child: const Text('Supprimer', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteEvent(id: id);
      unawaited(_load());
    } catch (e) {
      debugPrint('AdminEventsPage: delete failed err=$e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
    }
  }

  Future<void> _openEditor(BuildContext context, Map<String, dynamic>? row) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventEditor(initial: row, service: _svc),
    );
    if (saved == true) unawaited(_load());
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final DocumentService documents;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventTile({required this.row, required this.documents, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final title = (row['title'] ?? '—').toString();
    final place = (row['place'] ?? '—').toString();
    final startsAt = (row['starts_at'] ?? '').toString();
    final virtualLink = (row['virtual_link'] ?? '').toString();
    final status = (row['status'] ?? 'published').toString();
    final isFeatured = (row['is_featured'] == true) || (row['is_featured']?.toString() == 'true');
    final coverBucket = (row['cover_image_bucket'] ?? AdminEventService.coverBucketDefault).toString();
    final coverPath = (row['cover_image_path'] ?? '').toString();
    final availability = (row['availability_status'] ?? '').toString();
    final placesRemaining = row['places_remaining'];
    final registrationsCount = (row['registrations_count'] is num) ? (row['registrations_count'] as num).toInt() : int.tryParse((row['registrations_count'] ?? '').toString()) ?? 0;

    final soldOut = availability.toUpperCase() == 'SOLD OUT' || availability.toUpperCase() == 'COMPLET';
    final borderColor = soldOut
        ? AdminCyberColors.danger
        : (isFeatured ? Colors.amber : AdminCyberColors.stroke.withValues(alpha: 0.9));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AdminCyberColors.panel.withValues(alpha: 0.78),
        border: Border.all(color: borderColor, width: isFeatured || soldOut ? 1.4 : 1),
      ),
      child: Row(
        children: [
          _EventCoverThumb(bucket: coverBucket, storagePath: coverPath, documents: documents, isFeatured: isFeatured, soldOut: soldOut),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text))),
                    if (isFeatured) const SizedBox(width: 8),
                    if (isFeatured) const _TagBadge(label: 'Premium', icon: Icons.stars_rounded, color: Colors.amber),
                    if (soldOut) const SizedBox(width: 8),
                    if (soldOut) const _TagBadge(label: 'SOLD OUT', icon: Icons.block_rounded, color: AdminCyberColors.danger),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${startsAt.isEmpty ? '—' : startsAt} • $place${virtualLink.trim().isEmpty ? '' : ' • virtuel'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _Chip(icon: Icons.people_alt_rounded, label: '$registrationsCount inscrit(s)'),
                    if (placesRemaining != null) _Chip(icon: Icons.event_seat_rounded, label: _placesLabel(placesRemaining)),
                    _Chip(icon: Icons.circle, label: status, color: status == 'published' ? AdminCyberColors.success : AdminCyberColors.textDim),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(tooltip: 'Modifier', onPressed: onEdit, icon: const Icon(Icons.edit_rounded, color: AdminCyberColors.neonCyan)),
          IconButton(tooltip: 'Supprimer', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: AdminCyberColors.danger)),
        ],
      ),
    );
  }

  static String _placesLabel(Object? v) {
    if (v == null) return '';
    if (v is num) {
      if (v.toInt() <= 0) return 'Places illimitées';
      return '${v.toInt()} places restantes';
    }
    final s = v.toString().trim();
    final n = int.tryParse(s);
    if (n == null) return s;
    if (n <= 0) return 'Places illimitées';
    return '$n places restantes';
  }
}

class _TagBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _TagBadge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EventCoverThumb extends StatefulWidget {
  final String bucket;
  final String storagePath;
  final DocumentService documents;
  final bool isFeatured;
  final bool soldOut;
  const _EventCoverThumb({required this.bucket, required this.storagePath, required this.documents, required this.isFeatured, required this.soldOut});

  @override
  State<_EventCoverThumb> createState() => _EventCoverThumbState();
}

class _EventCoverThumbState extends State<_EventCoverThumb> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _EventCoverThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath || oldWidget.bucket != widget.bucket) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final p = widget.storagePath.trim();
    if (p.isEmpty) {
      if (mounted) setState(() => _url = null);
      return;
    }
    // Some schemas store a full URL instead of a Storage path.
    if (p.startsWith('http://') || p.startsWith('https://')) {
      if (mounted) setState(() => _url = p);
      return;
    }
    try {
      final url = await widget.documents.createDownloadUrl(storagePath: p, bucketName: widget.bucket.trim().isEmpty ? AdminEventService.coverBucketDefault : widget.bucket);
      if (!mounted) return;
      setState(() => _url = url);
    } catch (e) {
      debugPrint('_EventCoverThumb resolve failed bucket=${widget.bucket} path=${widget.storagePath} err=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.soldOut
        ? AdminCyberColors.danger
        : (widget.isFeatured ? Colors.amber : AdminCyberColors.stroke.withValues(alpha: 0.9));

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        color: AdminCyberColors.black.withValues(alpha: 0.18),
      ),
      clipBehavior: Clip.antiAlias,
      child: _url == null
          ? Container(
              decoration: BoxDecoration(gradient: AdminCyberGradients.glowViolet()),
              child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 20),
            )
          : Image.network(
              _url!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(gradient: AdminCyberGradients.glowViolet()),
                child: const Icon(Icons.broken_image_rounded, color: Colors.white, size: 20),
              ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Chip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AdminCyberColors.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: AdminCyberColors.black.withValues(alpha: 0.22), border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.7))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c)),
        ],
      ),
    );
  }
}

class _EventEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final AdminEventService service;
  const _EventEditor({required this.initial, required this.service});

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  final _docs = DocumentService();

  late final TextEditingController _title;
  late final TextEditingController _quickHook;
  late final TextEditingController _place;
  late final TextEditingController _virtualLink;
  late final TextEditingController _meetingLink;
  late final TextEditingController _organizer;
  late final TextEditingController _maxParticipants;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _highlights;
  late final TextEditingController _speakers;
  late final TextEditingController _sponsors;
  late final TextEditingController _agenda;

  DateTime _startsAt = DateTime.now().add(const Duration(days: 1));
  bool _featured = false;
  bool _isFree = true;
  String _category = 'Formation';
  String _eventType = 'En ligne';

  PlatformFile? _pickedCover;
  String? _coverBucket;
  String? _coverPath;
  String? _coverResolvedUrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: (widget.initial?['title'] ?? '').toString());
    _quickHook = TextEditingController(text: (widget.initial?['quick_hook'] ?? '').toString());
    _place = TextEditingController(text: (widget.initial?['place'] ?? '').toString());
    _virtualLink = TextEditingController(text: (widget.initial?['virtual_link'] ?? '').toString());
    _meetingLink = TextEditingController(text: (widget.initial?['meeting_link'] ?? '').toString());
    _organizer = TextEditingController(text: ((widget.initial?['organizer'] ?? '').toString().trim().isEmpty ? 'SONATHIX GROUP' : (widget.initial?['organizer'] ?? '').toString()));
    _maxParticipants = TextEditingController(text: (widget.initial?['max_participants'] ?? '0').toString());
    _price = TextEditingController(text: (widget.initial?['price'] ?? '').toString());
    _description = TextEditingController(text: (widget.initial?['description'] ?? '').toString());
    _highlights = TextEditingController(text: _linesFromJsonList(widget.initial?['highlights']));
    _speakers = TextEditingController(text: _linesFromJsonMapList(widget.initial?['speakers'], key: 'name'));
    _sponsors = TextEditingController(text: _linesFromJsonMapList(widget.initial?['sponsors'], key: 'name'));
    _agenda = TextEditingController(text: _agendaLines(widget.initial?['agenda']));

    _featured = (widget.initial?['is_featured'] == true) || (widget.initial?['is_featured']?.toString() == 'true');
    _isFree = (widget.initial?['is_free'] == true) || (widget.initial?['is_free']?.toString() == 'true') || (widget.initial?['price'] == null);
    final cat = (widget.initial?['category'] ?? '').toString().trim();
    if (cat.isNotEmpty) _category = cat;
    final rawType = (widget.initial?['event_type'] ?? '').toString().trim().toLowerCase();
    _eventType = switch (rawType) {
      'online' || 'en ligne' => 'En ligne',
      'physical' || 'physique' => 'Physique',
      'hybrid' || 'hybride' => 'Hybride',
      _ => 'En ligne',
    };

    _coverBucket = (widget.initial?['cover_image_bucket'] ?? AdminEventService.coverBucketDefault).toString();
    _coverPath = (widget.initial?['cover_image_path'] ?? '').toString().trim().isEmpty ? null : (widget.initial?['cover_image_path'] ?? '').toString();

    final raw = (widget.initial?['starts_at'] ?? '').toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) _startsAt = parsed.toLocal();

    unawaited(_resolveCoverUrl());
  }

  @override
  void dispose() {
    _title.dispose();
    _quickHook.dispose();
    _place.dispose();
    _virtualLink.dispose();
    _meetingLink.dispose();
    _organizer.dispose();
    _maxParticipants.dispose();
    _price.dispose();
    _description.dispose();
    _highlights.dispose();
    _speakers.dispose();
    _sponsors.dispose();
    _agenda.dispose();
    super.dispose();
  }

  static String _linesFromJsonList(Object? v) {
    if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join('\n');
    return '';
  }

  static String _linesFromJsonMapList(Object? v, {required String key}) {
    if (v is List) {
      return v.whereType<Map>().map((m) => (m[key] ?? '').toString()).where((s) => s.trim().isNotEmpty).join('\n');
    }
    return '';
  }

  static String _agendaLines(Object? v) {
    if (v is List) {
      return v.whereType<Map>().map((m) {
        final t = (m['time'] ?? '').toString().trim();
        final title = (m['title'] ?? '').toString().trim();
        if (t.isEmpty && title.isEmpty) return '';
        return t.isEmpty ? title : '$t | $title';
      }).where((s) => s.trim().isNotEmpty).join('\n');
    }
    return '';
  }

  Future<void> _resolveCoverUrl() async {
    final bucket = (_coverBucket ?? AdminEventService.coverBucketDefault).trim();
    final path = (_coverPath ?? '').trim();
    if (path.isEmpty) {
      if (mounted) setState(() => _coverResolvedUrl = null);
      return;
    }
    // Some schemas store a full URL instead of a Storage path.
    if (path.startsWith('http://') || path.startsWith('https://')) {
      if (mounted) setState(() => _coverResolvedUrl = path);
      return;
    }
    try {
      final url = await _docs.createDownloadUrl(storagePath: path, bucketName: bucket);
      if (!mounted) return;
      setState(() => _coverResolvedUrl = url);
    } catch (e) {
      debugPrint('_EventEditor resolve cover failed bucket=$bucket path=$path err=$e');
    }
  }

  Future<void> _pickCover() async {
    try {
      // IMPORTANT (Web): without withData=true, PlatformFile.bytes is null and uploads fail.
      final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'], withData: true, allowMultiple: false);
      if (res == null || res.files.isEmpty) return;
      setState(() {
        _pickedCover = res.files.first;
      });
    } catch (e) {
      debugPrint('AdminEventsPage: cover pick failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur sélection image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final maxW = MediaQuery.sizeOf(context).width < 720 ? double.infinity : 720.0;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final showMeetingLink = _eventType == 'En ligne' || _eventType == 'Hybride';

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.viewInsetsOf(context).bottom),
            decoration: BoxDecoration(color: AdminCyberColors.panelHi, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(isEdit ? 'Modifier Event' : 'Nouvel Event', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => context.pop(false), icon: const Icon(Icons.close_rounded, color: AdminCyberColors.textDim)),
                  ],
                ),
                const SizedBox(height: 12),
                _CoverField(
                  resolvedUrl: _coverResolvedUrl,
                  pickedFile: _pickedCover,
                  onPick: _saving ? null : _pickCover,
                ),
                const SizedBox(height: 12),

                _TwoCol(
                  wide: wide,
                  left: _Field(label: 'Titre', controller: _title, icon: Icons.mic_rounded),
                  right: _DropdownField(
                    label: 'Catégorie',
                    icon: Icons.category_rounded,
                    value: _category,
                    values: const ['Formation', 'Webinaire', 'Certification', 'Conférence'],
                    onChanged: _saving ? null : (v) => setState(() => _category = v),
                  ),
                ),
                const SizedBox(height: 10),

                _TwoCol(
                  wide: wide,
                  left: _LimitedField(label: 'Accroche Rapide (150 max)', controller: _quickHook, icon: Icons.bolt_rounded, maxChars: 150),
                  right: _SwitchField(label: 'Mettre à la une', icon: Icons.stars_rounded, value: _featured, onChanged: _saving ? null : (v) => setState(() => _featured = v)),
                ),
                const SizedBox(height: 10),

                _TwoCol(
                  wide: wide,
                  left: _DateTimeField(
                    value: _startsAt,
                    enabled: !_saving,
                    onChanged: (v) => setState(() => _startsAt = v),
                  ),
                  right: _SegmentedField(
                    label: "Type d'événement",
                    icon: Icons.public_rounded,
                    value: _eventType,
                    values: const ['En ligne', 'Physique', 'Hybride'],
                    onChanged: _saving ? null : (v) => setState(() => _eventType = v),
                  ),
                ),
                const SizedBox(height: 10),

                _TwoCol(
                  wide: wide,
                  left: _Field(label: 'Lieu', controller: _place, icon: Icons.map_rounded),
                  right: _Field(label: 'Lien virtuel (optionnel)', controller: _virtualLink, icon: Icons.link_rounded),
                ),

                if (showMeetingLink) ...[
                  const SizedBox(height: 10),
                  _Field(label: 'Lien de la réunion (Zoom/Meet)', controller: _meetingLink, icon: Icons.videocam_rounded),
                ],

                const SizedBox(height: 14),
                const _SectionDivider(title: 'Logistique'),
                const SizedBox(height: 12),

                _TwoCol(
                  wide: wide,
                  left: _Field(label: 'Organisé par', controller: _organizer, icon: Icons.apartment_rounded),
                  right: _Field(label: 'Nombre de places (0 = illimité)', controller: _maxParticipants, icon: Icons.event_seat_rounded, keyboardType: TextInputType.number),
                ),
                const SizedBox(height: 10),
                _TwoCol(
                  wide: wide,
                  left: _SwitchField(label: 'Événement Gratuit', icon: Icons.payments_rounded, value: _isFree, onChanged: _saving ? null : (v) => setState(() => _isFree = v)),
                  right: _isFree ? const SizedBox.shrink() : _Field(label: 'Prix (USD)', controller: _price, icon: Icons.attach_money_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ),
                const SizedBox(height: 14),

                const _SectionDivider(title: 'Contenu'),
                const SizedBox(height: 12),
                _MultilineField(label: 'Description', controller: _description, icon: Icons.subject_rounded, minLines: 4),
                const SizedBox(height: 10),
                _MultilineField(label: 'Highlights (1 ligne = 1 point)', controller: _highlights, icon: Icons.auto_awesome_rounded, minLines: 3),
                const SizedBox(height: 10),
                _MultilineField(label: 'Speakers (1 ligne = 1 nom)', controller: _speakers, icon: Icons.record_voice_over_rounded, minLines: 3),
                const SizedBox(height: 10),
                _MultilineField(label: 'Sponsors (1 ligne = 1 nom)', controller: _sponsors, icon: Icons.handshake_rounded, minLines: 2),
                const SizedBox(height: 10),
                _MultilineField(label: 'Agenda (format: 10:00 | Opening)', controller: _agenda, icon: Icons.view_agenda_rounded, minLines: 3),
                const SizedBox(height: 14),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.electricBlue, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, color: Colors.white),
                  label: Text(_saving ? 'Saving…' : (isEdit ? 'Save changes' : 'Publish'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final place = _place.text.trim();
    if (title.isEmpty || place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titre et lieu requis.')));
      return;
    }

    int parseIntSafe(String v) => int.tryParse(v.trim()) ?? 0;
    num? parseNumSafe(String v) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return num.tryParse(s.replaceAll(',', '.'));
    }

    final maxParticipants = parseIntSafe(_maxParticipants.text);
    final price = _isFree ? null : parseNumSafe(_price.text);

    setState(() => _saving = true);
    try {
      final eventId = await widget.service.upsertEvent(
        id: (widget.initial?['id'] ?? '').toString().trim().isEmpty ? null : (widget.initial?['id'] ?? '').toString().trim(),
        title: title,
        startsAt: _startsAt,
        place: place,
        virtualLink: _virtualLink.text,
        isFeatured: _featured,
        quickHook: _quickHook.text,
        category: _category,
        maxParticipants: maxParticipants,
        isFree: _isFree,
        price: price,
        eventType: _eventType == 'En ligne' ? 'online' : (_eventType == 'Physique' ? 'physical' : 'hybrid'),
        meetingLink: _meetingLink.text,
        organizer: _organizer.text,
        description: _description.text,
        highlights: _highlights.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false),
        speakers: _speakers.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((name) => {'name': name})
            .toList(growable: false),
        sponsors: _sponsors.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((name) => {'name': name})
            .toList(growable: false),
        agenda: _agenda.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((line) {
              final parts = line.split('|');
              if (parts.length >= 2) return {'time': parts[0].trim(), 'title': parts.sublist(1).join('|').trim()};
              return {'time': '', 'title': line};
            })
            .toList(growable: false),
      );

      final picked = _pickedCover;
      if (picked != null) {
        final uid = SupabaseConfig.client.auth.currentUser?.id ?? 'admin';
        final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
        final safeName = picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final objectPath = 'events/$eventId/cover_${ts}_$safeName';
        final bucket = AdminEventService.coverBucketDefault;
        final uploadedPath = await _docs.uploadPickedFileToBucket(bucketName: bucket, uid: uid, objectPath: objectPath, file: picked);
        await widget.service.updateCoverImage(eventId: eventId, bucket: bucket, storagePath: uploadedPath);
      }

      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      debugPrint('AdminEventsPage: save failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  const _Field({required this.label, required this.controller, required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
        prefixIcon: Icon(icon, color: AdminCyberColors.neonCyan),
        filled: true,
        fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2)),
      ),
    );
  }
}

class _MultilineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int minLines;
  const _MultilineField({required this.label, required this.controller, required this.icon, required this.minLines});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines + 4,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
        prefixIcon: Icon(icon, color: AdminCyberColors.neonCyan),
        filled: true,
        fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2)),
        alignLabelWithHint: true,
      ),
    );
  }
}

class _LimitedField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int maxChars;
  const _LimitedField({required this.label, required this.controller, required this.icon, required this.maxChars});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxChars,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
        prefixIcon: Icon(icon, color: AdminCyberColors.neonCyan),
        filled: true,
        fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2)),
      ),
    );
  }
}

class _SwitchField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchField({required this.label, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AdminCyberColors.neonCyan, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w700))),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: AdminCyberColors.neonCyan),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> values;
  final ValueChanged<String>? onChanged;
  const _DropdownField({required this.label, required this.icon, required this.value, required this.values, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: values.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(growable: false),
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? value),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
      dropdownColor: AdminCyberColors.panelHi,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
        prefixIcon: Icon(icon, color: AdminCyberColors.neonCyan),
        filled: true,
        fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2)),
      ),
    );
  }
}

class _SegmentedField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> values;
  final ValueChanged<String>? onChanged;
  const _SegmentedField({required this.label, required this.icon, required this.value, required this.values, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final set = values.toSet();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AdminCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AdminCyberColors.neonCyan, size: 20),
              const SizedBox(width: 10),
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: values.map((e) => ButtonSegment(value: e, label: Text(e))).toList(growable: false),
            selected: {value}.intersection(set),
            onSelectionChanged: onChanged == null
                ? null
                : (sel) {
                    final v = sel.isEmpty ? value : sel.first;
                    onChanged!(v);
                  },
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AdminCyberColors.electricBlue.withValues(alpha: 0.25) : Colors.transparent),
              foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AdminCyberColors.text : AdminCyberColors.textDim),
              side: WidgetStateProperty.all(BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.7))),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;
  const _DateTimeField({required this.value, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        foregroundColor: AdminCyberColors.text,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AdminCyberColors.panel.withValues(alpha: 0.48),
      ),
      onPressed: !enabled
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: value,
              );
              if (picked == null) return;
              if (!context.mounted) return;
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
              if (t == null) return;
              onChanged(DateTime(picked.year, picked.month, picked.day, t.hour, t.minute));
            },
      icon: const Icon(Icons.calendar_month_rounded, color: AdminCyberColors.neonCyan),
      label: Text('Date/Heure: ${value.toString()}', style: const TextStyle(color: AdminCyberColors.text)),
    );
  }
}

class _TwoCol extends StatelessWidget {
  final bool wide;
  final Widget left;
  final Widget right;
  const _TwoCol({required this.wide, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          left,
          const SizedBox(height: 10),
          right,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String title;
  const _SectionDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AdminCyberColors.stroke.withValues(alpha: 0.55))),
        const SizedBox(width: 12),
        Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AdminCyberColors.textDim, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: AdminCyberColors.stroke.withValues(alpha: 0.55))),
      ],
    );
  }
}

class _CoverField extends StatelessWidget {
  final String? resolvedUrl;
  final PlatformFile? pickedFile;
  final VoidCallback? onPick;
  const _CoverField({required this.resolvedUrl, required this.pickedFile, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final border = AdminCyberColors.stroke.withValues(alpha: 0.9);
    final url = resolvedUrl;
    final picked = pickedFile;

    Widget preview;
    if (picked != null && picked.bytes != null) {
      preview = Image.memory(picked.bytes!, fit: BoxFit.cover);
    } else if (url != null && url.trim().isNotEmpty) {
      preview = Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: AdminCyberColors.textDim));
    } else {
      preview = Container(
        decoration: BoxDecoration(gradient: AdminCyberGradients.glowViolet()),
        child: const Center(child: Icon(Icons.image_rounded, color: Colors.white, size: 28)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 88, height: 56, child: preview)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image de couverture', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(picked?.name ?? 'PNG/JPG/WebP recommandé (thumbnail dans la liste).', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
              foregroundColor: AdminCyberColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onPick,
            icon: const Icon(Icons.upload_rounded, color: AdminCyberColors.neonCyan),
            label: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}
