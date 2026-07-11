import 'dart:html' as html;

void navigateTo(String url) => html.window.location.href = url;

void clearQuery(String cleanUrl) =>
    html.window.history.replaceState(null, '', cleanUrl);

void sessionSet(String key, String value) =>
    html.window.sessionStorage[key] = value;

String? sessionGet(String key) => html.window.sessionStorage[key];

void sessionRemove(String key) => html.window.sessionStorage.remove(key);
