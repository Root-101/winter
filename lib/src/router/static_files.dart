import 'dart:io';
import 'dart:math';

import 'package:winter/winter.dart';

/// Serves the files of a [directory]: what [Route.static] uses, and usable from any handler.
///
/// - Only the files inside [directory]: a path with `..`, a hidden file or folder (`.env`,
///   `.git/`), a `\`, a `:`, or a link that leads out of it is a 404.
/// - `ETag` and `Last-Modified`, and a 304 for `If-None-Match`/`If-Modified-Since`.
/// - `Range` requests (one range: a 206, or a 416 when it's out of the file), as video players and
///   resumed downloads send them, checked with `If-Range`.
/// - The file is streamed, never read whole into memory.
///
/// {@category Routing}
final class StaticFiles {
  /// The directory, canonical (absolute, links resolved)
  final String directory;

  /// The file served for a directory (`index.html`); null serves none (a 404)
  final String? index;

  /// The `Cache-Control` of every file (`public, max-age=3600`), or none
  final String? cacheControl;

  /// The `Content-Type` of each extension (without the dot, lowercase: `{'md': 'text/markdown'}`),
  /// over the defaults
  final Map<String, String> mimeTypes;

  /// [directory] must exist: an [ArgumentError] otherwise.
  StaticFiles(
    String directory, {
    this.index = 'index.html',
    this.cacheControl,
    Map<String, String> mimeTypes = const {},
  }) : directory = _canonicalDirectory(directory),
       mimeTypes = Map.unmodifiable({..._defaultMimeTypes, ...mimeTypes});

  static String _canonicalDirectory(String directory) {
    final Directory dir = Directory(directory);
    if (!dir.existsSync()) {
      throw ArgumentError.value(
        directory,
        'directory',
        'The directory of the static files does not exist',
      );
    }
    return dir.resolveSymbolicLinksSync();
  }

  /// The response for the file at [path] (`css/site.css`, `/`-separated and already URL-decoded)
  /// inside [directory]. A missing or forbidden file is a [NotFoundException].
  Future<ResponseEntity> serve(RequestEntity request, String path) async {
    final List<String> segments = [
      for (final String segment in path.split('/'))
        if (segment.isNotEmpty) segment,
    ];
    if (segments.any(_isForbidden)) throw const NotFoundException();

    String target = [directory, ...segments].join(Platform.pathSeparator);
    FileStat stat = await FileStat.stat(target);
    if (stat.type == FileSystemEntityType.directory) {
      final String? index = this.index;
      if (index == null) throw const NotFoundException();
      final Uri uri = request.requestedUri;
      if (!uri.path.endsWith('/')) {
        // Relative links of the index (`style.css`) resolve against the directory, so they need
        // the URL to end with `/`. A relative Location also works behind a proxy that adds a
        // prefix.
        final String last = uri.pathSegments.last;
        return ResponseEntity.permanentRedirect(
          '${Uri(pathSegments: [last])}/${uri.hasQuery ? '?${uri.query}' : ''}',
        );
      }
      target = '$target${Platform.pathSeparator}$index';
      stat = await FileStat.stat(target);
    }
    if (stat.type != FileSystemEntityType.file) throw const NotFoundException();

    final String canonical;
    try {
      canonical = await File(target).resolveSymbolicLinks();
    } on FileSystemException {
      throw const NotFoundException();
    }
    if (!_isInside(canonical)) throw const NotFoundException();

    return _respond(request, File(canonical), stat);
  }

