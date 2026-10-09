import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:winter/winter.dart';

/// The name of the session cookie
const String sessionCookie = 'session';

/// Who is logged in, by the token of their cookie. In memory: a real app keeps the sessions in a
/// database (or signs the cookie), so they survive a restart and several instances share them.
class Sessions {
  final Map<String, String> _users = {};

  /// A new session for [user]: the token for its cookie
  String open(String user) {
    final String token = randomId();
    _users[token] = user;
    return token;
  }

  String? userOf(String? token) => token == null ? null : _users[token];

  void close(String? token) => _users.remove(token);
}

/// 32 random hex characters: the ids of the sessions and of the saved files
String randomId() {
  final Random random = Random.secure();
  return [
    for (int i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// Authenticates the request with the user of its session cookie (nobody without one)
class SessionFilter extends Filter {
  final Sessions sessions;

  SessionFilter(this.sessions);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String? user = sessions.userOf(request.cookie(sessionCookie)?.value);
    if (user != null) {
      request.securityContext.setAuthentication(
        Authentication(principal: user),
      );
    }
    return chain.doFilter(request);
  }
}

class Photo {
  final String id;
  final String title;
  final String owner;

  const Photo(this.id, this.title, this.owner);

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'owner': owner,
    'url': '/photos/$id',
  };
}

/// The uploaded files, saved on disk with a name chosen by the app: never the name the client
/// sent (it can be `../../etc/passwd`), and never trusting the type it declared.
class FileStore {
  final Directory photos;
  final Directory videos;
  final List<Photo> _photos = [];

  /// Every photo saved, as it's saved: what `GET /photos/events` sends
  final StreamController<Photo> _added = StreamController<Photo>.broadcast();

  Stream<Photo> get added => _added.stream;

  /// The biggest photo, in bytes
  static const int maxPhotoSize = 5 * 1024 * 1024;

  FileStore(Directory directory)
    : photos = Directory('${directory.path}/photos')
        ..createSync(recursive: true),
      videos = Directory('${directory.path}/videos')
        ..createSync(recursive: true);

  List<Photo> get all => List.unmodifiable(_photos);

  /// Saves a photo read whole by `formData()`: its type comes from its first bytes
  Future<Photo> savePhoto(String title, String owner, UploadedFile file) async {
    if (file.length > maxPhotoSize) {
      throw const PayloadTooLargeException(detail: 'A photo is 5 MB at most');
    }
    final String extension =
        imageExtension(file.bytes) ??
        (throw const UnsupportedMediaTypeException(
          detail: 'A photo must be a PNG or a JPEG',
        ));
    final Photo photo = Photo('${randomId()}.$extension', title, owner);
    await File('${photos.path}/${photo.id}').writeAsBytes(file.bytes);
    _photos.add(photo);
    _added.add(photo);
    return photo;
  }

  /// Copies a video to disk while it arrives (`multipart()`): it's never whole in memory. The
  /// first bytes must be those of an MP4; otherwise the file is deleted.
  Future<(String id, int size)> saveVideo(MultipartPart part) async {
    final String id = '${randomId()}.mp4';
    final File file = File('${videos.path}/$id');
    final IOSink sink = file.openWrite();
    final BytesBuilder header = BytesBuilder();
    int size = 0;
    try {
      await for (final List<int> chunk in part.read()) {
        if (header.length < 12) {
          header.add(chunk);
          if (header.length >= 12 && !isMp4(header.toBytes())) {
            throw const UnsupportedMediaTypeException(
              detail: 'A video must be an MP4',
            );
          }
        }
        size += chunk.length;
        sink.add(chunk);
      }
      if (header.length < 12) {
        throw const UnsupportedMediaTypeException(
          detail: 'A video must be an MP4',
        );
      }
      await sink.close();
      return (id, size);
    } catch (_) {
      await sink.close();
      await file.delete();
      rethrow;
    }
  }
}

/// `png` or `jpg` from the first bytes of an image (its "magic number"), or null
String? imageExtension(Uint8List bytes) {
  bool startsWith(List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  if (startsWith([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'png';
  }
  if (startsWith([0xFF, 0xD8, 0xFF])) return 'jpg';
  return null;
}

/// An MP4 has `ftyp` at its bytes 4 to 7
bool isMp4(Uint8List bytes) =>
    bytes.length >= 8 && String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp';

/// The chat of the gallery: every logged in user connected by WebSocket gets the messages of all
/// of them. In memory, like the sessions.
class Chat {
  final Set<WebSocket> _sockets = {};

  /// The code of `Route.websocket('/chat')`: the user comes from the session cookie of the
  /// handshake, through `SessionFilter` and `AuthFilter` like any request
  Future<void> join(WebSocket socket, RequestEntity request) async {
    final String user = request.principal<String>();
    _sockets.add(socket);
    _send({'from': 'server', 'text': '$user joined'});
    await for (final Object? message in socket) {
      if (message is String && message.trim().isNotEmpty) {
        _send({'from': user, 'text': message.trim()});
      }
    }
    // The client left
    _sockets.remove(socket);
    _send({'from': 'server', 'text': '$user left'});
  }

  void _send(Map<String, String> message) {
    for (final WebSocket socket in _sockets) {
      socket.sendJson(message);
    }
  }
}

class FilesApp {
  /// Only a logged in user uploads or sees the files. Its challenge (required by a 401) says that
  /// the session is a cookie.
  static FilterConfig get _loggedIn =>
      FilterConfig([AuthFilter(challenge: 'Cookie name="$sessionCookie"')]);

  static WinterRouter router({
    required Sessions sessions,
    required FileStore files,
    Chat? chat,
    String web = 'web',
    List<String> origins = const ['http://localhost:8080'],
  }) => WinterRouter(
    routes: [
      /// An HTML form: `application/x-www-form-urlencoded`
      Route.post(
        path: '/login',
        handler: (request) async {
          final FormData form = await request.formData();
          final String user = form['user']?.trim() ?? '';
          if (user.isEmpty) {
            throw const BadRequestException(detail: 'The form needs a user');
          }
          return ResponseEntity.seeOther(
            '/',
            cookies: [
              Cookie(sessionCookie, sessions.open(user))
                ..httpOnly = true
                ..sameSite = SameSite.lax
                ..path = '/',
              // ..secure = true behind HTTPS (in production, always)
            ],
          );
        },
      ),
      Route.post(
        path: '/logout',
        handler: (request) {
          sessions.close(request.cookie(sessionCookie)?.value);
          return ResponseEntity.seeOther(
            '/',
            cookies: [
              Cookie(sessionCookie, '')
                ..maxAge = 0
                ..path = '/',
            ],
          );
        },
      ),
      Route.get(
        path: '/photos',
        filterConfig: _loggedIn,
        handler: (request) => ResponseEntity.ok(body: files.all),
      ),

      /// A form that uploads a file: `multipart/form-data`, read whole by formData()
      Route.post(
        path: '/photos',
        filterConfig: _loggedIn,
        handler: (request) async {
          final FormData form = await request.formData();
          final String title = form['title']?.trim() ?? '';
          final UploadedFile? file = form.files['photo'];
          if (title.isEmpty || file == null) {
            throw const BadRequestException(
              detail: 'The form needs a title and a photo',
            );
          }
          final Photo photo = await files.savePhoto(
            title,
            request.principal<String>(),
            file,
          );
          // After a form, a 303 makes the browser show the photo with a GET
          return ResponseEntity.seeOther('/photos/${photo.id}');
        },
      ),

      /// Server-Sent Events: every new photo, as it's uploaded (the page adds it without reloading).
      /// Declared before `/photos/{id}`: a static path wins anyway, but it reads better.
      Route.get(
        path: '/photos/events',
        filterConfig: _loggedIn,
        handler: (request) => ResponseEntity.sse(
          files.added.map(
            (photo) =>
                ServerSentEvent.json(photo, event: 'photo', id: photo.id),
          ),
        ),
      ),

      /// With ETag, 304 and Range; the id goes through StaticFiles, so `..` is a 404
      Route.get(
        path: '/photos/{id}',
        filterConfig: _loggedIn,
        handler: (request) => StaticFiles(
          files.photos.path,
        ).serve(request, request.pathParam<String>('id')),
      ),

      /// A big file, streamed to disk with multipart()
      Route.post(
        path: '/videos',
        filterConfig: _loggedIn,
        handler: (request) async {
          final List<Map<String, Object>> saved = [];
          await for (final MultipartPart part in request.multipart()) {
            if (part.name != 'video' || !part.isFile) continue;
            final (String id, int size) = await files.saveVideo(part);
            saved.add({'id': id, 'size': size, 'url': '/videos/$id'});
          }
          if (saved.isEmpty) {
            throw const BadRequestException(detail: 'The form needs a video');
          }
          return ResponseEntity.created(
            location: saved.first['url'] as String,
            body: saved,
          );
        },
      ),

      /// Range requests let a video player seek without downloading the whole file
      Route.get(
        path: '/videos/{id}',
        filterConfig: _loggedIn,
        handler: (request) => StaticFiles(
          files.videos.path,
        ).serve(request, request.pathParam<String>('id')),
      ),

      /// A WebSocket: the chat of the logged in users. Only from the origin of the page: browsers
      /// send the cookie on a WebSocket of any website (no CORS here), so the origin is checked
      Route.websocket(
        path: '/chat',
        filterConfig: _loggedIn,
        allowedOrigins: origins,
        handler: (chat ?? Chat()).join,
      ),

      /// The page with the forms. Last: it matches every GET
      Route.static(path: '/', directory: web),
    ],
  );

  static Future<void> start({int port = 8080}) async {
    final Sessions sessions = Sessions();
    await Winter.start(
      config: ServerConfig(
        port: port,
        // Room for the videos: the limit applies to every request
        maxBodySize: 200 * 1024 * 1024,
        requestTimeout: const Duration(minutes: 5),
      ),
      globalFilterConfig: FilterConfig([SessionFilter(sessions)]),
      router: router(
        sessions: sessions,
        files: FileStore(Directory('uploads')),
      ),
    );
  }
}
