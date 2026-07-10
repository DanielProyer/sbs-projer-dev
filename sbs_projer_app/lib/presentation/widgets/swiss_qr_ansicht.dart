import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Zeigt einen Swiss-QR-Bill-Code (aus dem Payload) mit zwingendem
/// Schweizerkreuz in der Mitte — zum Scannen mit der Banking-App.
class SwissQrAnsicht extends StatelessWidget {
  final String payload;
  final double size;
  const SwissQrAnsicht({super.key, required this.payload, this.size = 240});

  @override
  Widget build(BuildContext context) {
    final svg = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium)
        .toSvg(payload, width: size, height: size, drawText: false);
    final k = size / 6; // Schweizerkreuz-Grösse

    return Container(
      width: size,
      height: size,
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.string(svg, width: size, height: size),
          // Schweizerkreuz: schwarzes Quadrat, weisser Rand, weisses Kreuz.
          Container(
            width: k,
            height: k,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.white, width: k * 0.07),
            ),
            child: Center(
              child: SizedBox(
                width: k * 0.6,
                height: k * 0.6,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(width: k * 0.6, height: k * 0.2, color: Colors.white),
                    Container(width: k * 0.2, height: k * 0.6, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
