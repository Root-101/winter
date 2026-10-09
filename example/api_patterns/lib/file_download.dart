/// Downloads: a big CSV export streamed row by row (never whole in memory) as an attachment
/// with a file name that has accents, and a generated file shown inline by the browser.
///
/// Run: `dart run lib/file_download.dart`, then `curl -OJ localhost:8080/exports/customers`
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:winter/winter.dart';

/// The rows, as a database cursor would give them: one at a time
Stream<List<Object>> customers(int count) async* {
  for (int id = 1; id <= count; id++) {
    yield [id, 'Customer $id', id.isEven ? 'active' : 'blocked'];
  }
}

/// A CSV field: quoted when it has a comma, a quote or a line break
String csvField(Object value) {
  final String text = '$value';
  return text.contains(RegExp('[",\r\n]'))
      ? '"${text.replaceAll('"', '""')}"'
      : text;
}

/// The CSV as bytes: the header row first, then each row as it comes
Stream<List<int>> csv(List<String> header, Stream<List<Object>> rows) async* {
  yield utf8.encode('${header.join(',')}\r\n');
  await for (final List<Object> row in rows) {
    yield utf8.encode('${row.map(csvField).join(',')}\r\n');
  }
}

/// `Content-Disposition` for any file name: an ASCII fallback for old clients, and the real
/// name encoded (RFC 6266), since a header can't carry characters that aren't ASCII
String attachment(String filename) {
  final String ascii = filename.replaceAll(RegExp(r'[^\x20-\x7e]|"'), '_');
  return 'attachment; filename="$ascii"; '
      "filename*=UTF-8''${Uri.encodeComponent(filename)}";
}

WinterRouter router({int rows = 10000}) => WinterRouter(
  routes: [
    Route.get(
      path: '/exports/customers',
      handler: (request) {
        return ResponseEntity<Stream<List<int>>>(
          StatusCode.ok.value,
          body: csv(['id', 'name', 'status'], customers(rows)),
          headers: {
            HttpHeader.contentType: 'text/csv; charset=utf-8',
            HttpHeader.contentDisposition: attachment('clientes-año.csv'),
          },
        );
      },
    ),
    Route.get(
      path: '/receipts/{id|[0-9]+}',
      handler: (request) => ResponseEntity.ok(
        // A Uint8List is sent as bytes, with its Content-Length
        body: Uint8List.fromList(
          utf8.encode('Receipt ${request.pathParam<int>('id')}\n'),
        ),
        headers: {
          HttpHeader.contentType: 'text/plain; charset=utf-8',
          // inline: the browser shows it instead of saving it
          HttpHeader.contentDisposition: 'inline; filename="receipt.txt"',
        },
      ),
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());
