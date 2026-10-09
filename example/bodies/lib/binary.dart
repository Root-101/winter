/// binary: the bytes as they came (an image, a PDF), with any `Content-Type`: `bytes()`.
///
/// Run: `dart run lib/binary.dart`, then
/// `curl localhost:8080/avatar -H 'Content-Type: image/png' --data-binary @me.png`
library;

import 'dart:typed_data';

import 'package:winter/winter.dart';

/// The first bytes of each format: check the content, not the Content-Type the client declares
const Map<String, List<int>> _signatures = {
  'image/png': [0x89, 0x50, 0x4E, 0x47],
  'image/jpeg': [0xFF, 0xD8, 0xFF],
  'application/pdf': [0x25, 0x50, 0x44, 0x46],
};

WinterRouter router() => WinterRouter(
  routes: [
    Route.put(
      path: '/avatar',
      handler: (request) async {
        final Uint8List bytes = await request.bytes();
        final String? detected = _signatures.entries
            .where((format) => _startsWith(bytes, format.value))
            .map((format) => format.key)
            .firstOrNull;
        if (detected == null || !detected.startsWith('image/')) {
          throw const UnsupportedMediaTypeException(
            detail: 'Send a PNG or a JPEG',
          );
        }
        return ResponseEntity.ok(
          body: {
            'declared': request.mimeType,
            'detected': detected,
            'bytes': bytes.length,
          },
        );
      },
    ),
  ],
);

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (int i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

Future<void> main() async => Winter.start(router: router());
