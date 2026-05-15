import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thix_id/models/app_user.dart' as models;
import 'package:url_launcher/url_launcher.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/presentation/common/trainings_editor_sheet.dart';
import 'package:thix_id/services/verification_status.dart';
import 'package:thix_id/theme.dart';

class ProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const ProfileStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final bd = context.theme.colorScheme.primary.withValues(alpha: 0.18);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: bd, width: 1.25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: context.theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: context.textStyles.titleMedium?.copyWith(
                color: context.theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: context.textStyles.labelSmall?.copyWith(
                color: LightModeColors.secondaryText,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool showAction;
  final String actionLabel;
  final VoidCallback? onActionPressed;
  final Widget child;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.showAction,
    this.actionLabel = 'Voir plus',
    this.onActionPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bd = context.theme.colorScheme.primary.withValues(alpha: 0.18);
    final divider = context.theme.colorScheme.primary.withValues(alpha: 0.14);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: bd, width: 1.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: context.textStyles.titleLarge?.copyWith(
                    color: context.theme.colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ),
              if (showAction)
                TextButton(
                  onPressed: onActionPressed,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: context.textStyles.labelMedium?.copyWith(
                      color: context.theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: divider, thickness: 1, height: 1),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Premium group header for public profile sections.
class SectionGroupHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionGroupHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: context.theme.colorScheme.onSurface)),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Simple expandable text with “Voir plus / Voir moins”.
///
/// Uses a conservative length heuristic (no expensive text measurement).
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int collapsedMaxChars;
  final int collapsedMaxLines;
  final bool initiallyExpanded;

  const ExpandableText({
    super.key,
    required this.text,
    this.style,
    this.collapsedMaxChars = 240,
    this.collapsedMaxLines = 4,
    this.initiallyExpanded = false,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant ExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.text.trim();
    if (raw.isEmpty) return Text('—', style: widget.style);

    final canExpand = raw.length > widget.collapsedMaxChars;
    final shown = (!_expanded && canExpand) ? _truncate(raw, widget.collapsedMaxChars) : raw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shown,
          style: widget.style,
          maxLines: _expanded ? null : widget.collapsedMaxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (canExpand) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                splashFactory: NoSplash.splashFactory,
              ),
              child: Text(
                _expanded ? 'Voir moins' : 'Voir plus',
                style: context.textStyles.labelSmall?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ]
      ],
    );
  }
}

class InfoGridItem extends StatelessWidget {
  final String label;
  final String value;

