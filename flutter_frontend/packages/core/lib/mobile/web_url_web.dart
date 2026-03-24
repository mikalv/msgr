// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Replace the browser URL without navigation.
void replaceUrl(String path) {
  html.window.history.replaceState(null, '', path);
}
