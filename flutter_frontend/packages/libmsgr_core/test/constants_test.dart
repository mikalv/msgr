import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:test/test.dart';

void main() {
  test('exposes production hosts', () {
    expect(MsgrHosts.apiServer, isNotEmpty);
    expect(MsgrHosts.authApiServer, isNotEmpty);
  });
}
