# Basic Server Example

This example demonstrates the minimum configuration required to get a server up and running using the **Winter** framework.

## Key Features

1.  **Server Configuration**: Use of `Winter.start` to initialize the service with a custom port.
2.  **Basic Routing**: Implementation of a `WinterRouter` with static routes.
3.  **Testable Architecture**: Encapsulation of the server within a class with static methods (`start` and `close`) to facilitate reuse in automated testing environments.
4.  **Logging**: Configuration of `onLoadedRoutes` to visualize registered routes when the server starts.

## Defined Routes

*   `GET /hello`: Returns a plain text message "Hello World".

## How to Run

1. Ensure dependencies are installed: `dart pub get`.
2. Run the server: `dart run lib/main.dart`.
3. Test the endpoint: `curl http://localhost:8080/hello`.

> **Note:** The server starts on port `8080` by default, but it can be configured via the `start` method.
