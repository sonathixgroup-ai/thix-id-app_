import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/presentation/common/date_picker_field.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/verification_status.dart';
import 'package:thix_id/presentation/common/upload_document_preview.dart';
import 'package:thix_id/theme.dart';

/// Bottom-sheet to add/edit the user's professional trainings (Formations).
///
/// Reused from multiple places (Dashboard + Public Profile when owner).
class TrainingsEditorSheet {
  static Future<void> show(BuildContext context, {required ThixProfile profile, required ProfileService profileService}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrainingsEditorBody(profile: profile, profileService: profileService),
    );
  }
}

class _TrainingsEditorBody extends StatefulWidget {
  final ThixProfile profile;
  final ProfileService profileService;
  const _TrainingsEditorBody({required this.profile, required this.profileService});

  @override
  State<_TrainingsEditorBody> createState() => _TrainingsEditorBodyState();
}

class _TrainingsEditorBodyState extends State<_TrainingsEditorBody> {
  final _nameC = TextEditingController();
  final _skillsC = TextEditingController();
  String? _type;
  final _durationC = TextEditingController();
  final _startC = TextEditingController();
  final _endC = TextEditingController();
  final _orgC = TextEditingController();
  final _descC = TextEditingController();
  List<EvidenceFileRef> _evidence = const [];
  bool _saving = false;
  int? _editingIndex;
  final _docs = DocumentService();

  ({String bucket, String path})? _parseBucketPath(String storagePathOrUrl) {
    final v = storagePathOrUrl.trim();
    final idx = v.indexOf(':');
    if (idx <= 0) return null;
    final bucket = v.substring(0, idx).trim();
    final path = v.substring(idx + 1).trim();
    if (bucket.isEmpty || path.isEmpty) return null;
    return (bucket: bucket, path: path);
  }

  static String _sanitizeObjectName(String name) => name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  @override
  void dispose() {
    _nameC.dispose();
    _skillsC.dispose();
    _durationC.dispose();
    _startC.dispose();
    _endC.dispose();
    _orgC.dispose();
    _descC.dispose();
    super.dispose();
  }

  void _loadForEdit(int index, Map<String, dynamic> entry) {
    final rawEvidence = (entry['evidence'] as List?) ?? const [];
    final parsed = rawEvidence.map(EvidenceFileRef.tryParse).whereType<EvidenceFileRef>().toList(growable: false);
    setState(() {
      _editingIndex = index;
      _nameC.text = (entry['name'] as String?) ?? (entry['title'] as String?) ?? '';
      _skillsC.text = (entry['skills'] as String?) ?? (entry['skills_acquired'] as String?) ?? '';
      _type = (entry['type'] as String?) ?? '';
      _durationC.text = (entry['duration'] as String?) ?? '';
      _startC.text = (entry['start_date'] as String?) ?? (entry['start'] as String?) ?? '';
      _endC.text = (entry['end_date'] as String?) ?? (entry['end'] as String?) ?? '';
      _orgC.text = (entry['organized_by'] as String?) ?? (entry['provider'] as String?) ?? '';
      _descC.text = (entry['description'] as String?) ?? (entry['details'] as String?) ?? '';
      _evidence = parsed;
    });
  }

  void _resetForm() {
    setState(() {
      _editingIndex = null;
      _nameC.clear();
      _skillsC.clear();
      _type = null;
      _durationC.clear();
      _startC.clear();
      _endC.clear();
      _orgC.clear();
      _descC.clear();
      _evidence = const [];
    });
  }

