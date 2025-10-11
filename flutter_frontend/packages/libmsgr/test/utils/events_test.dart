import 'package:flutter_test/flutter_test.dart';
import '../../lib/src/utils/events.dart';

class MyClass {
  final IDelegate<String> errorDelegate = Delegate();

  void testError(String message) {
    errorDelegate.invoke(message);
  }
}

class MyParentClass {
  final MyClass dep = MyClass();

  MyParentClass() {
    dep.errorDelegate.subscribe((message) {
      print("ANONYMOUS $message");
    });
    dep.errorDelegate.subscribe(subscribeError);
    dep.testError("test 123");
    dep.errorDelegate.remove(subscribeError);
    dep.testError("test 123 again");
  }

  void subscribeError(String message) {
    print("SUBSCRIBE ERROR: $message");
  }
}

void main() {
  group('Delegate Tests', () {
    test('Delegate should invoke subscribed handlers', () {
      final delegate = Delegate<String>();
      String? result;

      delegate.subscribe((message) {
        result = message;
      });

      delegate.invoke('test message');

      expect(result, 'test message');
    });

    test('Delegate should remove subscribed handlers', () {
      final delegate = Delegate<String>();
      String? result;

      void handler(String message) {
        result = message;
      }

      delegate.subscribe(handler);
      delegate.remove(handler);
      delegate.invoke('test message');

      expect(result, isNull);
    });

    test('MyClass should invoke errorDelegate', () {
      final myClass = MyClass();
      String? result;

      myClass.errorDelegate.subscribe((message) {
        result = message;
      });

      myClass.testError('test error');

      expect(result, 'test error');
    });

    test('MyParentClass should handle errorDelegate correctly', () {
      final myParentClass = MyParentClass();
      String? anonymousResult;
      String? subscribeErrorResult;

      myParentClass.dep.errorDelegate.subscribe((message) {
        anonymousResult = message;
      });

      myParentClass.dep.errorDelegate.subscribe((message) {
        subscribeErrorResult = message;
      });

      myParentClass.dep.testError('test 123');

      expect(anonymousResult, 'test 123');
      expect(subscribeErrorResult, 'test 123');

      myParentClass.dep.errorDelegate.remove(myParentClass.subscribeError);
      anonymousResult = null;
      subscribeErrorResult = null;

      myParentClass.dep.testError('test 123 again');

      expect(anonymousResult, 'test 123 again');
      expect(subscribeErrorResult, isNull);
    });
  });
}
