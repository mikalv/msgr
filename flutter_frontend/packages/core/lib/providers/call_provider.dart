import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';

import 'auth_state_provider.dart';
import 'msgr_client_provider.dart';
import 'team_list_provider.dart';

final _log = Logger('CallProvider');

// ---------------------------------------------------------------------------
// Call state
// ---------------------------------------------------------------------------

enum CallStatus { idle, outgoing, incoming, connecting, active, ended }

class CallState {
  const CallState({
    this.status = CallStatus.idle,
    this.callId,
    this.channelId,
    this.remoteProfileId,
    this.remoteDisplayName,
    this.isVideo = false,
    this.isMicMuted = false,
    this.isCameraMuted = false,
    this.isSpeakerOn = true,
    this.duration = Duration.zero,
    this.localStream,
    this.remoteStream,
  });

  final CallStatus status;
  final String? callId;
  final String? channelId;
  final String? remoteProfileId;
  final String? remoteDisplayName;
  final bool isVideo;
  final bool isMicMuted;
  final bool isCameraMuted;
  final bool isSpeakerOn;
  final Duration duration;
  final MediaStream? localStream;
  final MediaStream? remoteStream;

  CallState copyWith({
    CallStatus? status,
    String? callId,
    String? channelId,
    String? remoteProfileId,
    String? remoteDisplayName,
    bool? isVideo,
    bool? isMicMuted,
    bool? isCameraMuted,
    bool? isSpeakerOn,
    Duration? duration,
    MediaStream? localStream,
    MediaStream? remoteStream,
    bool clearRemoteStream = false,
  }) {
    return CallState(
      status: status ?? this.status,
      callId: callId ?? this.callId,
      channelId: channelId ?? this.channelId,
      remoteProfileId: remoteProfileId ?? this.remoteProfileId,
      remoteDisplayName: remoteDisplayName ?? this.remoteDisplayName,
      isVideo: isVideo ?? this.isVideo,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isCameraMuted: isCameraMuted ?? this.isCameraMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      duration: duration ?? this.duration,
      localStream: localStream ?? this.localStream,
      remoteStream:
          clearRemoteStream ? null : (remoteStream ?? this.remoteStream),
    );
  }
}

// ---------------------------------------------------------------------------
// Call notifier
// ---------------------------------------------------------------------------

class CallNotifier extends StateNotifier<CallState> {
  CallNotifier(this._ref) : super(const CallState());

  final Ref _ref;
  RTCPeerConnection? _pc;
  Timer? _durationTimer;
  Timer? _timeoutTimer;

