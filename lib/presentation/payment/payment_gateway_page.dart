import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import '../../theme.dart';

class PaymentMethodCard extends StatelessWidget {
  final String name;
  final String description;
  final String providerLogo;
  final bool selected;

  const PaymentMethodCard({
    super.key,
    required this.name,
    required this.description,
    required this.providerLogo,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? LightModeColors.accent : context.theme.dividerColor,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 40,
            decoration: BoxDecoration(
              color: context.theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: context.theme.dividerColor),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.payment, color: LightModeColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: context.textStyles.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: LightModeColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? LightModeColors.accent : context.theme.dividerColor,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: LightModeColors.accent,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.textStyles.bodyMedium?.copyWith(
              color: LightModeColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentGatewayPage extends StatefulWidget {
  final String? returnTo;
  const PaymentGatewayPage({super.key, this.returnTo});

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  final _mobileMoneyPhoneC = TextEditingController();
  String _method = 'mobile_money';
  bool _isPaying = false;
  int _step = 1; // 1=Pay, 2=UID, 3=Finalize
  String? _lastTxRef;
  bool _isStartingTrial = false;

  @override
  void dispose() {
    _mobileMoneyPhoneC.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  bool _isPendingThixId(String thixId) {
    final v = thixId.trim().toUpperCase();
    return v.isEmpty || v == 'THIX-PENDING' || v == 'THIX-000000';
  }

  Future<void> _completeFictiveActivation({
    required AppUser me,
    required String method,
    required String txRef,
    required String amount,
    required String currency,
    required DateTime paidAt,
    String? registrationStatus,
    bool requireRealThixId = true,
  }) async {
    final auth = context.read<AuthController>();
    // Payment is fictive, but THIX ID must be real + persisted (searchable).
    final users = FirestoreUserService();
    String thixId = me.thixId.trim().toUpperCase();
    if (requireRealThixId && _isPendingThixId(thixId)) {
      try {
        thixId = await users.assignRealThixIdIfMissing(uid: me.id, countryOrOrigin: me.countryOrOrigin, displayName: me.displayName);
      } catch (e) {
        // A THIX ID must never remain pending: without a real ID the account
        // cannot be searched/used correctly.
        debugPrint('PaymentGateway: THIX ID assignment failed; aborting. err=$e');
        rethrow;
      }
    }
    final next = me.copyWith(
      thixId: thixId,
      registrationStatus: registrationStatus ?? 'verified',
      updatedAt: DateTime.now(),
    );

    // Persist in app state. Supabase writes (if any) are best-effort only.
    await auth.updateCurrentUser(next);

    // For free-trial, attempt to assign a real THIX ID in background when possible,
    // but do not block navigation.
    if (!requireRealThixId && _isPendingThixId(next.thixId)) {
      unawaited(() async {
        try {
           final real = await users.assignRealThixIdIfMissing(uid: next.id, countryOrOrigin: next.countryOrOrigin, displayName: next.displayName);
          await auth.updateCurrentUser(next.copyWith(thixId: real, updatedAt: DateTime.now()));
          debugPrint('PaymentGateway: background THIX ID assigned: $real');
        } catch (e) {
          debugPrint('PaymentGateway: background THIX ID assignment skipped/failed err=$e');
        }
      }());
    }
    if (!mounted) return;

    final qp = <String, String>{
      'txRef': txRef,
      'method': method,
      'amount': amount,
      'currency': currency,
      'paidAt': paidAt.toUtc().toIso8601String(),
    };
    context.go(Uri(path: AppRoutes.activationReceipt, queryParameters: qp).toString());
  }

  Future<void> _startFreeTrial() async {
    if (_isStartingTrial || _isPaying) return;
    final auth = context.read<AuthController>();
    final me = auth.currentUser;
    if (me == null) {
      _snack('Veuillez vous connecter d\'abord.');
      return;
    }

    setState(() => _isStartingTrial = true);
    try {
      // Payment is fictive, but the THIX ID must be REAL + persisted in Supabase,
      // otherwise the account won't work normally (search/public profile/chat).
      final now = DateTime.now().toUtc();
      final endsAt = now.add(const Duration(days: 7));
      final registrationStatus = 'trial_until:${endsAt.toIso8601String()}';
      final ref = _txRef();
      setState(() => _lastTxRef = ref);
      await _completeFictiveActivation(
        me: me,
        method: 'trial_7d',
        txRef: ref,
        amount: '0.00',
        currency: 'USD',
        paidAt: now,
        registrationStatus: registrationStatus,
        requireRealThixId: true,
      );
    } catch (e, st) {
      debugPrint('PaymentGateway: start free trial failed err=$e');
      debugPrint('$st');
      if (!mounted) return;
      _snack('Impossible de démarrer l\'essai gratuit (THIX ID non attribué).');
    } finally {
      if (mounted) setState(() => _isStartingTrial = false);
    }
  }

  String _txRef() {
    final rnd = Random();
    final suffix = List.generate(6, (_) => rnd.nextInt(10)).join();
    return 'TX-ID-$suffix-GOV';
  }

  Future<void> _confirmPayment() async {
    if (_isPaying) return;
    final auth = context.read<AuthController>();
    final me = auth.currentUser;
    if (me == null) {
      _snack('Veuillez vous connecter d\'abord.');
      return;
    }

    if (_method == 'mobile_money') {
      final p = _mobileMoneyPhoneC.text.trim();
      if (p.isEmpty || !RegExp(r'^\+?[0-9][0-9\s\-]{7,}$').hasMatch(p)) {
        _snack('Numéro Mobile Money invalide.');
        return;
      }
    }

    setState(() {
      _isPaying = true;
      _step = 1;
    });
    try {
      // Simulated payment (no real gateway).
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final ref = _txRef();
      _lastTxRef = ref;
      if (mounted) setState(() => _step = 2);

      if (mounted) setState(() => _step = 3);
      await _completeFictiveActivation(
        me: me,
        method: _method,
        txRef: ref,
        amount: '5.00',
        currency: 'USD',
        paidAt: DateTime.now().toUtc(),
        registrationStatus: 'verified',
      );
    } catch (e, st) {
      debugPrint('PaymentGateway: confirm payment failed err=$e');
      debugPrint('$st');
      if (!mounted) return;
      _snack('Paiement impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Widget _stepper(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaymentStepDot(label: 'Paiement', index: 1, activeIndex: _step),
        const SizedBox(width: 10),
        _PaymentStepDot(label: 'UID', index: 2, activeIndex: _step),
        const SizedBox(width: 10),
        _PaymentStepDot(label: 'Finalisation', index: 3, activeIndex: _step),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2F5C),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [Color(0xFF0F2B4A), Color(0xFF0A2F5C)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/images/gold_fingerprint_abstract_transparent_1775573968885.png',
                  height: 400,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.fingerprint, size: 400, color: LightModeColors.accent),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFFF9C74F).withValues(alpha: 0.13), Colors.transparent],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: context.theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: context.theme.colorScheme.onSurface),
                          onPressed: () => context.popOrGo(AppRoutes.home),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            "Paiement Institutionnel",
                            style: context.textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF8FAFC),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.security_rounded, size: 14, color: LightModeColors.accent),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                "THIX ID SECURE GATEWAY",
                                style: context.textStyles.labelSmall?.copyWith(
                                  color: LightModeColors.accent,
                                  letterSpacing: 1.2,
                                ),
                              ),
                          const SizedBox(height: 8),
                          _stepper(context),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded, color: LightModeColors.secondaryText),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: const Color(0xFFF9C74F).withValues(alpha: 0.26)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0A3D62), Color(0xFF0F2B4A)],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "TOTAL À PAYER",
                                  style: context.textStyles.labelLarge?.copyWith(
                                    color: const Color(0xFFF9C74F),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Icon(Icons.account_balance_rounded, color: Color(0xFFF9C74F), size: 20),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "5.00",
                                  style: context.textStyles.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    "USD",
                                    style: context.textStyles.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                              height: 1,
                              color: const Color(0xFFF9C74F).withValues(alpha: 0.3),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "RÉFÉRENCE TRANSACTION",
                                      style: context.textStyles.labelSmall?.copyWith(
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    Text(
                                        _lastTxRef ?? '—',
                                      style: context.textStyles.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9C74F).withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                    border: Border.all(color: const Color(0xFFF9C74F).withValues(alpha: 0.26)),
                                  ),
                                  child: Text(
                                    "OFFICIEL",
                                    style: context.textStyles.labelSmall?.copyWith(
                                      color: const Color(0xFFF9C74F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Transform.rotate(
                          angle: 20 * 3.14159 / 180,
                          child: Container(
                            width: 200,
                            height: 400,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.transparent, Colors.white.withValues(alpha: 0.06), Colors.transparent],
                                stops: const [0, 0.5, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    decoration: BoxDecoration(
                      color: context.theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.lg),
                        topRight: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ---- Free trial (7 days) ----
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: context.theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: context.theme.dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: LightModeColors.accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.auto_awesome_rounded, color: LightModeColors.accent),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Essai gratuit', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: context.theme.colorScheme.onSurface)),
                                          const SizedBox(height: 2),
                                          Text('Essayez toutes les fonctionnalités pendant 7 jours.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                GestureDetector(
                                  onTap: _isStartingTrial ? null : _startFreeTrial,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    opacity: _isStartingTrial ? 0.7 : 1,
                                    child: Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: context.theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(AppRadius.full),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (_isStartingTrial) ...[
                                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: context.theme.colorScheme.onPrimary)),
                                            const SizedBox(width: AppSpacing.md),
                                          ] else ...[
                                            Icon(Icons.play_circle_outline_rounded, color: context.theme.colorScheme.onPrimary),
                                            const SizedBox(width: AppSpacing.sm),
                                          ],
                                          Text('ESSAYER GRATUITEMENT (7 JOURS)', style: context.textStyles.labelLarge?.copyWith(color: context.theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Détails de la transaction",
                                style: context.textStyles.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
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
                                child: Column(
                                  children: [
                                    const SummaryRow(label: "Service", value: "Création de Compte THIX ID"),
                                    const SummaryRow(label: "Type", value: "Identité Numérique Souveraine"),
                                    const SummaryRow(label: "Frais de dossier", value: "5.00 USD"),
                                    Divider(color: context.theme.dividerColor),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Montant Final",
                                          style: context.textStyles.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: context.theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          "5.00 USD",
                                          style: context.textStyles.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: context.theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Mode de paiement sécurisé",
                                style: context.textStyles.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              GestureDetector(
                                onTap: _isPaying ? null : () => setState(() => _method = 'mobile_money'),
                                child: PaymentMethodCard(
                                  name: "Mobile Money",
                                  description: "M-Pesa, Orange, Airtel, Africell",
                                  providerLogo: "mobile money logo gold",
                                  selected: _method == 'mobile_money',
                                ),
                              ),
                              GestureDetector(
                                onTap: _isPaying ? null : () => setState(() => _method = 'card'),
                                child: PaymentMethodCard(
                                  name: "Carte Bancaire",
                                  description: "Visa, Mastercard, Maestro",
                                  providerLogo: "bank card logo gold",
                                  selected: _method == 'card',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Numéro de téléphone Mobile Money",
                                style: context.textStyles.labelLarge?.copyWith(
                                  color: context.theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Container(
                                    width: 85,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: context.theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(color: context.theme.dividerColor),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.flag_rounded, size: 20),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          "+243",
                                          style: context.textStyles.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: TextField(
                                      controller: _mobileMoneyPhoneC,
                                      enabled: _method == 'mobile_money' && !_isPaying,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: "812 345 678",
                                        prefixIcon: const Icon(Icons.phone_android_rounded),
                                        filled: true,
                                        fillColor: context.theme.colorScheme.surface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A3D62),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: const Color(0xFFF9C74F).withValues(alpha: 0.26)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF9C74F),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0A3D62), size: 22),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Transaction Protégée",
                                        style: context.textStyles.labelLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFF9C74F),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        "Cryptage de niveau gouvernemental AES-256",
                                        style: context.textStyles.bodySmall?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          GestureDetector(
                            onTap: _isPaying ? null : _confirmPayment,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _isPaying ? 0.75 : 1,
                              child: Container(
                                height: 64,
                                decoration: BoxDecoration(
                                  color: LightModeColors.accent,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 15,
                                      offset: const Offset(0, 10),
                                    )
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isPaying) ...[
                                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF0A2F5C))),
                                      const SizedBox(width: AppSpacing.md),
                                    ] else ...[
                                      const Icon(Icons.lock_rounded, color: Color(0xFF0A2F5C), size: 22),
                                      const SizedBox(width: AppSpacing.md),
                                    ],
                                    Text(
                                      _isPaying ? 'CONFIRMATION…' : "CONFIRMER LE PAIEMENT (5 USD)",
                                      style: context.textStyles.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0A2F5C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Column(
                            children: [
                              Text(
                                "Propulsé par THIX ID Infrastructure",
                                style: context.textStyles.labelSmall?.copyWith(
                                  color: LightModeColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.security, color: LightModeColors.hint, size: 18),
                                  const SizedBox(width: AppSpacing.lg),
                                  Icon(Icons.verified, color: LightModeColors.hint, size: 18),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

class _PaymentStepDot extends StatelessWidget {
  final String label;
  final int index;
  final int activeIndex;

  const _PaymentStepDot({required this.label, required this.index, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final isDone = activeIndex > index;
    final isActive = activeIndex == index;
    final bg = isDone
        ? const Color(0xFF17B26A)
        : (isActive ? LightModeColors.accent : Colors.white.withValues(alpha: 0.12));
    final fg = isDone
        ? Colors.white
        : (isActive ? const Color(0xFF0A2F5C) : Colors.white.withValues(alpha: 0.75));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: isActive ? 0.55 : 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isDone
                ? const Icon(Icons.check_rounded, key: ValueKey('check'), size: 16, color: Colors.white)
                : Text(
                    '$index',
                    key: ValueKey('num_$index'),
                    style: context.textStyles.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w900),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}