import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'package:thix_id/models/news_item.dart';
import 'package:thix_id/services/admin_rbac_service.dart';
import 'package:thix_id/services/news_service.dart';
import 'package:thix_id/theme.dart';

class AdminNewsPage extends StatefulWidget {
  const AdminNewsPage({super.key, required this.role});
  final String role;

  @override
  State<AdminNewsPage> createState() => _AdminNewsPageState();
}

class _AdminNewsPageState extends State<AdminNewsPage> {
  final _service = NewsService();
  bool _loading = true;
  String? _error;
  List<NewsItem> _items = const [];

  bool get _canCreate => AdminRbacService.canAccess(role: widget.role, minLevel: 5);
  bool get _canManage => AdminRbacService.canAccess(role: widget.role, minLevel: 5);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.listNews(limit: 200);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      debugPrint('AdminNewsPage: load failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUpsert({NewsItem? initial}) async {
    if (!_canManage) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpsertNewsSheet(initial: initial),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(NewsItem item) async {
    if (!_canManage) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminCyberColors.panel,
        title: Text('Supprimer', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
        content: Text('Supprimer cette publication ?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.danger, elevation: 0),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteNews(id: item.id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      debugPrint('AdminNewsPage: delete failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(onRefresh: _load, count: _items.length),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : (_error != null)
                      ? _ErrorState(error: _error!, onRetry: _load)
                    : _List(
                        items: _items,
                        canManage: _canManage,
                        onEdit: (item) => _openUpsert(initial: item),
                        onDelete: _delete,
                      ),
            ),
          ],
        ),
        if (_canCreate)
          Positioned(
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: FloatingActionButton.extended(
                heroTag: 'create_news_fab',
                backgroundColor: AdminCyberColors.electricBlue,
                foregroundColor: Colors.white,
                onPressed: () => _openUpsert(initial: null),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text('Publier une info'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  final int count;
  const _Header({required this.onRefresh, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Info / News', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AdminCyberColors.text)),
              const SizedBox(height: 4),
              Text('Source: ${NewsService.table} • $count publication(s)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
            ],
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            foregroundColor: AdminCyberColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
          label: const Text('Fetch Data'),
        ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  final List<NewsItem> items;
  final bool canManage;
  final ValueChanged<NewsItem> onEdit;
  final ValueChanged<NewsItem> onDelete;
  const _List({required this.items, required this.canManage, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('Aucune publication.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _Tile(item: items[i], canManage: canManage, onEdit: onEdit, onDelete: onDelete),
    );
  }
}

class _Tile extends StatelessWidget {
  final NewsItem item;
  final bool canManage;
  final ValueChanged<NewsItem> onEdit;
  final ValueChanged<NewsItem> onDelete;
  const _Tile({required this.item, required this.canManage, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AdminCyberColors.panel.withValues(alpha: 0.78),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 46,
              height: 46,
              child: (item.imageUrl != null && item.imageUrl!.startsWith('http'))
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(gradient: AdminCyberGradients.glowBlue()),
                      child: const Icon(Icons.campaign_rounded, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (item.featured) _Pill(text: 'À la une', color: AdminCyberColors.neonCyan),
                    if (canManage) ...[
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        tooltip: 'Actions',
                        color: AdminCyberColors.panelHi,
                        icon: const Icon(Icons.more_horiz_rounded, color: AdminCyberColors.textDim),
                        onSelected: (v) {
                          if (v == 'edit') onEdit(item);
                          if (v == 'delete') onDelete(item);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Modifier')),
                          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _Pill(text: item.category, color: AdminCyberColors.neonViolet),
                    _Pill(text: item.source, color: AdminCyberColors.stroke),
                    _Pill(text: item.severity, color: AdminCyberColors.electricBlue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
        color: color.withValues(alpha: 0.10),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.text)),
    );
  }
}

class _UpsertNewsSheet extends StatefulWidget {
  const _UpsertNewsSheet({required this.initial});

  final NewsItem? initial;

  @override
  State<_UpsertNewsSheet> createState() => _UpsertNewsSheetState();
}

class _UpsertNewsSheetState extends State<_UpsertNewsSheet> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _source = TextEditingController(text: 'THIX');
  String? _uploadedImageUrl;
  Uint8List? _pickedImageBytes;
  bool _uploadingImage = false;
  String _category = 'Actualités';
  String _severity = 'Info';
  bool _featured = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _title.text = i.title;
      _subtitle.text = i.subtitle;
      _source.text = i.source;
      _uploadedImageUrl = i.imageUrl;
      _category = i.category;
      _severity = i.severity;
      _featured = i.featured;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _error = null);
    try {
      final res = await FilePicker.pickFiles(type: FileType.image, withData: true, allowMultiple: false);
      if (res == null || res.files.isEmpty) return;
      final file = res.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = "Impossible de lire l'image sélectionnée.");
        return;
      }

      setState(() {
        _pickedImageBytes = bytes;
        _uploadingImage = true;
      });

      final ext = (file.extension ?? 'jpg').toLowerCase();
      final url = await NewsService().uploadNewsImage(bytes: bytes, extension: ext);
      if (!mounted) return;
      setState(() => _uploadedImageUrl = url);
    } catch (e) {
      debugPrint('CreateNewsSheet: image upload failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _removeImage() {
    setState(() {
      _uploadedImageUrl = null;
      _pickedImageBytes = null;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Le titre est obligatoire.');
      return;
    }
    if (_uploadingImage) {
      setState(() => _error = "Upload de l'image en cours… réessaie dans 1 seconde.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final now = DateTime.now();
    final existing = widget.initial;
    final item = NewsItem(
      id: existing?.id ?? 'tmp',
      title: title,
      subtitle: _subtitle.text.trim(),
      source: _source.text.trim().isEmpty ? 'THIX' : _source.text.trim(),
      category: _category,
      severity: _severity,
      featured: _featured,
      imageUrl: _uploadedImageUrl,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final svc = NewsService();
      if (_isEdit) {
        await svc.updateNews(id: item.id, item: item);
      } else {
        await svc.createNews(item);
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      debugPrint('CreateNewsSheet: insert failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
          color: AdminCyberColors.panel.withValues(alpha: 0.92),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_isEdit ? 'Modifier une info' : 'Publier une info', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AdminCyberColors.text))),
                IconButton(onPressed: () => context.pop(false), icon: const Icon(Icons.close_rounded, color: AdminCyberColors.textDim)),
              ],
            ),
            const SizedBox(height: 10),
            _Field(controller: _title, label: 'Titre *', icon: Icons.title_rounded),
            const SizedBox(height: 10),
            _Field(controller: _subtitle, label: 'Contenu / résumé', icon: Icons.subject_rounded, maxLines: 4),
            const SizedBox(height: 10),
            _Field(controller: _source, label: 'Source', icon: Icons.apartment_rounded),
            const SizedBox(height: 10),
            _ImageUploadCard(
              uploading: _uploadingImage,
              pickedBytes: _pickedImageBytes,
              uploadedUrl: _uploadedImageUrl,
              onPickUpload: _pickAndUploadImage,
              onRemove: _removeImage,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Dropdown(label: 'Catégorie', value: _category, onChanged: (v) => setState(() => _category = v), items: const ['Actualités', 'Sécurité', 'Institution', 'Alerte', 'Événements'])),
                const SizedBox(width: 10),
                Expanded(child: _Dropdown(label: 'Sévérité', value: _severity, onChanged: (v) => setState(() => _severity = v), items: const ['Info', 'Important', 'Critique'])),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              value: _featured,
              onChanged: (v) => setState(() => _featured = v),
              title: Text('Mettre à la une', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text)),
              subtitle: Text('Affiché en haut dans THIX INFO', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
              activeColor: AdminCyberColors.neonCyan,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.danger)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AdminCyberColors.electricBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.publish_rounded, color: Colors.white),
                label: Text(_isEdit ? 'Enregistrer' : 'Publier'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Table attendue: ${NewsService.table}. Si insert/select bloque: vérifie RLS (SUPER_ADMIN) + colonnes NOT NULL.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  const _Field({required this.controller, required this.label, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
        prefixIcon: Icon(icon, color: AdminCyberColors.neonCyan),
        filled: true,
        fillColor: AdminCyberColors.black.withValues(alpha: 0.22),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> items;
  const _Dropdown({required this.label, required this.value, required this.onChanged, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AdminCyberColors.black.withValues(alpha: 0.22),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: AdminCyberColors.neonCyan, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim))),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: AdminCyberColors.panel,
              iconEnabledColor: AdminCyberColors.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(growable: false),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageUploadCard extends StatelessWidget {
  final bool uploading;
  final Uint8List? pickedBytes;
  final String? uploadedUrl;
  final VoidCallback onPickUpload;
  final VoidCallback onRemove;

  const _ImageUploadCard({
    required this.uploading,
    required this.pickedBytes,
    required this.uploadedUrl,
    required this.onPickUpload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasImage = pickedBytes != null || (uploadedUrl != null && uploadedUrl!.trim().isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        color: AdminCyberColors.black.withValues(alpha: 0.22),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 52,
              height: 52,
              color: AdminCyberColors.panel,
              child: uploading
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : (pickedBytes != null
                      ? Image.memory(pickedBytes!, fit: BoxFit.cover)
                      : const Icon(Icons.image_rounded, color: AdminCyberColors.textDim)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Photo (optionnel)', style: textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text)),
                const SizedBox(height: 2),
                Text(
                  uploading
                      ? "Téléversement en cours…"
                      : (uploadedUrl != null && uploadedUrl!.trim().isNotEmpty)
                          ? 'Upload OK (visible dans l’app)'
                          : 'Télécharge une photo au lieu de coller une URL',
                  style: textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (hasImage && !uploading)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, color: AdminCyberColors.textDim),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AdminCyberColors.electricBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: uploading ? null : onPickUpload,
            icon: Icon(hasImage ? Icons.swap_horiz_rounded : Icons.cloud_upload_rounded, color: Colors.white, size: 18),
            label: Text(hasImage ? 'Changer' : 'Télécharger'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            color: AdminCyberColors.panel.withValues(alpha: 0.78),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supabase error', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
              const SizedBox(height: 8),
              Text(error, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim, height: 1.4)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                  foregroundColor: AdminCyberColors.text,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
