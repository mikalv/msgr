/// Convenience barrel export for the Msgr API + realtime client.
///
/// Usage:
/// ```dart
/// import 'package:libmsgr/api.dart';
///
/// final client = MsgrClient(baseUrl: 'https://dev.msgr.no');
/// ```
library;

export 'src/api/models.dart';
export 'src/api/msgr_api_client.dart';
export 'src/api/msgr_client.dart';
export 'src/realtime/channel_client.dart';
