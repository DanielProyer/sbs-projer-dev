import 'package:web/web.dart' as web;

void navigateTo(String url) => web.window.location.href = url;

void clearQuery(String cleanUrl) =>
    web.window.history.replaceState(null, '', cleanUrl);

void sessionSet(String key, String value) =>
    web.window.sessionStorage.setItem(key, value);

String? sessionGet(String key) => web.window.sessionStorage.getItem(key);

void sessionRemove(String key) => web.window.sessionStorage.removeItem(key);
