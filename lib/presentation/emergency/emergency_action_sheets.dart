import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/services/emergency_service.dart';
import 'package:thix_id/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class EmergencyActionSheets {
  static Color _sheetBarrierColor(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // IMPORTANT: keep the underlying Emergency overlay from “bleeding through”.
    // We want a fully opaque barrier so the form never looks transparent.
    return isDark ? DarkModeColors.background : Colors.white;
  }

  static Future<EmergencyBloodPayload?> showBloodSheet(BuildContext context) async {
    return await showModalBottomSheet<EmergencyBloodPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: _sheetBarrierColor(context),
      builder: (context) => const _BloodSheet(),
    );
  }

  static Future<EmergencyAccidentPayload?> showAccidentSheet(BuildContext context) async {
    return await showModalBottomSheet<EmergencyAccidentPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: _sheetBarrierColor(context),
      builder: (context) => const _AccidentSheet(),
    );
  }

  static Future<EmergencyAnonymousReportPayload?> showAnonymousReportSheet(BuildContext context) async {
    return await showModalBottomSheet<EmergencyAnonymousReportPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: _sheetBarrierColor(context),
      builder: (context) => const _AnonymousReportSheet(),
    );
  }

  static Future<List<TrustedContact>?> showTrustedContactsSheet(BuildContext context, List<TrustedContact> initial) async {
    return await showModalBottomSheet<List<TrustedContact>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: _sheetBarrierColor(context),
      builder: (context) => _TrustedContactsSheet(initial: initial),
    );
  }

  static Future<void> shareLiveLocation({required BuildContext context, required double lat, required double lng, String? label}) async {
    final mapsUrl = 'https://www.google.com/maps?q=$lat,$lng';
    final text = '${label ?? 'THIX ID'} — Position en direct: $mapsUrl';
    try {
      await Share.share(text);
    } catch (e) {
      debugPrint('EmergencyActionSheets: share failed: $e');
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié dans le presse-papiers.')));
      }
    }
  }

  static Future<void> launchPhoneCall(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appel indisponible sur cet appareil.')));
      }
    } catch (e) {
      debugPrint('EmergencyActionSheets: call failed: $e');
    }
  }

  static Future<void> launchSms(BuildContext context, {required String phone, required String body}) async {
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(body)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS indisponible sur cet appareil.')));
      }
    } catch (e) {
      debugPrint('EmergencyActionSheets: sms failed: $e');
    }
  }

  static Future<void> launchMaps(BuildContext context, {required double lat, required double lng}) async {
    // Google Maps works broadly across platforms; if not installed it opens browser.
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d’ouvrir la carte.')));
      }
    } catch (e) {
      debugPrint('EmergencyActionSheets: maps failed: $e');
    }
  }
}

class EmergencyBloodPayload {
  final String intent; // donate|request
  final String bloodGroup;
  final double urgency01; // 0..1 (stable -> critical)

  // Identity / medical contact
  final String? requesterName;
  final String? doctorName;
  final String? doctorQualification;
  final String? doctorId;
  final String? contact;

  final String? hospitalOrPlace;
  final double? lat;
  final double? lng;
  final int? quantityBags;
  final String? note;
  final String? city;
  final PlatformFile? medicalProofPhoto;

  const EmergencyBloodPayload({
    required this.intent,
    required this.bloodGroup,
    required this.urgency01,
    this.requesterName,
    this.doctorName,
    this.doctorQualification,
    this.doctorId,
    this.contact,
    this.hospitalOrPlace,
    this.lat,
    this.lng,
    this.quantityBags,
    this.note,
    this.city,
    this.medicalProofPhoto,
  });

  Map<String, dynamic> toMetadata() => {
    'blood_intent': intent,
    'blood_group': bloodGroup,
    'urgency': urgency01,
    if (requesterName != null) 'requester_name': requesterName,
    if (doctorName != null) 'doctor_name': doctorName,
    if (doctorQualification != null) 'doctor_qualification': doctorQualification,
    if (doctorId != null) 'doctor_id': doctorId,
    if (contact != null) 'contact': contact,
    if (hospitalOrPlace != null) 'hospital_or_place': hospitalOrPlace,
    if (lat != null && lng != null) 'requested_location': {'lat': lat, 'lng': lng},
    if (quantityBags != null) 'quantity_bags': quantityBags,
    'has_medical_proof': medicalProofPhoto != null,
    if (note != null) 'note': note,
    if (city != null) 'city': city,
  };
}

