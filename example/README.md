# Winter Examples 🚀

This directory contains independent examples demonstrating the core features and architectural patterns of the **Winter** framework.

## Examples

1.  **[01_basic_server](./01_basic_server)**: A minimal server implementation.
    - a) **Server Configuration**: Minimal setup using `Winter.start` with custom port support.
    - b) **Static Routing**: Implementation of basic GET endpoints.
    - c) **Testable Architecture**: Encapsulation for easy testing and reuse.
    - d) **Route Logging**: Visualizing registered routes on startup.

2.  **[02_routing](./02_routing)**: Advanced routing, services, and data handling.
    - a) **Dynamic CRUD**: Full lifecycle (GET, POST, PUT, DELETE) with path parameters.
    - b) **Dependency Injection**: Decoupling logic using `di.put()` and `di.find()`.
    - c) **ObjectMapper**: Automatic JSON serialization with `toJson()` and deserialization with a registered `Deserializer`.
    - d) **Exception Handling**: Using `ApiException` (like `NotFoundException`) to handle business errors cleanly.
    - e) **OpenAPI**: `RouteDocs` on every route, the document at `/api/v1/openapi.json` and Swagger UI at `/api/v1/docs`.

3.  **[03_auth_security](./03_auth_security)**: Complete Authentication and Authorization flow.
    - a) **JWT Integration**: Industry-standard token handling with `dart_jsonwebtoken`.
    - b) **Controller Pattern**: Clean routing using nested `Route.parent` and dedicated controllers.
    - c) **Typed Data Handling**: Using `ObjectMapper` to deserialize specific Request objects.
    - d) **RBAC & Permissions**: Advanced authorization using complex `AuthorizationRules`.
    - e) **Security Context**: Managing authenticated principals via global filters.
    - f) **Async validation**: `RegisterRequest` checks that the email is free in `validateAsync()` (a 422 per field).

4.  **[04_i18n](./04_i18n)**: Responses in the language of the request.
    - a) **slang + YAML**: Typed translations generated from `*.i18n.yaml` with `dart run slang`.
    - b) **`requestLocale`**: A `t` getter reads the language of the request in progress from any code (validators, services, handlers).
    - c) **Translated validations**: A 422 mixes the texts of the app and of Winter in the same language.
    - d) **In-memory tests**: `WinterTestClient` and `RequestScope.run`.

5.  **[05_validation_object_mapper](./05_validation_object_mapper)**: An orders API with nested DTOs.
    - a) **Object mapper**: snake_case JSON, `includeNulls: false`, a `Serializer`/`Deserializer` of its own (`Money` as `"12.50 EUR"`) and enums by name.
    - b) **Nested validation**: `valid()` and `validEach()`, a `custom()` rule with its code, and a 422 whose fields follow the JSON (`shipping_address.zip_code`, `items[0].quantity`).
    - c) **Typed params**: `pathParam<int>`, `queryParam<int>`, an enum from the query.

6.  **[06_files](./06_files)**: A photo gallery with forms, uploads and a session cookie.
    - a) **Forms & cookies**: `formData()` of a login form, an `HttpOnly` session cookie, a 303 after each form, and a filter that authenticates by the cookie.
    - b) **Uploads in memory**: `formData()` of a `multipart/form-data` form, a random file name, and the type checked by the bytes (not the declared one).
    - c) **Streamed uploads**: `multipart()` copies a video to disk while it arrives.
    - d) **Static files**: `StaticFiles` behind the login with `ETag` and `Range`, and `Route.static` for the page.
    - e) **Server-Sent Events**: `ResponseEntity.sse` sends every new photo to the open pages (`EventSource`).
    - f) **WebSockets**: a chat of the logged in users with `Route.websocket`, the session cookie and `allowedOrigins`.

7.  **[07_production](./07_production)**: Ready for a container.
    - a) **Configuration**: `.env` and profiles under the variables of the process, `requireAll`, `ServerConfig.fromEnv`.
    - b) **Operations**: `JsonLogger`, liveness and readiness checks with `Route.health`.
    - c) **Security behind a proxy**: rate limit by client IP with `trustedProxies`, CORS and HSTS from the environment.
    - d) **Graceful shutdown & Docker**: `onShutdown`, a "database" closed by its `onDispose`, and a native `scratch` image.

8.  **[08_request_bodies](./08_request_bodies)**: Every kind of request body, one endpoint each.
    - a) **The tabs of Postman**: none, raw (JSON, Text, XML, HTML, JavaScript), x-www-form-urlencoded, form-data, binary and GraphQL.
    - b) **The method for each one**: `body<T>()`, `body<String>()`, `formData()`, `bytes()`, with the errors of a wrong body (400, 415, 422, 413).
    - c) **A `curl` per kind** in its README.

## How to run an example

Each example is a standalone Dart project. To run one:

1.  Navigate to the example directory:
    ```bash
    cd example/01_basic_server
    ```
2.  Get dependencies:
    ```bash
    dart pub get
    ```
3.  Run the server:
    ```bash
    dart run lib/main.dart
    ```

## Running tests

You can run the tests for each example using:
```bash
dart test
```
