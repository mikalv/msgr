# WebRTC Voice/Video Calls — Design Specification (#138)

## Overview

1:1 and group voice/video calls using WebRTC with signaling via Phoenix Channels. Mesh topology for up to 6 participants, with SFU planned for larger meetings.

## Architecture

```
Flutter (flutter_webrtc)  ←→  Phoenix Channel (signaling)  ←→  Flutter (flutter_webrtc)
         ↕                                                              ↕
    getUserMedia                                                   getUserMedia
         ↕                                                              ↕
    PeerConnection  ←————————— P2P media stream (WebRTC) ——————————→  PeerConnection
                                       ↕
                              STUN/TURN (coturn)
```

- **Signaling**: Phoenix Channels (`call:{call_id}`) relay SDP offers/answers and ICE candidates
- **Media**: direct peer-to-peer, no media through server
- **NAT traversal**: STUN + TURN via coturn (already in docker-compose)
- **Call state**: existing CallRegistry GenServer (in-memory)

## Topology

- **Mesh** for up to 6 participants (n*(n-1)/2 connections)
- Over 6 → friendly message pointing to future SFU support
- Each peer pair has its own RTCPeerConnection

## Signaling Protocol

### Channel: `call:{call_id}`

**Call lifecycle events:**
| Event | Direction | Description |
|-------|-----------|-------------|
| `call:initiate` | client → server | Start a call, creates CallSession |
| `call:incoming` | server → client | Notify callee (WS + push notification) |
| `call:accept` | client → server | Callee accepts, joins channel |
| `call:reject` | client → server | Callee declines |
| `call:hangup` | client → server | Leave/end call |
| `call:ended` | server → clients | Call terminated |
| `call:timeout` | server → caller | No answer after 30s |

**WebRTC signaling events:**
| Event | Direction | Description |
|-------|-----------|-------------|
| `sdp:offer` | client → server → client | SDP offer |
| `sdp:answer` | client → server → client | SDP answer |
| `ice:candidate` | client → server → client | ICE candidate |

**In-call events:**
| Event | Direction | Description |
|-------|-----------|-------------|
| `media:toggle` | client → server → clients | Mute/unmute audio/video |
| `peer:joined` | server → clients | New participant entered |
| `peer:left` | server → clients | Participant left |

### 1:1 Call Flow

```
Alice                    Server                     Bob
  |                        |                          |
  |-- call:initiate ------>|                          |
  |                        |-- call:incoming (WS) --->|
  |                        |-- push notification ---->|
  |                        |                          |
  |                        |<-- call:accept ----------|
  |                        |                          |
  |    (both join call:{call_id} channel)             |
  |                        |                          |
  |-- sdp:offer ---------->|-- sdp:offer ----------->|
  |<-- sdp:answer ---------|<-- sdp:answer ----------|
  |-- ice:candidate ------>|-- ice:candidate -------->|
  |<-- ice:candidate ------|<-- ice:candidate --------|
  |                        |                          |
  |    ========== P2P media stream ============       |
  |                        |                          |
  |-- call:hangup -------->|-- call:ended ----------->|
```

### Group Call Flow (mesh)

When a new participant joins an existing call:

1. Server broadcasts `peer:joined` to all existing participants
2. Each existing participant creates a new PeerConnection for the joiner
3. Existing participants send SDP offers to the new participant (via server relay)
4. New participant creates PeerConnections and sends SDP answers back
5. ICE candidates exchanged per peer pair

Max 6 participants in mesh. Over that → "Group calls support up to 6 participants. Larger meetings coming soon."

## TURN Configuration

### Ephemeral credentials

Server generates short-lived TURN credentials via HMAC:
- Username: `{expiry_timestamp}:{profile_id}`
- Credential: HMAC-SHA1(username, static_auth_secret)
- TTL: 24 hours
- Coturn validates automatically — no DB lookup

### API endpoint

```
GET /api/teams/:slug/turn-credentials
→ {
    "ice_servers": [
      {"urls": "stun:dev.msgr.no:3478"},
      {"urls": "turn:dev.msgr.no:3478",
       "username": "1711590000:user123",
       "credential": "hmac_sha1_result"}
    ]
  }
```

