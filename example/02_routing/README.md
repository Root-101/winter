# Advanced Routing & Services Example

This example demonstrates the advanced capabilities of the **Winter** framework, including dynamic routing, dependency injection, and data model handling.

## Key Concepts

### 1. Dynamic Routing (CRUD)
A `WinterRouter` is defined with support for path parameters and multiple HTTP methods:
*   `GET /api/v1/users`: Retrieves the full list of users.
*   `GET /api/v1/users/{id}`: Retrieves a specific user via a path parameter.
*   `POST /api/v1/users`: Creates a new user.
*   `PUT /api/v1/users/{id}`: Updates an existing user.
*   `PATCH /api/v1/users/{id}`: Changes only the fields sent (`UserUpdate` with `PatchValue`):
    `{"nickname": null}` clears the nickname, `{}` changes nothing, `{"name": null}` is a 400.
*   `DELETE /api/v1/users/{id}`: Deletes a user.

### 2. ObjectMapper (Serialization)
*   **Models**: The `User` class has a `toJson()` method, which the object mapper calls to write the responses (no interface to implement).
*   **Deserialization**: Registration of a `Deserializer<User>` to automatically process request bodies (`request.body<User>()`), with typed fields (`json.field<String>('name')`).
*   **Partial updates**: `json.patch<String?>('nickname')` gives a `PatchValue`, absent or a value (`null` included), and `orElse(current)` gives the value after the update.

### 3. OpenAPI and Swagger UI
*   Every route has `RouteDocs` (a summary, an example of `User` as its body), and the children of `/users` take the tag `users` of their parent.
*   `{id|[0-9]+}`: the id is an integer in the document (and `/users/abc` is a 404).
*   The PATCH documents its body with a `JsonSchema` by hand and a JSON example (`UserUpdate` has no `toJson()`).
*   `Route.openApi` serves `GET /api/v1/openapi.json` and `Route.swaggerUi` the page at `http://localhost:8080/api/v1/docs`.

### 4. Dependency Injection (DI)
*   Use of `di.put()` to register the `UserService`.
*   Total decoupling between the controller (router) and business logic (service) using `di.find()`.

### 5. Exception Handling
*   Use of global exceptions such as `NotFoundException` and `BadRequestException`.
*   The framework captures these exceptions in the business logic and automatically translates them into appropriate HTTP responses with descriptive JSON bodies.

## How to Run

1. Installation: `dart pub get`.
2. Execution: `dart run lib/main.dart`.
3. The server will start by default on port `8080`.

## Testing
This example includes a complete test suite in `test/routing_test.dart` that validates the CRUD lifecycle and error handling.
