/// form-data for big files: `multipart()` reads the parts as they arrive, and each file goes to
/// disk without being in memory. The file gets a name of its own, never the one sent.
///
/// Run: `dart run lib/streaming_upload.dart`, then `curl localhost:8080/uploads -F file=@video.mp4`
library;

import 'dart:io';

import 'package:winter/winter.dart';

WinterRouter router({required Directory directory}) {
  int lastId = 0;
  return WinterRouter(
    routes: [
      Route.post(
        path: '/uploads',
        handler: (request) async {
          final Map<String, String> fields = {};
          final List<Map<String, Object?>> saved = [];
          // Read each part before asking for the next one
          await for (final MultipartPart part in request.multipart()) {
            if (part.isFile) {
              final File file = File('${directory.path}/upload-${++lastId}');
              await part.read().pipe(file.openWrite());
              saved.add({
                'field': part.name,
                'savedAs': file.uri.pathSegments.last,
                'bytes': await file.length(),
              });
            } else {
              fields[part.name!] = await part.readAsString();
            }
          }
          return ResponseEntity.ok(body: {'fields': fields, 'files': saved});
        },
      ),
    ],
  );
}

Future<void> main() async {
  final Directory uploads = await Directory('uploads').create();
  await Winter.start(
    // 10 MB by default: raise it for big uploads
    config: const ServerConfig(maxBodySize: 500 * 1024 * 1024),
    router: router(directory: uploads),
  );
}
