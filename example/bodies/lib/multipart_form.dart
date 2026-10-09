/// form-data: fields and files (`multipart/form-data`) read at once with `formData()`, for small
/// uploads (the whole body is in memory).
///
/// Run: `dart run lib/multipart_form.dart`, then
/// `curl localhost:8080/albums -F title=Holiday -F photos=@a.png -F photos=@b.jpg`
library;

import 'package:winter/winter.dart';

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/albums',
      handler: (request) async {
        final FormData form = await request.formData();
        return ResponseEntity.created(
          location: '/albums/1',
          body: {
            'title': form['title'],
            'photos': [
              // <input type="file" name="photos" multiple>
              for (final UploadedFile file
                  in form.filesAll['photos'] ?? const [])
                {
                  // As the client sent them: never use the name as a path
                  'filename': file.filename,
                  'type': file.mimeType,
                  'bytes': file.length,
                },
            ],
          },
        );
      },
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());
