# WebRTC 1:1 Voice/Video Calls — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Working 1:1 voice and video calls between two users, with incoming call notification, call UI, and TURN relay.

**Architecture:** Flutter `flutter_webrtc` connects via existing `RTCChannel` (Phoenix Channel) for SDP/ICE signaling. CallRegistry manages server-side state. coturn provides STUN/TURN for NAT traversal. CallProvider (Riverpod) manages client-side call lifecycle.

**Tech Stack:** flutter_webrtc, Phoenix Channels (RTCChannel already exists), coturn (already deployed), Riverpod

**What already exists:**
- Backend: `RTCChannel` at `backend/apps/msgr_web/lib/msgr_web/channels/rtc_channel.ex` — full signaling (SDP offer/answer, ICE candidates, join/leave/end)
- Backend: `CallRegistry`, `CallSession`, `Participant` — in-memory call state
- Backend: Channel route `rtc:*` in `user_socket.ex:128`
- Flutter: `flutter_webrtc` in deps, `enums.dart` with CallState/Session models
- Flutter: TURN helper at `services/webrtc_calls/turn.dart`
- Flutter: Skeleton `VideoCallScreen` at `ui/screens/call_screen/call_screen.dart`
- Infra: `msgr_coturn` Docker container running

---

### Task 1: TURN credentials endpoint

**Files:**
- Create: `backend/apps/msgr_web/lib/msgr_web/controllers/turn_controller.ex`
- Modify: `backend/apps/msgr_web/lib/msgr_web/router.ex`

**Step 1: Create TurnController**

```elixir
defmodule MessngrWeb.TurnController do
  use MessngrWeb, :controller

  @turn_ttl 86400  # 24 hours
  @turn_host Application.compile_env(:msgr_web, :turn_host, "dev.msgr.no")
  @turn_port Application.compile_env(:msgr_web, :turn_port, 3478)
  @turn_secret Application.compile_env(:msgr_web, :turn_secret, "relay-turn-secret")

  def credentials(conn, _params) do
    account = conn.assigns.current_account
    expiry = System.system_time(:second) + @turn_ttl
    username = "#{expiry}:#{account.id}"
    credential = :crypto.mac(:hmac, :sha, @turn_secret, username) |> Base.encode64()

    json(conn, %{
      ice_servers: [
        %{urls: "stun:#{@turn_host}:#{@turn_port}"},
        %{
          urls: ["turn:#{@turn_host}:#{@turn_port}", "turn:#{@turn_host}:#{@turn_port}?transport=tcp"],
          username: username,
          credential: credential
        }
      ]
    })
  end
end
```

**Step 2: Add route**

In the authenticated `/api` scope in router.ex:
```elixir
get "/turn-credentials", TurnController, :credentials
```

**Step 3: Commit**

```bash
git commit -m "feat: TURN credentials endpoint with ephemeral HMAC auth"
```

---

### Task 2: CallProvider — Riverpod state management

**Files:**
- Create: `flutter_frontend/packages/core/lib/providers/call_provider.dart`

**Step 1: Create CallProvider**

Core state notifier managing the full call lifecycle:

```dart
enum CallStatus { idle, outgoing, incoming, connecting, active, ended }

class CallState {
  final CallStatus status;
  final String? callId;
  final String? channelId;  // relay channel where call was initiated
  final String? remoteProfileId;
  final String? remoteDisplayName;
  final bool isVideo;
  final bool isMicMuted;
  final bool isCameraMuted;
  final bool isSpeakerOn;
  final Duration duration;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
}
```

Methods:
- `initiateCall(channelId, remoteProfileId, {video: false})` — start outgoing call
- `acceptCall()` — accept incoming
- `rejectCall()` — decline incoming
- `hangUp()` — end active call
- `toggleMic()` / `toggleCamera()` / `toggleSpeaker()`
- `_handleSignalingEvent(event, payload)` — route WS events

**Step 2: Wire to RTCChannel via libmsgr realtime**

Join `rtc:{conversationId}` channel on call initiate/accept.
Listen for `signal:offer`, `signal:answer`, `signal:candidate`, `call:ended`, `participant:left`.

**Step 3: WebRTC PeerConnection setup**

```dart
Future<void> _createPeerConnection() async {
  final creds = await _api.getTurnCredentials();
  _pc = await createPeerConnection({'iceServers': creds['ice_servers']});

  _localStream = await navigator.mediaDevices.getUserMedia({
    'audio': true,
    'video': _state.isVideo,
  });

  _localStream!.getTracks().forEach((track) => _pc!.addTrack(track, _localStream!));

  _pc!.onTrack = (event) {
    state = state.copyWith(remoteStream: event.streams[0]);
  };

  _pc!.onIceCandidate = (candidate) {
    _channel.push('signal:candidate', {
      'candidate': candidate.toMap(),
    });
  };
}
```

**Step 4: Commit**

```bash
git commit -m "feat: CallProvider with WebRTC lifecycle and signaling"
```

---

### Task 3: libmsgr — TURN credentials + call channel methods

**Files:**
- Modify: `flutter_frontend/packages/libmsgr/lib/src/api/msgr_api_client.dart`

**Step 1: Add API methods**

```dart
/// GET /api/turn-credentials
Future<Map<String, dynamic>> getTurnCredentials() async {
  return get('/api/turn-credentials');
}
```

**Step 2: Add realtime methods for call channel**

In `MsgrRealtimeClient` or equivalent — ability to join `rtc:*` topics and push/receive signaling events.

**Step 3: Commit**

```bash
git commit -m "feat: libmsgr TURN credentials + call channel methods"
```

---

### Task 4: Incoming call overlay