  /// `..`, `.`, hidden files, and what a path on Windows would read as a separator, a drive or a
  /// stream (`a.txt::$DATA`)
  static bool _isForbidden(String segment) =>
      segment.startsWith('.') ||
      segment.contains(r'\') ||
      segment.contains(':') ||
      segment.contains('\x00');

  bool _isInside(String canonical) {
    final String root = directory.endsWith(Platform.pathSeparator)
        ? directory
        : '$directory${Platform.pathSeparator}';
    return Platform.isWindows
        ? canonical.toLowerCase().startsWith(root.toLowerCase())
        : canonical.startsWith(root);
  }

  ResponseEntity _respond(RequestEntity request, File file, FileStat stat) {
    final int size = stat.size;
    final DateTime modified = stat.modified;
    final String etag =
        '"${size.toRadixString(16)}-${modified.millisecondsSinceEpoch.toRadixString(16)}"';
    final String lastModified = HttpDate.format(modified);
    final Map<String, String> validators = {
      HttpHeader.etag: etag,
      HttpHeader.lastModified: lastModified,
      HttpHeader.cacheControl: ?cacheControl,
    };

    if (_notModified(request, etag, modified)) {
      return ResponseEntity(StatusCode.notModified.value, headers: validators);
    }

    final Map<String, String> headers = {
      ...validators,
      HttpHeader.contentType: _contentType(file.path),
      HttpHeader.acceptRanges: 'bytes',
    };
    final String? range = request.headers[HttpHeader.range];
    if (range != null && _ifRange(request, etag, modified)) {
      final (int, int)? bytes = _parseRange(range, size);
      if (bytes != null) {
        final (int start, int end) = bytes;
        return ResponseEntity<Stream<List<int>>>(
          StatusCode.partialContent.value,
          body: file.openRead(start, end + 1),
          headers: {
            ...headers,
            HttpHeader.contentRange: 'bytes $start-$end/$size',
            HttpHeader.contentLength: '${end - start + 1}',
          },
        );
      }
    }
    return ResponseEntity<Stream<List<int>>>(
      StatusCode.ok.value,
      body: file.openRead(),
      headers: {...headers, HttpHeader.contentLength: '$size'},
    );
  }

  /// `If-None-Match` (any of its ETags, weak or not, or `*`), or, without it, `If-Modified-Since`
  /// (HTTP dates have seconds)
  static bool _notModified(
    RequestEntity request,
    String etag,
    DateTime modified,
  ) {
    final String? ifNoneMatch = request.headers[HttpHeader.ifNoneMatch];
    if (ifNoneMatch != null) {
      return ifNoneMatch.trim() == '*' ||
          ifNoneMatch
              .split(',')
              .map((tag) => tag.trim())
              .map((tag) => tag.startsWith('W/') ? tag.substring(2) : tag)
              .contains(etag);
    }
    final DateTime? since = _parseDate(
      request.headers[HttpHeader.ifModifiedSince],
    );
    return since != null && _seconds(modified) <= _seconds(since);
  }

  /// A `Range` is used only if `If-Range` is missing or still matches the file: its ETag
  /// (strong) or its exact `Last-Modified`
  static bool _ifRange(RequestEntity request, String etag, DateTime modified) {
    final String? ifRange = request.headers[HttpHeader.ifRange]?.trim();
    if (ifRange == null) return true;
    if (ifRange.startsWith('"') || ifRange.startsWith('W/')) {
      return ifRange == etag;
    }
    final DateTime? date = _parseDate(ifRange);
    return date != null && _seconds(date) == _seconds(modified);
  }

  /// The first and the last byte of a `Range` with one range (`bytes=0-99`, `bytes=100-`,
  /// `bytes=-100`), or null to ignore it and send the whole file (an invalid header, or several
  /// ranges). A range that starts after the file is a 416.
  static (int, int)? _parseRange(String header, int size) {
    final RegExpMatch? match = _rangePattern.firstMatch(header.trim());
    if (match == null) return null;
    final String first = match[1]!;
    final String last = match[2]!;
    if (first.isEmpty && last.isEmpty) return null;

    final int start;
    final int end;
    if (first.isEmpty) {
      final int? suffix = int.tryParse(last);
      if (suffix == null) return null;
      if (suffix == 0 || size == 0) throw _notSatisfiable(size);
      start = max(0, size - suffix);
      end = size - 1;
    } else {
      final int? from = int.tryParse(first);
      if (from == null) return null;
      final int? to = last.isEmpty ? null : int.tryParse(last);
      if (to != null && to < from) return null;
      if (from >= size) throw _notSatisfiable(size);
      start = from;
      end = min(to ?? size - 1, size - 1);
    }
    return (start, end);
  }

  static final RegExp _rangePattern = RegExp(r'^bytes=(\d*)-(\d*)$');

  static ApiException _notSatisfiable(int size) => ApiException(
    StatusCode.rangeNotSatisfiable,
    headers: {HttpHeader.contentRange: 'bytes */$size'},
  );

  static DateTime? _parseDate(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value);
    } on HttpException {
      return null;
    }
  }

  static int _seconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;

  String _contentType(String path) {
    final String name = path.split(Platform.pathSeparator).last;
    final int dot = name.lastIndexOf('.');
    final String? type = dot < 0
        ? null
        : mimeTypes[name.substring(dot + 1).toLowerCase()];
    if (type == null) return MediaType.applicationOctetStream.mimeType;
    return type.startsWith('text/') ||
            type == 'application/javascript' ||
            type == 'application/json' ||
            type == 'image/svg+xml'
        ? '$type; charset=utf-8'
        : type;
  }

  @override
  String toString() => 'StaticFiles{$directory}';
}

const Map<String, String> _defaultMimeTypes = {
  'html': 'text/html',
  'htm': 'text/html',
  'css': 'text/css',
  'js': 'application/javascript',
  'mjs': 'application/javascript',
  'json': 'application/json',
  'map': 'application/json',
  'webmanifest': 'application/manifest+json',
  'xml': 'application/xml',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'md': 'text/markdown',
  'svg': 'image/svg+xml',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'avif': 'image/avif',
  'ico': 'image/x-icon',
  'bmp': 'image/bmp',
  'woff': 'font/woff',
  'woff2': 'font/woff2',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'wasm': 'application/wasm',
  'pdf': 'application/pdf',
  'zip': 'application/zip',
  'gz': 'application/gzip',
  'mp4': 'video/mp4',
  'webm': 'video/webm',
  'ogv': 'video/ogg',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'm4a': 'audio/mp4',
};
