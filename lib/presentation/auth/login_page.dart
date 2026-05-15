import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../theme.dart';
import '../../nav.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: LightModeColors.accent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 25,
                offset: const Offset(0, 10),
              )
            ],
          ),
          alignment: Alignment.center,
          child: Icon(Icons.fingerprint_rounded, color: context.theme.colorScheme.primary, size: 52),
        ),
        const SizedBox(height: AppSpacing.md),
        Column(
          children: [
            Text(
              "THIX ID",
              style: context.textStyles.headlineLarge?.copyWith(
                color: context.theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF9C74F).withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: const Color(0xFFF9C74F).withValues(alpha: 0.26)),
              ),
              child: Text(
                "IDENTITÉ SÉCURISÉE • AVENIR DE CONFIANCE",
                style: context.textStyles.labelSmall?.copyWith(
                  color: LightModeColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SecureInput extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType type;
  final TextEditingController controller;
  final TextInputAction textInputAction;

  const SecureInput({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isPassword,
    required this.type,
    required this.controller,
    required this.textInputAction,
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
              Icon(icon, size: 16, color: LightModeColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: context.textStyles.labelLarge?.copyWith(
                  color: context.theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: type,
            textInputAction: textInputAction,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: context.theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: context.theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: context.theme.dividerColor),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}

class SocialAuth extends StatelessWidget {
  final IconData icon;
  final String label;

  const SocialAuth({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 64,
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.theme.colorScheme.onSurface, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: LightModeColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginPageBody();
  }
}

class _LoginPageBody extends StatefulWidget {
  const _LoginPageBody();

  @override
  State<_LoginPageBody> createState() => _LoginPageBodyState();
}

class _LoginPageBodyState extends State<_LoginPageBody> {
  final _identifierC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;
  PhoneAuthSession? _phoneSession;

  @override
  void dispose() {
    _identifierC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final auth = context.read<AuthController>();
    final identifier = _identifierC.text.trim();
    final password = _passwordC.text;
    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir votre identifiant et mot de passe.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_looksLikePhone(identifier) && !identifier.contains('@')) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connexion par SMS non disponible dans la Preview web. Utilisez un email ou testez sur Android/iOS.')));
          return;
        }
        if (_phoneSession == null) {
          _phoneSession = await auth.startPhoneAuth(phoneNumber: identifier);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS envoyé. Entrez le code dans le champ Mot de passe puis validez.')));
          return;
        }
        final u = await auth.confirmPhoneCode(session: _phoneSession!, smsCode: password);
        if (!mounted) return;
        final target = u.accountType == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard;
        context.go(target);
        return;
      }

      final u = await auth.signIn(identifier: identifier, password: password, rememberMe: _rememberMe);
      if (!mounted) return;
      final target = u.accountType == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard;
      context.go(target);
    } catch (e) {
      debugPrint('Login failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A3D62), Color(0xFF0A2F5C), Color(0xFF0F2B4A)],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
            Align(
              alignment: const Alignment(1, -1),
              child: Opacity(
                opacity: 0.05,
                child: Icon(Icons.fingerprint_rounded, size: 300, color: LightModeColors.accent),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  const LoginHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Connexion Institutionnelle",
                              style: context.textStyles.titleLarge?.copyWith(
                                color: context.theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              "Connectez-vous avec votre email ou votre identifiant THIX (TX-XXX-XXX)",
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: LightModeColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SecureInput(
                          label: "Identifiant THIX ID",
                          hint: "Ex: TX-882-091 ou email",
                          icon: Icons.badge_rounded,
                          isPassword: false,
                          type: TextInputType.text,
                          controller: _identifierC,
                          textInputAction: TextInputAction.next,
                        ),
                        SecureInput(
                          label: "Mot de passe",
                          hint: "••••••••••••",
                          icon: Icons.lock_rounded,
                          isPassword: true,
                          type: TextInputType.text,
                          controller: _passwordC,
                          textInputAction: TextInputAction.done,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: _isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: _rememberMe ? LightModeColors.accent : context.theme.scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: _rememberMe ? LightModeColors.accent : context.theme.dividerColor),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.check_rounded, size: 14, color: _rememberMe ? context.theme.colorScheme.primary : Colors.transparent),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    "Rester connecté",
                                    style: context.textStyles.bodySmall?.copyWith(
                                      color: LightModeColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Mode local: réinitialisation par email indisponible (à connecter à un backend).')),
                                );
                              },
                              child: Text(
                                "Oublié ?",
                                style: context.textStyles.labelLarge?.copyWith(
                                  color: context.theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GestureDetector(
                          onTap: _isLoading ? null : _signIn,
                          child: Opacity(
                            opacity: _isLoading ? 0.7 : 1,
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: LightModeColors.accent,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLoading) ...[
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: context.theme.colorScheme.primary),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                  ],
                                  Text(
                                    _isLoading ? "VÉRIFICATION…" : "SE CONNECTER",
                                    style: context.textStyles.titleMedium?.copyWith(
                                      color: context.theme.colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Icon(Icons.arrow_forward_rounded, color: context.theme.colorScheme.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(child: Divider(color: context.theme.dividerColor, thickness: 1)),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              "BIOMÉTRIE",
                              style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.hint),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: Divider(color: context.theme.dividerColor, thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SocialAuth(icon: Icons.face_rounded, label: "Face ID"),
                            SizedBox(width: AppSpacing.md),
                            SocialAuth(icon: Icons.fingerprint_rounded, label: "Touch ID"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9C74F).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A3D62),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF9C74F).withValues(alpha: 0.26)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: LightModeColors.accent, size: 24),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Standard de Sécurité Étatique",
                                      style: context.textStyles.labelMedium?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      "Chiffrement local & session persistante",
                                      style: context.textStyles.bodySmall?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Nouvel utilisateur ?",
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.personalReg),
                            child: Text(
                              "Créer un compte THIX ID",
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: LightModeColors.accent,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: LightModeColors.accent,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text("FR", style: context.textStyles.labelSmall?.copyWith(color: context.theme.colorScheme.primary)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text("EN", style: context.textStyles.labelSmall?.copyWith(color: Colors.white)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text("SW", style: context.textStyles.labelSmall?.copyWith(color: Colors.white)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text("LN", style: context.textStyles.labelSmall?.copyWith(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
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