**Files:**
- Create: `flutter_frontend/packages/core/lib/ui/call/incoming_call_overlay.dart`

**Step 1: Build overlay widget**

- Fullscreen overlay with dark translucent background
- Caller avatar (large, centered) + display name
- "Voice Call" or "Video Call" label
- Green accept button (phone icon) + red decline button
- Pulsating ring animation on avatar
- Auto-dismiss after 30s timeout

**Step 2: Trigger from CallProvider**

When `call:incoming` WS event arrives → CallProvider sets `status: incoming` → AppShell shows overlay.

**Step 3: Commit**

```bash
git commit -m "feat: incoming call overlay with accept/decline"
```

---

### Task 5: Outgoing call screen

**Files:**
- Create: `flutter_frontend/packages/core/lib/ui/call/outgoing_call_screen.dart`

**Step 1: Build screen**

- Callee avatar + name (centered)
- "Calling..." label with pulsating dots
- Red "Cancel" button
- 30s timeout → auto-cancel with toast

**Step 2: Wire to CallProvider**

`initiateCall()` → push to `rtc:*` channel → show this screen → wait for `signal:answer` or timeout.

**Step 3: Commit**

```bash
git commit -m "feat: outgoing call screen with cancel and timeout"
```

---

### Task 6: Active call screen

**Files:**
- Rewrite: `flutter_frontend/packages/core/lib/ui/screens/call_screen/call_screen.dart`

**Step 1: Build active call UI**

- **Video mode**: RTCVideoView for remote (fullscreen), local self-preview (small draggable PiP, 120x160)
- **Voice mode**: two avatars with pulsating animation when speaking
- **Bottom toolbar**: mic toggle, camera toggle, flip camera, speaker toggle, hang up (red)
- **Top bar**: call duration timer (MM:SS), callee name
- **State from CallProvider**: localStream, remoteStream, isMicMuted, isCameraMuted, duration

**Step 2: Duration timer**

Start a periodic Timer when status becomes `active`, increment every second.

**Step 3: Commit**

```bash
git commit -m "feat: active call screen with video, controls, and timer"
```

---

### Task 7: Call buttons in UI

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/channel_header.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/profile_card.dart`

**Step 1: Add call buttons to DM channel header**

Next to search/pin/members icons, add phone + video icons (only for DM channels):

```dart
if (channel.kind == ChannelKind.dm) ...[
  _HeaderIcon(Icons.phone_outlined, onTap: onVoiceCall),
  _HeaderIcon(Icons.videocam_outlined, onTap: onVideoCall),
],
```

**Step 2: Add "Call" button to profile hover card**

In `_MiniProfileCard`, add a call button next to "Message".

**Step 3: Wire callbacks through to CallProvider**

```dart
ref.read(callProvider.notifier).initiateCall(channel.id, otherProfileId, video: false);
```

**Step 4: Commit**

```bash
git commit -m "feat: call buttons in DM header and profile cards"
```

---

### Task 8: Call notification via push

**Files:**
- Modify: `backend/apps/msgr_web/lib/msgr_web/channels/rtc_channel.ex` (or add to call initiation flow)

**Step 1: Send push notification on incoming call**

When a call is initiated, if the callee is not in the `rtc:*` channel within 3 seconds, send a push notification:

```elixir
# After broadcasting call:incoming via WS, spawn a push fallback:
Task.Supervisor.start_child(Messngr.TaskSupervisor, fn ->
  Process.sleep(3_000)
  # Check if callee joined — if not, send push
  case Calls.fetch_call(call_id) do
    {:ok, call} ->
      unless Map.has_key?(call.participants, callee_profile_id) do
        Messngr.Push.Dispatcher.notify_incoming_call(team_slug, prefix, caller_name, callee_profile_id)
      end
    _ -> :ok
  end
end)
```

**Step 2: Handle push notification tap in Flutter**

Open incoming call overlay when push notification is tapped.

**Step 3: Commit**

```bash
git commit -m "feat: push notification fallback for incoming calls"
```

---

### Task 9: Integration and call routing in AppShell

**Files:**
- Modify: `flutter_frontend/packages/core/lib/ui/shell/app_shell.dart`
- Modify: `flutter_frontend/packages/core/lib/ui/shell/chat/simple_chat_content.dart`

**Step 1: Add call overlay to AppShell**

Watch `callProvider` in AppShell build. Show appropriate screen as overlay:

```dart
final callState = ref.watch(callProvider);

return Stack(children: [
  // ... normal app content ...
  if (callState.status == CallStatus.incoming)
    IncomingCallOverlay(...),
  if (callState.status == CallStatus.outgoing)
    OutgoingCallScreen(...),
  if (callState.status == CallStatus.active || callState.status == CallStatus.connecting)
    ActiveCallScreen(...),
]);
```

**Step 2: Wire WS events to CallProvider**

In RealtimeNotifier, detect `call:incoming` events on team channel and route to CallProvider.

**Step 3: Commit**

```bash
git commit -m "feat: call routing in AppShell with overlay stack"
```

---

## Task Dependencies

```
Task 1 (TURN endpoint) ──────────────┐
Task 3 (libmsgr methods) ────────────┤
                                      ├── Task 2 (CallProvider) ── Task 4 (Incoming) ──┐
                                                                    Task 5 (Outgoing) ──┤
                                                                    Task 6 (Active) ────┤
                                                                    Task 7 (Buttons) ───┤
                                                                                        ├── Task 9 (Integration)
                                                                    Task 8 (Push) ──────┘
```

Tasks 1+3 can run in parallel. Tasks 4-8 depend on Task 2. Task 9 ties everything together.
