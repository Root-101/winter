# Files Example

A small photo gallery: a login form that sets a session cookie, photos uploaded with an HTML form,
videos streamed to disk while they arrive, and the files served back with `ETag` and `Range`.

## Key Concepts

### 1. Forms and a session cookie (`/login`, `/logout`, `SessionFilter`)
*   `request.formData()` reads the `application/x-www-form-urlencoded` login form.
*   `ResponseEntity.seeOther('/', cookies: [...])`: a 303 after a form, with an `HttpOnly`,
    `SameSite=Lax` cookie (add `secure` behind HTTPS). Logging out sends it again with `Max-Age=0`.
*   `SessionFilter` reads `request.cookie('session')` and sets the authentication of the request;
    `AuthFilter(challenge: 'Cookie name="session"')` answers a 401 without it.

### 2. Photos: `formData()` of a `multipart/form-data` form (`POST /photos`)
*   The fields are in `form['title']`, the files in `form.files['photo']` (an `UploadedFile`), read
    whole into memory: fine for small files.
*   **Never trust the client**: the file is saved with a random name of the app (its `filename` can
    be `../../evil.png`), and its type comes from its first bytes (PNG or JPEG), not from the
    `Content-Type` it declared. A text file called `photo.png` is a 415.

### 3. Videos: `multipart()` streamed to disk (`POST /videos`)
*   `await for (final part in request.multipart())` and `part.read()`: each chunk is written to the
    file as it arrives, so a 200 MB video never sits in memory.
*   The first bytes are checked while copying; a file that isn't an MP4 is deleted and answered
    with a 415.
*   `ServerConfig(maxBodySize: 200 MB, requestTimeout: 5 minutes)`: both apply to every request.

### 4. Serving the files (`StaticFiles`, `Route.static`)
*   `GET /photos/{id}` and `/videos/{id}` call `StaticFiles(directory).serve(request, id)` behind the
    login: `ETag`, 304, and `Range` requests (a video player seeks with them). An id with `..` is a
    404.
*   `Route.static(path: '/', directory: 'web')` serves the page with the forms. It's declared last:
    it matches every `GET`.

### 5. Tests in memory (`test/files_test.dart`)
`WinterTestClient` sends the multipart bodies built by the test, and `response.bodyBytes` compares
the photo byte by byte. Each test uses its own temporary folder.

## How to Run

1. Installation: `dart pub get`.
2. Execution: `dart run lib/main.dart`, and open <http://localhost:8080>. The files go to `uploads/`.
3. Tests: `dart test`.

```bash
curl -c jar.txt -d 'user=ann' localhost:8080/login
curl -b jar.txt -F title=Beach -F photo=@beach.png localhost:8080/photos
curl -b jar.txt -F video=@clip.mp4 localhost:8080/videos
curl -b jar.txt -H 'Range: bytes=0-99' localhost:8080/videos/<id>.mp4
```
