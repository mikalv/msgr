# Libsignal Research for Msgr

## Executive Summary
- **Libsignal provides a mature end-to-end encryption (E2EE) stack** with session management, double-ratchet messaging, and advanced privacy features (sealed sender, contact discovery) that align with Msgr's long-term security goals.
- **Signal's ecosystem relies on Rust for its modern clients and bridges**, suggesting benefits if Msgr adopts or interoperates with Rust components for cryptographic correctness and performance.
- **Existing community bridges (e.g., matrix-signal via signald, signal-cli-rest-api)** expose APIs that demonstrate patterns Msgr could reuse or improve upon, but they also highlight risks around account control and legal considerations.

## Libsignal Fundamentals
Libsignal is the reference implementation of the Signal Protocol. Key properties include:

1. **Double Ratchet & X3DH Handshake**: Provides forward secrecy and post-compromise security through per-message ratchets and ephemeral Diffie-Hellman key agreements. Sessions survive reconnects while limiting key reuse.
2. **Sealed Sender**: Allows encrypted envelopes where the sender identity is hidden from the server, reducing metadata leakage.
3. **PreKeys & Key Distribution**: Uses signed prekeys and one-time prekeys stored on the server to bootstrap new sessions asynchronously, which is relevant for store-and-forward messaging.
4. **Safety Numbers & Verification**: Human-verifiable safety numbers mitigate active attacks by letting contacts confirm session fingerprints.

For Msgr, adopting similar primitives could strengthen confidentiality, authentication, and deniability guarantees.

## Signal Bridge Landscape
Signal does not officially support third-party bridges, but community efforts provide insight:

- **signal-cli and signal-cli-rest-api**: Java and REST wrappers that expose Signal messaging through a headless client. They rely on linking as an additional device, managing session state and message sync. Msgr's existing bridge experiments (see `bridge_sdks`) already leverage similar workflows.
- **signald / matrix-signal bridge**: signald is a daemon that wraps signal-cli and provides a JSON API. Matrix bridges (e.g., `mx-puppet-signal`) demonstrate how to sync messages, contacts, and typing indicators while handling rate limits and attachment uploads.
- **safrnet/signal-bridge** and other community projects: show patterns for queue-based relays, message normalization, and bridging ephemeral events.

**Key lessons**:
- Bridge clients must respect Signal's device-link and storage model; linking creates a full replica of message history on the bridge. Secure storage and clear user consent are critical.
- Rate limits, attachment upload flows, and message acknowledgements need careful handling to avoid account bans.
- Signal's terms of service discourage automated use; Msgr should plan for responsible disclosure and user-controlled linking.

## Security & Privacy Considerations
- **State Storage**: Libsignal clients store identity keys, signed prekeys, and session state locally. Msgr bridge daemons need encrypted at-rest storage with hardware security options where possible.
- **Account Safety**: Running a bridge as a linked device means the bridge can read all messages. Msgr should surface clear UX warnings and per-contact opt-in for bridging.
- **Metadata Reduction**: Libsignal supports sealed sender and private contact discovery (via `libsignal-service`). Leveraging these features would reduce server-visible metadata if Msgr interoperates directly.
- **Attestation & Device Capabilities**: Signal mobile clients use device checks (e.g., SafetyNet, attestation). Bridges mimicking a mobile device may need to emulate or bypass checks; this is an ongoing risk area.

## Implications for the Msgr Protocol
- **Session Model Alignment**: Msgr could adopt a double-ratchet layer for end-to-end encrypted chats, potentially using libsignal-protocol as a building block or inspiration.
- **Identity Abstraction**: Safety numbers map well to Msgr's identity verification roadmap. Integrating similar verification flows would improve trust.
- **Envelope Design**: Sealed sender shows how to minimize metadata; Msgr transports (StoneMQ, REST) could embed encrypted envelopes to hide sender IDs from infrastructure components.

## Rust Client Considerations
Signal's modern client stack (`libsignal-client`) is primarily Rust with bindings to other languages. Adopting Rust for Msgr client or bridge components offers:

- **Memory safety and FFI-friendly bindings** for Flutter/Dart, Go, and Python components.
- **Shared crypto primitives**: Reusing libsignal-client crates could avoid reimplementing complex cryptography.
- **Performance**: Rust's efficiency aids attachment processing and large group sync.

Challenges include:

- Binding maintenance (e.g., Dart FFI) and build complexity.
- Licensing and legal implications if directly reusing Signal's code (GPLv3 components must be respected).
- Keeping pace with upstream protocol changes; Signal evolves quickly and intentionally limits third-party use.

## Recommendations
1. **Prototype a Rust-based Msgr crypto module** leveraging libsignal-client's public crates for session management, exposed via FFI to Flutter and backend services for evaluation.
2. **Harden bridge storage** with encrypted vaults (e.g., age, libsodium, or Rust-based secure stores) mirroring libsignal's expectations for device safety.
3. **Document user consent flows** for Signal bridging, highlighting risks around message duplication and account policies.
4. **Engage with Signal community** to monitor protocol updates and ensure Msgr's bridge clients respect rate limits and device behavior.
5. **Assess legal/licensing constraints** before shipping libsignal-derived code, ensuring compatibility with Msgr's licensing.

## Further Reading
- Signal Protocol documentation: <https://signal.org/docs/>
- libsignal-client repository: <https://github.com/signalapp/libsignal>
- signal-cli project: <https://github.com/AsamK/signal-cli>
- matrix-signal bridge (mx-puppet-signal): <https://github.com/matrix-org/matrix-hookshot/tree/main/packages/mx-puppet-signal>
