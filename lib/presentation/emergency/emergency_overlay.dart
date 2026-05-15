import 'dart:ui';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/emergency/emergency_action_sheets.dart';
import 'package:thix_id/services/emergency_service.dart';
import 'package:thix_id/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const EmergencyOverlay({super.key, required this.onClose});

  static Future<void> show(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Emergency',
      // Dark premium scrim to match the URGENT template and keep focus on SOS.
      barrierColor: EmergencyUrgentColors.scrim(),
      pageBuilder: (context, a1, a2) => const SizedBox.shrink(),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, anim, _, __) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curve),
            child: EmergencyOverlay(onClose: () => context.pop()),
          ),
        );
      },
    );
  }

  @override
  State<EmergencyOverlay> createState() => _EmergencyOverlayState();
}

class _EmergencyOverlayState extends State<EmergencyOverlay> with TickerProviderStateMixin {
  final _service = EmergencyService();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  bool _silentMode = false;
  bool _working = false;
  String? _activeAlertId;
  String? _status;
  List<SponsoredSafetyAd> _ads = const [];
  List<String> _adminPhones = const [];

  Timer? _uiPosTimer;
  DateTime? _lastUiPosAt;
  Position? _latestPos;

  bool get _isAuthenticated => context.read<AuthController>().isAuthenticated;

