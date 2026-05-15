import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/alert_info_sheet.dart';
import 'package:thix_id/presentation/emergency/emergency_fab.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/firestore_user_service.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import '../../theme.dart';
import '../../nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  final _notifications = NotificationService();
  final _counters = NotificationCountersService();

  static final RegExp _uidLikeRegex = RegExp(r'^[A-Za-z0-9_\-]{20,}$');

  // Couleurs du nouveau design
  final Color primaryBlue = const Color(0xFF0033AD);
  final Color accentBlue = const Color(0xFF3B66FF);
  final Color lightBg = const Color(0xFFF7F9FC);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE PRODUCTION : PICKER DE LANGUE ---
  Future<void> _showLanguagePicker() async {
    final localeCtrl = context.read<LocaleController>();
    final currentCode = localeCtrl.locale?.languageCode;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.loc.t('choose_language'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                ...LocaleController.supportedLocales.map((l) => ListTile(
                  title: Text(AppLocalizations.localeLabel(l)),
                  trailing: currentCode == l.languageCode ? Icon(Icons.check_circle, color: primaryBlue) : null,
                  onTap: () {
                    localeCtrl.setLocale(l);
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- LOGIQUE DE PRODUCTION : RECHERCHE & VÉRIFICATION ---
  Future<void> _handleHomeSearchVerify() async {
    final raw = _searchController.text.trim();
    if (raw.isEmpty) {
      await FullScreenMessage.showError(context, title: 'Identifiant requis', message: "Saisissez un THIX ID.");
      return;
    }

    final normalized = ThixIdService.normalize(raw);
    final isThix = normalized.startsWith('THIX-') && ThixIdService.isValid(normalized);
    final isUid = _uidLikeRegex.hasMatch(raw);

    if (!isThix && !isUid) {
      await FullScreenMessage.showError(context, title: 'Invalide', message: 'Format incorrect.');
      return;
    }

    setState(() => _searching = true);
    try {
      final userService = FirestoreUserService();
      AppUser? user = isThix ? await userService.fetchUserByThixId(normalized) : await userService.fetchUserByUid(raw);

      if (!mounted) return;
      if (user == null) {
        await FullScreenMessage.showError(context, title: 'Introuvable', message: "Aucun profil trouvé.");
        return;
      }

      final thix = user.thixId.trim().toUpperCase();
      if (thix.isNotEmpty && ThixIdService.isValid(thix)) {
        context.push('${AppRoutes.publicProfile}?thixId=$thix');
      } else {
        await ThixIdentitySheets.showVerifySheet(context, initialUidOrThixId: user.id);
      }
    } catch (e) {
      if (mounted) await FullScreenMessage.showError(context, title: 'Erreur', message: e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final safeTop = MediaQuery.paddingOf(context).top;
    final badgeCountsStream = auth.currentUser == null 
        ? Stream<SectionBadgeCounts>.value(SectionBadgeCounts.zero) 
        : _counters.streamCounts(auth.currentUser!.id);

    return Scaffold(
      backgroundColor: lightBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // 1. HEADER DÉGRADÉ (NOUVEAU DESIGN)
                Container(
                  padding: EdgeInsets.fromLTRB(20, safeTop + 20, 20, 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryBlue, const Color(0xFF001D6E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("THIX ID", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                              Text("Identité Sécurisée. Avenir de Confiance.", style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.language, color: Colors.white),
                                onPressed: _showLanguagePicker,
                              ),
                              const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),
                      const Text("Bienvenue !", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const Text("Que voulez-vous faire aujourd'hui ?", style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 25),
                      
                      // Barre de Recherche (Production)
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.all(5),
                        child: Row(
                          children: [
                            const SizedBox(width: 15),
                            const Icon(Icons.search, color: Colors.grey),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onSubmitted: (_) => _handleHomeSearchVerify(),
                                decoration: const InputDecoration(hintText: "Rechercher un THIX ID...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _searching ? null : _handleHomeSearchVerify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              ),
                              child: Row(
                                children: const [
                                  Text("Vérifier", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 5),
                                  Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. ACTIONS SCAN & NFC
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _buildQuickAction(Icons.qr_code_scanner, "Scanner QR", "Scannez un code", accentBlue, () => ThixIdentitySheets.showQrScanSheet(context)),
                      const SizedBox(width: 15),
                      _buildQuickAction(Icons.nfc, "Lire NFC", "Approchez l'appareil", const Color(0xFF00C897), () => ThixIdentitySheets.showNfcScanSheet(context)),
                    ],
                  ),
                ),

                // 3. NOTIFICATIONS (LOGIQUE STREAM)
                _buildSectionHeader("Notifications", () => NotificationsSheet.show(context)),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _notifications.streamForHome(uid: auth.currentUser?.id),
                  builder: (context, snap) {
                    final hasData = snap.hasData && snap.data!.isNotEmpty;
                    final title = hasData ? snap.data![0]['title'] : "Restez informé de vos activités";
                    return _buildNotificationCard(title, hasData);
                  },
                ),

                // 4. GRILLE DES SERVICES (LOGIQUE BADGES)
                const SizedBox(height: 10),
                _buildSectionHeader("Nos services", null),
                StreamBuilder<SectionBadgeCounts>(
                  stream: badgeCountsStream,
                  builder: (context, badgeSnap) {
                    final counts = badgeSnap.data ?? SectionBadgeCounts.zero;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        childAspectRatio: 0.8,
                        children: [
                          _buildServiceItem(Icons.person_add, "Demander compte", counts.info, () => context.push(AppRoutes.personalReg)),
                          _buildServiceItem(Icons.account_circle, "Mon Compte", 0, () {
                            if (auth.isAuthenticated) {
                              context.go(auth.currentUser?.accountType == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard);
                            } else {
                              context.push(AppRoutes.login);
                            }
                          }),
                          _buildServiceItem(Icons.school, "Formations", counts.formations, () => context.push(AppRoutes.trainingHome)),
                          _buildServiceItem(Icons.work, "Emplois", counts.jobs, () => context.push(AppRoutes.jobs)),
                          _buildServiceItem(Icons.list_alt, "THIX INFO", counts.info, () => AlertInfoSheet.show(context)),
                          _buildServiceItem(Icons.lightbulb, "Opportunités", counts.opportunities, () => context.push(AppRoutes.opportunities)),
                          _buildServiceItem(Icons.calendar_month, "Événements", counts.events, () => context.push(AppRoutes.events)),
                          _buildServiceItem(Icons.groups, "Réseau Pro", 0, () => context.push(AppRoutes.network)),
                        ],
                      ),
                    );
                  },
                ),

                // 5. BANNIÈRE MISSION
                _buildMissionBanner(),
                const SizedBox(height: 100),
              ],
            ),
          ),

          // BOUTONS FLOTTANTS
          Positioned(bottom: 20, left: 20, child: const EmergencyFab()),
          Positioned(
            bottom: 20, right: 20,
            child: FloatingActionButton(
              backgroundColor: primaryBlue,
              child: const Icon(Icons.forum_rounded, color: Colors.white),
              onPressed: () => context.push(AppRoutes.chat),
            ),
          ),
          
          if (_searching)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  // --- HELPERS DE CONSTRUCTION UI ---

  Widget _buildQuickAction(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.black87, size: 28),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              const SizedBox(height: 5),
              Align(alignment: Alignment.bottomRight, child: Icon(Icons.arrow_circle_right, color: color, size: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(String message, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: active ? accentBlue : Colors.grey.shade200, child: Icon(Icons.notifications, color: active ? Colors.white : Colors.grey)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(message, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: primaryBlue),
        ],
      ),
    );
  }

  Widget _buildServiceItem(IconData icon, String label, int badge, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
                child: Icon(icon, color: accentBlue),
              ),
              if (badge > 0)
                Positioned(
                  right: -5, top: -5,
                  child: CircleAvatar(radius: 8, backgroundColor: Colors.red, child: Text(badge.toString(), style: const TextStyle(color: Colors.white, fontSize: 8))),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onSeeAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text("Tout voir >", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildMissionBanner() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF001D6E), Color(0xFF0033AD)]),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("NOTRE MISSION", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text("Construisons ensemble\nl'avenir de la jeunesse.", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text("Accédez à des opportunités, des ressources et un réseau engagé.", style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}
