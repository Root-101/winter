import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:winter/winter.dart';

/// One part of a multipart body, read with [RequestEntity.multipart]: a field of a form or a
/// file, with its own [headers] and a body that is streamed.
///
/// The parts come in order and the body of each one is read while it arrives, so read it (or
/// leave it) before asking for the next part: the part you skip is discarded without keeping it
/// in memory, and it can't be read later.
///
/// {@category Requests and responses}
final class MultipartPart {
  /// The headers of the part, with lowercase names (`content-disposition`, `content-type`).
  /// Read-only.
  final Map<String, String> headers;

  final _MultipartParser _parser;

  bool _listened = false;
  bool _done = false;
  bool _skipped = false;
  Completer<void>? _reading;

  MultipartPart._(this.headers, this._parser);

  late final Map<String, String> _disposition = _dispositionParams(
    headers['content-disposition'],
  );

  /// The name of the field (`name` of the `Content-Disposition`), or null
  String? get name => _disposition['name'];

  /// The name of the file as the client sent it (`filename` of the `Content-Disposition`), or
  /// null when the part isn't a file. Never use it as a path: it can be `../../etc/passwd`.
  String? get filename => _disposition['filename'];

  /// Whether the part is a file (it has a [filename])
  bool get isFile => filename != null;

  /// The MIME type of its `Content-Type` (`image/png`), without its parameters, or null
  String? get mimeType => _mimeTypeOf(headers['content-type']);

  /// The charset of its `Content-Type`, or null
  Encoding? get encoding => _encodingOf(headers['content-type']);

  /// The body of the part as a stream of bytes. It can be read once, and only before asking for
  /// the next part.
  Stream<List<int>> read() {
    if (_listened) {
      throw StateError('The body of a multipart part can be read once');
    }
    _listened = true;
    return _body();
  }

  /// The body of the part, whole (see [read])
  Future<Uint8List> readAsBytes() async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> chunk in read()) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// The body of the part as text, decoded with [encoding] (default: the charset of its
  /// `Content-Type`, or UTF-8). See [read].
  Future<String> readAsString([Encoding? encoding]) =>
      (encoding ?? this.encoding ?? utf8).decodeStream(read());

  Stream<List<int>> _body() async* {
    if (_skipped) {
      throw StateError(
        'The part was skipped: read a multipart part before asking for the next one',
      );
    }
    final Completer<void> reading = _reading = Completer<void>();
    try {
      while (true) {
        final Uint8List? chunk = await _parser._nextBodyChunk();
        if (chunk == null) {
          _done = true;
          return;
        }
        yield chunk;
      }
    } finally {
      reading.complete();
    }
  }

  /// Called when the next part is asked for: waits for a read that is running, and skips what is
  /// left of the body
  Future<void> _finish() async {
    final Completer<void>? reading = _reading;
    if (reading == null) {
      _skipped = true;
    } else {
      await reading.future;
    }
    if (_done) return;
    while (await _parser._nextBodyChunk() != null) {}
    _done = true;
  }

  @override
  String toString() =>
      'MultipartPart{name: $name, ${isFile ? 'file' : 'field'}}';
}

/// A file of a `multipart/form-data` form, read whole by [RequestEntity.formData]
///
/// {@category Requests and responses}
final class UploadedFile {
  /// The name of the field
  final String name;

  /// The name of the file as the client sent it. Never use it as a path: it can be
  /// `../../etc/passwd`.
  final String filename;

  /// The headers of its part, with lowercase names. Read-only.
  final Map<String, String> headers;

  /// The content of the file
  final Uint8List bytes;

