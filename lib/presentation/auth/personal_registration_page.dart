import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/common/parcours_form.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/theme.dart';
import 'package:thix_id/presentation/common/date_picker_field.dart';
import 'package:thix_id/services/profile_photo_service.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart'
    if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class FormSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const FormSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: LightModeColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: context.textStyles.titleMedium?.copyWith(
                  color: context.theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: context.textStyles.bodySmall?.copyWith(
              color: LightModeColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class InputField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType type;
  final TextEditingController? controller;

  const InputField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.type = TextInputType.text,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: context.textStyles.labelMedium?.copyWith(
              color: context.theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: context.theme.dividerColor),
              color: context.theme.colorScheme.surface,
            ),
            clipBehavior: Clip.antiAlias,
            child: TextField(
              controller: controller,
              keyboardType: type,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon, color: LightModeColors.hint),
                border: InputBorder.none,
                filled: true,
                fillColor: context.theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StepIndicator extends StatelessWidget {
  final String num;
  final String label;
  final bool active;

  const StepIndicator({
    super.key,
    required this.num,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? LightModeColors.accent : context.theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? LightModeColors.accent : context.theme.dividerColor,
              width: 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: context.textStyles.labelSmall?.copyWith(
              color: active ? const Color(0xFF0A2F5C) : LightModeColors.secondaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: context.textStyles.labelSmall?.copyWith(
            color: active ? LightModeColors.accent : LightModeColors.secondaryText,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class PremiumCard extends StatelessWidget {
  final String headerIcon;
  final String headerTitle;
  final Widget child;

  const PremiumCard({
    super.key,
    required this.headerIcon,
    required this.headerTitle,
    required this.child,
  });

  IconData _getIcon(String iconStr) {
    switch (iconStr) {
      case 'school_rounded':
        return Icons.school_rounded;
      case 'business_center_rounded':
        return Icons.business_center_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: LightModeColors.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 10),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Transform.rotate(
              angle: 45 * 3.14159 / 180,
              child: Container(
                width: 60,
                height: 60,
                color: LightModeColors.accent.withValues(alpha: 0.2),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9C74F).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: Icon(_getIcon(headerIcon), size: 18, color: context.theme.colorScheme.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        headerTitle,
                        style: context.textStyles.titleMedium?.copyWith(
                          color: context.theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: LightModeColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: LightModeColors.error, size: 20),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ],
      ),
    );
  }
}

class PersonalRegistrationPage extends StatefulWidget {
  final int initialStep;
  const PersonalRegistrationPage({super.key, this.initialStep = 1});

  @override
  State<PersonalRegistrationPage> createState() => _PersonalRegistrationPageState();
}

class _PersonalRegistrationPageState extends State<PersonalRegistrationPage> {
  final _firestoreUsers = FirestoreUserService();
  final _docs = DocumentService();
  final _photos = ProfilePhotoService();

  int _step = 1;

  @override
  void initState() {
    super.initState();
    final s = widget.initialStep;
    _step = s < 1 ? 1 : (s > 4 ? 4 : s);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<AuthController>().currentUser;
      if (me == null) return;
      if (_thixChatC.text.trim().isEmpty && (me.thixChat).trim().isNotEmpty) {
        _thixChatC.text = me.thixChat;
      }
    });
  }

  // Step 1: profile + credentials
  final _nameC = TextEditingController();
  final _emailOrPhoneC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();

  final _countryOriginC = TextEditingController();
  final _contactPhoneC = TextEditingController();
  final _dobC = TextEditingController();
  final _placeBirthC = TextEditingController();
  final _nationalityC = TextEditingController();
  final _maritalStatusC = TextEditingController();
  final _genderC = TextEditingController();
  final _occupationC = TextEditingController();
  final _addressC = TextEditingController();
  final _fatherNameC = TextEditingController();
  final _motherNameC = TextEditingController();

  // Structured origin & residence (Step 1)
  final _originProvinceC = TextEditingController();
  final _originTerritoryC = TextEditingController();
  final _originSectorC = TextEditingController();

  final _residenceCountryC = TextEditingController(text: 'RDC');
  final _residenceProvinceC = TextEditingController();
  final _residenceTerritoryC = TextEditingController();
  final _residenceCityC = TextEditingController();
  final _residenceCommuneC = TextEditingController();
  final _residenceQuarterC = TextEditingController();
  final _residenceAvenueC = TextEditingController();
  final _residenceNumberC = TextEditingController();

  // Emergency contacts (multi-add)
  final List<_EmergencyContactControllers> _emergencyContacts = [_EmergencyContactControllers()];

  // Step 2: parcours
  final _bioC = TextEditingController();
  final _competenceC = TextEditingController();

  // Physical / identity (Step 1)
  final _heightC = TextEditingController();
  final _weightC = TextEditingController();
  final _bloodGroupC = TextEditingController();
  bool _hasDisability = false;
  final _disabilityDescC = TextEditingController();
  final _nationalIdC = TextEditingController();
  final _idDocTypeC = TextEditingController();
  final _idIssueDateC = TextEditingController();
  final _idExpiryDateC = TextEditingController();
  final _idIssuePlaceC = TextEditingController();

  // Step 4: final - THIX CHAT (modifiable)
  final _thixChatC = TextEditingController();

  final List<EducationEntryControllers> _education = [EducationEntryControllers()];
  final List<ExperienceEntryControllers> _experience = [ExperienceEntryControllers()];

  bool _rememberMe = true;
  bool _isLoading = false;
  PlatformFile? _pickedPhoto;
  PhoneAuthSession? _phoneSession;
  final List<_PendingRegistrationDoc> _pendingDocs = [];

  @override
  void dispose() {
    _nameC.dispose();
    _emailOrPhoneC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    _countryOriginC.dispose();
    _contactPhoneC.dispose();
    _dobC.dispose();
    _placeBirthC.dispose();
    _nationalityC.dispose();
    _maritalStatusC.dispose();
    _genderC.dispose();
    _occupationC.dispose();
    _addressC.dispose();
    _fatherNameC.dispose();
    _motherNameC.dispose();
    _originProvinceC.dispose();
    _originTerritoryC.dispose();
    _originSectorC.dispose();
    _residenceCountryC.dispose();
    _residenceProvinceC.dispose();
    _residenceTerritoryC.dispose();
    _residenceCityC.dispose();
    _residenceCommuneC.dispose();
    _residenceQuarterC.dispose();
    _residenceAvenueC.dispose();
    _residenceNumberC.dispose();
    for (final c in _emergencyContacts) {
      c.dispose();
    }
    _bioC.dispose();
    _competenceC.dispose();
    _heightC.dispose();
    _weightC.dispose();
    _bloodGroupC.dispose();
    _disabilityDescC.dispose();
    _nationalIdC.dispose();
    _idDocTypeC.dispose();
    _idIssueDateC.dispose();
    _idExpiryDateC.dispose();
    _idIssuePlaceC.dispose();
    _thixChatC.dispose();
    for (final e in _education) e.dispose();
    for (final e in _experience) e.dispose();
    super.dispose();
  }

  bool get _hasAnyDoc => _pendingDocs.isNotEmpty;

  bool _looksLikePhone(String s) => RegExp(r'^\+?[0-9][0-9\s\-]{7,}$').hasMatch(s.trim());
  bool _looksLikeEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  bool _hasSupabaseSession() => Supabase.instance.client.auth.currentSession != null;

  void _handleUnauthedWrite() {
    if (!mounted) return;
    _snack('Session expirée. Connectez-vous pour continuer.');
    context.go(AppRoutes.login);
  }

  String _rawSupabaseError(Object e) {
    if (e is PostgrestException) return 'PostgrestException: ${e.message} (code: ${e.code})';
    return e.toString();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_dobC.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 110),
      lastDate: DateTime(now.year - 10),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: LightModeColors.accent)), child: child!),
    );
    if (picked == null) return;
    final v = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _dobC.text = v);
  }

  /// Validates step 1 (profile + credentials) without creating the account.
  ///
  /// User requirement: the account must only be created after ALL steps are
  /// filled (profil + parcours + documents).
  bool _validateStep1() {
    final name = _nameC.text.trim();
    final id = _emailOrPhoneC.text.trim();
    final pass = _passwordC.text;
    final confirm = _confirmC.text;

    if (name.isEmpty) {
      _snack('Nom complet requis.');
      return false;
    }
    if (id.isEmpty) {
      _snack('Email ou téléphone requis.');
      return false;
    }
    if (!_looksLikeEmail(id) && !_looksLikePhone(id)) {
      _snack('Email ou téléphone invalide.');
      return false;
    }
    if (pass.trim().length < 8 && !_looksLikePhone(id)) {
      _snack('Mot de passe: minimum 8 caractères.');
      return false;
    }
    if (!_looksLikePhone(id) && pass != confirm) {
      _snack('Les mots de passe ne correspondent pas.');
      return false;
    }

    if (_countryOriginC.text.trim().isEmpty) {
      _snack('Origines / Pays d\'origine requis.');
      return false;
    }
    if (_contactPhoneC.text.trim().isEmpty) {
      _snack('Téléphone de contact requis.');
      return false;
    }
    if (_dobC.text.trim().isEmpty) {
      _snack('Date de naissance requise.');
      return false;
    }
    if (_placeBirthC.text.trim().isEmpty) {
      _snack('Lieu de naissance requis.');
      return false;
    }
    if (_nationalityC.text.trim().isEmpty) {
      _snack('Nationalité requise.');
      return false;
    }
    if (_genderC.text.trim().isEmpty) {
      _snack('Genre requis.');
      return false;
    }
    if (_maritalStatusC.text.trim().isEmpty) {
      _snack('Statut matrimonial requis.');
      return false;
    }
    if (_occupationC.text.trim().isEmpty) {
      _snack('Profession / Occupation requise.');
      return false;
    }
    if (_addressC.text.trim().isEmpty) {
      _snack('Résidence / Adresse requise.');
      return false;
    }
    if (_fatherNameC.text.trim().isEmpty || _motherNameC.text.trim().isEmpty) {
      _snack('Nom du père et de la mère requis.');
      return false;
    }
    // Origine
    if (_originProvinceC.text.trim().isEmpty) {
      _snack('Province d\'origine requise.');
      return false;
    }
    // Territoire: saisie libre (optionnel). On supprime le blocage basé sur le catalogue interne.
    if (_originSectorC.text.trim().isEmpty) {
      _snack('Secteur d\'origine requis.');
      return false;
    }

    // Résidence
    if (_residenceCountryC.text.trim().isEmpty) {
      _snack('Pays de résidence requis.');
      return false;
    }
    if (_residenceProvinceC.text.trim().isEmpty) {
      _snack('Province de résidence requise.');
      return false;
    }
    // Territoire: saisie libre (optionnel). On supprime le blocage basé sur le catalogue interne.
    if (_residenceCityC.text.trim().isEmpty) {
      _snack('Ville de résidence requise.');
      return false;
    }
    if (_residenceCommuneC.text.trim().isEmpty) {
      _snack('Commune de résidence requise.');
      return false;
    }

    // Emergency contacts
    final primary = _emergencyContacts.isEmpty ? null : _emergencyContacts.first;
    if (primary == null || primary.nameC.text.trim().isEmpty || primary.phoneC.text.trim().isEmpty) {
      _snack('Contact d\'urgence (nom + téléphone) requis.');
      return false;
    }
    if (primary.relationC.text.trim().isEmpty) {
      _snack('Relation du contact d\'urgence requise (ex: frère, mère, ami).');
      return false;
    }
    return true;
  }

  Map<String, dynamic> _buildStep1ProfilePatch() {
    final contacts = _emergencyContacts
        .map((e) => e.toMap())
        .where((m) => (m['name'] as String).trim().isNotEmpty || (m['phone'] as String).trim().isNotEmpty)
        .toList(growable: false);
    final primary = contacts.isNotEmpty ? contacts.first : null;
    final addr = _addressC.text.trim().isNotEmpty
        ? _addressC.text.trim()
        : [
            _residenceCityC.text.trim(),
            _residenceQuarterC.text.trim(),
            _residenceAvenueC.text.trim().isEmpty ? '' : 'Av. ${_residenceAvenueC.text.trim()}',
            _residenceNumberC.text.trim().isEmpty ? '' : 'N° ${_residenceNumberC.text.trim()}',
          ].where((e) => e.trim().isNotEmpty).join(', ');

    return {
      'full_name': _nameC.text.trim(),
      'display_name': _nameC.text.trim(),
      'country_or_origin': _countryOriginC.text.trim(),
      'contact_phone': _contactPhoneC.text.trim(),
      'date_of_birth': _dobC.text.trim(),
      'place_of_birth': _placeBirthC.text.trim(),
      'nationality': _nationalityC.text.trim(),
      'marital_status': _maritalStatusC.text.trim(),
      'gender': _genderC.text.trim(),
      'occupation': _occupationC.text.trim(),
      'address': addr,
      'father_name': _fatherNameC.text.trim(),
      'mother_name': _motherNameC.text.trim(),
      // Backward-compatible primary emergency contact fields
      'emergency_contact_name': primary?['name'] ?? '',
      'emergency_contact_phone': primary?['phone'] ?? '',
      'emergency_contact_relation': primary?['relation'] ?? '',
      // Structured origin/residence
      'origin_province': _originProvinceC.text.trim(),
      'origin_territory': _originTerritoryC.text.trim(),
      'origin_sector': _originSectorC.text.trim(),
      'residence_country': _residenceCountryC.text.trim(),
      'residence_province': _residenceProvinceC.text.trim(),
      'residence_territory': _residenceTerritoryC.text.trim(),
      'residence_city': _residenceCityC.text.trim(),
      'residence_commune': _residenceCommuneC.text.trim(),
      'residence_quarter': _residenceQuarterC.text.trim(),
      'residence_avenue': _residenceAvenueC.text.trim(),
      'residence_number': _residenceNumberC.text.trim(),
      'emergency_contacts': contacts,
      // Physical/identity
      'height': _heightC.text.trim(),
      'weight': _weightC.text.trim(),
      'blood_group': _bloodGroupC.text.trim(),
      'has_physical_disability': _hasDisability,
      'physical_disability_description': _disabilityDescC.text.trim(),
      'national_id_number': _nationalIdC.text.trim(),
      'id_document_type': _idDocTypeC.text.trim(),
      'id_document_issue_date': _idIssueDateC.text.trim(),
      'id_document_expiry_date': _idExpiryDateC.text.trim(),
      'id_document_issue_place': _idIssuePlaceC.text.trim(),
      'registration_status': 'draft_step1',
    };
  }

  Future<void> _saveStep1AndEnsureAccount() async {
    if (_isLoading) return;
    if (!_validateStep1()) return;

    final auth = context.read<AuthController>();
    final draft = _buildStep1ProfilePatch();

    setState(() => _isLoading = true);
    try {
      if (auth.currentUser == null) {
        final name = _nameC.text.trim();
        final id = _emailOrPhoneC.text.trim();
        final pass = _passwordC.text;

        if (_looksLikePhone(id) && !id.contains('@')) {
          if (kIsWeb) {
            _snack('Inscription par SMS non disponible dans la Preview web. Utilisez un email ou testez sur Android/iOS.');
            return;
          }
          if (_phoneSession == null) {
            _phoneSession = await auth.startPhoneAuth(phoneNumber: id);
            if (!mounted) return;
            _snack('SMS envoyé. Entrez le code dans “Mot de passe” puis validez.');
            return;
          }
          await auth.confirmPhoneCode(session: _phoneSession!, smsCode: pass, displayName: name, accountType: AccountType.personal);
        } else {
          await auth.registerPersonal(email: id, password: pass, displayName: name, rememberMe: _rememberMe, profileDraft: draft);
        }
      }

      final me = auth.currentUser;
      if (me == null) throw Exception('Session utilisateur introuvable.');
      if (!_hasSupabaseSession()) {
        _handleUnauthedWrite();
        return;
      }

      // Persist step1 to Supabase.
      await _firestoreUsers.updateProfile(
        uid: me.id,
        displayName: _nameC.text.trim(),
        fullName: _nameC.text.trim(),
        countryOrOrigin: _countryOriginC.text.trim(),
        contactPhone: _contactPhoneC.text.trim(),
        dateOfBirth: _dobC.text.trim(),
        placeOfBirth: _placeBirthC.text.trim(),
        nationality: _nationalityC.text.trim(),
        maritalStatus: _maritalStatusC.text.trim(),
        gender: _genderC.text.trim(),
        occupation: _occupationC.text.trim(),
        address: (draft['address'] as String?) ?? _addressC.text.trim(),
        fatherName: _fatherNameC.text.trim(),
        motherName: _motherNameC.text.trim(),
        emergencyContactName: (draft['emergency_contact_name'] as String?) ?? '',
        emergencyContactPhone: (draft['emergency_contact_phone'] as String?) ?? '',
        emergencyContactRelation: (draft['emergency_contact_relation'] as String?) ?? '',
        originProvince: _originProvinceC.text.trim(),
        originTerritory: _originTerritoryC.text.trim(),
        originSector: _originSectorC.text.trim(),
        residenceCountry: _residenceCountryC.text.trim(),
        residenceProvince: _residenceProvinceC.text.trim(),
        residenceTerritory: _residenceTerritoryC.text.trim(),
        residenceCity: _residenceCityC.text.trim(),
        residenceCommune: _residenceCommuneC.text.trim(),
        residenceQuarter: _residenceQuarterC.text.trim(),
        residenceAvenue: _residenceAvenueC.text.trim(),
        residenceNumber: _residenceNumberC.text.trim(),
        emergencyContacts: (draft['emergency_contacts'] as List).cast<Map<String, dynamic>>(),
        height: _heightC.text.trim(),
        weight: _weightC.text.trim(),
        bloodGroup: _bloodGroupC.text.trim(),
        hasPhysicalDisability: _hasDisability,
        physicalDisabilityDescription: _disabilityDescC.text.trim(),
        nationalIdNumber: _nationalIdC.text.trim(),
        idDocumentType: _idDocTypeC.text.trim(),
        idDocumentIssueDate: _idIssueDateC.text.trim(),
        idDocumentExpiryDate: _idExpiryDateC.text.trim(),
        idDocumentIssuePlace: _idIssuePlaceC.text.trim(),
        registrationStatus: 'draft_step1',
      );

      if (_pickedPhoto != null) {
        final url = await _photos.uploadProfilePhoto(uid: me.id, file: _pickedPhoto!);
        await _firestoreUsers.updateProfile(uid: me.id, photoUrl: url);
      }
    } catch (e) {
      debugPrint('PersonalReg: save step1 failed err=$e');
      if (!mounted) return;
      _snack(_rawSupabaseError(e));
      rethrow;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Account creation is handled earlier (Step 1) to allow real-time saving to Supabase.

  Future<void> _pickPhoto() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image, withData: kIsWeb, allowMultiple: false);
      if (res == null || res.files.isEmpty) return;
      setState(() => _pickedPhoto = res.files.first);
    } catch (e) {
      debugPrint('PersonalReg: pick photo failed err=$e');
      if (!mounted) return;
      _snack('Sélection image impossible.');
    }
  }

  ImageProvider? _photoPreview() {
    final f = _pickedPhoto;
    if (f == null) return null;
    if (kIsWeb) {
      final bytes = f.bytes;
      if (bytes == null) return null;
      return MemoryImage(bytes);
    }
    final path = f.path;
    if (path == null) return null;
    return FileImage(fileFromPath(path) as dynamic);
  }

  Future<void> _next() async {
    if (_isLoading) return;
    if (_step == 1) {
      try {
        await _saveStep1AndEnsureAccount();
      } catch (_) {
        return;
      }
      if (!mounted) return;
      // If phone flow is awaiting SMS confirmation, we stay on step 1.
      if (context.read<AuthController>().currentUser == null) return;
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      final parcoursError = _validateParcours();
      if (parcoursError != null) {
        _snack(parcoursError);
        return;
      }

      final me = context.read<AuthController>().currentUser;
      if (me == null) {
        _snack('Session expirée.');
        setState(() => _step = 1);
        return;
      }
      if (!_hasSupabaseSession()) {
        _handleUnauthedWrite();
        return;
      }

      setState(() => _isLoading = true);
      try {
        await _firestoreUsers.updateProfile(
          uid: me.id,
          bio: _bioC.text.trim(),
          competence: _competenceC.text.trim(),
          education: _education.map((e) => e.toMap()).toList(growable: false),
          experience: _experience.map((e) => e.toMap()).toList(growable: false),
          registrationStatus: 'draft_step2',
        );
      } catch (e) {
        debugPrint('PersonalReg: save step2 failed uid=${me.id} err=$e');
        if (!mounted) return;
        _snack(_rawSupabaseError(e));
        return;
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }

      if (!mounted) return;
      setState(() => _step = 3);
      return;
    }
    if (_step == 3) {
      // Require at least one document to be selected before account creation.
      if (!_hasAnyDoc) {
        _snack('Ajoutez au moins un document avant de continuer.');
        return;
      }

      // Account already created at step 1; we now prepare identifiers.
      final me = context.read<AuthController>().currentUser;
      if (me == null) {
        _snack('Compte non disponible après inscription.');
        return;
      }
      if (!_hasSupabaseSession()) {
        _handleUnauthedWrite();
        return;
      }

      setState(() => _isLoading = true);
      try {
        final cc = _nationalityC.text.trim().isNotEmpty ? _nationalityC.text.trim() : _countryOriginC.text.trim();
        final thixId = await _firestoreUsers.ensureThixId(uid: me.id, countryCode: cc);
        final suggested = _suggestChatFromName(_nameC.text.trim());
        final claimed = await _firestoreUsers.ensureThixChat(uid: me.id, desired: _thixChatC.text.trim().isEmpty ? suggested : _thixChatC.text);
        _thixChatC.text = claimed;
        await _firestoreUsers.updateProfile(uid: me.id, registrationStatus: 'identifiers_ready', thixChat: claimed);
        debugPrint('PersonalReg: identifiers prepared uid=${me.id} thixId=$thixId thixChat=$claimed');
      } catch (e) {
        debugPrint('PersonalReg: identifiers prepare failed uid=${me.id} err=$e');
        if (!mounted) return;
        final msg = e.toString();
        if (msg.contains('Not authenticated') || msg.toLowerCase().contains('jwt') || msg.contains('42501')) {
          _handleUnauthedWrite();
          return;
        }
        _snack(_rawSupabaseError(e));
        return;
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }

      if (!mounted) return;
      setState(() => _step = 4);
      return;
    }
    if (_step == 4) {
      await _proceedToPayment();
      return;
    }
  }

  void _back() {
    if (_isLoading) return;
    if (_step <= 1) {
      context.popOrGo(AppRoutes.home);
      return;
    }
    setState(() => _step -= 1);
  }

  String _suggestChatFromName(String name) {
    final base = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList().isEmpty
        ? 'user'
        : name.trim().split(RegExp(r'\s+')).first;
    final cleaned = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
    final candidate = '@${cleaned.isEmpty ? 'user' : cleaned}${suffix.padLeft(4, '0')}';
    return candidate.length > 21 ? candidate.substring(0, 21) : candidate;
  }

  String? _validateParcours() {
    final bio = _bioC.text.trim();
    if (bio.isEmpty) return 'Bio requise (présentez-vous en quelques lignes).';
    if (bio.length < 40) return 'Bio trop courte (minimum 40 caractères).';

    bool hasValidEducation = false;
    for (final e in _education) {
      final level = e.levelC.text.trim().toLowerCase();
      final institution = e.institutionC.text.trim();
      final city = e.cityC.text.trim();
      final degree = e.degreeC.text.trim();
      final start = e.startYearC.text.trim();
      final degreeRequired = level.startsWith('sup') || level.startsWith('for');
      final ok = institution.isNotEmpty && city.isNotEmpty && start.isNotEmpty && (!degreeRequired || degree.isNotEmpty);
      if (ok) {
        hasValidEducation = true;
        break;
      }
    }
    if (!hasValidEducation) return 'Ajoutez au moins 1 cursus (niveau + établissement + ville + année début).';

    bool hasValidExperience = false;
    for (final e in _experience) {
      final company = e.companyC.text.trim();
      final city = e.cityC.text.trim();
      final title = e.titleC.text.trim();
      final missions = e.missionsC.text.trim();
      if (company.isNotEmpty && city.isNotEmpty && title.isNotEmpty && missions.isNotEmpty) {
        hasValidExperience = true;
        break;
      }
    }
    if (!hasValidExperience) return 'Ajoutez au moins 1 expérience (entreprise + ville + titre + missions).';

    return null;
  }

  Future<void> _proceedToPayment() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) {
      _snack('Session expirée.');
      setState(() => _step = 1);
      return;
    }
    if (!_hasSupabaseSession()) {
      _handleUnauthedWrite();
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Reserve/validate THIX CHAT before payment.
      final claimed = await _firestoreUsers.ensureThixChat(uid: me.id, desired: _thixChatC.text);
      await _firestoreUsers.updateProfile(uid: me.id, thixChat: claimed, registrationStatus: 'awaiting_payment');
      if (!mounted) return;

      final receiptReturn = Uri.encodeComponent('/activation-receipt');
      context.push('${AppRoutes.payment}?returnTo=$receiptReturn');
    } catch (e) {
      debugPrint('PersonalReg: submit failed uid=${me.id} err=$e');
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('Not authenticated') || msg.toLowerCase().contains('jwt') || msg.contains('42501')) {
        _handleUnauthedWrite();
        return;
      }
      if (msg.toLowerCase().contains('déjà utilisé')) {
        _snack('THIX CHAT déjà utilisé. Choisissez un autre.');
      } else if (msg.toLowerCase().contains('invalide')) {
        _snack('THIX CHAT invalide. Exemple: thix.john_23');
      } else {
        _snack(_rawSupabaseError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadDoc() async {
    final picked = await FilePicker.pickFiles(withData: kIsWeb);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (!mounted) return;

    final payload = await showModalBottomSheet<_RegUploadDocPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegistrationUploadDocumentSheet(fileName: file.name),
    );
    if (payload == null) return;

    final me = context.read<AuthController>().currentUser;
    if (me == null) {
      setState(() => _pendingDocs.add(_PendingRegistrationDoc(file: file, docId: payload.docId, title: payload.title, docType: payload.docType, expiresAt: payload.expiresAt)));
      _snack('Document ajouté (sera upload après création du compte).');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _docs.uploadPickedFile(uid: me.id, docId: payload.docId, title: payload.title, file: file, docType: payload.docType, expiresAt: payload.expiresAt);
      _snack('Document uploadé.');
    } catch (e) {
      debugPrint('PersonalReg: doc upload failed uid=${me.id} err=$e');
      setState(() => _pendingDocs.add(_PendingRegistrationDoc(file: file, docId: payload.docId, title: payload.title, docType: payload.docType, expiresAt: payload.expiresAt)));
      _snack('Upload impossible maintenant. Document mis en attente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _primaryCta() {
    final label = switch (_step) {
      1 => _isLoading ? 'CRÉATION…' : 'SUIVANT (PARCOURS)',
      2 => _isLoading ? 'SAUVEGARDE…' : 'SUIVANT (DOCUMENTS)',
      3 => _isLoading ? 'PRÉPARATION…' : 'SUIVANT (IDENTIFIANTS)',
      4 => _isLoading ? 'PRÉPARATION…' : 'CONFIRMER & PAYER',
      _ => 'CONTINUER',
    };
    return GestureDetector(
      onTap: _isLoading ? null : _next,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: LightModeColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: const Color(0xFFE5B644), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF0A2F5C))),
              const SizedBox(width: AppSpacing.md),
            ],
            Text(label, style: context.textStyles.labelLarge?.copyWith(color: const Color(0xFF0A2F5C), fontWeight: FontWeight.w900)),
            const SizedBox(width: AppSpacing.md),
            const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0A2F5C), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _stepContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          1 => _Step1Profile(
              photoPreview: _photoPreview(),
              onPickPhoto: _isLoading ? null : _pickPhoto,
              nameC: _nameC,
              emailOrPhoneC: _emailOrPhoneC,
              passwordC: _passwordC,
              confirmC: _confirmC,
              rememberMe: _rememberMe,
              onRememberChanged: _isLoading ? null : (v) => setState(() => _rememberMe = v),
              countryOriginC: _countryOriginC,
              contactPhoneC: _contactPhoneC,
              dobC: _dobC,
              onPickDob: _isLoading ? null : _pickDob,
              placeBirthC: _placeBirthC,
              nationalityC: _nationalityC,
              maritalStatusC: _maritalStatusC,
              genderC: _genderC,
              occupationC: _occupationC,
              addressC: _addressC,
              fatherNameC: _fatherNameC,
              motherNameC: _motherNameC,
              originProvinceC: _originProvinceC,
              originTerritoryC: _originTerritoryC,
              originSectorC: _originSectorC,
              residenceCountryC: _residenceCountryC,
              residenceProvinceC: _residenceProvinceC,
              residenceTerritoryC: _residenceTerritoryC,
              residenceCityC: _residenceCityC,
              residenceCommuneC: _residenceCommuneC,
              residenceQuarterC: _residenceQuarterC,
              residenceAvenueC: _residenceAvenueC,
              residenceNumberC: _residenceNumberC,
              emergencyContacts: _emergencyContacts,
              onAddEmergencyContact: _isLoading
                  ? null
                  : () => setState(() => _emergencyContacts.add(_EmergencyContactControllers())),
              onRemoveEmergencyContact: _isLoading
                  ? null
                  : (idx) {
                      if (_emergencyContacts.length <= 1) return;
                      setState(() {
                        final removed = _emergencyContacts.removeAt(idx);
                        removed.dispose();
                      });
                    },
              heightC: _heightC,
              weightC: _weightC,
              bloodGroupC: _bloodGroupC,
              hasDisability: _hasDisability,
              onHasDisabilityChanged: _isLoading ? null : (v) => setState(() => _hasDisability = v),
              disabilityDescC: _disabilityDescC,
              nationalIdC: _nationalIdC,
              idDocTypeC: _idDocTypeC,
              idIssueDateC: _idIssueDateC,
              idExpiryDateC: _idExpiryDateC,
              idIssuePlaceC: _idIssuePlaceC,
            ),
          2 => ParcoursForm(
              header: const FormSectionHeader(title: 'Compétences', subtitle: 'Ajoutez un résumé clair de vos compétences.'),
              bioC: _bioC,
              competenceC: _competenceC,
              education: _education,
              experience: _experience,
              enabled: !_isLoading,
              onAddEducation: () => setState(() => _education.add(EducationEntryControllers())),
              onRemoveEducation: (i) => setState(() => _education.removeAt(i).dispose()),
              onAddExperience: () => setState(() => _experience.add(ExperienceEntryControllers())),
              onRemoveExperience: (i) => setState(() => _experience.removeAt(i).dispose()),
            ),
          3 => _Step3Documents(onAddDoc: _pickAndUploadDoc, docCount: _pendingDocs.length),
          4 => _Step4Final(thixChatC: _thixChatC),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 190),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _stepContent(),
                        const SizedBox(height: AppSpacing.xl),
                        _primaryCta(),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _isLoading ? null : _back,
                          child: Text(
                            _step <= 1 ? 'Retour' : 'Précédent',
                            style: context.textStyles.labelMedium?.copyWith(color: LightModeColors.secondaryText),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: context.theme.dividerColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_user_rounded, color: LightModeColors.success, size: 18),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                "Données sécurisées par cryptage THIX ID Protocol v2.0",
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: LightModeColors.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0A3D62), Color(0xFF051F33)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _back,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "THIX ID",
                              style: context.textStyles.titleLarge?.copyWith(
                                color: LightModeColors.accent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              "IDENTITÉ SÉCURISÉE",
                              style: context.textStyles.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9C74F).withValues(alpha: 0.2),
                            border: Border.all(color: LightModeColors.accent),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.verified_user_rounded, color: LightModeColors.accent, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: LightModeColors.accent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          StepIndicator(num: '1', label: 'Profil', active: _step == 1),
                          StepIndicator(num: '2', label: 'Parcours', active: _step == 2),
                          StepIndicator(num: '3', label: 'Docs', active: _step == 3),
                          StepIndicator(num: '4', label: 'Identifiants', active: _step == 4),
                        ],
                      ),
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