  const InfoGridItem({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final bg = context.theme.colorScheme.primary.withValues(alpha: 0.055);
    final bd = context.theme.colorScheme.primary.withValues(alpha: 0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: bd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: LightModeColors.secondaryText,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class TimelineNode extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final bool hasNext;
  final List<String> details;
  final bool expanded;
  final String description;
  final VerificationStatus status;
  final List<EvidenceFileRef> evidence;

  const TimelineNode({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.hasNext,
    this.details = const [],
    this.expanded = false,
    this.description = '',
    this.status = VerificationStatus.pending,
    this.evidence = const [],
  });

  Future<void> _openEvidence(BuildContext context, EvidenceFileRef ref) async {
    try {
      final raw = ref.storagePathOrUrl.trim();
      if (raw.isEmpty) return;
      if (raw.startsWith('documents:')) {
        final docId = raw.substring('documents:'.length).trim();
        if (docId.isEmpty) return;
        final rows = await SupabaseConfig.client.from(DocumentService.table).select('*').eq('doc_id', docId).order('created_at', ascending: false).limit(1);
        if (rows is List && rows.isNotEmpty) {
          final row = (rows.first as Map).cast<String, dynamic>();
          final url = await DocumentService().resolveRowDownloadUrl(row);
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (raw.startsWith('certificates:')) {
        final p = raw.substring('certificates:'.length).trim();
        if (p.isEmpty) return;
        final url = await DocumentService().createDownloadUrl(storagePath: p, bucketName: 'certificates');
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }
      final url = raw.startsWith('http') ? raw : await DocumentService().createDownloadUrl(storagePath: raw);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('TimelineNode: openEvidence failed err=$e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture impossible.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = LightModeColors.metalGold.withValues(alpha: 0.9);
    final bg = context.theme.colorScheme.primary.withValues(alpha: 0.045);
    final bd = context.theme.colorScheme.primary.withValues(alpha: 0.12);
     final visibleDetails = expanded ? details : details.take(2).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: LightModeColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.theme.colorScheme.surface, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
              ),
              if (hasNext)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width: 2,
                  height: 35,
                  color: lineColor,
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: bd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _VerificationPill(status: status),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: LightModeColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ExpandableText(
                      text: description,
                      collapsedMaxChars: 260,
                      collapsedMaxLines: 4,
                      style: context.textStyles.bodySmall?.copyWith(color: context.theme.colorScheme.onSurface, height: 1.45, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (visibleDetails.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final d in visibleDetails)
                          _MetaPill(
                            icon: Icons.info_outline_rounded,
                            label: d,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 10, color: LightModeColors.hint),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        date,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: LightModeColors.hint,
                        ),
                      ),
                    ],
                  ),
                  if (evidence.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final e in evidence)
                          OutlinedButton.icon(
                            onPressed: () => _openEvidence(context, e),
                            icon: const Icon(Icons.attachment_rounded, size: 18),
                            label: Text((e.label ?? 'Pièce').trim().isEmpty ? 'Pièce' : e.label!.trim(), overflow: TextOverflow.ellipsis),
                            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: context.theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: context.textStyles.labelMedium?.copyWith(
                color: context.theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class SecureDoc extends StatelessWidget {
  final IconData icon;
  final String name;
  final String id;
  final String status;

  const SecureDoc({
    super.key,
    required this.icon,
    required this.name,
    required this.id,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = status == "Vérifié";
    final statusColor = isVerified ? LightModeColors.success : LightModeColors.error;
    final statusBg = isVerified ? const Color(0xFF059669).withValues(alpha: 0.08) : const Color(0xFFDC2626).withValues(alpha: 0.08);
    final statusIcon = isVerified ? Icons.verified : Icons.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: context.theme.dividerColor),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: context.theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: context.textStyles.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.theme.colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "N° $id",
                  style: context.textStyles.labelSmall?.copyWith(
                    color: LightModeColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  status,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PublicProfilePage extends StatefulWidget {
  final String? initialThixId;
  const PublicProfilePage({super.key, this.initialThixId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final _profiles = ProfileService();
  final _access = AccessRequestService();
  final _notifications = NotificationService();
  final _docs = DocumentService();
  bool _loading = false;
  String? _error;
  bool _bioExpanded = false;
  bool _infoExpanded = false;
  // Education (cursus) should be readable by default.
  bool _eduExpanded = true;
  bool _expExpanded = false;
  String? _thixId;
  bool _requestingAccess = false;
  Timer? _accessExpiryTicker;

  bool _looksLikeEducationEntry(Map<String, dynamic> e) {
    bool hasKey(String k) => (e[k]?.toString().trim() ?? '').isNotEmpty;
    // Academic cursus entries typically have institution/degree/level/startYear/endYear.
    if (hasKey('institution') || hasKey('school') || hasKey('degree') || hasKey('level') || hasKey('startYear') || hasKey('endYear')) return true;
    // Some schemas store dates under start_date / end_date but still include degree.
    if (hasKey('start_date') && hasKey('end_date') && hasKey('degree')) return true;
    return false;
  }

  String _extractEmailForContacts(ThixProfile p, models.AppUser? me) {
    // If the viewer is the owner, we can reliably show the authenticated email.
    if (me != null && me.id == p.userId && me.email.trim().isNotEmpty) return me.email.trim();
    // Otherwise, best-effort: look for an email inside the profile contacts list.
    for (final raw in p.contacts.whereType<Map>()) {
      final c = raw.cast<String, dynamic>();
      final type = (c['type'] ?? c['kind'] ?? '').toString().toLowerCase().trim();
      final label = (c['label'] ?? '').toString().toLowerCase().trim();
      final value = (c['value'] ?? c['contact'] ?? '').toString().trim();
      if (value.isEmpty) continue;
      final looksEmail = value.contains('@') && value.contains('.');
      if (type.contains('mail') || type.contains('email') || label.contains('mail') || label.contains('email') || looksEmail) return value;
    }
    return '';
  }

  get email => null;

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('launch failed');
      }
    } catch (e) {
      debugPrint('PublicProfilePage: openUrl failed url=$url err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture impossible.')));
    }
  }

  Future<void> _openDocumentRow(Map<String, dynamic> row) async {
    try {
      final url = await _docs.resolveRowDownloadUrl(row);
      if (url.trim().isEmpty) throw Exception('URL vide');
      await _openUrl(url);
    } catch (e) {
      debugPrint('PublicProfilePage: openDocumentRow failed err=$e rowKeys=${row.keys.toList()}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement / ouverture impossible.')));
    }
  }

  @override
  void initState() {
    super.initState();
    _thixId = widget.initialThixId;
    // Re-evaluate time-bounded access locally so the UI locks again when
    // `approved_until` expires, even if no realtime event happens.
    _accessExpiryTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    if (_thixId != null && _thixId!.trim().isNotEmpty) {
      _loadByThixId(_thixId!);
    }
  }

  @override
  void dispose() {
    _accessExpiryTicker?.cancel();
    _accessExpiryTicker = null;
    super.dispose();
  }

  Future<void> _loadByThixId(String raw) async {
    final thixId = raw.trim().toUpperCase();
    if (thixId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _thixId = thixId;
    });
    try {
      final found = await _profiles.fetchPublicProfileByThixId(thixId);
      if (found == null) {
        setState(() => _error = 'THIX ID introuvable.');
      }
    } catch (e) {
      debugPrint('PublicProfilePage: failed to load thixId=$raw err=$e');
      setState(() => _error = 'Impossible de charger le profil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentUser;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.theme.colorScheme.primary.withValues(alpha: 0.10),
              LightModeColors.background,
              context.theme.colorScheme.tertiary.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((_thixId ?? '').trim().isEmpty)
                    _PublicVisaHeader(
                      name: 'Profil',
                      thixId: _thixId ?? '',
                      subtitle: 'Recherchez un THIX ID depuis l’accueil',
                      verified: false,
                      photoUrl: null,
                      diplomasCount: 0,
                      certificationsCount: 0,
                      experiencesCount: 0,
                      consultationsCount: 0,
                      onBack: () => context.popOrGo(AppRoutes.home),
                      onCopyThixId: null,
                    )
                  else
                    StreamBuilder<ThixProfile?>(
                      stream: _profiles.streamPublicProfileByThixId(_thixId!),
                      builder: (context, snap) {
                        final p = snap.data;
                        final name = p?.displayName ?? 'Profil';
                        final thixId = p?.thixId ?? (_thixId ?? '');
                        final bio = p?.bio ?? '';
                        final edu = p?.education ?? const [];
                        final exp = p?.experience ?? const [];
                        final skills = p?.skills ?? const [];
                        final languages = p?.languages ?? const [];
                        final occupation = (p?.profession ?? p?.occupation) ?? '';
                        final thixChat = p?.thixChat ?? '';

                        Widget buildPublicWithGate({required bool canSeePrivate, required AccessRequestState? state}) {
                          final nowUtc = DateTime.now().toUtc();
                          final isExpired = (state?.status == AccessRequestStatus.approved) && !(state?.isActiveAt(nowUtc) ?? false);
                          final gate = _AccessGateCard(
                            status: isExpired ? AccessRequestStatus.none : (state?.status ?? AccessRequestStatus.none),
                            isLoggedIn: me != null,
                            expired: isExpired,
                            approvedUntil: state?.approvedUntil,
                            onRequest: me == null || p == null
                                ? null
                                : () async {
                                    if (_requestingAccess) return;
                                    setState(() => _requestingAccess = true);
                                    try {
                                      final res = await _access.requestAccess(requesterId: me.id, targetUserId: p.userId, thixId: p.thixId);
                                      // In strict-RLS projects, the notification is emitted by DB RPC.
                                      // We still try client-side insertion as a best-effort fallback.
                                      if (res.requestId != null && res.requestId!.trim().isNotEmpty) {
                                        try {
                                          await _notifications.add(
                                            toUid: p.userId,
                                            type: 'access_request',
                                            title: 'Nouvelle demande d’accès',
                                            body: '${me.displayName} (${me.thixId}) demande l’accès à votre profil.',
                                            data: {
                                              'request_id': res.requestId,
                                              'requester_id': me.id,
                                              'requester_name': me.displayName,
                                              'requester_thix_id': me.thixId,
                                              'target_user_id': p.userId,
                                              'thix_id': p.thixId,
                                            },
                                          );
                                        } catch (e) {
                                          debugPrint('PublicProfilePage: fallback notification add failed err=$e');
                                        }
                                      }
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée.')));
                                    } catch (e) {
                                      debugPrint('PublicProfilePage: requestAccess failed err=$e');
                                      if (!context.mounted) return;
                                      final msg = e.toString();
                                      // In most cases this is an RLS denial or missing RPC/table.
                                      // Show a short error to help diagnose during setup.
                                      final friendly = msg.toLowerCase().contains('permission') || msg.toLowerCase().contains('rls')
                                          ? "Envoi refusé (permissions Supabase)."
                                          : 'Impossible d’envoyer la demande.';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(kDebugMode ? '$friendly\n$msg' : friendly),
                                        ),
                                      );
                                    } finally {
                                      if (mounted) setState(() => _requestingAccess = false);
                                    }
                                  },
                            isLoading: _requestingAccess,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PublicVisaHeader(
                                name: name,
                                thixId: thixId,
                                subtitle: (exp.isNotEmpty ? ((exp.first['title'] as String?) ?? 'Profil THIX') : 'Profil THIX'),
                                verified: true,
                                photoUrl: p?.photoUrl,
                                diplomasCount: edu.length,
                                certificationsCount: _countCertificationsFromEducation(edu),
                                experiencesCount: exp.length,
                                consultationsCount: 0,
                                onBack: () => context.popOrGo(AppRoutes.home),
                                onCopyThixId: thixId.trim().isEmpty
                                    ? null
                                    : () async {
                                        await Clipboard.setData(ClipboardData(text: thixId));
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('THIX ID copié.')));
                                      },
                              ),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_loading)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                                        child: Center(child: CircularProgressIndicator(color: LightModeColors.accent.withValues(alpha: 0.9))),
                                      )
                                    else if (_error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                                        child: Text(_error!, style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurface)),
                                      )
                                    else if (p == null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                                        child: Text('Profil introuvable.', style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText)),
                                      )
                                    else ...[
                                      if (!canSeePrivate) ...[
                                        gate,
                                        const SizedBox(height: AppSpacing.lg),
                                      ],
                                      SectionGroupHeader(title: 'Aperçu', subtitle: 'Chaque information est classée par catégorie (plus lisible).'),
                                      _ExpandableSectionCard(
                                        icon: Icons.description,
                                        title: 'Bio',
                                        expanded: _bioExpanded,
                                        canExpand: canSeePrivate && bio.trim().length > 140,
                                        onToggle: () => setState(() => _bioExpanded = !_bioExpanded),
                                        child: canSeePrivate
                                            ? ExpandableText(
                                                text: bio,
                                                initiallyExpanded: _bioExpanded,
                                                collapsedMaxChars: 260,
                                                collapsedMaxLines: 5,
                                                style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurface, height: 1.55),
                                              )
                                            : Text(
                                                'Compte personnel: biographie masquée. Demandez l’accès pour voir plus.',
                                                style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurface, height: 1.55),
                                              ),
                                      ),
                                      _PersonalInfoExpandableCard(profile: p, expanded: _infoExpanded, onToggle: () => setState(() => _infoExpanded = !_infoExpanded), canSeePrivate: canSeePrivate),

                                      LayoutBuilder(
                                        builder: (context, c) {
                                          final email = _extractEmailForContacts(p, me);
                                          final originHasData = [p.originProvince, p.originTerritory, p.originSector].any((v) => (v ?? '').trim().isNotEmpty);
                                          final residenceHasData = [
                                            p.residenceCountry,
                                            p.residenceProvince,
                                            p.residenceTerritory,
                                            p.residenceCity,
                                            p.residenceCommune,
                                            p.residenceQuarter,
                                            p.residenceAvenue,
                                            p.residenceNumber,
                                          ].any((v) => (v ?? '').trim().isNotEmpty);
                                          final physicalHasData = [p.height, p.weight, p.bloodGroup, p.dateOfBirth].any((v) => (v ?? '').trim().isNotEmpty) || (p.hasPhysicalDisability ?? false);
                                          final nationalIdHasData = [
                                            p.nationalIdNumber,
                                            p.idDocumentType,
                                            p.idDocumentIssueDate,
                                            p.idDocumentExpiryDate,
                                            p.idDocumentIssuePlace,
                                            p.idDocumentFrontDocId,
                                            p.idDocumentBackDocId,
                                            p.idDocumentSelfieDocId,
                                          ].any((v) => (v ?? '').trim().isNotEmpty);
                                          final hasContacts =
                                              p.contacts.isNotEmpty ||
                                              (p.contactPhone ?? '').trim().isNotEmpty ||
                                              (p.thixChat ?? '').trim().isNotEmpty ||
                                              email.trim().isNotEmpty;

                                          final identityWidgets = <Widget>[];
                                          if (hasContacts) {
                                            identityWidgets.add(_ContactsCard(canSeePrivate: canSeePrivate, email: email, phone: p.contactPhone, thixChat: p.thixChat, contacts: p.contacts));
                                          }
                                          if (originHasData) identityWidgets.add(_OriginCard(profile: p, canSeePrivate: canSeePrivate));
                                          if (residenceHasData) identityWidgets.add(_ResidenceCard(profile: p, canSeePrivate: canSeePrivate));
                                          if (physicalHasData) identityWidgets.add(_PhysicalIdCard(profile: p, canSeePrivate: canSeePrivate));
                                          if (nationalIdHasData) identityWidgets.add(_NationalIdentityCard(profile: p, canSeePrivate: canSeePrivate));
                                          identityWidgets.add(
                                            StreamBuilder<List<Map<String, dynamic>>>(
                                              stream: _profiles.streamEmergencyContacts(p.userId),
                                              builder: (context, s) {
                                                final rows = s.data ?? const [];
                                                final fromTable = rows.map((r) => r['payload']).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
                                                final contacts = fromTable.isNotEmpty ? fromTable : p.emergencyContacts;
                                                if (contacts.isEmpty) return const SizedBox.shrink();
                                                return _EmergencyContactsCard(canSeePrivate: canSeePrivate, contacts: contacts);
                                              },
                                            ),
                                          );

                                          final careerWidgets = <Widget>[
                                            _ProfessionalOverviewCard(canSeePrivate: canSeePrivate, thixChat: thixChat, occupation: occupation),
                                            _SkillsLanguagesCard(
                                              canSeePrivate: canSeePrivate,
                                              competence: p.competence,
                                              skills: skills,
                                              languages: languages,
                                              languagesDetailed: p.languagesDetailed,
                                            ),
                                          ];

                                          final credentialsWidgets = <Widget>[];
                                          if (p.certifications.isNotEmpty) {
                                            credentialsWidgets.add(_CertificationsCard(canSeePrivate: canSeePrivate, certifications: p.certifications));
                                          }
                                          credentialsWidgets.add(
                                            StreamBuilder<List<Map<String, dynamic>>>(
                                              stream: _docs.streamDocuments(p.userId),
                                              builder: (context, s) {
                                                final docs = s.data ?? const <Map<String, dynamic>>[];
                                                if (docs.isEmpty && !canSeePrivate) return const SizedBox.shrink();
                                                return _PublicDocumentsCard(canSeePrivate: canSeePrivate, documents: docs, onOpen: canSeePrivate ? (row) => _openDocumentRow(row) : null);
                                              },
                                            ),
                                          );
                                          credentialsWidgets.add(_DigitalCard(thixId: thixId, name: name, nationality: (p.nationality ?? p.countryOrOrigin ?? '').trim(), canSeePrivate: canSeePrivate));

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              SectionGroupHeader(title: 'Identité & contacts'),
                                              _ResponsiveTwoColumn(maxWidth: c.maxWidth, gap: AppSpacing.lg, children: identityWidgets),
                                              const SizedBox(height: AppSpacing.md),
                                              StreamBuilder<List<Map<String, dynamic>>>(
                                                stream: _profiles.streamFormations(p.userId),
                                                builder: (context, s) {
                                                  final rows = s.data ?? const [];
                                                  final fromTableLegacy = rows.map((r) => r['payload']).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
                                                  final fromTableColumns = rows
                                                      .where((r) => r['payload'] == null)
                                                      .map((r) {
                                                        // The linked `formations` table can contain BOTH trainings and academic cursus.
                                                        // We keep the raw-ish mapping and later split using heuristics.
                                                        return {
                                                          // Shared-ish keys
                                                          'title': (r['title'] ?? r['name'] ?? '').toString(),
                                                          'name': (r['title'] ?? r['name'] ?? '').toString(),
                                                          'type': (r['type'] ?? '').toString(),
                                                          'duration': (r['duration'] ?? '').toString(),
                                                          'start_date': (r['start_date'] ?? '').toString(),
                                                          'end_date': (r['end_date'] ?? '').toString(),
                                                          'organized_by': (r['organizer'] ?? r['organized_by'] ?? '').toString(),
                                                          'provider': (r['organizer'] ?? r['organized_by'] ?? '').toString(),
                                                          'skills_acquired': (r['skills'] ?? '').toString(),
                                                          'skills': (r['skills'] ?? '').toString(),
                                                          'description': (r['description'] ?? r['details'] ?? '').toString(),

                                                          // Education-ish keys (best effort)
                                                          'institution': (r['institution'] ?? r['school'] ?? r['organizer'] ?? '').toString(),
                                                          'school': (r['school'] ?? r['institution'] ?? '').toString(),
                                                          'degree': (r['degree'] ?? '').toString(),
                                                          'level': (r['level'] ?? '').toString(),
                                                          'city': (r['city'] ?? '').toString(),
                                                          'startYear': (r['start_year'] ?? '').toString(),
                                                          'endYear': (r['end_year'] ?? '').toString(),
                                                        };
                                                      })
                                                      .where((m) => ((m['title'] ?? '') as String).trim().isNotEmpty || ((m['institution'] ?? '') as String).trim().isNotEmpty)
                                                      .toList(growable: false);

                                                  final merged = fromTableLegacy.isNotEmpty ? fromTableLegacy : (fromTableColumns.isNotEmpty ? fromTableColumns : [...p.trainings, ...p.education]);

                                                  final trainings = merged.where((e) {
                                                    final m = e.cast<String, dynamic>();
                                                    return !_looksLikeEducationEntry(m);
                                                  }).toList(growable: false);
                                                  final education = merged.where((e) {
                                                    final m = e.cast<String, dynamic>();
                                                    return _looksLikeEducationEntry(m);
                                                  }).toList(growable: false);

                                                  return Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: [
                                                      SectionGroupHeader(title: 'Formations', subtitle: 'Certificats & formations • détails visibles (Voir plus si nécessaire).'),
                                                      // Public view: no “Ajouter une formation” button.
                                                      // Formations are intentionally visible on public view.
                                                      _TrainingsCard(canSeePrivate: true, trainings: trainings, canEdit: false, onAddPressed: null),
                                                      const SizedBox(height: AppSpacing.md),
                                                      SectionGroupHeader(title: 'Cursus scolaire', subtitle: 'Parcours académique • séparé des formations.'),
                                                      _ExpandableTimelineCard(
                                                        icon: Icons.account_balance_rounded,
                                                        title: 'Cursus scolaire',
                                                        expanded: _eduExpanded,
                                                        canExpand: education.length > 2 || _timelineHasMoreDetails(education, _TimelineKind.education),
                                                        onToggle: () => setState(() => _eduExpanded = !_eduExpanded),
                                                        // Cursus is also visible on public view.
                                                        canSeePrivate: true,
                                                        items: education,
                                                        kind: _TimelineKind.education,
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: AppSpacing.md),
                                              SectionGroupHeader(title: 'Parcours'),
                                              _ResponsiveTwoColumn(
                                                maxWidth: c.maxWidth,
                                                gap: AppSpacing.lg,
                                                children: [
                                                  StreamBuilder<List<Map<String, dynamic>>>(
                                                    stream: _profiles.streamExperiences(p.userId),
                                                    builder: (context, s) {
                                                      final rows = s.data ?? const [];
                                                      final fromTableLegacy = rows.map((r) => r['payload']).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
                                                      final fromTableColumns = rows
                                                          .where((r) => r['payload'] == null)
                                                          .map((r) {
                                                            final company = (r['company_name'] ?? r['company'] ?? '').toString();
                                                            final title = (r['position'] ?? r['title'] ?? '').toString();
                                                            final desc = (r['description'] ?? '').toString();
                                                            return {
                                                              'company': company,
                                                              'company_name': company,
                                                              'title': title,
                                                              'position': title,
                                                              'description': desc,
                                                              'missions': desc,
                                                              'start_date': (r['start_date'] ?? '').toString(),
                                                              'end_date': (r['end_date'] ?? '').toString(),
                                                              'sector': (r['sector'] ?? '').toString(),
                                                              'city': (r['city'] ?? '').toString(),
                                                            };
                                                          })
                                                          .where((m) => ((m['company'] ?? '') as String).trim().isNotEmpty || ((m['title'] ?? '') as String).trim().isNotEmpty)
                                                          .toList(growable: false);

                                                      final list = fromTableLegacy.isNotEmpty ? fromTableLegacy : (fromTableColumns.isNotEmpty ? fromTableColumns : exp);
                                                      return _ExpandableTimelineCard(
                                                        icon: Icons.business_center,
                                                        title: 'Expériences Professionnelles',
                                                        expanded: _expExpanded,
                                                        canExpand: list.length > 2 || _timelineHasMoreDetails(list, _TimelineKind.experience),
                                                        onToggle: () => setState(() => _expExpanded = !_expExpanded),
                                                        canSeePrivate: canSeePrivate,
                                                        items: list,
                                                        kind: _TimelineKind.experience,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: AppSpacing.md),
                                              SectionGroupHeader(title: 'Compétences & profil'),
                                              _ResponsiveTwoColumn(maxWidth: c.maxWidth, gap: AppSpacing.lg, children: careerWidgets),
                                              const SizedBox(height: AppSpacing.md),
                                              SectionGroupHeader(title: 'Documents & preuves'),
                                              _ResponsiveTwoColumn(maxWidth: c.maxWidth, gap: AppSpacing.lg, children: credentialsWidgets),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                  ),
                                ),
                            ],
                          );
                        }

                        if (p == null) return buildPublicWithGate(canSeePrivate: false, state: null);

                        final ownerUid = p.userId;
                        final viewerUid = me?.id;
                        final isOwner = viewerUid != null && viewerUid == ownerUid;
                        if (isOwner) return buildPublicWithGate(canSeePrivate: true, state: null);
                        if (viewerUid == null) return buildPublicWithGate(canSeePrivate: false, state: null);

                        return StreamBuilder<AccessRequestState>(
                          stream: _access.streamState(requesterId: viewerUid, targetUserId: ownerUid),
                          builder: (context, s) {
                            final state = s.data;
                            final nowUtc = DateTime.now().toUtc();
                            final canSeePrivate = (state?.isActiveAt(nowUtc) ?? false);
                            return buildPublicWithGate(canSeePrivate: canSeePrivate, state: state);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary ? context.theme.colorScheme.primary : LightModeColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: isPrimary ? const Color(0xFFD4AF37) : const Color(0xFFB8860B)),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall?.copyWith(
          color: isPrimary ? Colors.white : const Color(0xFF0A2F5C),
          fontSize: 11,
        ),
      ),
    );
  }
}

String _truncate(String v, int max) {
  final t = v.trim();
  if (t.isEmpty) return '—';
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

int _countCertificationsFromEducation(List<Map<String, dynamic>> edu) {
  var count = 0;
  for (final e in edu) {
    final type = (e['type'] as String?)?.toLowerCase() ?? '';
    if (type.contains('cert')) count++;
  }
  return count;
}

String _countryCode(String v) {
  final t = v.trim();
  if (t.isEmpty) return '—';
  final letters = t.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
  if (letters.length >= 3) return letters.substring(0, 3);
  if (letters.isNotEmpty) return letters;
  return '—';
}

class _VerificationPill extends StatelessWidget {
  final VerificationStatus status;
  const _VerificationPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (status) {
      VerificationStatus.verified => (Colors.green.withValues(alpha: 0.12), Colors.green.shade800, Colors.green.withValues(alpha: 0.35)),
      VerificationStatus.rejected => (LightModeColors.error.withValues(alpha: 0.12), LightModeColors.error, LightModeColors.error.withValues(alpha: 0.35)),
      VerificationStatus.pending => (Colors.orange.withValues(alpha: 0.12), Colors.orange.shade900, Colors.orange.withValues(alpha: 0.35)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: border)),
      child: Text(status.labelFr, style: context.textStyles.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w900)),
    );
  }
}

class _PublicVisaHeader extends StatelessWidget {
  final String name;
  final String thixId;
  final String subtitle;
  final bool verified;
  final String? photoUrl;
  final int diplomasCount;
  final int certificationsCount;
  final int experiencesCount;
  final int consultationsCount;
  final VoidCallback onBack;
  final VoidCallback? onCopyThixId;

  const _PublicVisaHeader({
    required this.name,
    required this.thixId,
    required this.subtitle,
    required this.verified,
    required this.photoUrl,
    required this.diplomasCount,
    required this.certificationsCount,
    required this.experiencesCount,
    required this.consultationsCount,
    required this.onBack,
    required this.onCopyThixId,
  });

  @override
  Widget build(BuildContext context) {
    final p = (photoUrl ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [LightModeColors.primary, Color(0xFF0F2B4A)]),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.notifications_none_rounded, color: Colors.white.withValues(alpha: 0.85), size: 20),
                  const SizedBox(width: AppSpacing.md),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: LightModeColors.accent.withValues(alpha: 0.75), width: 3),
                      image: DecorationImage(
                        image: p.isEmpty ? const AssetImage('assets/images/African_businessman_in_suit_grayscale_1775573970767.jpg') : NetworkImage(p) as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: verified ? LightModeColors.success : LightModeColors.accent, shape: BoxShape.circle, border: Border.all(color: LightModeColors.primary, width: 3)),
                      alignment: Alignment.center,
                      child: Icon(verified ? Icons.check_rounded : Icons.hourglass_bottom_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.textStyles.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(child: Text('THIX ID: $thixId', style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700))),
                        IconButton(
                          onPressed: onCopyThixId,
                          icon: Icon(Icons.copy_rounded, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, size: 14, color: verified ? LightModeColors.accent : Colors.white70),
                          const SizedBox(width: AppSpacing.sm),
                          Text(verified ? 'Identité Vérifiée' : 'Identité en attente', style: context.textStyles.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6))]),
            child: Row(
              children: [
                ProfileStat(icon: Icons.school, value: diplomasCount.toString(), label: 'Diplômes'),
                const SizedBox(width: AppSpacing.md),
                ProfileStat(icon: Icons.workspace_premium, value: certificationsCount.toString(), label: 'Certifications'),
                const SizedBox(width: AppSpacing.md),
                ProfileStat(icon: Icons.business_center, value: experiencesCount.toString(), label: 'Expériences'),
                const SizedBox(width: AppSpacing.md),
                ProfileStat(icon: Icons.forum_rounded, value: consultationsCount.toString(), label: 'Consultations'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final bool canExpand;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableSectionCard({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.canExpand,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bg = context.theme.colorScheme.primary.withValues(alpha: 0.035);
    final bd = context.theme.colorScheme.primary.withValues(alpha: 0.10);
    return SectionCard(
      icon: icon,
      title: title,
      showAction: canExpand,
      actionLabel: expanded ? 'Voir moins' : 'Voir plus',
      onActionPressed: onToggle,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: bd),
        ),
        child: child,
      ),
    );
  }
}

enum _TimelineKind { education, experience }

bool _timelineHasMoreDetails(List<Map<String, dynamic>> items, _TimelineKind kind) {
  int detailsCount(Map<String, dynamic> item) {
    int n = 0;
    void inc(Object? v) {
      final t = v?.toString().trim() ?? '';
      if (t.isNotEmpty) n++;
    }

    if (kind == _TimelineKind.education) {
      inc(item['level']);
      inc(item['institution']);
      inc(item['school']);
      inc(item['city']);
      inc(item['startYear']);
      inc(item['endYear']);
      inc(item['degree']);
    } else {
      inc(item['title']);
      inc(item['role']);
      inc(item['company']);
      inc(item['org']);
      inc(item['city']);
      inc(item['sector']);
      inc(item['missions']);
      inc(item['tasks']);
    }
    return n;
  }

  for (final item in items) {
    if (detailsCount(item) > 2) return true;
  }
  return false;
}

class _ExpandableTimelineCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final bool canExpand;
  final VoidCallback onToggle;
  final bool canSeePrivate;
  final List<Map<String, dynamic>> items;
  final _TimelineKind kind;

