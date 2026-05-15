import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thix_id/services/call_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/theme.dart';

/// Bottom-sheet that hosts a 1:1 Agora call (audio/video).
///
/// Token is fetched from Supabase Edge Function: `agora-token`.
class ThixAgoraCallSheet extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String kind; // audio|video
  final bool isCaller;
  final CallService calls;
  const ThixAgoraCallSheet({
    super.key,
    required this.callId,
    required this.otherUserId,
    required this.kind,
    required this.isCaller,
    required this.calls,
  });

  @override
  State<ThixAgoraCallSheet> createState() => _ThixAgoraCallSheetState();
}

class _ThixAgoraCallSheetState extends State<ThixAgoraCallSheet> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _joined = false;
  bool _ending = false;
  bool _micOn = true;
  bool _camOn = true;
  DateTime? _startedAt;

  bool get _isVideo => widget.kind == 'video';

  String get _channelName => 'thix_call_${widget.callId}';

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    unawaited(_disposeAgora());
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _init() async {
    if (kIsWeb) {
      // Agora Flutter SDK (RTC Engine) is not supported on Flutter Web.
      _snack('Appel Agora non supporté sur Web.');
      if (mounted) context.pop();
      return;
    }

    final me = SupabaseConfig.client.auth.currentUser;
    if (me == null) {
      _snack('Veuillez vous connecter.');
      if (mounted) context.pop();
      return;
    }

    try {
      // Permissions.
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) throw Exception('Microphone permission denied');
      if (_isVideo) {
        final cam = await Permission.camera.request();
        if (!cam.isGranted) throw Exception('Camera permission denied');
      }

      final uid = widget.calls.agoraUidFor(me.id);
      final tokenRes = await widget.calls.fetchAgoraToken(channel: _channelName, uid: uid, role: 'publisher');
      final appId = (tokenRes['appId'] ?? '').toString();
      final token = (tokenRes['token'] ?? '').toString();

      if (appId.isEmpty || token.isEmpty) throw Exception('Missing Agora token/appId');

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      _engine = engine;

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            debugPrint('Agora: joined channel=${connection.channelId} uid=${connection.localUid}');
            if (!mounted) return;
            setState(() {
              _joined = true;
              _startedAt ??= DateTime.now();
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            debugPrint('Agora: remote joined uid=$remoteUid');
            if (!mounted) return;
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            debugPrint('Agora: remote offline uid=$remoteUid reason=$reason');
            if (!mounted) return;
            setState(() => _remoteUid = null);
          },
          onLeaveChannel: (connection, stats) {
            debugPrint('Agora: left channel');
          },
          onError: (err, msg) {
            debugPrint('Agora: error=$err msg=$msg');
          },
        ),
      );

      await engine.enableAudio();
      if (_isVideo) {
        await engine.enableVideo();
        await engine.startPreview();
      }

      await engine.joinChannel(
        token: token,
        channelId: _channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
    } catch (e) {
      debugPrint('ThixAgoraCallSheet: init failed err=$e');
      _snack('Impossible de démarrer l\'appel Agora.');
      if (mounted) context.pop();
    }
  }

  Future<void> _disposeAgora() async {
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
  }

  Future<void> _toggleMic() async {
    final engine = _engine;
    if (engine == null) return;
    final enabled = !_micOn;
    await engine.muteLocalAudioStream(!enabled);
    if (mounted) setState(() => _micOn = enabled);
  }

  Future<void> _toggleCam() async {
    final engine = _engine;
    if (engine == null) return;
    final enabled = !_camOn;
    await engine.muteLocalVideoStream(!enabled);
    if (mounted) setState(() => _camOn = enabled);
  }

  Future<void> _end({required String reason}) async {
    if (_ending) return;
    setState(() => _ending = true);

    final started = _startedAt;
    try {
      if (started != null) {
        await widget.calls.completeCall(callId: widget.callId, startedAt: started, endedAt: DateTime.now());
      } else {
        await widget.calls.setCallStatus(callId: widget.callId, status: 'declined');
      }
    } catch (e) {
      debugPrint('ThixAgoraCallSheet: end update call failed err=$e');
    }

    await _disposeAgora();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isVideo ? 'Appel vidéo (Agora)' : 'Appel audio (Agora)', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          _joined ? 'Connecté' : 'Connexion…',
                          style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.60), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  _HeaderAction(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => _end(reason: 'closed')),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.35)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_isVideo)
                          _remoteUid == null
                              ? Center(child: Text('En attente…', style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7))))
                              : AgoraVideoView(
                                  controller: VideoViewController.remote(
                                    rtcEngine: _engine!,
                                    canvas: VideoCanvas(uid: _remoteUid),
                                    connection: RtcConnection(channelId: _channelName),
                                  ),
                                )
                        else
                          Center(child: Icon(Icons.graphic_eq_rounded, size: 64, color: scheme.primary.withValues(alpha: 0.65))),
                        if (_isVideo)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: SizedBox(
                                width: 120,
                                height: 160,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7))),
                                    child: _engine == null
                                        ? const SizedBox.shrink()
                                        : AgoraVideoView(
                                            controller: VideoViewController(
                                              rtcEngine: _engine!,
                                              canvas: const VideoCanvas(uid: 0),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Pill(icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded, label: _micOn ? 'Micro' : 'Muet', onTap: _ending ? null : _toggleMic),
                  const SizedBox(width: AppSpacing.sm),
                  if (_isVideo) _Pill(icon: _camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, label: _camOn ? 'Cam' : 'Cam off', onTap: _ending ? null : _toggleCam),
                  if (_isVideo) const SizedBox(width: AppSpacing.sm),
                  _Hangup(onTap: _ending ? null : () => _end(reason: 'hangup')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 18, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;
  const _Pill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        ),
        child: InkWell(
          onTap: onTap == null ? null : () => unawaited(onTap!.call()),
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: scheme.onSurface),
                const SizedBox(width: 8),
                Text(label, style: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hangup extends StatelessWidget {
  final VoidCallback? onTap;
  const _Hangup({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: Icon(Icons.call_end_rounded, size: 18, color: scheme.onError),
        label: Text('Raccrocher', style: context.textStyles.labelLarge?.copyWith(color: scheme.onError, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