class _EmergencyContactControllers {
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final relationC = TextEditingController();

  void dispose() {
    nameC.dispose();
    phoneC.dispose();
    relationC.dispose();
  }

  Map<String, dynamic> toMap() => {
        'name': nameC.text.trim(),
        'phone': phoneC.text.trim(),
        'relation': relationC.text.trim(),
      };
}

class _Step1Profile extends StatelessWidget {
  final ImageProvider? photoPreview;
  final VoidCallback? onPickPhoto;
  final TextEditingController nameC;
  final TextEditingController emailOrPhoneC;
  final TextEditingController passwordC;
  final TextEditingController confirmC;
  final bool rememberMe;
  final ValueChanged<bool>? onRememberChanged;

  final TextEditingController countryOriginC;
  final TextEditingController contactPhoneC;
  final TextEditingController dobC;
  final VoidCallback? onPickDob;
  final TextEditingController placeBirthC;
  final TextEditingController nationalityC;
  final TextEditingController maritalStatusC;
  final TextEditingController genderC;
  final TextEditingController occupationC;
  final TextEditingController addressC;
  final TextEditingController fatherNameC;
  final TextEditingController motherNameC;

  final TextEditingController originProvinceC;
  final TextEditingController originTerritoryC;
  final TextEditingController originSectorC;

