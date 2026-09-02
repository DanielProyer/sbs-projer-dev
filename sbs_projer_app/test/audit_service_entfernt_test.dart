import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuditService ist abgelöst — kein Import mehr in lib/', () {
    expect(
      File('lib/services/buchhaltung/audit_service.dart').existsSync(),
      isFalse,
    );
    final treffer = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              f.readAsStringSync().contains('audit_service.dart'),
        );
    expect(
      treffer,
      isEmpty,
      reason: 'Die Abschlussprüfung ersetzt AuditService (Spec 02.09.2026).',
    );
  });
}