  const _ExpandableTimelineCard({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.canExpand,
    required this.onToggle,
    required this.canSeePrivate,
    required this.items,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final visible = expanded ? items : items.take(2).toList(growable: false);
    return _ExpandableSectionCard(
      icon: icon,
      title: title,
      expanded: expanded,
      canExpand: canExpand,
      onToggle: onToggle,
      child: Column(
        children: List.generate(
          canSeePrivate ? (visible.isEmpty ? 1 : visible.length) : 1,
          (i) {
            if (!canSeePrivate) return const TimelineNode(title: 'Accès requis', subtitle: 'Contenu masqué', date: '—', hasNext: false);
            if (visible.isEmpty) return const TimelineNode(title: '—', subtitle: 'Aucune entrée', date: '—', hasNext: false);
            final item = visible[i];
            String dateRange(String? start, String? end) {
              final s = (start ?? '').trim();
              final e = (end ?? '').trim();
              final r = [s, e].where((v) => v.isNotEmpty).join(' – ');
              return r.isEmpty ? '—' : r;
            }

            final (t, sub, d, desc) = switch (kind) {
              _TimelineKind.education => (
                  (item['degree'] as String?) ?? (item['title'] as String?) ?? 'Diplôme',
                  [
                    (item['institution'] as String?) ?? (item['school'] as String?) ?? (item['org'] as String?) ?? '—',
                    (item['city'] as String?) ?? '',
                  ].where((v) => v.trim().isNotEmpty).join(' • '),
                  dateRange(
                    (item['startYear'] as String?) ?? (item['start_date'] as String?) ?? (item['date'] as String?),
                    (item['endYear'] as String?) ?? (item['end_date'] as String?),
                  ),
                  (item['description'] as String?) ?? (item['details'] as String?) ?? ''
                ),
              _TimelineKind.experience => (
                  (item['title'] as String?) ?? (item['role'] as String?) ?? 'Expérience',
                  [
                    (item['company'] as String?) ?? (item['org'] as String?) ?? '—',
                    (item['city'] as String?) ?? '',
                    (item['sector'] as String?) ?? '',
                  ].where((v) => v.trim().isNotEmpty).join(' • '),
                  dateRange((item['start_date'] as String?) ?? (item['start'] as String?) ?? (item['date'] as String?), (item['end_date'] as String?) ?? (item['end'] as String?)),
                  (item['missions'] as String?) ?? (item['description'] as String?) ?? ''
                ),
            };
            final details = <String>[];
            void add(String? v, {String? prefix}) {
              final vv = (v ?? '').trim();
              if (vv.isEmpty) return;
              details.add(prefix == null ? vv : '$prefix: $vv');
            }

            if (kind == _TimelineKind.education) {
              add(item['level'] as String?, prefix: 'Niveau');
              add(item['institution'] as String?, prefix: 'Établissement');
              add(item['city'] as String?, prefix: 'Ville');
              add((item['startYear'] as String?) ?? (item['start_date'] as String?), prefix: 'Début');
              add((item['endYear'] as String?) ?? (item['end_date'] as String?), prefix: 'Fin');
            } else {
              add(item['company'] as String?, prefix: 'Entreprise');
              add(item['city'] as String?, prefix: 'Ville');
              add(item['sector'] as String?, prefix: 'Secteur');
              add(item['contract'] as String?, prefix: 'Contrat');
            }

            final status = VerificationStatusX.parse(item['verification_status'] ?? item['verificationStatus']);
            final evidence = ((item['evidence'] as List?) ?? const []).map(EvidenceFileRef.tryParse).whereType<EvidenceFileRef>().toList(growable: false);

            return TimelineNode(
              title: t,
              subtitle: sub,
              date: d,
              hasNext: i < (visible.length - 1),
              details: details,
              expanded: expanded,
              description: desc,
              status: status,
              evidence: evidence,
            );
          },
        ),
      ),
    );
  }
}

class _ResponsiveTwoColumn extends StatelessWidget {
  final double maxWidth;
  final double gap;
  final List<Widget> children;