  final TextEditingController residenceCountryC;
  final TextEditingController residenceProvinceC;
  final TextEditingController residenceTerritoryC;
  final TextEditingController residenceCityC;
  final TextEditingController residenceCommuneC;
  final TextEditingController residenceQuarterC;
  final TextEditingController residenceAvenueC;
  final TextEditingController residenceNumberC;

  final List<_EmergencyContactControllers> emergencyContacts;
  final VoidCallback? onAddEmergencyContact;
  final void Function(int index)? onRemoveEmergencyContact;

  final TextEditingController heightC;
  final TextEditingController weightC;
  final TextEditingController bloodGroupC;
  final bool hasDisability;
  final ValueChanged<bool>? onHasDisabilityChanged;
  final TextEditingController disabilityDescC;
  final TextEditingController nationalIdC;
  final TextEditingController idDocTypeC;
  final TextEditingController idIssueDateC;
  final TextEditingController idExpiryDateC;
  final TextEditingController idIssuePlaceC;

  const _Step1Profile({
    required this.photoPreview,
    required this.onPickPhoto,
    required this.nameC,
    required this.emailOrPhoneC,
    required this.passwordC,
    required this.confirmC,
    required this.rememberMe,
    required this.onRememberChanged,
    required this.countryOriginC,
    required this.contactPhoneC,
    required this.dobC,
    required this.onPickDob,
    required this.placeBirthC,
    required this.nationalityC,
    required this.maritalStatusC,
    required this.genderC,
    required this.occupationC,
    required this.addressC,
    required this.fatherNameC,
    required this.motherNameC,
    required this.originProvinceC,
    required this.originTerritoryC,
    required this.originSectorC,
    required this.residenceCountryC,
    required this.residenceProvinceC,
    required this.residenceTerritoryC,
    required this.residenceCityC,
    required this.residenceCommuneC,
    required this.residenceQuarterC,
    required this.residenceAvenueC,
    required this.residenceNumberC,
    required this.emergencyContacts,
    required this.onAddEmergencyContact,
    required this.onRemoveEmergencyContact,
    required this.heightC,
    required this.weightC,
    required this.bloodGroupC,
    required this.hasDisability,
    required this.onHasDisabilityChanged,
    required this.disabilityDescC,
    required this.nationalIdC,
    required this.idDocTypeC,
    required this.idIssueDateC,
    required this.idExpiryDateC,
    required this.idIssuePlaceC,
  });

