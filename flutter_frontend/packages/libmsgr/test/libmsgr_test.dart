import 'package:libmsgr/libmsgr.dart';
import 'package:test/test.dart';

abstract class Observer {
  String name;

  Observer(this.name);

  void notify(dynamic notification) {
    print("[$notification] Hey $name, ${notification.message}!");
  }
}

void main() {
  group('A group of tests', () {
    final awesome = LibMsgr();

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(awesome.isAwesome, isTrue);
    });
  });
}