  const _ResponsiveTwoColumn({required this.maxWidth, required this.gap, required this.children});

  @override
  Widget build(BuildContext context) {
    final twoCols = maxWidth >= 760;
    if (!twoCols) {
      return Column(children: children.map((w) => Padding(padding: EdgeInsets.only(bottom: gap), child: w)).toList(growable: false));
    }

    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      (i.isEven ? left : right).add(children[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left.map((w) => Padding(padding: EdgeInsets.only(bottom: gap), child: w)).toList(growable: false))),
        SizedBox(width: gap),
        Expanded(child: Column(children: right.map((w) => Padding(padding: EdgeInsets.only(bottom: gap), child: w)).toList(growable: false))),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool canSeePrivate;
  final String name;
  final String dob;
  final String pob;
  final String nationality;
  final String email;
  final String phone;
  final String maritalStatus;
  final String origin;

  const _InfoCard({
    required this.canSeePrivate,
    required this.name,
    required this.dob,
    required this.pob,
    required this.nationality,
    required this.email,
    required this.phone,
    required this.maritalStatus,
    required this.origin,
  });

  @override
  Widget build(BuildContext context) {
    String mask(String v) => canSeePrivate ? (v.trim().isEmpty ? '—' : v.trim()) : '—';

    return SectionCard(
      icon: Icons.badge_outlined,
      title: 'Informations Personnelles',
      showAction: false,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 3.0,
        children: [
          InfoGridItem(label: 'Date de naissance', value: mask(dob)),
          InfoGridItem(label: 'Lieu de naissance', value: mask(pob)),
          InfoGridItem(label: 'Nationalité', value: mask(nationality)),
          InfoGridItem(label: 'État civil', value: mask(maritalStatus)),
          InfoGridItem(label: 'Email', value: mask(email)),
          InfoGridItem(label: 'Téléphone', value: mask(phone)),
          InfoGridItem(label: 'Origine', value: mask(origin)),
          InfoGridItem(label: 'Identité', value: 'Vérifiée'),
        ],
      ),
    );
  }
}

class _OriginCard extends StatelessWidget {
  final ThixProfile profile;
  final bool canSeePrivate;
  const _OriginCard({required this.profile, required this.canSeePrivate});

