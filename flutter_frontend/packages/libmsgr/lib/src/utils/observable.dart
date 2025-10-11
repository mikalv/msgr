/// A class that allows objects to be observed for changes.
///
/// The `Observable` class maintains a list of listeners that are notified
/// whenever the `notifyListeners` method is called with an item of type `T`.
///
/// Type Parameters:
/// - `T`: The type of the item that will be passed to the listeners.
///
/// Methods:
/// - `addListener(void Function(T) listener)`: Adds a listener to the list of listeners.
/// - `removeListener(void Function(T) listener)`: Removes a listener from the list of listeners.
/// - `notifyListeners(T item)`: Notifies all registered listeners with the provided item.
///
/// Properties:
/// - `listeners`: Returns the list of registered listeners.
class Observable<T> {
  final List<void Function(T)> _listeners = <void Function(T)>[];

  void addListener(void Function(T) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(T) listener) {
    _listeners.remove(listener);
  }

  get listeners => _listeners;

  void notifyListeners(T item) {
    for (var listener in _listeners) {
      listener(item);
    }
  }
}

/*
abstract class Observer {
  String name;

  Observer(this.name);

  void notify(dynamic notification) {
    print("[$notification] Hey $name, ${notification.message}!");
  }
}

class Observable {
  final List<Observer> _observers;

  Observable(this._observers) {}

  void registerObserver(Observer observer) {
    _observers.add(observer);
  }

  void notify_observers(dynamic notification) {
    for (var observer in _observers) {
      observer.notify(notification);
    }
  }
}
*/

/**
 * 
 * Example: 
 * 
 * 
 class CoffeeMaker extends Observable {
  CoffeeMaker([List<Observer> observers]) : super(observers);
  void brew() {
    print("Brewing the coffee...");
    notify_observers(Notification.forNow("coffee's done"));
  }
}

void main() {
  var me = Observer("Tyler");
  var mrCoffee = CoffeeMaker(List.from([me]));
  var myWife = Observer("Kate");
  mrCoffee.registerObserver(myWife);
  mrCoffee.brew();
}
 * 
 * 
 */
