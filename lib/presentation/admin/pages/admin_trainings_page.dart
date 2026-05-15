import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/admin_training_service.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/theme.dart';

class AdminTrainingsPage extends StatefulWidget {
  const AdminTrainingsPage({super.key});

  @override
  State<AdminTrainingsPage> createState() => _AdminTrainingsPageState();
}

class _AdminTrainingsPageState extends State<AdminTrainingsPage> {
  final _svc = AdminTrainingService();
  final _docs = DocumentService();
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listTrainings();
      if (!mounted) return;
      setState(() => _rows = list);
    } catch (e) {
      debugPrint('AdminTrainingsPage: load failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    try {
      _channel = SupabaseConfig.client.channel('admin:trainings');
      _channel!
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AdminTrainingService.trainingsTable, callback: (_) => unawaited(_load()))
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AdminTrainingService.lessonsTable, callback: (_) => unawaited(_load()))
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AdminTrainingService.enrollmentsTable, callback: (_) => unawaited(_load()))
          .subscribe();
    } catch (e) {
      debugPrint('AdminTrainingsPage: realtime subscribe failed err=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _rows
        : _rows.where((r) {
            final id = (r['id'] ?? '').toString().toLowerCase();
            final title = (r['title'] ?? '').toString().toLowerCase();
            final cat = (r['category'] ?? '').toString().toLowerCase();
            return id.contains(q) || title.contains(q) || cat.contains(q);
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
                  Text('Trainings / Formations', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AdminCyberColors.text)),
                  const SizedBox(height: 4),
                  Text('Publish courses • manage featured & pricing • ${filtered.length} training(s)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                ],
              ),
            ),
            SizedBox(
              width: 340,
              child: TextField(
                controller: _search,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
                decoration: InputDecoration(
                  hintText: 'Search title, category…',
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
              label: const Text('New Training', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
                      ? Center(child: Text('No trainings.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _TrainingTile(row: filtered[i], docs: _docs, onEdit: () => _openEditor(context, filtered[i]), onDelete: () => _delete(context, filtered[i])),
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
        title: Text('Delete Training', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
        content: Text('Delete this training?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => context.pop(true), style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.danger, elevation: 0), child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteTraining(id: id);
      unawaited(_load());
    } catch (e) {
      debugPrint('AdminTrainingsPage: delete failed err=$e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _openEditor(BuildContext context, Map<String, dynamic>? row) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrainingEditor(initial: row, service: _svc, documents: _docs),
    );
    if (saved == true) unawaited(_load());
  }
}

class _TrainingTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final DocumentService docs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TrainingTile({required this.row, required this.docs, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final title = (row['title'] ?? '—').toString();
    final category = (row['category'] ?? 'General').toString();
    final isFeatured = row['is_featured'] == true;
    final isPublished = row['is_published'] == true;
    final students = (row['students_count'] ?? 0).toString();
    final rating = (row['rating'] ?? 0).toString();
    final coverBucket = (row['cover_image_bucket'] ?? '').toString();
    final coverPath = (row['cover_image_path'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: AdminCyberColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: ListTile(
        leading: _CoverThumb(bucket: coverBucket, path: coverPath, docs: docs),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
        subtitle: Text('$category • ⭐ $rating • $students students', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFeatured) _Pill(label: 'Featured', color: AdminCyberColors.neonCyan.withValues(alpha: 0.22), border: AdminCyberColors.neonCyan),
            if (!isFeatured) _Pill(label: 'Standard', color: AdminCyberColors.panelHi.withValues(alpha: 0.6), border: AdminCyberColors.stroke),
            const SizedBox(width: 10),
            _Pill(label: isPublished ? 'Published' : 'Draft', color: isPublished ? AdminCyberColors.success.withValues(alpha: 0.18) : AdminCyberColors.danger.withValues(alpha: 0.16), border: isPublished ? AdminCyberColors.success : AdminCyberColors.danger),
            const SizedBox(width: 10),
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, color: AdminCyberColors.neonCyan)),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: AdminCyberColors.danger)),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _CoverThumb extends StatefulWidget {
  final String bucket;
  final String path;
  final DocumentService docs;
  const _CoverThumb({required this.bucket, required this.path, required this.docs});

  @override
  State<_CoverThumb> createState() => _CoverThumbState();
}

class _CoverThumbState extends State<_CoverThumb> {
  String? _url;

  @override
  void didUpdateWidget(covariant _CoverThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bucket != widget.bucket || oldWidget.path != widget.path) {
      _url = null;
      unawaited(_resolve());
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    if (widget.bucket.trim().isEmpty || widget.path.trim().isEmpty) return;
    try {
      final url = await widget.docs.createDownloadUrl(bucketName: widget.bucket.trim(), storagePath: widget.path.trim(), expiresIn: const Duration(minutes: 10));
      if (!mounted) return;
      setState(() => _url = url);
    } catch (e) {
      debugPrint('AdminTrainingsPage: resolve cover failed err=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AdminCyberColors.electricBlue, AdminCyberColors.neonCyan]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _url == null
            ? const Icon(Icons.school_rounded, color: Colors.white)
            : Image.network(_url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: Colors.white)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color border;
  const _Pill({required this.label, required this.color, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999), border: Border.all(color: border.withValues(alpha: 0.8))),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
    );
  }
}

class _TrainingEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final AdminTrainingService service;
  final DocumentService documents;
  const _TrainingEditor({required this.initial, required this.service, required this.documents});

  @override
  State<_TrainingEditor> createState() => _TrainingEditorState();
}

class _TrainingEditorState extends State<_TrainingEditor> {
  final _title = TextEditingController();
  final _tagline = TextEditingController();
  final _desc = TextEditingController();
  final _skills = TextEditingController();
  final _requirements = TextEditingController();
  final _duration = TextEditingController();
  final _price = TextEditingController();
  String _category = 'Cybersecurity';
  String _level = 'Beginner';
  String _language = 'FR';
  String _mode = 'online';
  bool _isFree = false;
  bool _cert = true;
  bool _featured = false;
  bool _published = true;
  bool _saving = false;

  String? _coverBucket;
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    final row = widget.initial;
    if (row != null) {
      _title.text = (row['title'] ?? '').toString();
      _tagline.text = (row['tagline'] ?? '').toString();
      _desc.text = (row['description'] ?? '').toString();
      _skills.text = (row['skills'] is List) ? (row['skills'] as List).join(', ') : (row['skills'] ?? '').toString();
      _requirements.text = (row['requirements'] ?? '').toString();
      _duration.text = (row['duration_minutes'] ?? '').toString();
      _price.text = (row['price_amount'] ?? '').toString();
      _category = (row['category'] ?? _category).toString();
      _level = (row['level'] ?? _level).toString();
      _language = (row['language'] ?? _language).toString();
      _mode = (row['delivery_mode'] ?? _mode).toString();
      _isFree = row['is_free'] == true;
      _cert = row['certification_included'] != false;
      _featured = row['is_featured'] == true;
      _published = row['is_published'] != false;
      _coverBucket = (row['cover_image_bucket'] ?? '').toString().trim().isEmpty ? null : (row['cover_image_bucket'] ?? '').toString();
      _coverPath = (row['cover_image_path'] ?? '').toString().trim().isEmpty ? null : (row['cover_image_path'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _tagline.dispose();
    _desc.dispose();
    _skills.dispose();
    _requirements.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  static List<String> _splitSkills(String raw) => raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);

  Future<void> _pickCover(String trainingId) async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image, withData: kIsWeb);
      if (res == null || res.files.isEmpty) return;
      setState(() => _saving = true);
      final f = res.files.first;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final safeName = f.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final objectPath = 'trainings/$trainingId/covers/${ts}_$safeName';
      final bucket = AdminTrainingService.coverBucketDefault;
      final uploadedPath = await widget.documents.uploadPickedFileToBucket(bucketName: bucket, uid: trainingId, objectPath: objectPath, file: f);
      await widget.service.updateCoverImage(trainingId: trainingId, bucket: bucket, storagePath: uploadedPath);
      if (!mounted) return;
      setState(() {
        _coverBucket = bucket;
        _coverPath = uploadedPath;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover uploaded.')));
    } catch (e) {
      debugPrint('AdminTrainingsPage: pick cover failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final id = (widget.initial?['id'] ?? '').toString().trim();
      final duration = int.tryParse(_duration.text.trim());
      final price = num.tryParse(_price.text.trim());
      final trainingId = await widget.service.upsertTraining(
        id: id.isEmpty ? null : id,
        title: title,
        tagline: _tagline.text.trim(),
        description: _desc.text.trim(),
        category: _category,
        level: _level,
        language: _language,
        deliveryMode: _mode,
        durationMinutes: duration,
        isFree: _isFree,
        priceAmount: _isFree ? 0 : price,
        currency: 'USD',
        certificationIncluded: _cert,
        isFeatured: _featured,
        isPublished: _published,
        requirements: _requirements.text.trim(),
        skills: _splitSkills(_skills.text),
        coverImageBucket: _coverBucket,
        coverImagePath: _coverPath,
      );
      if (!mounted) return;
      // If there is no cover yet, prompt user to upload quickly.
      if ((_coverPath ?? '').trim().isEmpty) {
        unawaited(_pickCover(trainingId));
      }
      context.pop(true);
    } catch (e) {
      debugPrint('AdminTrainingsPage: save failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = ((widget.initial?['id'] ?? '').toString().trim().isNotEmpty);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AdminCyberColors.black,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl)),
          border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(isEdit ? 'Edit Training' : 'New Training', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => context.pop(false), icon: const Icon(Icons.close_rounded, color: AdminCyberColors.textDim)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Field(label: 'Title', controller: _title),
              const SizedBox(height: 10),
              _Field(label: 'Tagline (150 max)', controller: _tagline, maxLines: 2),
              const SizedBox(height: 10),
              _Field(label: 'Description', controller: _desc, maxLines: 5),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Dropdown(label: 'Category', value: _category, items: const [
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
                    'Soft Skills'
                  ], onChanged: (v) => setState(() => _category = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _Dropdown(label: 'Level', value: _level, items: const ['Beginner', 'Intermediate', 'Advanced'], onChanged: (v) => setState(() => _level = v))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Dropdown(label: 'Language', value: _language, items: const ['FR', 'EN'], onChanged: (v) => setState(() => _language = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _Dropdown(label: 'Mode', value: _mode, items: const ['online', 'physical', 'hybrid'], onChanged: (v) => setState(() => _mode = v))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Field(label: 'Duration (minutes)', controller: _duration, keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(label: 'Price (USD)', controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), enabled: !_isFree),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Field(label: 'Skills (comma separated)', controller: _skills, maxLines: 2),
              const SizedBox(height: 10),
              _Field(label: 'Requirements', controller: _requirements, maxLines: 3),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _Switch(label: 'Free', value: _isFree, onChanged: (v) => setState(() => _isFree = v)),
                  _Switch(label: 'Certificate', value: _cert, onChanged: (v) => setState(() => _cert = v)),
                  _Switch(label: 'Featured', value: _featured, onChanged: (v) => setState(() => _featured = v)),
                  _Switch(label: 'Published', value: _published, onChanged: (v) => setState(() => _published = v)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.electricBlue, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(isEdit ? 'Save Changes' : 'Create Training', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            final id = (widget.initial?['id'] ?? '').toString().trim();
                            if (id.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save first, then upload cover.')));
                              return;
                            }
                            unawaited(_pickCover(id));
                          },
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AdminCyberColors.stroke), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14)),
                    icon: const Icon(Icons.image_rounded, color: AdminCyberColors.neonCyan),
                    label: const Text('Cover', style: TextStyle(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Cover: ${(_coverBucket ?? '-')}:${(_coverPath ?? '-')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool enabled;
  const _Field({required this.label, required this.controller, this.maxLines = 1, this.keyboardType, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
        filled: true,
        fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.neonCyan, width: 1.2)),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AdminCyberColors.panelHi,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
        filled: true,
        fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.neonCyan, width: 1.2)),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(growable: false),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }
}

class _Switch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AdminCyberColors.panel.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(16), border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AdminCyberColors.neonCyan,
            inactiveThumbColor: AdminCyberColors.textDim,
            inactiveTrackColor: AdminCyberColors.panelHi.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
