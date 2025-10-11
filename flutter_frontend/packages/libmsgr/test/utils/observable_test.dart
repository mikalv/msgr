import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/src/utils/observable.dart';

void main() {
  group('Observable', () {
    test('addListener adds a listener', () {
      final observable = Observable<void Function()>();
      void listener(listen) {}

      observable.addListener(listener);

      expect(observable.listeners.contains(listener), isTrue);
    });

    test('removeListener removes a listener', () {
      final observable = Observable<void Function()>();
      void listener(listen) {}

      observable.addListener(listener);
      observable.removeListener(listener);

      expect(observable.listeners.contains(listener), isFalse);
    });

    test('notifyListeners notifies all listeners', () {
      final observable = Observable<void Function()>();
      bool listener1Notified = false;
      bool listener2Notified = false;

      void listener1(listen) {
        listener1Notified = true;
      }

      void listener2(listen) {
        listener2Notified = true;
      }

      observable.addListener(listener1);
      observable.addListener(listener2);

      observable.notifyListeners(() => {});

      expect(listener1Notified, isTrue);
      expect(listener2Notified, isTrue);
    });
  });
}