  @override
  Widget build(BuildContext context) {
    if (!canSeePrivate) {
      return SectionCard(
        icon: Icons.flag_rounded,
        title: 'Origine',
        showAction: false,
        child: Text('Compte personnel: informations masquées. Demandez l’accès.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
      );
    }
    final items = <MapEntry<String, String>>[];
    void add(String label, String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return;
      items.add(MapEntry(label, t));
    }

    // Removed: father/mother names (privacy + requested by user).
    add('Province', profile.originProvince);
    add('Territoire', profile.originTerritory);
    add('Secteur', profile.originSector);
    if (items.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      icon: Icons.flag_rounded,
      title: 'Origine',
      showAction: false,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 3.0,
        children: items.map((e) => InfoGridItem(label: e.key, value: e.value)).toList(growable: false),
      ),
    );
  }
}

class _ResidenceCard extends StatelessWidget {
  final ThixProfile profile;
  final bool canSeePrivate;
  const _ResidenceCard({required this.profile, required this.canSeePrivate});

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, String>>[];
    void add(String label, String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return;
      items.add(MapEntry(label, t));
    }

    // Public view: show the current residence (non-sensitive subset) when available.
    // This avoids an empty/hidden section and matches the user's expectation.
    if (!canSeePrivate) {
      add('Pays', profile.residenceCountry);
      add('Province', profile.residenceProvince);
      add('Ville', profile.residenceCity);

      if (items.isEmpty) {
        return SectionCard(
          icon: Icons.home_work_rounded,
          title: 'Résidence actuelle',
          showAction: false,
          child: Text('Non renseignée.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
        );
      }

      return SectionCard(
        icon: Icons.home_work_rounded,
        title: 'Résidence actuelle',
        showAction: false,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 3.0,
          children: items.map((e) => InfoGridItem(label: e.key, value: e.value)).toList(growable: false),
        ),
      );
    }

    add('Pays', profile.residenceCountry);
    add('Province', profile.residenceProvince);
    add('Territoire', profile.residenceTerritory);
    add('Ville', profile.residenceCity);
    add('Commune', profile.residenceCommune);
    add('Quartier', profile.residenceQuarter);
    add('Avenue', profile.residenceAvenue);
    add('Numéro', profile.residenceNumber);
    if (items.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      icon: Icons.home_work_rounded,
      title: 'Résidence actuelle',
      showAction: false,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 3.0,
        children: items.map((e) => InfoGridItem(label: e.key, value: e.value)).toList(growable: false),
      ),
    );
  }
}

class _PhysicalIdCard extends StatelessWidget {
  final ThixProfile profile;
  final bool canSeePrivate;
  const _PhysicalIdCard({required this.profile, required this.canSeePrivate});

  @override
  Widget build(BuildContext context) {
    if (!canSeePrivate) {
      return SectionCard(
        icon: Icons.health_and_safety_rounded,
        title: 'Informations physiques',
        showAction: false,
        child: Text('Compte personnel: informations masquées. Demandez l’accès.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
      );
    }
    final items = <MapEntry<String, String>>[];
    void add(String label, String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return;
      items.add(MapEntry(label, t));
    }

    int? ageFromDob(String? dob) {
      final t = (dob ?? '').trim();
      if (t.isEmpty) return null;
      final d = DateTime.tryParse(t);
      if (d == null) return null;
      final now = DateTime.now();
      var years = now.year - d.year;
      final hasHadBirthday = (now.month > d.month) || (now.month == d.month && now.day >= d.day);
      if (!hasHadBirthday) years -= 1;
      return years < 0 ? null : years;
    }

    final age = ageFromDob(profile.dateOfBirth);
    if (age != null) add('Âge', '$age ans');

    add('Taille', profile.height);
    add('Poids', profile.weight);
    add('Groupe sanguin', profile.bloodGroup);
    if ((profile.hasPhysicalDisability ?? false)) add('Handicap', (profile.physicalDisabilityDescription ?? 'Oui').trim());
    if (items.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      icon: Icons.health_and_safety_rounded,
      title: 'Informations physiques',
      showAction: false,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 3.0,
        children: items.map((e) => InfoGridItem(label: e.key, value: e.value)).toList(growable: false),
      ),
    );
  }
}

class _NationalIdentityCard extends StatelessWidget {
  final ThixProfile profile;
  final bool canSeePrivate;
  const _NationalIdentityCard({required this.profile, required this.canSeePrivate});

