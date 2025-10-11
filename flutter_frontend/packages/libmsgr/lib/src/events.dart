class Events {
  ///
  static const String healthCheck = 'health:check';

  /// Event sent when a user starts typing a message
  static const String typingStart = 'typing:start';

  /// Event sent when a user stops typing a message
  static const String typingStop = 'typing:stop';

  /// Event sent when receiving a new message
  static const String messageNew = 'new:msg';

  /// Event sent when receiving a new room
  static const String roomNew = 'new:room';
}
