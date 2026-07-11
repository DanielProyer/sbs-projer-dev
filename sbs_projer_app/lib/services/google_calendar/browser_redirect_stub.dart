// Native-Stub: der OAuth-Verbinden-Flow läuft nur im Web.
void navigateTo(String url) =>
    throw UnsupportedError('Google-Verbinden nur im Web verfügbar');
void clearQuery(String cleanUrl) {}
void sessionSet(String key, String value) {}
String? sessionGet(String key) => null;
void sessionRemove(String key) {}