  Future<bool> _ensureAuthenticated() async {
    if (_isAuthenticated) return true;
    if (!mounted) return false;

    final goLogin = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Connexion requise'),
          content: const Text('Vous devez être connecté pour envoyer une alerte et utiliser les fonctionnalités URGENCE.'),
          actions: [
            TextButton(onPressed: () => context.pop(false), child: Text(context.loc.t('cancel'))),
            FilledButton(onPressed: () => context.pop(true), child: Text(context.loc.t('login'))),
          ],
        );
      },
    );

    if (goLogin == true && mounted) {
      widget.onClose();
      if (mounted) context.go(AppRoutes.login);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadAds();
    _loadAdmins();
  }

  Future<void> _loadAds() async {
    final ads = await _service.fetchSafetyAds();
    if (!mounted) return;
    setState(() => _ads = ads);
  }

  Future<void> _loadAdmins() async {
    final phones = await _service.fetchAdminPhones();
    if (!mounted) return;
    setState(() => _adminPhones = phones);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _glow.dispose();
    final id = _activeAlertId;
    if (id != null) {
      // Best-effort: ensure we stop and upload audio when user closes the overlay.
      scheduleMicrotask(() async {
        await _service.stopLiveTracking();
        await _service.stopLiveAudioStreaming();
        await _service.stopAndUploadAudioEvidence(alertId: id);
      });
    } else {
      _service.stopLiveTracking();
      _service.stopLiveAudioStreaming();
    }

    try {
      _uiPosTimer?.cancel();
    } catch (_) {}
    _uiPosTimer = null;

    super.dispose();
  }

  void _startUiPositionRefresh() {
    try {
      _uiPosTimer?.cancel();
    } catch (_) {}

    _uiPosTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final pos = await _service.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) return;
      setState(() {
        _latestPos = pos;
        _lastUiPosAt = DateTime.now();
      });
    });
  }

  // Emergency overlay uses a dedicated premium dark template, even in light mode.
  Color get _bg0 => EmergencyUrgentColors.bg0;
  Color get _bg1 => EmergencyUrgentColors.bg1;
  Color get _panel => EmergencyUrgentColors.panel;
  Color get _card => EmergencyUrgentColors.card;
  Color get _stroke => EmergencyUrgentColors.stroke;
  Color get _text => EmergencyUrgentColors.text;
  Color get _muted => EmergencyUrgentColors.textDim;
  Color get _red => EmergencyUrgentColors.danger;

  Future<void> _triggerAlert({required String type, required bool critical, String? title}) async {
    if (!await _ensureAuthenticated()) return;
    if (_working) return;
    setState(() {
      _working = true;
      _status = 'Initialisation sécurisée…';
    });

    try {
      final pos = await _service.getCurrentPosition();
      if (!mounted) return;
      setState(() => _status = pos == null ? 'Localisation indisponible (permissions ?)' : 'Localisation capturée.');

      final id = await _service.createEmergencyAlert(type: type, isCritical: critical, silentMode: _silentMode, title: title, position: pos);
      if (!mounted) return;
      if (id == null) {
        setState(() => _status = 'Impossible de créer l’alerte (connexion / session).');
        return;
      }

      setState(() {
        _activeAlertId = id;
        _status = 'Alerte active. Envoi + suivi en temps réel…';
      });

      _startUiPositionRefresh();

      // 1) Always notify admins backend (best-effort) + keep audit.
      await _service.notifyAdminsSos(alertId: id, type: type, title: title ?? 'SOS', position: pos, silentMode: _silentMode, isCritical: critical);
      await _service.notifyBackend(alertId: id, channel: 'audit');

      // 2) Start live tracking persistence (if schema available).
      await _service.startLiveTracking(alertId: id);

      // 3) Auto-share live map link (disabled when silent mode).
      if (!_silentMode && pos != null) {
        await EmergencyActionSheets.shareLiveLocation(context: context, lat: pos.latitude, lng: pos.longitude, label: 'THIX ID — SOS');
      }

      if (critical) {
        setState(() => _status = 'Micro activé (enregistrement sécurisé)…');
        // Stream small chunks to enable near real-time listening from Admin SOS.
        // (Foreground-only; OS may pause in background.)
        await _service.startLiveAudioStreaming(alertId: id, chunkDuration: const Duration(seconds: 10));
        await _maybeNotifyTrustedContactsForCritical(alertId: id);
        if (!_silentMode) {
          final phone = _adminPhones.isNotEmpty ? _adminPhones.first : EmergencyService.hotlineEmergency;
          await _startEmergencyCall(phone);
        } else {
          setState(() => _status = 'Mode silencieux: appel automatique désactivé (audit activé).');
          final phone = _adminPhones.isNotEmpty ? _adminPhones.first : EmergencyService.hotlineEmergency;
          await _service.logPhoneCallIntent(phone);
        }
      }
    } catch (e) {
      debugPrint('EmergencyOverlay: triggerAlert failed: $e');
      if (mounted) setState(() => _status = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _maybeNotifyTrustedContactsForCritical({required String alertId}) async {
    try {
      final contacts = await _service.loadTrustedContacts();
      if (!mounted || contacts.isEmpty) return;

      final pos = await _service.getCurrentPosition();
      final lat = pos?.latitude;
      final lng = pos?.longitude;
      final mapsUrl = (lat != null && lng != null) ? 'https://www.google.com/maps?q=$lat,$lng' : null;
      final body = 'THIX ID — URGENCE: Je suis en danger. Position: ${mapsUrl ?? 'indisponible'}';
      await _service.sendSmsAudit(phones: contacts.map((c) => c.phone).toList(growable: false), body: body);

      // Limitation OS: l’envoi SMS silencieux automatique n’est pas autorisé.
      // En mode silencieux, on ne déclenche aucune UI externe (discret) — on journalise seulement.
      if (_silentMode) {
        await _service.updateAlertMetadata(alertId: alertId, metadata: {'trusted_contacts_count': contacts.length, 'maps_url': mapsUrl, 'trusted_contacts_prepared': true});
        return;
      }

      final sendNow = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Prévenir vos contacts ?'),
            content: Text('Ouvrir les SMS pour ${contacts.length} contact(s) de confiance ?'),
            actions: [
              TextButton(onPressed: () => context.pop(false), child: const Text('Non')),
              FilledButton(onPressed: () => context.pop(true), child: const Text('Oui')),
            ],
          );
        },
      );
      if (sendNow != true) return;

      for (final c in contacts) {
        if (!mounted) break;
        await EmergencyActionSheets.launchSms(context, phone: c.phone, body: body);
      }
      await _service.updateAlertMetadata(alertId: alertId, metadata: {'trusted_contacts_count': contacts.length, 'maps_url': mapsUrl, 'trusted_contacts_opened_sms': true});
    } catch (e) {
      debugPrint('EmergencyOverlay: trusted contacts notify failed: $e');
    }
  }

  Future<void> _handleActionTap(String type, String label) async {
    if (!await _ensureAuthenticated()) return;
    switch (type) {
      case EmergencyAlertType.critical:
        await _triggerAlert(type: type, critical: true, title: 'URGENCE CRITIQUE');
        break;
      case EmergencyAlertType.aggression:
        await _triggerAlert(type: type, critical: false, title: 'SIGNALER UNE AGRESSION');
        break;
      case EmergencyAlertType.ambulance:
        await _triggerHotlineFlow(type: type, title: 'AMBULANCE', phone: EmergencyService.hotlineAmbulance);
        break;
      case EmergencyAlertType.firefighters:
        await _triggerHotlineFlow(type: type, title: 'POMPIERS', phone: EmergencyService.hotlineFirefighters);
        break;
      case EmergencyAlertType.blood:
        final payload = await EmergencyActionSheets.showBloodSheet(context);
        if (payload == null) return;
        await _triggerAlertWithMetadata(type: type, title: 'SANG', metadata: {
          ...payload.toMetadata(),
          'matching': 'requested',
          'geo_targeting': payload.city != null || (payload.lat != null && payload.lng != null),
        });
        final id = _activeAlertId;
        if (id != null) {
          // Best-effort upload of medical proof (if provided). If schema is unavailable,
          // EmergencyService safely disables evidence uploads.
          final proof = payload.medicalProofPhoto;
          if (proof != null) {
            final path = await _service.uploadEvidenceFile(alertId: id, file: proof, kind: 'medical_proof');
            if (path != null) {
              await _service.updateAlertMetadata(
                alertId: id,
                metadata: {
                  ...payload.toMetadata(),
                  'matching': 'requested',
                  'geo_targeting': payload.city != null || (payload.lat != null && payload.lng != null),
                  'medical_proof_path': path,
                },
              );
            }
          }
          await _service.notifyBackend(alertId: id, channel: 'blood_match');
          if (mounted) setState(() => _status = 'Demande Sang envoyée. Matching (zone) en cours côté backend.');
        }
        break;
      case EmergencyAlertType.accident:
        final payload = await EmergencyActionSheets.showAccidentSheet(context);
        if (payload == null) return;
        await _triggerAccident(payload);
        break;
      case EmergencyAlertType.reportAnonymous:
        final payload = await EmergencyActionSheets.showAnonymousReportSheet(context);
        if (payload == null) return;
        await _triggerAnonymousReport(payload);
        break;
      case EmergencyAlertType.quickAssist:
        await _triggerAssistChat();
        break;
      case EmergencyAlertType.trustedContacts:
        await _openTrustedContacts();
        break;
      case EmergencyAlertType.surveillance:
        await _triggerSurveillanceMode();
        break;
      case EmergencyAlertType.liveLocation:
        await _triggerLiveLocationShare();
        break;
      default:
        await _triggerAlert(type: type, critical: false, title: label);
    }
  }

  Future<void> _triggerAlertWithMetadata({required String type, required String title, required Map<String, dynamic> metadata}) async {
    if (!await _ensureAuthenticated()) return;
    if (_working) return;
    setState(() {
      _working = true;
      _status = 'Initialisation…';
    });
    try {
      final pos = await _service.getCurrentPosition();
      final id = await _service.createEmergencyAlert(type: type, isCritical: false, silentMode: _silentMode, title: title, position: pos, metadata: metadata);
      if (!mounted) return;
      if (id == null) {
        setState(() => _status = 'Impossible de créer l’alerte.');
        return;
      }
      setState(() {
        _activeAlertId = id;
        _status = 'Alerte envoyée aux administrateurs. Suivi en cours…';
      });
      await _service.notifyBackend(alertId: id, channel: 'audit');
      await _service.startLiveTracking(alertId: id);
    } catch (e) {
      debugPrint('EmergencyOverlay: _triggerAlertWithMetadata failed: $e');
      if (mounted) setState(() => _status = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _triggerHotlineFlow({required String type, required String title, required String phone}) async {
    if (!await _ensureAuthenticated()) return;
    await _triggerAlertWithMetadata(type: type, title: title, metadata: {'hotline': phone, 'action': 'call_and_gps'});
    await _service.logPhoneCallIntent(phone);
    if (!mounted) return;
    if (_silentMode) {
      setState(() => _status = 'Mode silencieux: appel non ouvert automatiquement (audit OK).');
      return;
    }
    await EmergencyActionSheets.launchPhoneCall(context, phone);
  }

  Future<void> _triggerAccident(EmergencyAccidentPayload payload) async {
    if (!await _ensureAuthenticated()) return;
    if (_working) return;
    setState(() {
      _working = true;
      _status = 'Création du signalement…';
    });
    try {
      final pos = await _service.getCurrentPosition();
      final id = await _service.createEmergencyAlert(
        type: EmergencyAlertType.accident,
        isCritical: false,
        silentMode: _silentMode,
        title: 'ACCIDENT',
        description: payload.description,
        position: pos,
        metadata: payload.toMetadata(),
      );
      if (!mounted) return;
      if (id == null) {
        setState(() => _status = 'Impossible de créer le signalement.');
        return;
      }
      if (payload.photos.isNotEmpty) {
        setState(() => _status = 'Upload des photos…');
        await _service.uploadEvidenceFiles(alertId: id, files: payload.photos, kind: 'image');
      }
      setState(() {
        _activeAlertId = id;
        _status = 'Accident signalé aux administrateurs.';
      });
      await _service.notifyBackend(alertId: id, channel: 'audit');
      await _service.startLiveTracking(alertId: id);
    } catch (e) {
      debugPrint('EmergencyOverlay: _triggerAccident failed: $e');
      if (mounted) setState(() => _status = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _triggerAnonymousReport(EmergencyAnonymousReportPayload payload) async {
    if (!await _ensureAuthenticated()) return;
    if (_working) return;
    setState(() {
      _working = true;
      _status = 'Envoi anonyme…';
    });
    try {
      final pos = await _service.getCurrentPosition();
      final id = await _service.createEmergencyAlert(
        type: EmergencyAlertType.reportAnonymous,
        isCritical: false,
        silentMode: true,
        title: 'DÉNONCIATION (ANONYME)',
        description: payload.description,
        position: pos,
        metadata: payload.toMetadata(),
      );
      if (!mounted) return;
      if (id == null) {
        setState(() => _status = 'Impossible d’envoyer la dénonciation.');
        return;
      }
      if (payload.attachments.isNotEmpty) {
        setState(() => _status = 'Upload des preuves…');
        await _service.uploadEvidenceFiles(alertId: id, files: payload.attachments, kind: 'document');
      }
      setState(() {
        _activeAlertId = id;
        _status = 'Dénonciation envoyée aux administrateurs.';
      });
      await _service.notifyBackend(alertId: id, channel: 'audit');
    } catch (e) {
      debugPrint('EmergencyOverlay: _triggerAnonymousReport failed: $e');
      if (mounted) setState(() => _status = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _triggerAssistChat() async {
    if (!await _ensureAuthenticated()) return;
    await _triggerAlertWithMetadata(type: EmergencyAlertType.quickAssist, title: 'ASSISTANCE', metadata: {'channel': 'chat_support'});
    if (!mounted) return;
    widget.onClose();
    if (!mounted) return;
    context.go(AppRoutes.chat);
  }

  Future<void> _openTrustedContacts() async {
    if (!await _ensureAuthenticated()) return;
    if (_working) return;
    setState(() {
      _working = true;
      _status = 'Chargement des contacts…';
    });
    try {
      final initial = await _service.loadTrustedContacts();
      if (!mounted) return;
      setState(() {
        _working = false;
        _status = null;
      });
      final updated = await EmergencyActionSheets.showTrustedContactsSheet(context, initial);
      if (updated == null) return;
      await _service.saveTrustedContacts(updated);
      if (!mounted) return;
      setState(() => _status = 'Contacts enregistrés.');

      if (updated.isNotEmpty) {
        final sendNow = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Alerter vos contacts ?'),
              content: Text('Envoyer “Je suis en danger + position live” à ${updated.length} contact(s) ?'),
              actions: [
                TextButton(onPressed: () => context.pop(false), child: const Text('Pas maintenant')),
                FilledButton(onPressed: () => context.pop(true), child: const Text('Envoyer')),
              ],
            );
          },
        );
        if (sendNow == true) await _sendTrustedContactsAlert(updated);
      }
    } catch (e) {
      debugPrint('EmergencyOverlay: trusted contacts failed: $e');
      if (mounted) setState(() => _status = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendTrustedContactsAlert(List<TrustedContact> contacts) async {
    if (!await _ensureAuthenticated()) return;
    if (_working) return;
    setState(() {
      _working = true;
      _status = 'Préparation SMS + position…';
    });
    try {
      final pos = await _service.getCurrentPosition();
      final lat = pos?.latitude;
      final lng = pos?.longitude;
      final mapsUrl = (lat != null && lng != null) ? 'https://www.google.com/maps?q=$lat,$lng' : null;
      final body = 'THIX ID: Je suis en danger. Ma position: ${mapsUrl ?? 'indisponible'}';
      await _service.sendSmsAudit(phones: contacts.map((c) => c.phone).toList(growable: false), body: body);

      final id = await _service.createEmergencyAlert(
        type: EmergencyAlertType.trustedContacts,
        isCritical: false,
        silentMode: true,
        title: 'CONTACTS DE CONFIANCE',
        description: 'Alerte contacts: ${contacts.length} destinataire(s).',
        position: pos,
        metadata: {'contacts_count': contacts.length, 'maps_url': mapsUrl},
      );
      if (id != null) {
        setState(() {
          _activeAlertId = id;
          _status = 'Alerte créée. Ouverture des SMS…';
        });
        await _service.notifyBackend(alertId: id, channel: 'audit');
      }

      // Limitation plateforme: envoi silencieux interdit -> on ouvre l’app SMS.
      if (_silentMode) {
        if (mounted) setState(() => _status = 'Mode silencieux: SMS non ouverts automatiquement (audit OK).');
        return;
      }
      for (final c in contacts) {
        if (!mounted) break;
        await EmergencyActionSheets.launchSms(context, phone: c.phone, body: body);
      }
      if (mounted) setState(() => _status = 'SMS préparés.');
    } catch (e) {
      debugPrint('EmergencyOverlay: _sendTrustedContactsAlert failed: $e');
      if (mounted) setState(() => _status = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _triggerSurveillanceMode() async {
    if (!await _ensureAuthenticated()) return;
    if (_activeAlertId != null) {
      setState(() => _status = 'Mode surveillance déjà actif.');
      return;
    }
    await _triggerAlertWithMetadata(type: EmergencyAlertType.surveillance, title: 'MODE SURVEILLANCE', metadata: {'mode': 'preventive', 'audio': !kIsWeb});
    final id = _activeAlertId;
    if (id == null) return;
    if (!kIsWeb) {
      await _service.startLiveAudioStreaming(alertId: id, chunkDuration: const Duration(seconds: 10));
      if (mounted) setState(() => _status = 'Surveillance active: tracking + micro (foreground).');
    }
  }

  Future<void> _triggerLiveLocationShare() async {
    if (!await _ensureAuthenticated()) return;
    if (_activeAlertId == null) {
      await _triggerAlertWithMetadata(type: EmergencyAlertType.liveLocation, title: 'PARTAGE LOCALISATION LIVE', metadata: {'share': true});
    }
    final pos = await _service.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _status = 'Impossible de récupérer la position pour partager.');
      return;
    }
    await EmergencyActionSheets.shareLiveLocation(context: context, lat: pos.latitude, lng: pos.longitude, label: 'THIX ID — Localisation');
  }

  Future<void> _stopCriticalFlow() async {
    final id = _activeAlertId;
    if (id == null) return;
    setState(() {
      _working = true;
      _status = 'Finalisation…';
    });
    try {
      await _service.stopLiveTracking();
      await _service.stopLiveAudioStreaming();
      await _service.stopAndUploadAudioEvidence(alertId: id);
      if (mounted) setState(() => _status = 'Preuves envoyées.');
    } catch (e) {
      debugPrint('EmergencyOverlay: stop flow failed: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _startEmergencyCall(String phone) async {
    try {
      await _service.logPhoneCallIntent(phone);
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('EmergencyOverlay: emergency call failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final red = _red;
    final text = _text;
    final muted = _muted;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: EmergencyUrgentGradients.background(),
                ),
                child: CustomPaint(painter: _UrgentGlowPainter(red: red)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _EmergencyHeader(onClose: widget.onClose, textColor: text, mutedColor: muted),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: EmergencyUrgentGradients.panel(),
                          border: Border.all(color: _stroke.withValues(alpha: 0.70)),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SilentModeRow(
                                value: _silentMode,
                                onChanged: (v) => setState(() => _silentMode = v),
                                textColor: text,
                                mutedColor: muted,
                                bg: _card,
                                border: _stroke,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _CriticalButton(
                                pulse: _pulse,
                                glow: _glow,
                                red: red,
                                disabled: _working,
                                isActive: _activeAlertId != null,
                                onPressed: () => _triggerAlert(type: EmergencyAlertType.critical, critical: true, title: 'URGENCE CRITIQUE'),
                                onStop: _stopCriticalFlow,
                                textColor: text,
                                mutedColor: muted,
                              ),
                              if (_status != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                _StatusLine(text: _status!, accent: EmergencyUrgentColors.amber, bg: _card, border: _stroke, textColor: text),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              Text('Actions rapides', style: context.textStyles.titleMedium?.copyWith(color: text).semiBold),
                              const SizedBox(height: AppSpacing.sm),
                              _EmergencyGrid(
                                disabled: _working,
                                onTap: _handleActionTap,
                                bg: _card,
                                border: _stroke,
                                textColor: text,
                                mutedColor: muted,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (_activeAlertId == null) _SponsoredSafetySection(accent: EmergencyUrgentColors.cyan, ads: _ads, bg: _card, border: _stroke, textColor: text, mutedColor: muted),
                              if (_activeAlertId != null) ...[
                                _LiveLocationCard(
                                  accent: EmergencyUrgentColors.medicalBlue,
                                  bg: _card,
                                  border: _stroke,
                                  textColor: text,
                                  mutedColor: muted,
                                  pos: _latestPos,
                                  lastUpdatedAt: _lastUiPosAt,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _ActiveAlertFooter(
                                  alertId: _activeAlertId!,
                                  accent: EmergencyUrgentColors.medicalBlue,
                                  bg: _card,
                                  border: _stroke,
                                  textColor: text,
                                  mutedColor: muted,
                                  adminPhones: _adminPhones,
                                  latestPos: _latestPos,
                                  onCallAdmin: (phone) async {
                                    if (_silentMode) {
                                      if (mounted) setState(() => _status = 'Mode silencieux: appel manuel uniquement.');
                                      return;
                                    }
                                    await EmergencyActionSheets.launchPhoneCall(context, phone);
                                  },
                                  onOpenMap: () async {
                                    final p = _latestPos;
                                    if (p == null) return;
                                    await EmergencyActionSheets.launchMaps(context, lat: p.latitude, lng: p.longitude);
                                  },
                                  onShare: () async {
                                    final p = _latestPos;
                                    if (p == null) return;
                                    await EmergencyActionSheets.shareLiveLocation(context: context, lat: p.latitude, lng: p.longitude, label: 'THIX ID — Position live');
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyHeader extends StatelessWidget {
  final VoidCallback onClose;
  final Color textColor;
  final Color mutedColor;
  const _EmergencyHeader({required this.onClose, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderCircleButton(icon: Icons.arrow_back_rounded, onPressed: onClose, color: textColor),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: EmergencyUrgentColors.panel.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: EmergencyUrgentColors.stroke.withValues(alpha: 0.80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, color: EmergencyUrgentColors.safetyGreen, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connecté', style: context.textStyles.labelLarge?.copyWith(color: textColor).semiBold),
                  const SizedBox(height: 1),
                  Text('Position exacte', style: context.textStyles.labelSmall?.copyWith(color: mutedColor)),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        _HeaderCircleButton(icon: Icons.close_rounded, onPressed: onClose, color: textColor),
      ],
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  const _HeaderCircleButton({required this.icon, required this.onPressed, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        splashFactory: NoSplash.splashFactory,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: EmergencyUrgentColors.panel.withValues(alpha: 0.92),
            border: Border.all(color: EmergencyUrgentColors.stroke.withValues(alpha: 0.80)),
          ),
          child: Icon(icon, color: color.withValues(alpha: 0.92), size: 20),
        ),
      ),
    );
  }
}

class _SilentModeRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textColor;
  final Color mutedColor;
  final Color bg;
  final Color border;
  const _SilentModeRow({required this.value, required this.onChanged, required this.textColor, required this.mutedColor, required this.bg, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.80)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: EmergencyUrgentColors.danger.withValues(alpha: 0.14),
              border: Border.all(color: EmergencyUrgentColors.danger.withValues(alpha: 0.35)),
            ),
            child: Center(child: Premium3DIcon(icon: Icons.notifications_off_rounded, size: 22, color: EmergencyUrgentColors.danger)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode silencieux', style: context.textStyles.titleMedium?.copyWith(color: textColor).semiBold),
                const SizedBox(height: 2),
                Text('Aucun son. Mode discret activé.', style: context.textStyles.bodySmall?.copyWith(color: mutedColor)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: EmergencyUrgentColors.danger),
        ],
      ),
    );
  }
}

class _CriticalButton extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController glow;
  final Color red;
  final bool disabled;
  final bool isActive;
  final VoidCallback onPressed;
  final VoidCallback onStop;
  final Color textColor;
  final Color mutedColor;

  const _CriticalButton({
    required this.pulse,
    required this.glow,
    required this.red,
    required this.disabled,
    required this.isActive,
    required this.onPressed,
    required this.onStop,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut));
    final glowOpacity = Tween<double>(begin: 0.25, end: 0.55).animate(CurvedAnimation(parent: glow, curve: Curves.easeInOut));
    final ring = EmergencyUrgentColors.stroke;

    return Column(
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([pulse, glow]),
          builder: (context, _) {
            return Transform.scale(
              scale: disabled ? 1 : scale.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: red.withValues(alpha: disabled ? 0.2 : glowOpacity.value),
                          blurRadius: 42,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  // Outer ring
                  Container(
                    width: 212,
                    height: 212,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          ring.withValues(alpha: 0.85),
                          EmergencyUrgentColors.panel.withValues(alpha: 0.30),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.62, 1.0],
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: disabled ? null : onPressed,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      splashFactory: NoSplash.splashFactory,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [red, red.withValues(alpha: 0.82)],
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('SOS', style: context.textStyles.headlineMedium?.copyWith(color: Colors.white, letterSpacing: 1.0).bold),
                            const SizedBox(height: 10),
                            Text('URGENCE\nCRITIQUE', textAlign: TextAlign.center, style: context.textStyles.titleMedium?.copyWith(color: Colors.white).bold),
                            const SizedBox(height: 8),
                            Text('Audio + GPS + Alerte', style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if (isActive)
          TextButton.icon(
            onPressed: disabled ? null : onStop,
            icon: Icon(Icons.stop_circle_rounded, color: EmergencyUrgentColors.amber),
            label: Text('Arrêter & envoyer les preuves', style: context.textStyles.labelLarge?.copyWith(color: EmergencyUrgentColors.amber, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String text;
  final Color accent;
  final Color bg;
  final Color border;
  final Color textColor;
  const _StatusLine({required this.text, required this.accent, required this.bg, required this.border, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.80)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(accent)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium?.copyWith(color: textColor.withValues(alpha: 0.90)))),
        ],
      ),
    );
  }
}

class _EmergencyGrid extends StatelessWidget {
  final bool disabled;
  final void Function(String type, String label) onTap;
  final Color bg;
  final Color border;
  final Color textColor;
  final Color mutedColor;

  const _EmergencyGrid({required this.disabled, required this.onTap, required this.bg, required this.border, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final items = <_EmergencyItemData>[
      const _EmergencyItemData(icon: Icons.warning_amber_rounded, label: 'Signaler un danger', subtitle: 'Discret + position', type: EmergencyAlertType.aggression, accent: EmergencyUrgentColors.danger),
      const _EmergencyItemData(icon: Icons.local_hospital_rounded, label: 'Ambulance', subtitle: 'Urgence médicale', type: EmergencyAlertType.ambulance, accent: EmergencyUrgentColors.medicalBlue),
      const _EmergencyItemData(icon: Icons.local_fire_department_rounded, label: 'Pompiers', subtitle: 'Incendie / secours', type: EmergencyAlertType.firefighters, accent: EmergencyUrgentColors.fireOrange),
      const _EmergencyItemData(icon: Icons.bloodtype_rounded, label: 'Sang', subtitle: 'Donner / demander', type: EmergencyAlertType.blood, accent: EmergencyUrgentColors.danger),
      const _EmergencyItemData(icon: Icons.car_crash_rounded, label: 'Accident', subtitle: 'Photo + position', type: EmergencyAlertType.accident, accent: EmergencyUrgentColors.amber),
      const _EmergencyItemData(icon: Icons.gpp_maybe_rounded, label: 'Dénoncer', subtitle: 'Preuves', type: EmergencyAlertType.reportAnonymous, accent: EmergencyUrgentColors.safetyGreen),
      const _EmergencyItemData(icon: Icons.support_agent_rounded, label: 'Assistance THIX', subtitle: 'Support 24/7', type: EmergencyAlertType.quickAssist, accent: EmergencyUrgentColors.violet),
      const _EmergencyItemData(icon: Icons.group_rounded, label: 'Contacts de confiance', subtitle: 'Prévenir', type: EmergencyAlertType.trustedContacts, accent: EmergencyUrgentColors.cyan),
      const _EmergencyItemData(icon: Icons.remove_red_eye_rounded, label: 'Surveillance', subtitle: 'Préventif', type: EmergencyAlertType.surveillance, accent: EmergencyUrgentColors.safetyGreen),
      const _EmergencyItemData(icon: Icons.my_location_rounded, label: 'Position live', subtitle: 'Partager', type: EmergencyAlertType.liveLocation, accent: EmergencyUrgentColors.medicalBlue),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 92, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemBuilder: (context, i) => _EmergencyGridCard(item: items[i], disabled: disabled, onTap: () => onTap(items[i].type, items[i].label), bg: bg, border: border, textColor: textColor, mutedColor: mutedColor),
    );
  }
}

class _EmergencyGridCard extends StatelessWidget {
  final _EmergencyItemData item;
  final bool disabled;
  final VoidCallback onTap;
  final Color bg;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  const _EmergencyGridCard({required this.item, required this.disabled, required this.onTap, required this.bg, required this.border, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final accent = item.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashFactory: NoSplash.splashFactory,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: border.withValues(alpha: 0.80)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 8)),
                  ],
                ),
                child: Center(child: Premium3DIcon(icon: item.icon, size: 22, color: accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.bodyMedium?.copyWith(color: textColor.withValues(alpha: 0.92)).semiBold),
                    if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.labelSmall?.copyWith(color: mutedColor)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyItemData {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String type;
  final Color accent;
  const _EmergencyItemData({required this.icon, required this.label, this.subtitle, required this.type, required this.accent});
}

class _SponsoredSafetySection extends StatelessWidget {
  final Color accent;
  final List<SponsoredSafetyAd> ads;
  final Color bg;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  const _SponsoredSafetySection({required this.accent, required this.ads, required this.bg, required this.border, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              Text('Conseils & sécurité', style: context.textStyles.titleMedium?.copyWith(color: textColor).semiBold),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (ads.isEmpty)
            Text('Aucune annonce pour le moment. Restez vigilant et partagez votre position si nécessaire.', style: context.textStyles.bodyMedium?.copyWith(color: mutedColor))
          else
            ...ads.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AdCard(ad: a, accent: accent, bg: bg, border: border, textColor: textColor, mutedColor: mutedColor),
                )),
        ],
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final SponsoredSafetyAd ad;
  final Color accent;
  final Color bg;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  const _AdCard({required this.ad, required this.accent, required this.bg, required this.border, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ad.title, style: context.textStyles.titleMedium?.copyWith(color: textColor).semiBold),
          if (ad.body != null && ad.body!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(ad.body!, style: context.textStyles.bodyMedium?.copyWith(color: mutedColor)),
          ],
          if (ad.ctaUrl != null && ad.ctaUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(ad.ctaUrl!);
                  if (uri == null) return;
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: Icon(Icons.open_in_new_rounded, color: accent),
                label: Text(ad.ctaLabel?.trim().isEmpty == false ? ad.ctaLabel! : 'Ouvrir', style: context.textStyles.labelLarge?.copyWith(color: accent)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveAlertFooter extends StatelessWidget {
  final String alertId;
  final Color accent;
  final Color bg;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  final List<String> adminPhones;
  final Position? latestPos;
  final Future<void> Function(String phone) onCallAdmin;
  final Future<void> Function() onOpenMap;
  final Future<void> Function() onShare;
  const _ActiveAlertFooter({
    required this.alertId,
    required this.accent,
    required this.bg,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.adminPhones,
    required this.latestPos,
    required this.onCallAdmin,
    required this.onOpenMap,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final canUseMap = latestPos != null;
    final admin = adminPhones.isNotEmpty ? adminPhones.first : EmergencyService.hotlineEmergency;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radio_button_checked_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alerte active', style: context.textStyles.titleMedium?.copyWith(color: textColor).semiBold),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${(alertId.length <= 8) ? alertId : alertId.substring(0, 8)}… • suivi en cours',
                      style: context.textStyles.bodySmall?.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onCallAdmin(admin),
                  icon: const Icon(Icons.call_rounded, color: Colors.white),
                  label: Text('Appeler Admin', style: context.textStyles.labelLarge?.copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canUseMap ? () => onOpenMap() : null,
                  icon: Icon(Icons.map_rounded, color: canUseMap ? accent : mutedColor),
                  label: Text('Carte', style: context.textStyles.labelLarge?.copyWith(color: canUseMap ? accent : mutedColor)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: canUseMap ? () => onShare() : null,
            icon: Icon(Icons.share_rounded, color: canUseMap ? accent : mutedColor),
            label: Text('Partager ma position', style: context.textStyles.labelLarge?.copyWith(color: canUseMap ? accent : mutedColor)),
          ),
        ],
      ),
    );
  }
}

class _LiveLocationCard extends StatelessWidget {
  final Color accent;
  final Color bg;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  final Position? pos;
  final DateTime? lastUpdatedAt;
  const _LiveLocationCard({
    required this.accent,
    required this.bg,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.pos,
    required this.lastUpdatedAt,
  });

  static String _osmStaticUrl(double lat, double lng) {
    // No API key needed; suitable as a lightweight preview inside the emergency sheet.
    // https://staticmap.openstreetmap.de/
    final center = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    final marker = center;
    return 'https://staticmap.openstreetmap.de/staticmap.php?center=$center&zoom=15&size=900x360&maptype=mapnik&markers=$marker,red-pushpin';
  }

  @override
  Widget build(BuildContext context) {
    final p = pos;
    final hasPos = p != null;
    final subtitle = hasPos
        ? 'Lat ${p.latitude.toStringAsFixed(5)} • Lng ${p.longitude.toStringAsFixed(5)} • ±${p.accuracy.toStringAsFixed(0)}m'
        : 'Position indisponible (permissions / GPS)';
    final last = lastUpdatedAt;
    final updated = last == null ? null : '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}:${last.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Localisation live', style: context.textStyles.titleMedium?.copyWith(color: textColor).semiBold),
                    const SizedBox(height: 2),
                    Text(
                      '${subtitle}${updated == null ? '' : ' • $updated'}',
                      style: context.textStyles.bodySmall?.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: 900 / 360,
              child: hasPos
                  ? Image.network(
                      _osmStaticUrl(p.latitude, p.longitude),
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) {
                        return Container(
                          color: EmergencyUrgentColors.stroke.withValues(alpha: 0.35),
                          alignment: Alignment.center,
                          child: Text('Carte indisponible', style: context.textStyles.bodyMedium?.copyWith(color: mutedColor)),
                        );
                      },
                    )
                  : Container(
                      color: EmergencyUrgentColors.stroke.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Text('En attente de position…', style: context.textStyles.bodyMedium?.copyWith(color: mutedColor)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A lightweight “3D” icon effect using only Material Icons (no assets).
///
/// It creates a subtle depth by layering the same icon with two offsets.
class Premium3DIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  const Premium3DIcon({super.key, required this.icon, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final shadow = Colors.black.withValues(alpha: 0.28);
    final highlight = Colors.white.withValues(alpha: 0.22);
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(offset: const Offset(1.2, 1.6), child: Icon(icon, size: size, color: shadow)),
        Transform.translate(offset: const Offset(-0.8, -1.0), child: Icon(icon, size: size, color: highlight)),
        Icon(icon, size: size, color: color),
      ],
    );
  }
}

class _UrgentGlowPainter extends CustomPainter {
  final Color red;
  const _UrgentGlowPainter({required this.red});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.shortestSide * 0.62;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          red.withValues(alpha: 0.18),
          red.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _UrgentGlowPainter oldDelegate) => oldDelegate.red != red;
}
