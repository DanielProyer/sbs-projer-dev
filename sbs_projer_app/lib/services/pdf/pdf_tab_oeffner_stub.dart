import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Native/Test-Fallback: Kein Browser-Tab verfügbar — Druck-/Vorschau-Dialog.
Future<void> oeffnePdfImNeuenTab(Uint8List bytes, String dateiname) =>
    Printing.layoutPdf(onLayout: (_) => bytes, name: dateiname);
