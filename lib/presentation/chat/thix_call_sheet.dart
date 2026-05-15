import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/services/call_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/theme.dart';

/// Bottom-sheet that hosts a 1:1 WebRTC call (audio/video).
///
/// Signaling is done via Supabase Realtime using [CallService.signalsTable].
class ThixCallSheet extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String kind; // audio|video
  final bool isCaller;
  final CallService calls;
  const ThixCallSheet({
    super.key,
    required this.callId,
    required this.otherUserId,
    required this.kind,
    required this.isCaller,
    required this.calls,
  });

  @override
  State<ThixCallSheet> createState() => _ThixCallSheetState();
}

class _ThixCallSheetState extends State<ThixCallSheet> {
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  StreamSubscription<List<Map<String, dynamic>>>? _signalsSub;
  final Set<String> _handledSignalIds = <String>{};

  bool _micOn = true;
  bool _camOn = true;
  bool _connected = false;
  bool _ending = false;
  DateTime? _startedAt;

  bool get _isVideo => widget.kind == 'video';

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    unawaited(_signalsSub?.cancel());
    unawaited(_disposeRtc());
    _local.dispose();
    _remote.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _local.initialize();
      await _remote.initialize();

      await _preparePeer();
      await _startSignalListener();

      if (widget.isCaller) {
        await _makeOffer();
      }
    } catch (e) {
      debugPrint('ThixCallSheet: init failed err=$e');
      if (mounted) _snack('Impossible de démarrer l’appel.');
    }
  }

  Future<void> _preparePeer() async {
    // Free STUN server for basic connectivity. For production, add TURN.
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };
    _pc = await createPeerConnection(config);

    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      unawaited(widget.calls.sendSignal(
        callId: widget.callId,
        toUserId: widget.otherUserId,
        type: 'candidate',
        payload: {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        },
      ));
    };

    _pc!.onConnectionState = (state) {
      debugPrint('ThixCallSheet: pc connectionState=$state');
      if (!mounted) return;
      final ok = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (ok && !_connected) {
        setState(() {
          _connected = true;
          _startedAt ??= DateTime.now();
        });
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed || state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        unawaited(_end(reason: 'disconnected'));
      }
    };

    _pc!.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remote.srcObject = event.streams.first;
      if (mounted) setState(() {});
    };

    final media = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': _isVideo,
    });
    _localStream = media;
    _local.srcObject = media;

    for (final t in media.getTracks()) {
      await _pc!.addTrack(t, media);
    }
    _startedAt = DateTime.now();
  }

  Future<void> _startSignalListener() async {
    final me = SupabaseConfig.client.auth.currentUser;
    if (me == null) throw Exception('Not authenticated');
    _signalsSub = widget.calls.streamSignals(callId: widget.callId, forUserId: me.id).listen((signals) {
      for (final s in signals.reversed) {
        final id = (s['id'] ?? '').toString();
        if (id.isEmpty || _handledSignalIds.contains(id)) continue;
        _handledSignalIds.add(id);
        unawaited(_handleSignal(s));
      }
    });
  }

  Future<void> _handleSignal(Map<String, dynamic> s) async {
    try {
      final type = (s['type'] as String?) ?? '';
      final payload = (s['payload'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      if (_pc == null) return;

      if (type == 'offer') {
        final offer = RTCSessionDescription(payload['sdp'] as String?, payload['type'] as String?);
        await _pc!.setRemoteDescription(offer);
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        await widget.calls.sendSignal(
          callId: widget.callId,
          toUserId: widget.otherUserId,
          type: 'answer',
          payload: {'sdp': answer.sdp, 'type': answer.type},
        );
      } else if (type == 'answer') {
        final ans = RTCSessionDescription(payload['sdp'] as String?, payload['type'] as String?);
        await _pc!.setRemoteDescription(ans);
      } else if (type == 'candidate') {
        final cand = RTCIceCandidate(payload['candidate'] as String?, payload['sdpMid'] as String?, (payload['sdpMLineIndex'] as num?)?.toInt());
        await _pc!.addCandidate(cand);
      } else if (type == 'hangup' || type == 'decline') {
        await _end(reason: type);
      }
    } catch (e) {
      debugPrint('ThixCallSheet: handleSignal failed err=$e');
    }
  }

  Future<void> _makeOffer() async {
    if (_pc == null) return;
    final offer = await _pc!.createOffer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': _isVideo ? 1 : 0});
    await _pc!.setLocalDescription(offer);
    await widget.calls.sendSignal(
      callId: widget.callId,
      toUserId: widget.otherUserId,
      type: 'offer',
      payload: {'sdp': offer.sdp, 'type': offer.type},
    );
  }

  Future<void> _disposeRtc() async {
    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleMic() async {
    final stream = _localStream;
    if (stream == null) return;
    final enabled = !_micOn;
    for (final t in stream.getAudioTracks()) {
      t.enabled = enabled;
    }
    setState(() => _micOn = enabled);
  }

  Future<void> _toggleCam() async {
    final stream = _localStream;
    if (stream == null) return;
    final enabled = !_camOn;
    for (final t in stream.getVideoTracks()) {
      t.enabled = enabled;
    }
    setState(() => _camOn = enabled);
  }

  Future<void> _end({required String reason}) async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      // Notify remote best-effort.
      await widget.calls.sendSignal(callId: widget.callId, toUserId: widget.otherUserId, type: 'hangup', payload: {'reason': reason});
    } catch (_) {}

    final started = _startedAt;
    if (started != null) {
      try {
        await widget.calls.completeCall(callId: widget.callId, startedAt: started, endedAt: DateTime.now());
      } catch (e) {
        debugPrint('ThixCallSheet: completeCall failed (ignored) err=$e');
      }
    } else {
      try {
        await widget.calls.setCallStatus(callId: widget.callId, status: 'declined');
      } catch (_) {}
    }

    await _disposeRtc();
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
                        Text(_isVideo ? 'Appel vidéo' : 'Appel audio', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          _connected ? 'Connecté' : (widget.isCaller ? 'Appel en cours…' : 'Connexion…'),
                          style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.60), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  _Action(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => _end(reason: 'closed')),
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
                          RTCVideoView(_remote, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                        else
                          Center(
                            child: Icon(Icons.graphic_eq_rounded, size: 64, color: scheme.primary.withValues(alpha: 0.65)),
                          ),
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
                                    child: RTCVideoView(_local, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
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

class _Action extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.tooltip, required this.onTap});

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
