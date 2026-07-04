import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_service_app/widgets/app_icon.dart';

/// Renders the PrintEase app icon into the real launcher assets.
///
/// Run: flutter test test/render_app_icon_test.dart
Future<void> _render(String path, int size, {required bool maskable}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  AppIconPainter(maskable: maskable).paint(canvas, Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render launcher icons into web/', () async {
    await _render('web/icons/Icon-512.png', 512, maskable: false);
    await _render('web/icons/Icon-192.png', 192, maskable: false);
    await _render('web/icons/Icon-maskable-512.png', 512, maskable: true);
    await _render('web/icons/Icon-maskable-192.png', 192, maskable: true);
    await _render('web/favicon.png', 64, maskable: false);

    expect(File('web/favicon.png').lengthSync(), greaterThan(0));
  });
}
