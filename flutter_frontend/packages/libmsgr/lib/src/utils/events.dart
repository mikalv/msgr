/**
 * 
 *  Usage:
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
 */

Type typeof<T>() => T;
typedef DelegateHandler<T> = void Function(T response);

abstract class IHandler {
  void run(dynamic response);
  bool isType<T>(T type);
  dynamic get();
}

class Handler<T> implements IHandler {
  late T type;
  late DelegateHandler<T> _handler;
  Handler(DelegateHandler<T> handler) {
    _handler = handler;
  }

  T cast<T>(x) {
    return x == T ? x : null;
  }

  @override
  void run(dynamic response) {
    _handler(cast<T>(response));
  }

  @override
  bool isType<T2>(T2 type) {
    if (type is T) {
      return true;
    }
    return false;
  }

  @override
  DelegateHandler<T> get() {
    return _handler;
  }
}

abstract class IDelegate<T> {
  void subscribe(DelegateHandler<T> handler);
  void remove(DelegateHandler<T> handler);
  void invoke(T response);
}

class Delegate<T> implements IDelegate<T> {
  final _handlers = List<IHandler>.empty();

  @override
  void subscribe(DelegateHandler<T> handler) {
    _handlers.add(Handler(handler));
  }

  @override
  void invoke(T response) {
    for (var element in _handlers) {
      if (element.isType(response)) {
        element.run(response);
      }
    }
  }

  @override
  void remove(DelegateHandler<T> handler) {
    int indexSplice = -1;
    for (var i = 0; i < _handlers.length; i++) {
      if (_handlers[i].get() == handler) {
        indexSplice = i;
      }
    }
    _handlers.removeAt(indexSplice);
  }
}