  Future<void> _pickEvidenceFiles() async {
    try {
      // Photos only.
      final res = await FilePicker.pickFiles(allowMultiple: true, withData: kIsWeb, type: FileType.custom, allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp']);
      if (res == null || res.files.isEmpty) return;
      if (!mounted) return;
      setState(() => _saving = true);
      final uid = widget.profile.userId;
      final uploaded = <EvidenceFileRef>[];
      for (final f in res.files) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final safeName = _sanitizeObjectName(f.name);
        final objectPath = 'users/$uid/trainings/${ts}_$safeName';
        try {
          final uploadedPath = await _docs.uploadPickedFileToBucket(bucketName: 'certificates', uid: uid, objectPath: objectPath, file: f);
          uploaded.add(EvidenceFileRef(storagePathOrUrl: 'certificates:$uploadedPath', label: f.name));
        } catch (e) {
          // Fallback: some projects use a different credentials bucket.
          if (DocumentService.isBucketNotFound(e)) {
            final fallbackBucket = ProfileService.credentialsBucket;
            final uploadedPath = await _docs.uploadPickedFileToBucket(bucketName: fallbackBucket, uid: uid, objectPath: objectPath, file: f);
            uploaded.add(EvidenceFileRef(storagePathOrUrl: '$fallbackBucket:$uploadedPath', label: f.name));
          } else {
            rethrow;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _evidence = [..._evidence, ...uploaded];
      });
    } catch (e) {
      debugPrint('TrainingsEditor: pick evidence failed err=$e');
      if (!mounted) return;
      final msg = DocumentService.isBucketNotFound(e)
          ? 'Upload impossible: bucket Storage manquant ("certificates" / "${ProfileService.credentialsBucket}").'
          : 'Ajout de pièces impossible.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save(List<Map<String, dynamic>> existing) async {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom de formation requis.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final next = [...existing];
      final patch = {
        'name': name,
        'skills_acquired': _skillsC.text.trim(),
        'type': (_type ?? '').trim(),
        'duration': _durationC.text.trim(),
        'start_date': _startC.text.trim(),
        'end_date': _endC.text.trim(),
        'organized_by': _orgC.text.trim(),
        'description': _descC.text.trim(),
        // For user edits, status is always pending (admin will verify).
        'verification_status': VerificationStatus.pending.value,
        'evidence': _evidence.map((e) => e.toJson()).toList(growable: false),
      };
      if (_editingIndex != null && _editingIndex! >= 0 && _editingIndex! < next.length) {
        next[_editingIndex!] = patch;
      } else {
        next.add(patch);
      }
      await widget.profileService.updateProfile(userId: widget.profile.userId, trainings: next);
      if (!mounted) return;
      final wasEdit = _editingIndex != null;
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wasEdit ? 'Formation mise à jour.' : 'Formation ajoutée.')));
    } catch (e) {
      debugPrint('TrainingsEditor: save failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sauvegarde impossible.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(List<Map<String, dynamic>> existing, int index) async {
    if (index < 0 || index >= existing.length) return;
    setState(() => _saving = true);
    try {
      final next = [...existing]..removeAt(index);
      await widget.profileService.updateProfile(userId: widget.profile.userId, trainings: next);
      if (!mounted) return;
      if (_editingIndex == index) _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formation supprimée.')));
    } catch (e) {
      debugPrint('TrainingsEditor: delete failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suppression impossible.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl)),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: StreamBuilder<ThixProfile?>(
            stream: widget.profileService.streamMyProfile(widget.profile.userId),
            builder: (context, snap) {
              final existing = (snap.data ?? widget.profile).trainings;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_editingIndex == null ? 'Ajouter une formation' : 'Modifier une formation', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (existing.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Vos formations', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: AppSpacing.sm),
                        ...List.generate(existing.length, (i) {
                          final e = existing[i];
                          final name = (e['name'] as String?) ?? (e['title'] as String?) ?? '—';
                          final type = (e['type'] as String?) ?? '';
                          final period = [(e['start_date'] as String?) ?? '', (e['end_date'] as String?) ?? ''].where((v) => v.trim().isNotEmpty).join(' → ');
                          final subtitle = [type, period].where((v) => v.trim().isNotEmpty).join(' • ');
                          final selected = _editingIndex == i;
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: selected ? LightModeColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: selected ? LightModeColors.accent : Theme.of(context).dividerColor),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(name, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                              subtitle: subtitle.trim().isEmpty ? null : Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
                              onTap: _saving ? null : () => _loadForEdit(i, e),
                              trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: LightModeColors.error), onPressed: _saving ? null : () => _delete(existing, i)),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                if (existing.isNotEmpty) const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _nameC,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Nom de formation', prefixIcon: const Icon(Icons.school_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _skillsC,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Compétences acquises', prefixIcon: const Icon(Icons.psychology_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _descC,
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Détails / description', prefixIcon: const Icon(Icons.notes_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: Theme.of(context).dividerColor)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.attachment_rounded, size: 18, color: LightModeColors.secondaryText),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Pièces obtenues', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _pickEvidenceFiles,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Ajouter'),
                            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_evidence.isEmpty)
                        Text('Aucune pièce ajoutée.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _evidence.map((e) {
                            final label = (e.label ?? '').trim().isEmpty ? e.storagePathOrUrl : e.label!.trim();
                            final parsed = _parseBucketPath(e.storagePathOrUrl);
                            if (parsed == null) {
                              return UploadDocumentPreview(
                                bucketName: DocumentService.bucket,
                                storagePath: e.storagePathOrUrl,
                                fileName: label,
                                label: label,
                                onDelete: _saving
                                    ? null
                                    : () async {
                                        setState(() => _evidence = _evidence.where((x) => x != e).toList(growable: false));
                                      },
                              );
                            }
                            return UploadDocumentPreview(
                              bucketName: parsed.bucket,
                              storagePath: parsed.path,
                              fileName: (e.label ?? '').trim().isEmpty ? parsed.path.split('/').last : e.label!.trim(),
                              label: (e.label ?? '').trim().isEmpty ? 'Pièce' : e.label!.trim(),
                              onDelete: _saving
                                  ? null
                                  : () async {
                                      try {
                                        await _docs.deleteObjectFromBucket(bucketName: parsed.bucket, storagePath: parsed.path);
                                      } catch (err) {
                                        debugPrint('TrainingsEditor: evidence delete failed err=$err');
                                      }
                                      if (!mounted) return;
                                      setState(() => _evidence = _evidence.where((x) => x != e).toList(growable: false));
                                    },
                            );
                          }).toList(growable: false),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: (_type ?? '').trim().isEmpty ? null : _type,
                  items: const ['Présentiel', 'En ligne'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(growable: false),
                  onChanged: _saving ? null : (v) => setState(() => _type = v),
                  decoration: InputDecoration(labelText: 'Type', prefixIcon: const Icon(Icons.toggle_on_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _durationC,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Durée', hintText: 'Ex: 3 mois', prefixIcon: const Icon(Icons.timer_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DatePickerField(
                        controller: _startC,
                        enabled: !_saving,
                        labelText: 'Date début',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icons.event_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DatePickerField(
                        controller: _endC,
                        enabled: !_saving,
                        labelText: 'Date fin',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icons.event_available_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _orgC,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: 'Organisé par', prefixIcon: const Icon(Icons.account_balance_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : () => _save(existing),
                    icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0A2F5C))) : const Icon(Icons.save_rounded, color: Color(0xFF0A2F5C)),
                    label: Text(_editingIndex == null ? 'AJOUTER' : 'METTRE À JOUR', style: context.textStyles.labelLarge?.copyWith(color: const Color(0xFF0A2F5C), fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.accent,
                      foregroundColor: const Color(0xFF0A2F5C),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    ),
                  ),
                ),
                if (_editingIndex != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(onPressed: _saving ? null : _resetForm, icon: const Icon(Icons.restart_alt_rounded), label: const Text('Annuler la modification')),
                ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
