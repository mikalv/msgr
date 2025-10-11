//Simple wrapper where I can inject a callback similar to store.dispatch
//Because of this I can add this to a provider and consume the callback lower
//in the widget tree
class Dispatcher {
  const Dispatcher(void Function(Object action) dispatch)
      : _dispatch = dispatch;
  final void Function(Object action) _dispatch;
  void call(Object action) => _dispatch(action);
}
