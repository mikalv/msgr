import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/utils/device_info_impl.dart';
import 'package:messngr/utils/secure_store_impl.dart';
import 'package:messngr/utils/shared_preferences_impl.dart';

/// Configures the [LibMsgr] singleton with the concrete platform adapters
/// used by the legacy application.
Future<void> bootstrapLibMsgr() async {
  LibMsgr().secureStorage = SecureStore();
  LibMsgr().deviceInfoInstance = DeviceInfoImpl();
  LibMsgr().sharedPreferences = SharedPreferencesImpl();

  await LibMsgr().bootstrapLibrary();
}