  /// Start an outgoing call to a remote user.
  Future<void> initiateCall(String channelId, String remoteProfileId,
      {bool video = false, String? remoteName}) async {
    if (state.status != CallStatus.idle) return;

    _log.info(
        'Initiating ${video ? "video" : "voice"} call to $remoteProfileId');

    state = state.copyWith(
      status: CallStatus.outgoing,
      channelId: channelId,
      remoteProfileId: remoteProfileId,
      remoteDisplayName: remoteName,
      isVideo: video,
    );

    try {
      await _setupPeerConnection(video);
      await _joinRtcChannel(channelId);

      // Create and send offer
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      _pushSignal('signal:offer', {'sdp': offer.sdp, 'type': offer.type});

      // 30s timeout
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (state.status == CallStatus.outgoing) {
          _log.info('Call timeout — no answer');
          hangUp();
        }
      });
    } catch (e) {
      _log.warning('Failed to initiate call: $e');
      _cleanup();
    }
  }

  /// Handle an incoming call (triggered by WS event).
  void onIncomingCall(String callId, String channelId, String callerProfileId,
      String callerName, bool isVideo) {
    if (state.status != CallStatus.idle) {
      _log.info('Rejecting incoming call — already in a call');
      return;
    }

    state = state.copyWith(
      status: CallStatus.incoming,
      callId: callId,
      channelId: channelId,
      remoteProfileId: callerProfileId,
      remoteDisplayName: callerName,
      isVideo: isVideo,
    );

    // 30s auto-reject
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (state.status == CallStatus.incoming) {
        rejectCall();
      }
    });
  }

  /// Accept an incoming call.
  Future<void> acceptCall() async {
    if (state.status != CallStatus.incoming) return;
    _timeoutTimer?.cancel();

    _log.info('Accepting call from ${state.remoteProfileId}');
    state = state.copyWith(status: CallStatus.connecting);

    try {
      await _setupPeerConnection(state.isVideo);
      await _joinRtcChannel(state.channelId!);
    } catch (e) {
      _log.warning('Failed to accept call: $e');
      _cleanup();
    }
  }

  /// Reject an incoming call.
  void rejectCall() {
    if (state.status != CallStatus.incoming) return;
    _log.info('Rejecting call');
    _timeoutTimer?.cancel();
    _pushSignal('call:leave', {});
    _cleanup();
  }

  /// Hang up the current call.
  void hangUp() {
    _log.info('Hanging up');
    _timeoutTimer?.cancel();
    _pushSignal('call:leave', {});
    _cleanup();
  }

  /// Toggle microphone mute.
  void toggleMic() {
    final muted = !state.isMicMuted;
    state.localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
    state = state.copyWith(isMicMuted: muted);
    _pushSignal('media:toggle', {'audio': !muted});
  }

  /// Toggle camera.
  void toggleCamera() {
    final muted = !state.isCameraMuted;
    state.localStream?.getVideoTracks().forEach((t) => t.enabled = !muted);
    state = state.copyWith(isCameraMuted: muted);
    _pushSignal('media:toggle', {'video': !muted});
  }

  /// Flip between front/back camera.
  Future<void> flipCamera() async {
    final videoTrack = state.localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  // ── Signaling event handlers ──────────────────────────────

  void handleSignalingEvent(String event, Map<String, dynamic> payload) {
    switch (event) {
      case 'signal:offer':
        _onRemoteOffer(payload);
      case 'signal:answer':
        _onRemoteAnswer(payload);
      case 'signal:candidate':
        _onRemoteCandidate(payload);
      case 'call:ended':
        _log.info('Call ended by remote');
        _cleanup();
      case 'participant:left':
        final leftId = payload['profile_id']?.toString();
        if (leftId == state.remoteProfileId) {
          _log.info('Remote participant left');
          _cleanup();
        }
    }
  }

  Future<void> _onRemoteOffer(Map<String, dynamic> payload) async {
    if (_pc == null) return;
    final sdp = RTCSessionDescription(
        payload['sdp'] as String?, payload['type'] as String?);
    await _pc!.setRemoteDescription(sdp);

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _pushSignal('signal:answer', {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> _onRemoteAnswer(Map<String, dynamic> payload) async {
    if (_pc == null) return;
    final sdp = RTCSessionDescription(
        payload['sdp'] as String?, payload['type'] as String?);
    await _pc!.setRemoteDescription(sdp);

    // Connected!
    _timeoutTimer?.cancel();
    state = state.copyWith(status: CallStatus.active);
    _startDurationTimer();
  }

  Future<void> _onRemoteCandidate(Map<String, dynamic> payload) async {
    if (_pc == null) return;
    final candidate = payload['candidate'] as Map<String, dynamic>?;
    if (candidate != null) {
      await _pc!.addCandidate(RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ));
    }
  }

  // ── Private helpers ───────────────────────────────────────

  Future<void> _setupPeerConnection(bool video) async {
    if (kIsWeb) return; // Web WebRTC needs different handling

    final api = _ref.read(msgrApiProvider);
    Map<String, dynamic> iceConfig;
    try {
      final creds = await api.getTurnCredentials();
      iceConfig = {'iceServers': creds['ice_servers']};
    } catch (_) {
      // Fallback to public STUN only
      iceConfig = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ]
      };
    }

    _pc = await createPeerConnection(
        {...iceConfig, 'sdpSemantics': 'unified-plan'});

    // Get local media
    final localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });
    state = state.copyWith(localStream: localStream);

    localStream
        .getTracks()
        .forEach((track) => _pc!.addTrack(track, localStream));

    // Handle remote stream
    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        state = state.copyWith(
            remoteStream: event.streams[0], status: CallStatus.active);
        _timeoutTimer?.cancel();
        _startDurationTimer();
      }
    };

    // Send ICE candidates
    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      _pushSignal('signal:candidate', {'candidate': candidate.toMap()});
    };

    // Connection state monitoring
    _pc!.onConnectionState = (RTCPeerConnectionState connState) {
      _log.fine('PeerConnection state: $connState');
      if (connState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          connState ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _log.warning('PeerConnection failed/disconnected');
        _cleanup();
      }
    };
  }

  Future<void> _joinRtcChannel(String channelId) async {
    // Join rtc:{channelId} via the existing realtime client
    final client = _ref.read(msgrClientProvider);
    if (!client.isRealtimeConnected) return;

    final params = {
      'kind': 'direct',
      'media': state.isVideo ? ['audio', 'video'] : ['audio'],
      if (state.callId != null) 'call_id': state.callId,
    };

    await client.realtime.join('rtc:$channelId', payload: params);
  }

  void _pushSignal(String event, Map<String, dynamic> payload) {
    try {
      final client = _ref.read(msgrClientProvider);
      final channelId = state.channelId;
      if (channelId == null || !client.isRealtimeConnected) return;
      client.realtime.push('rtc:$channelId', event, payload);
    } catch (e) {
      _log.warning('Failed to push signal $event: $e');
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state =
          state.copyWith(duration: state.duration + const Duration(seconds: 1));
    });
  }

  void _cleanup() {
    _durationTimer?.cancel();
    _timeoutTimer?.cancel();

    // Close peer connection
    _pc?.close();
    _pc = null;

    // Stop local media
    state.localStream?.getTracks().forEach((t) => t.stop());

    // Leave rtc channel
    if (state.channelId != null) {
      try {
        final client = _ref.read(msgrClientProvider);
        client.realtime.leave('rtc:${state.channelId}');
      } catch (_) {}
    }

    state = const CallState(status: CallStatus.ended);

    // Reset to idle after a brief delay
    Future.delayed(const Duration(seconds: 2), () {
      if (state.status == CallStatus.ended) {
        state = const CallState();
      }
    });
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier(ref);
});