class EmergencyAccidentPayload {
  final String? description;
  final List<PlatformFile> photos;
  const EmergencyAccidentPayload({required this.description, required this.photos});

  Map<String, dynamic> toMetadata() => {
    'has_photos': photos.isNotEmpty,
    if (description != null) 'description': description,
  };
}

class EmergencyAnonymousReportPayload {
  final String category;
  final String description;
  final List<PlatformFile> attachments;
  const EmergencyAnonymousReportPayload({required this.category, required this.description, required this.attachments});

  Map<String, dynamic> toMetadata() => {
    'anonymous': true,
    'category': category,
    'description': description,
    'attachment_count': attachments.length,
  };
}

class _SheetFrame extends StatelessWidget {
  final Widget child;
  final bool medical;
  const _SheetFrame({required this.child, this.medical = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Default: premium gold sheet. Medical sheets use a clean clinic background.
    final gold = isDark ? DarkModeColors.metalGold : LightModeColors.metalGold;
    final goldSoft = isDark ? DarkModeColors.metalGoldSoft : LightModeColors.metalGoldSoft;
    final surface = theme.colorScheme.surface;

    final Gradient gradient;
    final Color border;
    if (medical && !isDark) {
      gradient = EmergencyMedicalSheetGradients.background();
      border = EmergencyMedicalSheetColors.stroke;
    } else {
      final tintedSurface = Color.alphaBlend(goldSoft.withValues(alpha: isDark ? 0.14 : 0.18), surface);
      gradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [surface, tintedSurface]);
      border = gold.withValues(alpha: isDark ? 0.34 : 0.22);
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient,
              border: Border.all(color: border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _UrgencyScale {
  static const _t1 = 0.40;
  static const _t2 = 0.65;
  static const _t3 = 0.85;

  static String label(double v) {
    if (v >= _t3) return 'Critique';
    if (v >= _t2) return 'Urgent';
    if (v >= _t1) return 'Modéré';
    return 'Stable';
  }

  static Color color(double v) {
    if (v >= _t3) return EmergencyUrgencyScaleColors.critical;
    if (v >= _t2) return EmergencyUrgencyScaleColors.urgent;
    if (v >= _t1) return EmergencyUrgencyScaleColors.moderate;
    return EmergencyUrgencyScaleColors.stable;
  }

  static Color stepColor(double v01) {
    if (v01 >= _t3) return EmergencyUrgencyScaleColors.critical;
    if (v01 >= _t2) return EmergencyUrgencyScaleColors.urgent;
    if (v01 >= _t1) return EmergencyUrgencyScaleColors.moderate;
    return EmergencyUrgencyScaleColors.stable;
  }
}

class _UrgencyTrackShape extends SliderTrackShape {
  const _UrgencyTrackShape();

  @override
  Rect getPreferredRect({required RenderBox parentBox, Offset offset = Offset.zero, required SliderThemeData sliderTheme, bool isEnabled = false, bool isDiscrete = false}) {
    final trackHeight = sliderTheme.trackHeight ?? 6;
    final left = offset.dx + (sliderTheme.overlayShape?.getPreferredSize(isEnabled, isDiscrete).width ?? 0) / 2;
    final top = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final width = parentBox.size.width - left * 2;
    return Rect.fromLTWH(left, top, width, trackHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset, {required RenderBox parentBox, required SliderThemeData sliderTheme, required Animation<double> enableAnimation, required Offset thumbCenter, Offset? secondaryOffset, bool isEnabled = false, bool isDiscrete = false, required TextDirection textDirection}) {
    final canvas = context.canvas;
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete);
    final r = Radius.circular(rect.height / 2);
    final full = RRect.fromRectAndRadius(rect, r);
    final paint = Paint()..style = PaintingStyle.fill;

    // Background track
    paint.color = EmergencyMedicalSheetColors.stroke;
    canvas.drawRRect(full, paint);

    // Colored segments (Stable / Moderate / Urgent / Critical)
    final segs = [
      const _Seg(0.0, 0.40, EmergencyUrgencyScaleColors.stable),
      const _Seg(0.40, 0.65, EmergencyUrgencyScaleColors.moderate),
      const _Seg(0.65, 0.85, EmergencyUrgencyScaleColors.urgent),
      const _Seg(0.85, 1.0, EmergencyUrgencyScaleColors.critical),
    ];
    for (final s in segs) {
      final l = rect.left + rect.width * s.a;
      final w = rect.width * (s.b - s.a);
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(l, rect.top, w, rect.height), r);
      paint.color = s.c.withValues(alpha: 0.90);
      canvas.drawRRect(rr, paint);
    }

    // Tick dots (for discrete feel)
    const steps = 10;
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dotR = rect.height * 0.18;
    for (int i = 0; i <= steps; i++) {
      final v = i / steps;
      dotPaint.color = _UrgencyScale.stepColor(v).withValues(alpha: 0.85);
      final x = rect.left + rect.width * v;
      final y = rect.center.dy;
      canvas.drawCircle(Offset(x, y), dotR, dotPaint);
    }

    // Current value highlight up to thumb
    final leftToThumb = Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom);
    final highlight = RRect.fromRectAndRadius(leftToThumb, r);
    paint.color = sliderTheme.activeTrackColor ?? EmergencyMedicalSheetColors.medicalBlue;
    canvas.drawRRect(highlight, paint..color = paint.color.withValues(alpha: 0.22));
  }
}

class _Seg {
  final double a;
  final double b;
  final Color c;
  const _Seg(this.a, this.b, this.c);
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accent;
  const _SheetHeader({required this.icon, required this.title, required this.subtitle, this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = isDark ? DarkModeColors.metalGold : LightModeColors.metalGold;
    final goldSoft = isDark ? DarkModeColors.metalGoldSoft : LightModeColors.metalGoldSoft;
    final a = isDark ? gold : (accent ?? gold);
    final aSoft = isDark ? goldSoft : (accent == null ? goldSoft : EmergencyMedicalSheetColors.medicalBlueSoft);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  aSoft.withValues(alpha: isDark ? 0.12 : 0.72),
                  Colors.white.withValues(alpha: isDark ? 0.06 : 0.80),
                  a.withValues(alpha: isDark ? 0.18 : 0.14),
                ],
              ),
              border: Border.all(color: a.withValues(alpha: isDark ? 0.45 : 0.25)),
            ),
            child: Icon(icon, color: a),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textStyles.titleLarge?.semiBold),
                const SizedBox(height: 2),
                Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ),
          ),
          IconButton(onPressed: () => context.pop(), icon: Icon(Icons.close_rounded, color: theme.hintColor)),
        ],
      ),
    );
  }
}

