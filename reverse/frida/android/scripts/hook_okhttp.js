Java.perform(() => {
  const RealCall = Java.use('okhttp3.RealCall');
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

  RealCall.execute.implementation = function execute() {
    const response = this.execute();
    const request = this.request();
    const url = request.url().toString();
    const method = request.method();

    emit({ type: 'http-request', url, method });

    const body = request.body();
    if (body) {
      try {
        const buffer = Buffer.$new();
        body.writeTo(buffer);
        const bytes = buffer.readByteArray();
        emit({
          type: 'http-request-body',
          url,
          method,
          length: bytes.length,
          base64: Base64.encodeToString(bytes, 2),
        });
      } catch (error) {
        emit({
          type: 'error',
          stage: 'request-body',
          message: error.toString(),
        });
      }
    }

    try {
      const resBody = response.body();
      if (resBody) {
        const source = resBody.source();
        source.request(java.lang.Long.MAX_VALUE);
        const buffer = source.getBuffer().clone();
        const bytes = buffer.readByteArray();
        emit({
          type: 'http-response-body',
          url,
          code: response.code(),
          length: bytes.length,
          base64: Base64.encodeToString(bytes, 2),
        });
      }
    } catch (error) {
      emit({ type: 'error', stage: 'response-body', message: error.toString() });
    }

    return response;
  };
});