### Coturn config (existing)

```
use-auth-secret
static-auth-secret=<shared-secret>
realm=msgr.no
```

## Flutter UI

### 1. Outgoing call screen
- Callee avatar + name, pulsating ring animation
- Red "Hang up" button
- 30s timeout → auto-cancel

### 2. Incoming call overlay
- Fullscreen overlay on top of app
- Caller avatar + name + call type label
- Green "Accept" + red "Decline" buttons
- Ringtone (system sound)
- Push notification triggers this if app is backgrounded

### 3. Active call screen
- **Video**: large remote video, small draggable self-preview (PiP)
- **Voice-only**: avatars with pulsating animation on speech
- **Bottom toolbar**: toggle mic, toggle camera, flip camera, speaker, hang up
- **Timer**: 00:00 counting up
- **Group**: grid layout (2x2, 3x3) with active speaker highlight (green border)

### Active speaker detection
- `RTCPeerConnection.getStats()` → check `audioLevel`
- Highlight speaking participant with accent-colored border
- Optional: prioritize active speaker in grid layout

## State Management (Flutter)

```dart
CallProvider (Riverpod StateNotifier)
├── callState: idle | ringing | connecting | active | ended
├── callId: String?
├── localStream: MediaStream?
├── peers: Map<String, PeerState>  // profileId → {pc, remoteStream, audioLevel}
├── isMicMuted: bool
├── isCameraMuted: bool
└── callDuration: Duration
```

Listens to WS events from `call:{call_id}` channel.

### WebRTC lifecycle

```dart
// 1. Get TURN credentials
final creds = await api.getTurnCredentials(teamSlug);

// 2. Create peer connection
final pc = await createPeerConnection({'iceServers': creds.iceServers});

// 3. Get local media
final localStream = await navigator.mediaDevices.getUserMedia({
  'audio': true, 'video': isVideoCall,
});
localStream.getTracks().forEach((track) => pc.addTrack(track, localStream));

// 4. Exchange SDP
final offer = await pc.createOffer();
await pc.setLocalDescription(offer);
channel.push('sdp:offer', {'sdp': offer.toMap(), 'to': targetProfileId});

// 5. Handle remote answer
channel.on('sdp:answer', (payload) {
  pc.setRemoteDescription(RTCSessionDescription(payload['sdp'], payload['type']));
});

// 6. Exchange ICE candidates
pc.onIceCandidate = (candidate) {
  channel.push('ice:candidate', {'candidate': candidate.toMap(), 'to': targetProfileId});
};
channel.on('ice:candidate', (payload) {
  pc.addCandidate(RTCIceCandidate(...));
});

// 7. Display remote stream
pc.onTrack = (event) {
  remoteRenderer.srcObject = event.streams[0];
};
```

## Call Initiation Points

- **DM**: call button (phone/video icon) in DM channel header
- **Profile card**: "Call" button on profile hover card
- **Group**: "Start call" button in channel header (group channels only)

## Notification

- **In-app (WS)**: `call:incoming` event triggers fullscreen overlay
- **Push**: push notification with call metadata, tapping opens incoming call screen
- **Timeout**: 30s no answer → server sends `call:timeout`, call cancelled

## Dependencies

- `flutter_webrtc` — WebRTC for all platforms (macOS, iOS, Android, Web, Windows, Linux)
- Existing: `msgr_coturn` Docker container, `CallRegistry`, `CallSession`, `Participant`

## Phased Implementation

**Phase 1: 1:1 voice calls**
- Signaling channel (replace CallChannel stub)
- TURN credentials endpoint
- CallProvider in Flutter
- Outgoing/incoming/active call screens (voice only)
- Push notification for incoming calls

**Phase 2: 1:1 video calls**
- Add video to existing call flow
- Camera preview, flip camera
- PiP self-view

**Phase 3: Group calls (mesh)**
- Multi-peer connection management
- Grid layout UI
- Active speaker detection
- Max 6 participant limit

**Phase 4: SFU (separate issue)**
- MediaServer integration (LiveKit or similar)
- Scales to 50+ participants
- Screen sharing