class _BloodSheet extends StatefulWidget {
  const _BloodSheet();

  @override
  State<_BloodSheet> createState() => _BloodSheetState();
}

class _BloodSheetState extends State<_BloodSheet> {
  String _intent = 'request';
  String _group = 'O+';
  double _urgency01 = 0.70;

  final _requesterName = TextEditingController();
  final _doctorName = TextEditingController();
  final _doctorQualification = TextEditingController();
  final _doctorId = TextEditingController();
  final _contact = TextEditingController();

  final _city = TextEditingController();
  final _hospital = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();

  Position? _pos;
  bool _gettingPos = false;
  PlatformFile? _medicalProof;

  @override
  void dispose() {
    _requesterName.dispose();
    _doctorName.dispose();
    _doctorQualification.dispose();
    _doctorId.dispose();
    _contact.dispose();
    _city.dispose();
    _hospital.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  String _urgencyLabel(double v) => _UrgencyScale.label(v);

  Future<void> _useGps() async {
    if (_gettingPos) return;
    setState(() => _gettingPos = true);
    try {
      final pos = await EmergencyService().getCurrentPosition();
      if (!mounted) return;
      setState(() => _pos = pos);
    } catch (e) {
      debugPrint('BloodSheet: getCurrentPosition failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de récupérer la position GPS.')));
      }
    } finally {
      if (mounted) setState(() => _gettingPos = false);
    }
  }

  Future<void> _pickMedicalProof() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image, allowMultiple: false, withData: kIsWeb);
      if (res == null || res.files.isEmpty) return;
      setState(() => _medicalProof = res.files.first);
    } catch (e) {
      debugPrint('BloodSheet: pick proof failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const groups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final medical = isDark ? theme.colorScheme.tertiary : EmergencyMedicalSheetColors.medicalBlue;
    final isRequest = _intent == 'request';

    final qty = int.tryParse(_quantity.text.trim());
    final requesterName = _requesterName.text.trim();
    final doctorName = _doctorName.text.trim();
    final doctorQualification = _doctorQualification.text.trim();
    final doctorId = _doctorId.text.trim();
    final contact = _contact.text.trim();

    final requestIdentityOk = !isRequest || (requesterName.isNotEmpty && doctorName.isNotEmpty && doctorQualification.isNotEmpty && doctorId.isNotEmpty && contact.isNotEmpty);
    final requestQtyOk = !isRequest || (qty != null && qty > 0);
    final canSubmit = _group.trim().isNotEmpty && requestQtyOk && requestIdentityOk;

    final maxH = MediaQuery.of(context).size.height * 0.88;
    return _SheetFrame(
      medical: !isDark,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          children: [
            _SheetHeader(icon: Icons.bloodtype_rounded, title: 'Sang', subtitle: 'Donner ou demander — matching rapide', accent: EmergencyMedicalSheetColors.medicalBlue),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: Column(
                  children: [
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: EmergencyMedicalSheetColors.text,
                        selectedForegroundColor: Colors.white,
                        selectedBackgroundColor: EmergencyMedicalSheetColors.medicalBlue,
                        side: BorderSide(color: EmergencyMedicalSheetColors.stroke),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      segments: const [
                        ButtonSegment(value: 'request', label: Text('Demander')),
                        ButtonSegment(value: 'donate', label: Text('Donner')),
                      ],
                      selected: {_intent},
                      onSelectionChanged: (s) => setState(() => _intent = s.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: _group,
                      items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(growable: false),
                      onChanged: (v) => setState(() => _group = v ?? 'O+'),
                      decoration: const InputDecoration(labelText: 'Groupe sanguin requis'),
                    ),
                    if (isRequest) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _requesterName,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Nom du demandeur'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _contact,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Contact (téléphone / WhatsApp)'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _doctorName,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Nom du médecin'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextField(
                              controller: _doctorQualification,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Qualification'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _doctorId,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'ID / Matricule du médecin'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text('Degré d\'urgence', style: context.textStyles.titleSmall?.semiBold),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.full),
                                color: _UrgencyScale.color(_urgency01).withValues(alpha: 0.12),
                                border: Border.all(color: _UrgencyScale.color(_urgency01).withValues(alpha: 0.25)),
                              ),
                              child: Text(_urgencyLabel(_urgency01), style: context.textStyles.labelMedium?.copyWith(color: _UrgencyScale.color(_urgency01)).semiBold),
                            ),
                          ],
                        ),
                      ),
                      SliderTheme(
                        data: theme.sliderTheme.copyWith(
                          trackHeight: 7,
                          trackShape: const _UrgencyTrackShape(),
                          activeTrackColor: _UrgencyScale.color(_urgency01),
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: _UrgencyScale.color(_urgency01),
                          overlayColor: _UrgencyScale.color(_urgency01).withValues(alpha: 0.12),
                          valueIndicatorColor: _UrgencyScale.color(_urgency01),
                        ),
                        child: Slider(
                          value: _urgency01,
                          onChanged: (v) => setState(() => _urgency01 = v),
                          divisions: 10,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _hospital,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Hôpital / Lieu (manuel)'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _gettingPos ? null : _useGps,
                              icon: Icon(Icons.my_location_rounded, color: medical),
                              label: Text(_pos == null ? 'GPS auto' : 'GPS OK', style: TextStyle(color: medical)),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _pos == null ? 'Aucune position' : '±${_pos!.accuracy.toStringAsFixed(0)}m',
                              textAlign: TextAlign.right,
                              style: context.textStyles.bodySmall?.copyWith(color: theme.hintColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Quantité (poches)'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _pickMedicalProof,
                        icon: Icon(Icons.upload_rounded, color: medical),
                        label: Text(
                          _medicalProof == null ? 'Justificatif médical (photo)' : 'Justificatif: ${_medicalProof!.name}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: medical),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ] else ...[
                      const SizedBox(height: AppSpacing.md),
                      TextField(controller: _city, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Ville / Zone (optionnel)')),
                      const SizedBox(height: AppSpacing.md),
                      TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Détails (optionnel)')),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: !canSubmit
                          ? null
                          : () {
                          final city = _city.text.trim();
                          final hospital = _hospital.text.trim();
                          final note = _note.text.trim();
                          final qty = int.tryParse(_quantity.text.trim());
                          final requesterName = _requesterName.text.trim();
                          final doctorName = _doctorName.text.trim();
                          final doctorQualification = _doctorQualification.text.trim();
                          final doctorId = _doctorId.text.trim();
                          final contact = _contact.text.trim();

                          if (isRequest && (requesterName.isEmpty || doctorName.isEmpty || doctorQualification.isEmpty || doctorId.isEmpty || contact.isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci de compléter les informations du demandeur et du médecin.')));
                            return;
                          }
                          context.pop(
                            EmergencyBloodPayload(
                              intent: _intent,
                              bloodGroup: _group,
                              urgency01: isRequest ? _urgency01 : 0.0,
                              requesterName: isRequest && requesterName.isNotEmpty ? requesterName : null,
                              doctorName: isRequest && doctorName.isNotEmpty ? doctorName : null,
                              doctorQualification: isRequest && doctorQualification.isNotEmpty ? doctorQualification : null,
                              doctorId: isRequest && doctorId.isNotEmpty ? doctorId : null,
                              contact: isRequest && contact.isNotEmpty ? contact : null,
                              hospitalOrPlace: isRequest && hospital.isNotEmpty ? hospital : null,
                              lat: isRequest ? _pos?.latitude : null,
                              lng: isRequest ? _pos?.longitude : null,
                              quantityBags: isRequest ? (qty != null && qty > 0 ? qty : null) : null,
                              medicalProofPhoto: isRequest ? _medicalProof : null,
                              city: city.isEmpty ? null : city,
                              note: note.isEmpty ? null : note,
                            ),
                          );
                        },
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text('Lancer la demande', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccidentSheet extends StatefulWidget {
  const _AccidentSheet();

  @override
  State<_AccidentSheet> createState() => _AccidentSheetState();
}

class _AccidentSheetState extends State<_AccidentSheet> {
  final _desc = TextEditingController();
  List<PlatformFile> _photos = const [];

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image, allowMultiple: true, withData: kIsWeb);
      if (res == null) return;
      setState(() => _photos = res.files);
    } catch (e) {
      debugPrint('AccidentSheet: pick photo failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.tertiary;
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHeader(icon: Icons.car_crash_rounded, title: 'Signaler un accident', subtitle: 'Photo + position + alerte communauté'),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              children: [
                TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optionnel)')),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _pickPhotos,
                  icon: Icon(Icons.add_a_photo_rounded, color: gold),
                  label: Text(_photos.isEmpty ? 'Ajouter une photo' : 'Photos (${_photos.length})', style: TextStyle(color: gold)),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    context.pop(EmergencyAccidentPayload(description: _desc.text.trim().isEmpty ? null : _desc.text.trim(), photos: _photos));
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  label: const Text('Envoyer le signalement', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnonymousReportSheet extends StatefulWidget {
  const _AnonymousReportSheet();

  @override
  State<_AnonymousReportSheet> createState() => _AnonymousReportSheetState();
}

class _AnonymousReportSheetState extends State<_AnonymousReportSheet> {
  String _cat = 'Corruption';
  final _desc = TextEditingController();
  List<PlatformFile> _files = const [];

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickProofs() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.any, allowMultiple: true, withData: kIsWeb);
      if (res == null) return;
      setState(() => _files = res.files);
    } catch (e) {
      debugPrint('AnonymousReportSheet: pick proofs failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.tertiary;
    const categories = ['Corruption', 'Fraude', 'Abus', 'Arnaque', 'Autre'];
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHeader(icon: Icons.gpp_maybe_rounded, title: 'Dénoncer (anonyme)', subtitle: 'Preuves audio/doc/image — envoyé aux admins'),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _cat,
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(growable: false),
                  onChanged: (v) => setState(() => _cat = v ?? 'Corruption'),
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Décrivez les faits (obligatoire)')),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _pickProofs,
                  icon: Icon(Icons.attach_file_rounded, color: gold),
                  label: Text(_files.isEmpty ? 'Ajouter des preuves' : 'Preuves (${_files.length})', style: TextStyle(color: gold)),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    final d = _desc.text.trim();
                    if (d.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci de décrire les faits.')));
                      return;
                    }
                    context.pop(EmergencyAnonymousReportPayload(category: _cat, description: d, attachments: _files));
                  },
                  icon: const Icon(Icons.lock_rounded, color: Colors.white),
                  label: const Text('Envoyer anonymement', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustedContactsSheet extends StatefulWidget {
  final List<TrustedContact> initial;
  const _TrustedContactsSheet({required this.initial});

  @override
  State<_TrustedContactsSheet> createState() => _TrustedContactsSheetState();
}

class _TrustedContactsSheetState extends State<_TrustedContactsSheet> {
  late List<TrustedContact> _contacts = [...widget.initial];

  Future<void> _add() async {
    final res = await showDialog<TrustedContact>(
      context: context,
      builder: (context) => const _AddTrustedContactDialog(),
    );
    if (res == null) return;
    setState(() => _contacts = [..._contacts, res]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.tertiary;
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHeader(icon: Icons.group_rounded, title: 'Contacts de confiance', subtitle: 'Famille / amis — SMS + position live'),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              children: [
                if (_contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text('Ajoutez au moins 1 contact pour pouvoir alerter rapidement.', style: context.textStyles.bodyMedium?.copyWith(color: theme.hintColor)),
                  )
                else
                  ..._contacts.asMap().entries.map((e) {
                    final i = e.key;
                    final c = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: gold.withValues(alpha: 0.14), child: Icon(Icons.person_rounded, color: gold)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: context.textStyles.titleMedium?.semiBold),
                                const SizedBox(height: 2),
                                Text(c.phone, style: context.textStyles.bodySmall?.copyWith(color: theme.hintColor)),
                              ],
                            ),
                          ),
                          IconButton(onPressed: () => setState(() => _contacts = [..._contacts]..removeAt(i)), icon: Icon(Icons.delete_outline_rounded, color: LightModeColors.error)),
                        ],
                      ),
                    );
                  }),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _add,
                          icon: Icon(Icons.person_add_alt_1_rounded, color: gold),
                          label: Text('Ajouter', style: TextStyle(color: gold)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.pop(_contacts),
                        icon: const Icon(Icons.save_rounded, color: Colors.white),
                        label: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                      ),
                    ),
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

class _AddTrustedContactDialog extends StatefulWidget {
  const _AddTrustedContactDialog();

  @override
  State<_AddTrustedContactDialog> createState() => _AddTrustedContactDialogState();
}

class _AddTrustedContactDialogState extends State<_AddTrustedContactDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom'), textInputAction: TextInputAction.next),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Téléphone (ex: +243...)'), keyboardType: TextInputType.phone),
        ],
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final n = _name.text.trim();
            final p = _phone.text.trim();
            if (n.isEmpty || p.isEmpty) return;
            context.pop(TrustedContact(name: n, phone: p));
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
