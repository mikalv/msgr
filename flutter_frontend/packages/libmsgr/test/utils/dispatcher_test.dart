import 'package:flutter_test/flutter_test.dart';
import '../../lib/src/utils/dispatcher.dart';

void main() {
  group('Dispatcher', () {
    test('should call the provided dispatch function with the correct action',
        () {
      // Arrange
      bool wasCalled = false;
      Object? receivedAction;
      void mockDispatch(Object action) {
        wasCalled = true;
        receivedAction = action;
      }

      final dispatcher = Dispatcher(mockDispatch);
      final testAction = 'TEST_ACTION';

      // Act
      dispatcher.call(testAction);

      // Assert
      expect(wasCalled, isTrue);
      expect(receivedAction, equals(testAction));
    });
  });
}
