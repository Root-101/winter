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

3.  **[03_auth_security](./03_auth_security)**: Complete Authentication and Authorization flow.
    - a) **JWT Integration**: Industry-standard token handling with `dart_jsonwebtoken`.
    - b) **Controller Pattern**: Clean routing using nested `Route.parent` and dedicated controllers.
    - c) **Typed Data Handling**: Using `ObjectMapper` to deserialize specific Request objects.
    - d) **RBAC & Permissions**: Advanced authorization using complex `AuthorizationRules`.
    - e) **Security Context**: Managing authenticated principals via global filters.

4.  **[04_i18n](./04_i18n)**: Responses in the language of the request.
    - a) **slang + YAML**: Typed translations generated from `*.i18n.yaml` with `dart run slang`.
    - b) **`requestLocale`**: A `t` getter reads the language of the request in progress from any code (validators, services, handlers).
    - c) **Translated validations**: A 422 mixes the texts of the app and of Winter in the same language.
    - d) **In-memory tests**: `WinterTestClient` and `RequestScope.run`.

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