  static const List<String> _genderChoices = ['Homme', 'Femme', 'Autre'];
  static const List<String> _maritalChoices = ['Célibataire', 'Marié(e)', 'Divorcé(e)', 'Veuf(ve)'];
  static const List<String> _nationalityChoices = [
    'Congolaise (RDC)',
    'Congolaise (RC)',
    'Rwandaise',
    'Burundaise',
    'Ougandaise',
    'Angolaise',
    'Ivoirienne',
    'Sénégalaise',
    'Camerounaise',
    'Autre',
  ];

  String? _normalizeChoice(String raw, List<String> choices) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final idx = choices.indexWhere((c) => c.toLowerCase() == t.toLowerCase());
    if (idx == -1) return null;
    return choices[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: LightModeColors.accent.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.person_pin_rounded, size: 18, color: context.theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Profil Personnel (Étape 1/4)', style: context.textStyles.titleMedium?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Renseignez votre identité complète, origines, filiation et contact d\'urgence.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: LightModeColors.accent.withValues(alpha: 0.65), width: 2),
                      image: DecorationImage(
                        image: photoPreview ?? const AssetImage('assets/images/African_businessman_in_suit_grayscale_1775573970767.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickPhoto,
                      icon: const Icon(Icons.add_a_photo_rounded),
                      label: const Text('Ajouter une photo'),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Nom complet',
                  prefixIcon: const Icon(Icons.person_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: countryOriginC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Origines / Pays d\'origine',
                  prefixIcon: const Icon(Icons.public_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: contactPhoneC,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Contact (Téléphone personnel)',
                  prefixIcon: const Icon(Icons.call_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onPickDob,
                  icon: const Icon(Icons.cake_rounded),
                  label: Text(dobC.text.trim().isEmpty ? 'Date de naissance (obligatoire)' : 'Date de naissance: ${dobC.text.trim()}'),
                  style: OutlinedButton.styleFrom(foregroundColor: context.theme.colorScheme.primary, side: BorderSide(color: context.theme.dividerColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: placeBirthC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Lieu de naissance',
                  prefixIcon: const Icon(Icons.location_on_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 420;
                  final a = DropdownButtonFormField<String>(
                    value: _normalizeChoice(nationalityC.text, _nationalityChoices),
                    items: _nationalityChoices.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(growable: false),
                    selectedItemBuilder: (context) => _nationalityChoices.map((e) => Text(e, maxLines: 1, overflow: TextOverflow.ellipsis)).toList(growable: false),
                    onChanged: (v) => nationalityC.text = v ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Nationalité',
                      prefixIcon: const Icon(Icons.flag_rounded),
                      filled: true,
                      fillColor: context.theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  );

                  final b = DropdownButtonFormField<String>(
                    value: _normalizeChoice(maritalStatusC.text, _maritalChoices),
                    items: _maritalChoices.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(growable: false),
                    selectedItemBuilder: (context) => _maritalChoices.map((e) => Text(e, maxLines: 1, overflow: TextOverflow.ellipsis)).toList(growable: false),
                    onChanged: (v) => maritalStatusC.text = v ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'État civil',
                      prefixIcon: const Icon(Icons.favorite_rounded),
                      filled: true,
                      fillColor: context.theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  );

                  if (isNarrow) {
                    return Column(children: [a, const SizedBox(height: AppSpacing.md), b]);
                  }
                  return Row(children: [Expanded(child: a), const SizedBox(width: AppSpacing.md), Expanded(child: b)]);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 420;
                  final a = DropdownButtonFormField<String>(
                    value: _normalizeChoice(genderC.text, _genderChoices),
                    items: _genderChoices.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(growable: false),
                    selectedItemBuilder: (context) => _genderChoices.map((e) => Text(e, maxLines: 1, overflow: TextOverflow.ellipsis)).toList(growable: false),
                    onChanged: (v) => genderC.text = v ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Genre',
                      prefixIcon: const Icon(Icons.wc_rounded),
                      filled: true,
                      fillColor: context.theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  );

                  final b = TextField(
                    controller: occupationC,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Profession (optionnel)',
                      prefixIcon: const Icon(Icons.work_rounded, color: LightModeColors.hint),
                      filled: true,
                      fillColor: context.theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                    ),
                  );

                  if (isNarrow) {
                    return Column(children: [a, const SizedBox(height: AppSpacing.md), b]);
                  }
                  return Row(children: [Expanded(child: a), const SizedBox(width: AppSpacing.md), Expanded(child: b)]);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: addressC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Adresse',
                  prefixIcon: const Icon(Icons.home_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fatherNameC,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Nom du père',
                        prefixIcon: const Icon(Icons.man_rounded, color: LightModeColors.hint),
                        filled: true,
                        fillColor: context.theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: motherNameC,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Nom de la mère',
                        prefixIcon: const Icon(Icons.woman_rounded, color: LightModeColors.hint),
                        filled: true,
                        fillColor: context.theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: context.theme.dividerColor, thickness: 1),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(Icons.map_rounded, size: 18, color: context.theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Origine', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: originProvinceC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Province d\'origine',
                  hintText: 'Commencez à saisir…',
                  prefixIcon: const Icon(Icons.map_outlined, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: originTerritoryC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Territoire (optionnel)',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: originSectorC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Secteur',
                  prefixIcon: const Icon(Icons.hub_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(Icons.my_location_rounded, size: 18, color: context.theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Résidence actuelle', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: residenceCountryC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Pays',
                  prefixIcon: const Icon(Icons.public_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: residenceProvinceC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Province',
                  hintText: 'Commencez à saisir…',
                  prefixIcon: const Icon(Icons.map_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: residenceTerritoryC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Territoire (optionnel)',
                  prefixIcon: const Icon(Icons.location_on_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: residenceCityC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Ville',
                  hintText: 'Commencez à saisir…',
                  prefixIcon: const Icon(Icons.location_city_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: residenceCommuneC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Commune',
                  hintText: 'Commencez à saisir…',
                  prefixIcon: const Icon(Icons.apartment_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: residenceQuarterC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Quartier',
                  prefixIcon: const Icon(Icons.people_alt_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: residenceAvenueC,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Avenue',
                        prefixIcon: const Icon(Icons.route_rounded, color: LightModeColors.hint),
                        filled: true,
                        fillColor: context.theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: residenceNumberC,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Numéro',
                        prefixIcon: const Icon(Icons.numbers_rounded, color: LightModeColors.hint),
                        filled: true,
                        fillColor: context.theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(Icons.contact_emergency_rounded, size: 18, color: context.theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Contacts d\'urgence', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...List.generate(emergencyContacts.length, (i) {
                final c = emergencyContacts[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: context.theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: context.theme.dividerColor)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: c.nameC,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: i == 0 ? 'Nom (principal)' : 'Nom',
                                  prefixIcon: const Icon(Icons.person_add_alt_rounded, color: LightModeColors.hint),
                                  filled: true,
                                  fillColor: context.theme.scaffoldBackgroundColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                ),
                              ),
                            ),
                            if (i > 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                onPressed: onRemoveEmergencyContact == null ? null : () => onRemoveEmergencyContact!(i),
                                icon: const Icon(Icons.delete_outline_rounded, color: LightModeColors.error),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: c.phoneC,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: 'Contact',
                                  prefixIcon: const Icon(Icons.call_rounded, color: LightModeColors.hint),
                                  filled: true,
                                  fillColor: context.theme.scaffoldBackgroundColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextField(
                                controller: c.relationC,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: 'Lien',
                                  prefixIcon: const Icon(Icons.family_restroom_rounded, color: LightModeColors.hint),
                                  filled: true,
                                  fillColor: context.theme.scaffoldBackgroundColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: onAddEmergencyContact,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Ajouter un contact (multi)'),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: context.theme.dividerColor, thickness: 1),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, size: 18, color: context.theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Informations physiques & identité', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: heightC,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Taille (cm)',
                        prefixIcon: const Icon(Icons.height_rounded, color: LightModeColors.hint),
                        filled: true,
                        fillColor: context.theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: weightC,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Poids (kg)',
                        prefixIcon: const Icon(Icons.monitor_weight_rounded, color: LightModeColors.hint),
                        filled: true,
                        fillColor: context.theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: bloodGroupC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Groupe sanguin (A+, O-, …)',
                  prefixIcon: const Icon(Icons.bloodtype_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                value: hasDisability,
                onChanged: onHasDisabilityChanged,
                activeColor: LightModeColors.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Handicap physique'),
                subtitle: Text(hasDisability ? 'Oui' : 'Non'),
              ),
              if (hasDisability) ...[
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: disabilityDescC,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Description du handicap',
                    prefixIcon: const Icon(Icons.notes_rounded, color: LightModeColors.hint),
                    filled: true,
                    fillColor: context.theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nationalIdC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Numéro ID national',
                  prefixIcon: const Icon(Icons.badge_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: idDocTypeC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Type de pièce (Passeport, Carte…)',
                  prefixIcon: const Icon(Icons.credit_card_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DatePickerField(
                      controller: idIssueDateC,
                      enabled: true,
                      labelText: 'Date émission',
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icons.event_available_rounded,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DatePickerField(
                      controller: idExpiryDateC,
                      enabled: true,
                      labelText: 'Date expiration',
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icons.event_busy_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: idIssuePlaceC,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Lieu émission',
                  prefixIcon: const Icon(Icons.location_on_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: context.theme.dividerColor, thickness: 1),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(Icons.badge_rounded, size: 18, color: context.theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Accès THIX ID', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: emailOrPhoneC,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Email ou Téléphone',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: passwordC,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Mot de passe (ou code SMS)',
                  prefixIcon: const Icon(Icons.lock_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: confirmC,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.verified_user_rounded, color: LightModeColors.hint),
                  filled: true,
                  fillColor: context.theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Switch(value: rememberMe, onChanged: onRememberChanged, activeColor: LightModeColors.accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text('Rester connecté sur cet appareil', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step3Documents extends StatelessWidget {
  final VoidCallback onAddDoc;
  final int docCount;
  const _Step3Documents({required this.onAddDoc, required this.docCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionHeader(title: 'Documents', subtitle: 'Ajoutez vos pièces justificatives. Plusieurs documents sont possibles.'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: context.theme.colorScheme.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: context.theme.dividerColor)),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: LightModeColors.secondaryText),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Pour les pièces d\'identité (CIN / Passeport), la date d\'expiration est obligatoire.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: context.theme.colorScheme.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: context.theme.dividerColor)),
          child: Row(
            children: [
              Icon(Icons.folder_copy_rounded, color: context.theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Documents sélectionnés: $docCount', style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onAddDoc,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un document'),
            style: OutlinedButton.styleFrom(foregroundColor: context.theme.colorScheme.primary, side: BorderSide(color: context.theme.colorScheme.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
          ),
        ),
      ],
    );
  }
}

class _Step4Final extends StatelessWidget {
  final TextEditingController thixChatC;
  const _Step4Final({required this.thixChatC});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentUser;
    final thixId = me?.thixId.trim().isEmpty ?? true ? '—' : me!.thixId;
    final uid = (me?.id ?? '').trim().isEmpty ? '—' : me!.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionHeader(title: 'Identifiants', subtitle: 'Vérifiez votre THIX ID et choisissez votre Chat ID avant paiement.'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: context.theme.colorScheme.surface, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: LightModeColors.accent, width: 1.5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: LightModeColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadius.md)),
                    alignment: Alignment.center,
                    child: Icon(Icons.verified_user_rounded, color: context.theme.colorScheme.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('Votre THIX ID', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(thixId, style: context.textStyles.displaySmall?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.sm),
              Text('Ce code sera visible sur votre profil et utilisé pour la vérification.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: context.theme.colorScheme.surface, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: context.theme.dividerColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: context.theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
                    alignment: Alignment.center,
                    child: Icon(Icons.key_rounded, color: context.theme.colorScheme.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('UID (non modifiable)', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SelectableText(uid, style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.lg),
              Text('THIX CHAT (modifiable)', style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: thixChatC,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'ex: @thix.john_23',
                  prefixIcon: const Icon(Icons.forum_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
               Text('Règles: @ + 3–20 caractères (a-z, 0-9, . ou _). Unique.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegUploadDocPayload {
  final String docId;
  final String title;
  final String docType;
  final DateTime? expiresAt;
  const _RegUploadDocPayload({required this.docId, required this.title, required this.docType, required this.expiresAt});
}

class _PendingRegistrationDoc {
  final PlatformFile file;
  final String docId;
  final String title;
  final String docType;
  final DateTime? expiresAt;

  const _PendingRegistrationDoc({required this.file, required this.docId, required this.title, required this.docType, required this.expiresAt});
}

class _RegistrationUploadDocumentSheet extends StatefulWidget {
  final String fileName;
  const _RegistrationUploadDocumentSheet({required this.fileName});

  @override
  State<_RegistrationUploadDocumentSheet> createState() => _RegistrationUploadDocumentSheetState();
}

class _RegistrationUploadDocumentSheetState extends State<_RegistrationUploadDocumentSheet> {
  final _docIdC = TextEditingController();
  final _titleC = TextEditingController();
  String _type = 'Autre';
  DateTime? _expiresAt;

  @override
  void dispose() {
    _docIdC.dispose();
    _titleC.dispose();
    super.dispose();
  }

  bool get _needsExpiry => _type == 'CIN' || _type == 'Passeport' || _type == 'Permis';

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 20)),
      lastDate: now.add(const Duration(days: 365 * 50)),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: LightModeColors.accent)), child: child!),
    );
    if (picked != null) setState(() => _expiresAt = DateTime(picked.year, picked.month, picked.day));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final expiryLabel = _expiresAt == null ? 'Choisir une date' : '${_expiresAt!.year.toString().padLeft(4, '0')}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl)),
          border: Border.all(color: context.theme.dividerColor),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ajouter un document', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded))
              ],
            ),
            Text(widget.fileName, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'CIN', child: Text('Pièce d\'identité — CIN')),
                DropdownMenuItem(value: 'Passeport', child: Text('Pièce d\'identité — Passeport')),
                DropdownMenuItem(value: 'Permis', child: Text('Pièce d\'identité — Permis')),
                DropdownMenuItem(value: 'Diplôme', child: Text('Diplôme / Attestation')),
                DropdownMenuItem(value: 'PreuveAdresse', child: Text('Preuve d\'adresse')),
                DropdownMenuItem(value: 'Autre', child: Text('Autre')),
              ],
              onChanged: (v) => setState(() {
                _type = v ?? 'Autre';
                if (!_needsExpiry) _expiresAt = null;
              }),
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Type de document', prefixIcon: const Icon(Icons.folder_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _docIdC,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: 'Doc ID', hintText: 'CIN-2023-001', prefixIcon: const Icon(Icons.tag_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleC,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: 'Titre', hintText: 'Carte d\'identité nationale', prefixIcon: const Icon(Icons.description_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_needsExpiry)
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _pickExpiry,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text('Date d\'expiration: $expiryLabel'),
                  style: OutlinedButton.styleFrom(foregroundColor: context.theme.colorScheme.primary, side: BorderSide(color: context.theme.colorScheme.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                ),
              ),
            if (_needsExpiry) const SizedBox(height: AppSpacing.lg) else const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  final docId = _docIdC.text.trim();
                  if (docId.isEmpty) {
                    _snack('Doc ID requis.');
                    return;
                  }
                  if (_needsExpiry && _expiresAt == null) {
                    _snack('Date d\'expiration requise pour cette pièce.');
                    return;
                  }
                  context.pop(_RegUploadDocPayload(docId: docId, title: _titleC.text, docType: _type, expiresAt: _expiresAt));
                },
                icon: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF0A2F5C)),
                label: const Text('UPLOAD'),
                style: ElevatedButton.styleFrom(backgroundColor: LightModeColors.accent, foregroundColor: const Color(0xFF0A2F5C), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}