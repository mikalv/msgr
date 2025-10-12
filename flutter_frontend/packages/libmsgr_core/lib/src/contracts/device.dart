/// Abstraction describing the device information required by libmsgr.
abstract class DeviceInfoProvider {
  /// Metadata about the physical/logical device (model, OS, IDs).
  Future<Map<String, dynamic>> deviceInfo();

  /// Application information (name, version, build number).
  Future<Map<String, dynamic>> appInfo();
}