  Future<void> _openDocId(BuildContext context, String docId) async {
    try {
      final rows = await SupabaseConfig.client.from(DocumentService.table).select('*').eq('doc_id', docId).order('created_at', ascending: false).limit(1);
      if (rows is List && rows.isNotEmpty) {
        final row = (rows.first as Map).cast<String, dynamic>();
        final url = await DocumentService().resolveRowDownloadUrl(row);
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('NationalIdentityCard: open failed docId=$docId err=$e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture impossible.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canSeePrivate) {
      return SectionCard(
        icon: Icons.verified_user_rounded,
        title: 'Identité nationale',
        showAction: false,
        child: Text('Compte personnel: informations masquées. Demandez l’accès.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
      );
    }

    String mask(String v) => v.trim().isEmpty ? '—' : v.trim();
    final status = VerificationStatusX.parse(profile.idVerificationStatus);

    final items = <MapEntry<String, String>>[];
    void add(String label, String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return;
      items.add(MapEntry(label, t));
    }

    add('Numéro', profile.nationalIdNumber);
    add('Type', profile.idDocumentType);
    add('Émission', profile.idDocumentIssueDate);
    add('Expiration', profile.idDocumentExpiryDate);
    add('Lieu', profile.idDocumentIssuePlace);

    return SectionCard(
      icon: Icons.verified_user_rounded,
      title: 'Identité nationale',
      showAction: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Statut', style: context.textStyles.labelMedium?.copyWith(fontWeight: FontWeight.w900))),
              _VerificationPill(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 3.0,
            children: items.map((e) => InfoGridItem(label: e.key, value: mask(e.value))).toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((profile.idDocumentFrontDocId ?? '').trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openDocId(context, profile.idDocumentFrontDocId!.trim()),
                  icon: const Icon(Icons.photo_rounded, size: 18),
                  label: const Text('Recto'),
                ),
              if ((profile.idDocumentBackDocId ?? '').trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openDocId(context, profile.idDocumentBackDocId!.trim()),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Verso'),
                ),
              if ((profile.idDocumentSelfieDocId ?? '').trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openDocId(context, profile.idDocumentSelfieDocId!.trim()),
                  icon: const Icon(Icons.face_rounded, size: 18),
                  label: const Text('Selfie'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactsCard extends StatefulWidget {
  final bool canSeePrivate;
  final List<Map<String, dynamic>> contacts;
  const _EmergencyContactsCard({required this.canSeePrivate, required this.contacts});

  @override
  State<_EmergencyContactsCard> createState() => _EmergencyContactsCardState();
}

class _EmergencyContactsCardState extends State<_EmergencyContactsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.canSeePrivate) {
      return SectionCard(icon: Icons.contact_emergency_rounded, title: 'Contacts d\'urgence', showAction: false, child: Text('—', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)));
    }
    final list = widget.contacts.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    if (list.isEmpty) return const SizedBox.shrink();
    final canExpand = list.length > 3;
    final visible = _expanded ? list : list.take(3).toList(growable: false);

    return SectionCard(
      icon: Icons.contact_emergency_rounded,
      title: 'Contacts d\'urgence',
      showAction: canExpand,
      actionLabel: _expanded ? 'Voir moins' : 'Voir plus',
      onActionPressed: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: visible.map((e) {
          final name = (e['name'] as String?) ?? '—';
          final phone = (e['phone'] as String?) ?? (e['number'] as String?) ?? '';
          final relation = (e['relation'] as String?) ?? '';
          final city = (e['city'] as String?) ?? '';
          final subtitle = [relation, city, phone].where((v) => v.trim().isNotEmpty).join(' • ');
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_pin_circle_rounded, size: 20, color: LightModeColors.secondaryText),
            title: Text(name, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            subtitle: subtitle.trim().isEmpty ? null : Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _TrainingsCard extends StatefulWidget {
  final bool canSeePrivate;
  final List<Map<String, dynamic>> trainings;
  final bool canEdit;
  final VoidCallback? onAddPressed;
  const _TrainingsCard({required this.canSeePrivate, required this.trainings, required this.canEdit, required this.onAddPressed});

  @override
  State<_TrainingsCard> createState() => _TrainingsCardState();
}

class _TrainingsCardState extends State<_TrainingsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.canSeePrivate) {
      return SectionCard(icon: Icons.school_rounded, title: 'Formations', showAction: false, child: Text('—', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)));
    }
    final list = widget.trainings.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    // Public view should still show a card with an empty-state message (so the section doesn't look broken).
    final canExpand = list.length > 3;
    final visible = _expanded ? list : list.take(3).toList(growable: false);
    return SectionCard(
      icon: Icons.school_rounded,
      title: 'Formations',
      showAction: canExpand,
      actionLabel: _expanded ? 'Voir moins' : 'Voir plus',
      onActionPressed: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list.isEmpty)
            Text('Aucune formation.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
          else
            ...visible.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TrainingItemCard(data: e),
                )),
        ],
      ),
    );
  }
}

class TrainingItemCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const TrainingItemCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    String v(Object? o) => (o ?? '').toString().trim();
    final title = v(data['name']).isNotEmpty ? v(data['name']) : (v(data['title']).isNotEmpty ? v(data['title']) : 'Formation');
    final org = v(data['organized_by']).isNotEmpty ? v(data['organized_by']) : v(data['provider']);
    final type = v(data['type']);
    final duration = v(data['duration']);
    final start = v(data['start_date']);
    final end = v(data['end_date']);
    final period = [start, end].where((e) => e.isNotEmpty).join(' – ');
    final skills = v(data['skills_acquired']).isNotEmpty ? v(data['skills_acquired']) : v(data['skills']);
    final desc = v(data['description']).isNotEmpty ? v(data['description']) : v(data['details']);
    final status = VerificationStatusX.parse(data['verification_status'] ?? data['verificationStatus']);
    final evidence = ((data['evidence'] as List?) ?? const []).map(EvidenceFileRef.tryParse).whereType<EvidenceFileRef>().toList(growable: false);

    final bd = context.theme.colorScheme.primary.withValues(alpha: 0.14);
    final bg = context.theme.colorScheme.primary.withValues(alpha: 0.035);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: context.theme.dividerColor),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.workspace_premium_rounded, color: context.theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w900, color: context.theme.colorScheme.onSurface)),
                    if (org.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(org, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _VerificationPill(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (type.isNotEmpty) _MetaPill(icon: Icons.category_rounded, label: type),
              if (duration.isNotEmpty) _MetaPill(icon: Icons.timer_rounded, label: duration),
              if (period.isNotEmpty) _MetaPill(icon: Icons.calendar_month_rounded, label: period),
            ],
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Compétences acquises', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            ExpandableText(
              text: skills,
              collapsedMaxChars: 220,
              collapsedMaxLines: 3,
              style: context.textStyles.bodySmall?.copyWith(color: context.theme.colorScheme.onSurface, height: 1.45, fontWeight: FontWeight.w600),
            ),
          ],
          if (desc.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Description', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            ExpandableText(
              text: desc,
              collapsedMaxChars: 320,
              collapsedMaxLines: 5,
              style: context.textStyles.bodySmall?.copyWith(color: context.theme.colorScheme.onSurface, height: 1.5, fontWeight: FontWeight.w600),
            ),
          ],
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final e in evidence)
                  OutlinedButton.icon(
                    onPressed: () {
                      // Reuse TimelineNode opener logic by instantiating its helper.
                      TimelineNode(title: '', subtitle: '', date: '', hasNext: false)._openEvidence(context, e);
                    },
                    icon: const Icon(Icons.attachment_rounded, size: 18),
                    label: Text((e.label ?? 'Pièce').trim().isEmpty ? 'Pièce' : e.label!.trim(), overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PublicDocumentsCard extends StatefulWidget {
  final bool canSeePrivate;
  final List<Map<String, dynamic>> documents;
  final Future<void> Function(Map<String, dynamic> row)? onOpen;
  const _PublicDocumentsCard({required this.canSeePrivate, required this.documents, required this.onOpen});

  @override
  State<_PublicDocumentsCard> createState() => _PublicDocumentsCardState();
}

class _PublicDocumentsCardState extends State<_PublicDocumentsCard> {
  bool _expanded = false;

  IconData _iconForMime(String? mime) {
    final m = (mime ?? '').toLowerCase();
    if (m.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (m.contains('image')) return Icons.image_rounded;
    return Icons.description_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.documents.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    if (list.isEmpty) {
      return SectionCard(
        icon: Icons.folder_open_rounded,
        title: 'Documents',
        showAction: false,
        child: Text('—', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
      );
    }
    final canExpand = list.length > 3;
    final visible = _expanded ? list : list.take(3).toList(growable: false);

    String v(Object? o) => (o ?? '').toString().trim();

    return SectionCard(
      icon: Icons.folder_open_rounded,
      title: 'Documents',
      showAction: canExpand,
      actionLabel: _expanded ? 'Voir moins' : 'Voir plus',
      onActionPressed: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: visible.map((row) {
          final title = v(row['title']).isEmpty ? (v(row['file_name']).isEmpty ? 'Document' : v(row['file_name'])) : v(row['title']);
          final docType = v(row['doc_type']);
          final statusRaw = v(row['status']);
          final status = statusRaw.toLowerCase();
          final mime = v(row['mime_type']);

          final (statusLabel, statusIcon, statusColor) = switch (status) {
            'verified' || 'verifie' || 'vérifié' || 'verifiee' || 'vérifiée' => ('Vérifié', Icons.verified_rounded, LightModeColors.success),
            'rejected' || 'rejete' || 'rejeté' || 'rejetee' || 'rejetée' => ('Rejeté', Icons.cancel_rounded, LightModeColors.error),
            _ => ('En attente', Icons.hourglass_bottom_rounded, LightModeColors.accent),
          };

          final canOpen = widget.canSeePrivate && (status == 'verified' || status == 'verifie' || status == 'vérifié' || status == 'vérifiée') && widget.onOpen != null;

          final subtitle = [docType, statusLabel].where((e) => e.trim().isNotEmpty).join(' • ');
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(_iconForMime(mime), size: 20, color: LightModeColors.secondaryText),
            title: Text(title, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: subtitle.trim().isEmpty ? null : Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(statusLabel, style: context.textStyles.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: canOpen ? () => widget.onOpen!.call(row) : null,
                  icon: Icon(canOpen ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: LightModeColors.secondaryText),
                  tooltip: canOpen ? 'Voir le document' : (widget.canSeePrivate ? 'Document non vérifié' : 'Accès requis'),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _CertificationsCard extends StatefulWidget {
  final bool canSeePrivate;
  final List<Map<String, dynamic>> certifications;
  const _CertificationsCard({required this.canSeePrivate, required this.certifications});

  @override
  State<_CertificationsCard> createState() => _CertificationsCardState();
}

class _CertificationsCardState extends State<_CertificationsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.canSeePrivate) {
      return SectionCard(
        icon: Icons.workspace_premium_rounded,
        title: 'Certifications',
        showAction: false,
        child: Text('Compte personnel: certifications masquées. Demandez l’accès.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
      );
    }

    final list = widget.certifications.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    if (list.isEmpty) return const SizedBox.shrink();
    final canExpand = list.length > 3;
    final visible = _expanded ? list : list.take(3).toList(growable: false);
    String v(Object? o) => (o ?? '').toString().trim();

    return SectionCard(
      icon: Icons.workspace_premium_rounded,
      title: 'Certifications',
      showAction: canExpand,
      actionLabel: _expanded ? 'Voir moins' : 'Voir plus',
      onActionPressed: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: visible.map((e) {
          final title = v(e['title']).isEmpty ? (v(e['name']).isEmpty ? 'Certification' : v(e['name'])) : v(e['title']);
          final issuer = v(e['issuer']).isEmpty ? v(e['org']) : v(e['issuer']);
          final date = v(e['date']).isEmpty ? v(e['issued_at']) : v(e['date']);
          final subtitle = [issuer, date].where((x) => x.trim().isNotEmpty).join(' • ');
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_rounded, size: 20, color: LightModeColors.secondaryText),
            title: Text(title, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
            subtitle: subtitle.trim().isEmpty ? null : Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ContactsCard extends StatefulWidget {
  final bool canSeePrivate;
  final String? email;
  final String? phone;
  final String? thixChat;
  final List<Map<String, dynamic>> contacts;
  const _ContactsCard({required this.canSeePrivate, required this.email, required this.phone, required this.thixChat, required this.contacts});

  @override
  State<_ContactsCard> createState() => _ContactsCardState();
}

class _ContactsCardState extends State<_ContactsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.canSeePrivate) {
      return SectionCard(
        icon: Icons.contact_phone_rounded,
        title: 'Contacts',
        showAction: false,
        child: Text('Compte personnel: contacts masqués. Demandez l’accès.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
      );
    }

    String v(Object? o) => (o ?? '').toString().trim();
    final email = v(widget.email);
    final phone = v(widget.phone);
    final thixChat = v(widget.thixChat);

    final normalized = widget.contacts
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map((c) {
          final type = v(c['type']).isEmpty ? v(c['kind']) : v(c['type']);
          final label = v(c['label']);
          final value = v(c['value']).isEmpty ? v(c['contact']) : v(c['value']);
          return {'type': type, 'label': label, 'value': value};
        })
        .where((c) => (c['value'] as String).isNotEmpty)
        .toList(growable: false);

    final canExpand = normalized.length > 4;
    final visible = _expanded ? normalized : normalized.take(4).toList(growable: false);

    final hasAny = email.isNotEmpty || phone.isNotEmpty || thixChat.isNotEmpty || normalized.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();

    return SectionCard(
      icon: Icons.contact_phone_rounded,
      title: 'Contacts',
      showAction: canExpand,
      actionLabel: _expanded ? 'Voir moins' : 'Voir plus',
      onActionPressed: canExpand ? () => setState(() => _expanded = !_expanded) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (email.isNotEmpty) ...[
            _ContactRow(icon: Icons.alternate_email_rounded, label: 'Email', value: email),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (phone.isNotEmpty) ...[
            _ContactRow(icon: Icons.call_rounded, label: 'Téléphone', value: phone),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (thixChat.isNotEmpty) ...[
            _ContactRow(icon: Icons.forum_rounded, label: 'THIX Chat', value: thixChat.startsWith('@') ? thixChat : '@$thixChat'),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (visible.isEmpty)
            Text('Aucun contact additionnel.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
          else
            Column(
              children: visible.map((c) {
                final type = c['type'] as String;
                final label = (c['label'] as String).isEmpty ? type : (c['label'] as String);
                final value = c['value'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ContactRow(icon: Icons.alternate_email_rounded, label: label, value: value),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final bg = context.theme.colorScheme.primary.withValues(alpha: 0.035);
    final bd = context.theme.colorScheme.primary.withValues(alpha: 0.10);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: bd)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: LightModeColors.secondaryText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(value, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalInfoExpandableCard extends StatelessWidget {
  final ThixProfile? profile;
  final bool expanded;
  final VoidCallback onToggle;
  final bool canSeePrivate;

  const _PersonalInfoExpandableCard({required this.profile, required this.expanded, required this.onToggle, required this.canSeePrivate});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    String v(String? s) {
      final t = (s ?? '').trim();
      if (!canSeePrivate) return '—';
      return t.isEmpty ? '—' : t;
    }

    final items = <Map<String, String>>[
      {'label': 'Date de naissance', 'value': v(p?.dateOfBirth)},
      {'label': 'Lieu de naissance', 'value': v(p?.placeOfBirth)},
      {'label': 'Nationalité', 'value': v(p?.nationality)},
      {'label': 'Genre', 'value': v(p?.gender)},
      {'label': 'État civil', 'value': v(p?.maritalStatus)},
      {'label': 'Téléphone', 'value': v(p?.contactPhone)},
      {'label': 'Origine / Pays', 'value': v(p?.countryOrOrigin)},
      {'label': 'Adresse', 'value': v(p?.address)},
      {'label': 'Nom du père', 'value': v(p?.fatherName)},
      {'label': 'Nom de la mère', 'value': v(p?.motherName)},
      {'label': 'Contact urgence', 'value': v(p?.emergencyContactName)},
      {'label': 'Téléphone urgence', 'value': v(p?.emergencyContactPhone)},
      {'label': 'Lien (urgence)', 'value': v(p?.emergencyContactRelation)},
    ];

    final nonEmpty = items.where((e) => e['value'] != '—').toList(growable: false);
    final shown = expanded ? (nonEmpty.isEmpty ? items.take(6).toList(growable: false) : nonEmpty) : (nonEmpty.isEmpty ? items.take(6).toList(growable: false) : nonEmpty.take(6).toList(growable: false));
    final canExpand = (nonEmpty.isNotEmpty ? nonEmpty.length : items.length) > 6;

    return SectionCard(
      icon: Icons.badge_outlined,
      title: 'Informations Personnelles',
      showAction: canExpand,
      actionLabel: expanded ? 'Voir moins' : 'Voir plus',
      onActionPressed: onToggle,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 3.0,
          children: shown.map((e) => InfoGridItem(label: e['label']!, value: e['value']!)).toList(growable: false),
        ),
      ),
    );
  }
}

class _AccessGateCard extends StatelessWidget {
  final AccessRequestStatus status;
  final bool isLoggedIn;
  final VoidCallback? onRequest;
  final bool isLoading;
  final bool expired;
  final DateTime? approvedUntil;

  const _AccessGateCard({
    required this.status,
    required this.isLoggedIn,
    required this.onRequest,
    required this.isLoading,
    this.expired = false,
    this.approvedUntil,
  });

  @override
  Widget build(BuildContext context) {
    final bg = context.theme.colorScheme.primary.withValues(alpha: 0.035);
    final bd = context.theme.colorScheme.primary.withValues(alpha: 0.12);

    String title;
    String body;
    String cta;
    bool enabled;

    if (!isLoggedIn) {
      title = 'Accès restreint';
      body = 'Connectez-vous pour demander l’accès au profil.';
      cta = context.loc.t('login');
      enabled = true;
    } else {
      if (expired) {
        title = 'Accès expiré';
        body = 'L’accès au profil est valable 10 minutes. Merci de refaire une demande.';
        cta = 'Redemander l’accès';
        enabled = true;
      } else {
      switch (status) {
        case AccessRequestStatus.pending:
          title = 'Demande envoyée';
          body = 'En attente d’approbation par le propriétaire du profil.';
          cta = 'Demande en attente';
          enabled = false;
          break;
        case AccessRequestStatus.rejected:
          title = 'Accès refusé';
          body = 'Vous pouvez renvoyer une demande si nécessaire.';
          cta = 'Redemander l’accès';
          enabled = true;
          break;
        case AccessRequestStatus.approved:
          title = 'Accès approuvé';
          final until = approvedUntil;
          body = until == null
              ? 'Vous pouvez voir les informations privées de ce profil.'
              : 'Accès actif jusqu’à ${until.toLocal().toString().replaceFirst('T', ' ').split('.').first}';
          cta = 'Accès accordé';
          enabled = false;
          break;
        case AccessRequestStatus.none:
          title = 'Informations masquées';
          body = 'Demandez l’accès pour voir la bio et les informations personnelles.';
          cta = 'Demander l’accès';
          enabled = true;
          break;
      }
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: bd)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: context.theme.colorScheme.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
                alignment: Alignment.center,
                child: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: (!enabled || isLoading)
                ? null
                : () {
                    if (!isLoggedIn) {
                      context.push(AppRoutes.login);
                      return;
                    }
                    onRequest?.call();
                  },
            style: FilledButton.styleFrom(
              backgroundColor: LightModeColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_open_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Text(cta, style: context.textStyles.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SkillsLanguagesCard extends StatefulWidget {
  final bool canSeePrivate;
  final String? competence;
  final List<Map<String, dynamic>> skills;
  final List<String> languages;
  final List<Map<String, dynamic>> languagesDetailed;

  const _SkillsLanguagesCard({required this.canSeePrivate, required this.competence, required this.skills, required this.languages, required this.languagesDetailed});

  @override
  State<_SkillsLanguagesCard> createState() => _SkillsLanguagesCardState();
}

class _SkillsLanguagesCardState extends State<_SkillsLanguagesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final canSeePrivate = widget.canSeePrivate;
    String mask(String v) => canSeePrivate ? (v.trim().isEmpty ? '—' : v.trim()) : '—';
    final skills = widget.skills;
    final languages = widget.languages;
    final competence = (widget.competence ?? '').trim();

    final normalizedSkills = skills
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map((s) {
          final name = (s['name'] as String?) ?? (s['title'] as String?) ?? '';
          final level = (s['level'] as String?) ?? '';
          final details = (s['details'] as String?) ?? (s['description'] as String?) ?? '';
          return {'name': name.trim(), 'level': level.trim(), 'details': details.trim()};
        })
        .where((s) => (s['name'] as String).isNotEmpty)
        .toList(growable: false);

    final detailedLangs = widget.languagesDetailed.whereType<Map>().map((e) => e.cast<String, dynamic>()).map((e) {
      final name = (e['name'] ?? e['language'] ?? '').toString().trim();
      final level = (e['level'] ?? e['niveau'] ?? '').toString().trim();
      return {'name': name, 'level': level};
    }).where((e) => (e['name'] as String).isNotEmpty).toList(growable: false);

    final normalizedLanguages = {
      ...languages.map((e) => e.trim()).where((e) => e.isNotEmpty),
      ...detailedLangs.map((e) => (e['name'] as String).trim()).where((e) => e.isNotEmpty),
    }.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final canExpand = normalizedSkills.length > 3 || normalizedLanguages.length > 3;
    final visibleSkills = _expanded ? normalizedSkills : normalizedSkills.take(3).toList(growable: false);
    final visibleLangs = _expanded ? normalizedLanguages : normalizedLanguages.take(3).toList(growable: false);

    return SectionCard(
      icon: Icons.auto_awesome,
      title: 'Compétences',
      showAction: canExpand,
      actionLabel: _expanded ? 'Voir moins' : 'Voir plus',
      onActionPressed: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canSeePrivate && competence.isNotEmpty) ...[
            Text('Résumé', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Text(competence, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!canSeePrivate)
            Text('Compte personnel: compétences masquées. Demandez l’accès.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
          else if (normalizedSkills.isEmpty)
            Text('Aucune compétence.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: visibleSkills.map((s) {
                final name = s['name'] as String;
                final level = s['level'] as String;
                final details = s['details'] as String;
                final label = level.isEmpty ? name : '$name • $level';
                return Tooltip(message: details.isEmpty ? label : '$label\n${mask(details)}', child: _PillChip(label: label));
              }).toList(growable: false),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Langues', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          if (!canSeePrivate)
            Text('—', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
          else if (normalizedLanguages.isEmpty)
            Text('Aucune langue renseignée.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: visibleLangs.map((l) {
                final match = detailedLangs.where((e) => (e['name'] as String).toLowerCase() == l.toLowerCase()).toList(growable: false);
                final level = match.isEmpty ? '' : (match.first['level'] as String);
                return _PillChip(label: level.trim().isEmpty ? l : '$l • $level', filled: false);
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _EnrollmentsCard extends StatelessWidget {
  final bool canSeePrivate;
  final List<Map<String, dynamic>> enrollments;
  const _EnrollmentsCard({required this.canSeePrivate, required this.enrollments});

  @override
  Widget build(BuildContext context) {
    final list = enrollments.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    return SectionCard(
      icon: Icons.school_rounded,
      title: 'Formations',
      showAction: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!canSeePrivate)
            Text('Compte personnel: formations masquées. Demandez l’accès.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
          else if (list.isEmpty)
            Text('Aucune formation.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))
          else
            Column(
              children: list.take(6).map((e) {
                final title = (e['title'] as String?) ?? 'Formation';
                final provider = (e['provider'] as String?) ?? (e['org'] as String?) ?? '—';
                final status = (e['status'] as String?) ?? '';
                final progress = (e['progress'] as num?)?.toInt();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: LightModeColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: LightModeColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(title, style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.onSurface, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                            if (status.trim().isNotEmpty) _PillChip(label: status.trim(), filled: false),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(provider, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w600)),
                        if (progress != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            child: LinearProgressIndicator(
                              value: (progress.clamp(0, 100)) / 100,
                              minHeight: 7,
                              color: LightModeColors.accent,
                              backgroundColor: LightModeColors.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('$progress% complété', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.hint, fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ProfessionalOverviewCard extends StatelessWidget {
  final bool canSeePrivate;
  final String thixChat;
  final String occupation;
  const _ProfessionalOverviewCard({required this.canSeePrivate, required this.thixChat, required this.occupation});

  @override
  Widget build(BuildContext context) {
    String mask(String v) => canSeePrivate ? (v.trim().isEmpty ? '—' : v.trim()) : '—';
    return SectionCard(
      icon: Icons.work_outline_rounded,
      title: 'Profil Professionnel',
      showAction: false,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 3.0,
        children: [
          InfoGridItem(label: 'THIX Chat', value: mask(thixChat.isEmpty ? '—' : '@$thixChat')),
          InfoGridItem(label: 'Profession', value: mask(occupation)),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool filled;
  const _PillChip({required this.label, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? LightModeColors.primary.withValues(alpha: 0.08) : LightModeColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: filled ? LightModeColors.primary.withValues(alpha: 0.22) : LightModeColors.accent.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.onSurface, fontWeight: FontWeight.w700)),
    );
  }
}

class _DigitalCard extends StatelessWidget {
  final String thixId;
  final String name;
  final String nationality;
  final bool canSeePrivate;
  const _DigitalCard({required this.thixId, required this.name, required this.nationality, required this.canSeePrivate});

  @override
  Widget build(BuildContext context) {
    final payload = thixId.trim().isEmpty ? 'THIX-ID' : thixId.trim();
    final natCode = _countryCode(nationality);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: LightModeColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: LightModeColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Carte Numérique THIX ID', style: context.textStyles.titleMedium?.copyWith(color: LightModeColors.onSurface, fontWeight: FontWeight.w800))),
              Container(
                width: 34,
                height: 22,
                decoration: BoxDecoration(color: LightModeColors.primary, borderRadius: BorderRadius.circular(AppRadius.sm)),
                alignment: Alignment.center,
                child: Text(natCode, style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: LightModeColors.background, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.divider)),
                child: QrImageView(
                  data: payload,
                  size: 96,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: LightModeColors.primary),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: LightModeColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THIX ID', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(payload, style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.onSurface, fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.md),
                    Text(canSeePrivate ? 'Profil accessible selon autorisation.' : 'Accès restreint (compte personnel).', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(name, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                onPressed: payload.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: payload));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR/THIX ID copié.')));
                      },
                icon: const Icon(Icons.copy_rounded, size: 18, color: LightModeColors.primary),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}