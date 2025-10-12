Java.perform(() => {
  const GeneratedMessageLite = Java.use('com.google.protobuf.GeneratedMessageLite');
  const MessageLite = Java.use('com.google.protobuf.MessageLite');
  const Base64 = Java.use('android.util.Base64');

  function safeSend(payload) {
    try {
      send(payload);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.log('Frida send failed:', err);
    }
  }

  const toByteArray = GeneratedMessageLite.toByteArray.overload();
  GeneratedMessageLite.toByteArray.overload().implementation = function () {
    const data = toByteArray.call(this);
    try {
      const className = this.$className || this.$class ? this.$class.$name : this.$className;
      safeSend({
        type: 'protobuf-serialized',
        className,
        length: data.length,
        base64: Base64.encodeToString(data, 2),
        stack: Java.use('android.util.Log').getStackTraceString(Java.use('java.lang.Throwable').$new()),
      });
    } catch (error) {
      safeSend({
        type: 'error',
        stage: 'protobuf-toByteArray',
        message: error.toString(),
      });
    }
    return data;
  };

  const parseFromBytes = GeneratedMessageLite.parseFrom.overload('com.google.protobuf.GeneratedMessageLite', '[B');
  parseFromBytes.implementation = function (instance, bytes) {
    try {
      safeSend({
        type: 'protobuf-parse',
        target: instance ? instance.$className : 'unknown',
        length: bytes.length,
        base64: Base64.encodeToString(bytes, 2),
        stack: Java.use('android.util.Log').getStackTraceString(Java.use('java.lang.Throwable').$new()),
      });
    } catch (error) {
      safeSend({
        type: 'error',
        stage: 'protobuf-parseFrom',
        message: error.toString(),
      });
    }
    return parseFromBytes.call(this, instance, bytes);
  };

  const toByteString = MessageLite.toByteString.overload();
  MessageLite.toByteString.overload().implementation = function () {
    const byteString = toByteString.call(this);
    try {
      const className = this.$className || this.$class ? this.$class.$name : this.$className;
      const byteArray = byteString.toByteArray();
      safeSend({
        type: 'protobuf-bytestring',
        className,
        length: byteArray.length,
        base64: Base64.encodeToString(byteArray, 2),
      });
    } catch (error) {
      safeSend({
        type: 'error',
        stage: 'protobuf-toByteString',
        message: error.toString(),
      });
    }
    return byteString;
  };
});
