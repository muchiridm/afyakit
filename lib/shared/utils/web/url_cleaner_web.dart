// Only compiled on web
import 'dart:html' as html;

void cleanUrl() {
  final cleaned = Uri.base.removeFragment();
  html.window.history.replaceState(null, '', cleaned.toString());
}
