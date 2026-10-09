/// raw > Text, XML, HTML, JavaScript, CSV: `body<String>()` gives the text as it came, decoded with
/// the charset of its `Content-Type`.
///
/// Run: `dart run lib/raw_text.dart`, then
/// `curl localhost:8080/csv -H 'Content-Type: text/csv' --data-binary $'name,age\nAnn,30'`
library;

import 'package:winter/winter.dart';

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/text',
      handler: (request) async {
        final String text = await request.body<String>();
        return ResponseEntity.ok(
          body: {
            'contentType': request.mimeType,
            'characters': text.length,
            'text': text,
          },
        );
      },
    ),
    // A CSV, parsed by hand: one object per row
    Route.post(
      path: '/csv',
      handler: (request) async {
        final List<String> lines = (await request.body<String>())
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        if (lines.isEmpty) throw const BadRequestException(detail: 'Empty CSV');
        final List<String> header = lines.first.split(',');
        return ResponseEntity.ok(
          body: [
            for (final String line in lines.skip(1))
              Map.fromIterables(header, line.split(',')),
          ],
        );
      },
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());
