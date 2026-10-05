# Advanced Routing & Services Example

This example demonstrates the advanced capabilities of the **Winter** framework, including dynamic routing, dependency injection, and data model handling.

## Key Concepts

### 1. Dynamic Routing (CRUD)
A `WinterRouter` is defined with support for path parameters and multiple HTTP methods:
*   `GET /api/v1/users`: Retrieves the full list of users.
*   `GET /api/v1/users/{id}`: Retrieves a specific user via a path parameter.
*   `POST /api/v1/users`: Creates a new user.
*   `PUT /api/v1/users/{id}`: Updates an existing user.
*   `DELETE /api/v1/users/{id}`: Deletes a user.

### 2. ObjectMapper (Serialization)
*   **Models**: Use of the `Serializable` interface in the `User` class for automatic JSON conversion.
*   **Deserialization**: Registration of a `Deserializer<User>` to automatically process request bodies (`request.body<User>()`).

### 3. Dependency Injection (DI)
*   Use of `di.put()` to register the `UserService`.
*   Total decoupling between the controller (router) and business logic (service) using `di.find()`.

### 4. Exception Handling
*   Use of global exceptions such as `NotFoundException` and `BadRequestException`.
*   The framework captures these exceptions in the business logic and automatically translates them into appropriate HTTP responses with descriptive JSON bodies.

## How to Run

1. Installation: `dart pub get`.
2. Execution: `dart run lib/main.dart`.
3. The server will start by default on port `8080`.

## Testing
This example includes a complete test suite in `test/routing_test.dart` that validates the CRUD lifecycle and error handling.
