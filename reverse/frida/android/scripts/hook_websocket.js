Java.perform(() => {
  const RealWebSocket = Java.use('okhttp3.internal.ws.RealWebSocket');
  const WebSocketReader = Java.use('okhttp3.internal.ws.WebSocketReader');
  const Buffer = Java.use('okio.Buffer');
  const Base64 = Java.use('android.util.Base64');

  function emit(payload) {
    try {
      send(payload);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log('Frida send failed:', error);
    }
  }

  RealWebSocket.sendMessage.overload(
    'okhttp3.WebSocket$PayloadType',
    'okio.Buffer',
    'boolean',
  ).implementation = function sendMessage(payloadType, buffer, compressed) {
    try {
      const clone = Buffer.$new();
      clone.write(buffer, buffer.size());
      const bytes = clone.readByteArray();
      emit({
        type: 'ws-outgoing',
        payloadType: payloadType ? payloadType.name() : 'unknown',
        compressed,
        length: bytes.length,
        base64: Base64.encodeToString(bytes, 2),
      });
    } catch (error) {
      emit({ type: 'error', stage: 'ws-send', message: error.toString() });
    }
    return this.sendMessage(payloadType, buffer, compressed);
  };

  const originalReadMessageFrame = WebSocketReader.readMessageFrame.overload();

  WebSocketReader.readMessageFrame.implementation = function readMessageFrame() {
    const result = originalReadMessageFrame.call(this);
    try {
      const buffer = Buffer.$new();
      this.frameCallback.value.onReadMessage(buffer);
      const bytes = buffer.readByteArray();
      emit({
        type: 'ws-incoming',
        length: bytes.length,
        base64: Base64.encodeToString(bytes, 2),
      });
    } catch (error) {
      emit({ type: 'error', stage: 'ws-read', message: error.toString() });
    }
    return result;
  };
});
