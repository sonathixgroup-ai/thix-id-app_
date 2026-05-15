import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../nav.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/services/profile_photo_service.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart'
    if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class FormLabel extends StatelessWidget {
  final String label;
  final bool required;

  const FormLabel({
    super.key,
    required this.label,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            label,
            style: context.textStyles.labelLarge?.copyWith(
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          if (required) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              '*',
              style: context.textStyles.labelLarge?.copyWith(
                color: LightModeColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const SectionHeader({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: LightModeColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: context.textStyles.labelLarge?.copyWith(
                    color: const Color(0xFF0A2F5C),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: context.textStyles.titleLarge?.copyWith(
                    color: context.theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: context.textStyles.bodyMedium?.copyWith(
              color: LightModeColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class EnterpriseRegistrationPage extends StatefulWidget {
  const EnterpriseRegistrationPage({super.key});

  @override
  State<EnterpriseRegistrationPage> createState() => _EnterpriseRegistrationPageState();
}

class _EnterpriseRegistrationPageState extends State<EnterpriseRegistrationPage> {
  final _firestoreUsers = FirestoreUserService();
  final _photos = ProfilePhotoService();
  final _companyNameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;

  PlatformFile? _pickedPhoto;
  PhoneAuthSession? _phoneSession;

  bool _hasSupabaseSession() => Supabase.instance.client.auth.currentSession != null;

  void _handleUnauthedWrite() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session expirée. Connectez-vous pour continuer.')));
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _companyNameC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _createEnterprise() async {
    final auth = context.read<AuthController>();
    final name = _companyNameC.text.trim();
    final email = _emailC.text.trim();
    final pass = _passwordC.text;
    final confirm = _confirmC.text;
    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez compléter Entreprise, Email et Mot de passe.')));
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Les mots de passe ne correspondent pas.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_looksLikePhone(email) && !email.contains('@')) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inscription par SMS non disponible dans la Preview web. Utilisez un email ou testez sur Android/iOS.')));
          return;
        }
        if (_phoneSession == null) {
          _phoneSession = await auth.startPhoneAuth(phoneNumber: email);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS envoyé. Entrez le code dans “Mot de passe” puis validez.')));
          return;
        }
        await auth.confirmPhoneCode(session: _phoneSession!, smsCode: pass, displayName: name, accountType: AccountType.enterprise);
        if (!mounted) return;
        await _prepareEnterpriseAndGoToPayment(companyName: name);
        return;
      }

      await auth.registerEnterprise(
        email: email,
        password: pass,
        displayName: name,
        rememberMe: _rememberMe,
        profileDraft: {
          'registration_status': 'draft',
          // Enterprise accounts also reuse `display_name`, but we keep the value
          // here so first login can initialize `public.profiles` reliably.
          'display_name': name,
        },
      );
      if (!mounted) return;
      await _prepareEnterpriseAndGoToPayment(companyName: name);
    } catch (e) {
      debugPrint('Enterprise registration failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _prepareEnterpriseAndGoToPayment({required String companyName}) async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) throw Exception('Session utilisateur introuvable.');
    if (!_hasSupabaseSession()) {
      _handleUnauthedWrite();
      return;
    }
    try {
      await _firestoreUsers.updateProfile(uid: me.id, displayName: companyName, registrationStatus: 'draft');
      if (_pickedPhoto != null) {
        try {
          final url = await _photos.uploadProfilePhoto(uid: me.id, file: _pickedPhoto!);
          await _firestoreUsers.updateProfile(uid: me.id, photoUrl: url);
        } catch (e) {
          debugPrint('EnterpriseReg: avatar upload failed uid=${me.id} err=$e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
          rethrow;
        }
      }
      await _firestoreUsers.ensureThixId(uid: me.id, countryCode: 'XX');
      await _firestoreUsers.ensureThixChat(uid: me.id, desired: '@${companyName.toLowerCase().replaceAll(RegExp(r"[^a-z0-9._]"), '')}${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}');
      await _firestoreUsers.updateProfile(uid: me.id, registrationStatus: 'awaiting_payment');
    } catch (e) {
      debugPrint('EnterpriseReg: prepare identifiers failed uid=${me.id} err=$e');
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('Not authenticated') || msg.toLowerCase().contains('jwt') || msg.contains('42501')) {
          _handleUnauthedWrite();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      rethrow;
    }
    if (!mounted) return;
    final receiptReturn = Uri.encodeComponent('/activation-receipt');
    context.go('${AppRoutes.payment}?returnTo=$receiptReturn');
  }

  Future<void> _pickPhoto() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image, withData: kIsWeb, allowMultiple: false);
      if (res == null || res.files.isEmpty) return;
      setState(() => _pickedPhoto = res.files.first);
    } catch (e) {
      debugPrint('EnterpriseReg: pick photo failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélection image impossible.')));
    }
  }

  bool _looksLikePhone(String s) => RegExp(r'^\+?[0-9][0-9\s\-]{7,}$').hasMatch(s.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF9C74F), Color(0xFFD4AF37), Color(0xFF996515)],
                  stops: [0, 0.5, 1],
                ),
                color: Colors.white, // fallback
              ),
              child: ColoredBox(color: context.theme.scaffoldBackgroundColor.withValues(alpha: 0.92)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.surface,
                    border: Border(bottom: BorderSide(color: context.theme.dividerColor)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.theme.colorScheme.onSurface, size: 20),
                        onPressed: () => context.popOrGo(AppRoutes.home),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Compte Entreprise",
                              style: context.textStyles.titleLarge?.copyWith(
                                color: context.theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              "Enregistrement THIX ID Institutionnel",
                              style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: LightModeColors.accent,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          "ÉTAPE 1/5",
                          style: context.textStyles.labelSmall?.copyWith(
                            color: const Color(0xFF0A2F5C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          color: context.theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            side: BorderSide(color: LightModeColors.accent.withValues(alpha: 0.75), width: 1.2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.shield_rounded, color: context.theme.colorScheme.primary, size: 18),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        'Identifiants Institutionnels',
                                        style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Ces identifiants permettent à votre organisation d’accéder au tableau de bord. Un ID THIX sera généré.',
                                  style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText),
                                ),
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
                                          image: _pickedPhoto == null
                                              ? const AssetImage('assets/images/African_businessman_in_suit_grayscale_1775573970767.jpg')
                                              : (kIsWeb ? MemoryImage(_pickedPhoto!.bytes!) : FileImage(fileFromPath(_pickedPhoto!.path!) as dynamic)) as ImageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _isLoading ? null : _pickPhoto,
                                        icon: const Icon(Icons.add_a_photo_rounded),
                                        label: const Text('Ajouter une photo'),
                                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: _companyNameC,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    hintText: "Nom de l'entreprise",
                                    prefixIcon: const Icon(Icons.domain_rounded, color: LightModeColors.hint),
                                    filled: true,
                                    fillColor: context.theme.scaffoldBackgroundColor,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: _emailC,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    hintText: 'Email administrateur',
                                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: LightModeColors.hint),
                                    filled: true,
                                    fillColor: context.theme.scaffoldBackgroundColor,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: _passwordC,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    hintText: 'Mot de passe (min. 8 caractères)',
                                    prefixIcon: const Icon(Icons.lock_rounded, color: LightModeColors.hint),
                                    filled: true,
                                    fillColor: context.theme.scaffoldBackgroundColor,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: context.theme.dividerColor)),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: _confirmC,
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
                                    Switch(
                                      value: _rememberMe,
                                      onChanged: _isLoading ? null : (v) => setState(() => _rememberMe = v),
                                      activeColor: LightModeColors.accent,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(child: Text('Rester connecté', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText))),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _createEnterprise,
                                  icon: _isLoading
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0A2F5C)))
                                      : const Icon(Icons.verified_rounded),
                                  label: Text(_isLoading ? 'Création…' : 'Créer le compte et accéder au Dashboard'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: LightModeColors.accent,
                                    foregroundColor: const Color(0xFF0A2F5C),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: context.textStyles.labelLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const SectionHeader(
                          number: "1",
                          title: "Informations sur l'Entreprise",
                          subtitle: "Détails officiels et localisation de votre entité.",
                        ),
                        Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          color: context.theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            side: const BorderSide(color: LightModeColors.accent, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(
                                  children: [
                                    const FormLabel(label: "Logo de l'entreprise", required: true),
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 110,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            color: context.theme.scaffoldBackgroundColor,
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            border: Border.all(color: context.theme.dividerColor, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                blurRadius: 6,
                                                offset: const Offset(0, 4),
                                              )
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.business_rounded, color: LightModeColors.hint, size: 48),
                                        ),
                                        Positioned(
                                          bottom: -5,
                                          right: -5,
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: LightModeColors.accent,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: context.theme.colorScheme.surface, width: 2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.1),
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 1),
                                                )
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF0A2F5C), size: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FormLabel(label: "Nom complet de l'entreprise", required: true),
                                    _buildTextField(context, "Ex: THIX Technologies SARL"),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FormLabel(label: "Sigle / Acronyme", required: false),
                                    _buildTextField(context, "Ex: THIX"),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const FormLabel(label: "Numéro RCCM", required: true),
                                          _buildTextField(context, "CD/KNG/RCCM/..."),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const FormLabel(label: "Numéro IDNAT", required: true),
                                          _buildTextField(context, "01-H4300-N..."),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FormLabel(label: "Secteur d'activité", required: true),
                                    _buildDropdown(context, "Sélectionner un secteur", ["Technologie", "Finance", "Agriculture", "Mines", "Santé", "Éducation"]),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FormLabel(label: "Type d'entreprise", required: true),
                                    _buildDropdown(context, "Sélectionner le statut juridique", ["SARL", "SA", "ASBL", "Entreprise Individuelle", "Coopérative"]),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FormLabel(label: "Pays de résidence", required: true),
                                    _buildTextField(context, "République Démocratique du Congo", icon: Icons.flag_rounded, readOnly: true),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const FormLabel(label: "Province", required: true),
                                          _buildDropdown(context, "Province", ["Kinshasa", "Haut-Katanga", "Lualaba", "Nord-Kivu", "Sud-Kivu"]),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const FormLabel(label: "Ville / Territoire", required: true),
                                          _buildDropdown(context, "Ville", ["Gombe", "Limete", "Ngaliema", "Lubumbashi"]),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FormLabel(label: "Adresse complète", required: true),
                                    _buildTextField(context, "N°, Rue, Quartier, Commune", maxLines: 2),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const FormLabel(label: "Site web", required: false),
                                          _buildTextField(context, "https://...", keyboardType: TextInputType.url),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const FormLabel(label: "Année de fondation", required: true),
                                          _buildTextField(context, "AAAA", keyboardType: TextInputType.number),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text("Continuer vers Représentant Légal"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.accent,
                            foregroundColor: const Color(0xFF0A2F5C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: context.textStyles.labelLarge,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            "Sauvegarder le brouillon",
                            style: context.textStyles.labelLarge?.copyWith(
                              color: LightModeColors.secondaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: LightModeColors.success, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              "Protégé par le protocole de sécurité THIX-Shield",
                              style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String hint, {IconData? icon, bool readOnly = false, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: LightModeColors.hint) : null,
        filled: true,
        fillColor: context.theme.scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: context.theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: context.theme.dividerColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      ),
      controller: readOnly ? TextEditingController(text: hint) : null,
    );
  }

  Widget _buildDropdown(BuildContext context, String hint, List<String> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(hint),
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: (value) {},
        ),
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}