  /// A file of the field [name] (a test can build one)
  UploadedFile({
    required this.name,
    required this.filename,
    required this.bytes,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(headers);

  /// The MIME type the client declared (`image/png`), or null. It's not checked against the
  /// content.
  String? get mimeType => _mimeTypeOf(headers['content-type']);

  /// The size of the file, in bytes
  int get length => bytes.length;

  @override
  String toString() => 'UploadedFile{name: $name, $length bytes}';
}

/// The parts of a multipart [body] split by [boundary], as they arrive. Internal: used by
/// [RequestEntity.multipart] and [RequestEntity.formData].
///
/// A malformed body is a [BadRequestException] (400), thrown where it's being read: by the
/// stream of the parts, or by the body of a part.
///
/// {@category Requests and responses}
Stream<MultipartPart> parseMultipart(Stream<List<int>> body, String boundary) =>
    _MultipartParser(body, boundary)._parts();

/// The boundary of a multipart [contentType]. A missing or invalid one is a
/// [BadRequestException] (400). Internal.
///
/// {@category Requests and responses}
String multipartBoundary(String contentType) {
  String? boundary;
  try {
    boundary = http_parser.MediaType.parse(contentType).parameters['boundary'];
  } on FormatException {
    boundary = null;
  }
  if (boundary == null || !_validBoundary.hasMatch(boundary)) {
    throw const BadRequestException(
      detail: 'The multipart Content-Type has no valid boundary',
    );
  }
  return boundary;
}

/// RFC 2046: 1 to 70 characters, and not ending in a space
final RegExp _validBoundary = RegExp(
  r"^[0-9A-Za-z'()+_,\-./:=? ]{0,69}[0-9A-Za-z'()+_,\-./:=?]$",
);

const BadRequestException _malformed = BadRequestException(
  detail: 'The body is not a valid multipart body',
);

/// The most bytes of the headers of one part
const int _maxHeaderBytes = 16 * 1024;

const int _cr = 13;
const int _lf = 10;
const int _dash = 45;
const int _space = 32;
const int _tab = 9;
const List<int> _headersEnd = [_cr, _lf, _cr, _lf];

/// Reads the parts by pulling the body (a [StreamIterator]), so an error of the body or a
/// malformed one is thrown by the read that is waiting for it, and nothing is buffered beyond the
/// chunk being parsed.
class _MultipartParser {
  final StreamIterator<List<int>> _input;

  /// `CRLF--boundary`: what ends the body of a part
  final Uint8List _delimiter;

  /// The bytes received and not parsed yet are `_buffer[_start..]`
  Uint8List _buffer = Uint8List.fromList(const [_cr, _lf]);
  int _start = 0;

  _MultipartParser(Stream<List<int>> body, String boundary)
    : _input = StreamIterator(body),
      _delimiter = Uint8List.fromList(ascii.encode('\r\n--$boundary'));

  int get _available => _buffer.length - _start;

  Stream<MultipartPart> _parts() async* {
    try {
      // The first delimiter has no CRLF before it: the buffer starts with one
      await _skipPreamble();
      while (await _startsPart()) {
        final MultipartPart part = MultipartPart._(await _readHeaders(), this);
        yield part;
        await part._finish();
      }
    } finally {
      await _input.cancel();
    }
  }

  /// Adds the next chunk of the body to the buffer; false at its end
  Future<bool> _fill() async {
    if (!await _input.moveNext()) return false;
    final List<int> chunk = _input.current;
    final int rest = _available;
    _buffer = Uint8List(rest + chunk.length)
      ..setRange(0, rest, _buffer, _start)
      ..setRange(rest, rest + chunk.length, chunk);
    _start = 0;
    return true;
  }

  /// Makes sure the buffer has [count] bytes; a body that ends before is malformed
  Future<void> _ensure(int count) async {
    while (_available < count) {
      if (!await _fill()) throw _malformed;
    }
  }

  /// The index in the buffer where [pattern] starts, or -1
  int _indexOf(List<int> pattern) {
    final int last = _buffer.length - pattern.length;
    outer:
    for (int i = _start; i <= last; i++) {
      for (int j = 0; j < pattern.length; j++) {
        if (_buffer[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  /// Discards everything before the first delimiter
  Future<void> _skipPreamble() async {
    while (true) {
      final int index = _indexOf(_delimiter);
      if (index >= 0) {
        _start = index + _delimiter.length;
        return;
      }
      _start = (_buffer.length - _delimiter.length + 1).clamp(
        _start,
        _buffer.length,
      );
      if (!await _fill()) throw _malformed;
    }
  }

  /// After a delimiter: `--` ends the body (what follows is ignored), and a CRLF (maybe after
  /// spaces) starts a part
  Future<bool> _startsPart() async {
    await _ensure(2);
    if (_buffer[_start] == _dash && _buffer[_start + 1] == _dash) return false;
    while (true) {
      await _ensure(1);
      final int byte = _buffer[_start];
      if (byte != _space && byte != _tab) break;
      _start++;
    }
    await _ensure(2);
    if (_buffer[_start] != _cr || _buffer[_start + 1] != _lf) throw _malformed;
    _start += 2;
    return true;
  }

  /// The headers of a part, until an empty line
  Future<Map<String, String>> _readHeaders() async {
    await _ensure(2);
    if (_buffer[_start] == _cr && _buffer[_start + 1] == _lf) {
      _start += 2;
      return const {};
    }
    int end;
    while ((end = _indexOf(_headersEnd)) < 0) {
      if (_available > _maxHeaderBytes) throw _malformed;
      if (!await _fill()) throw _malformed;
    }
    if (end - _start > _maxHeaderBytes) throw _malformed;
    final String block = utf8.decode(
      Uint8List.sublistView(_buffer, _start, end),
      allowMalformed: true,
    );
    _start = end + _headersEnd.length;
    return _parseHeaders(block);
  }

  /// The next chunk of the body of the current part, or null at its end (after its delimiter)
  Future<Uint8List?> _nextBodyChunk() async {
    while (true) {
      final int index = _indexOf(_delimiter);
      if (index > _start) return _take(index);
      if (index == _start) {
        _start += _delimiter.length;
        return null;
      }
      // The last bytes may be the start of a delimiter that is not complete yet
      final int safe = _buffer.length - _delimiter.length + 1;
      if (safe > _start) return _take(safe);
      if (!await _fill()) throw _malformed;
    }
  }

  /// The bytes up to [end], without copying them: a buffer is never changed, [_fill] makes a new
  /// one
  Uint8List _take(int end) {
    final Uint8List chunk = Uint8List.sublistView(_buffer, _start, end);
    _start = end;
    return chunk;
  }
}

/// `Name: value` lines; a line that starts with a space continues the one before it, and a
/// repeated header is joined with `, `
Map<String, String> _parseHeaders(String block) {
  final Map<String, String> headers = {};
  String? last;
  for (final String line in block.split('\r\n')) {
    if (line.startsWith(' ') || line.startsWith('\t')) {
      if (last == null) throw _malformed;
      headers[last] = '${headers[last]} ${line.trim()}';
      continue;
    }
    final int colon = line.indexOf(':');
    if (colon <= 0) throw _malformed;
    final String name = line.substring(0, colon).trim().toLowerCase();
    if (!_token.hasMatch(name)) throw _malformed;
    final String value = line.substring(colon + 1).trim();
    headers[name] = headers.containsKey(name)
        ? '${headers[name]}, $value'
        : value;
    last = name;
  }
  return Map.unmodifiable(headers);
}

final RegExp _token = RegExp(r"^[!#$%&'*+\-.^_`|~0-9a-z]+$");

/// The parameters of a `Content-Disposition` (`form-data; name="a"; filename="b.txt"`), with
/// lowercase names. As browsers send them (WHATWG): a quoted value ends at the next `"`, and a
/// backslash is not an escape (a `"` in a name comes as `%22`).
Map<String, String> _dispositionParams(String? value) {
  final Map<String, String> params = {};
  if (value == null) return params;
  int i = value.indexOf(';');
  if (i < 0) return params;
  i++;
  while (i < value.length) {
    while (i < value.length && (value[i] == ' ' || value[i] == ';')) {
      i++;
    }
    final int keyStart = i;
    while (i < value.length && value[i] != '=' && value[i] != ';') {
      i++;
    }
    final String key = value.substring(keyStart, i).trim().toLowerCase();
    String paramValue = '';
    if (i < value.length && value[i] == '=') {
      i++;
      while (i < value.length && value[i] == ' ') {
        i++;
      }
      if (i < value.length && value[i] == '"') {
        final int close = value.indexOf('"', i + 1);
        final int end = close < 0 ? value.length : close;
        paramValue = value.substring(i + 1, end);
        i = end + 1;
      } else {
        final int valueStart = i;
        while (i < value.length && value[i] != ';') {
          i++;
        }
        paramValue = value.substring(valueStart, i).trim();
      }
    }
    if (key.isNotEmpty) params.putIfAbsent(key, () => paramValue);
  }
  return params;
}

String? _mimeTypeOf(String? contentType) =>
    contentType?.split(';').first.trim().toLowerCase();

Encoding? _encodingOf(String? contentType) {
  if (contentType == null) return null;
  try {
    final String? charset = http_parser.MediaType.parse(contentType)
        .parameters['charset'];
    return charset == null ? null : Encoding.getByName(charset);
  } on FormatException {
    return null;
  }
}
