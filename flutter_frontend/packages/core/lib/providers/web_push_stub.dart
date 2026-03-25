/// Non-web stub — Web Push not available on native platforms.
bool isNotificationGranted() => false;
Future<String?> subscribeToPush(String vapidPublicKey) async => null;
