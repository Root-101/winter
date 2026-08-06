# Authentication & Security Example

This example demonstrates a comprehensive implementation of Authentication and Authorization using the **Winter** framework. It covers the full lifecycle from user registration and login to role-based access control (RBAC) and fine-grained permissions.

## Key Features

### 1. Advanced Routing with Controllers
- **Nested Routing**: Routes are organized into `AuthController` and `UserController` using `Route.parent`.
- **Clean Architecture**: Decoupling of routing logic from the main server configuration.

### 2. Authentication (JWT)
- **Standard JWT**: Implementation using the `dart_jsonwebtoken` library for robust token handling.
- **JwtFilter**: A global filter that intercepts the `Authorization: Bearer <token>` header, verifies the signature, and populates the `RequestSecurityContext`.
- **Secure Secrets**: Signing keys are managed via environment variables using `env.find('JWT_SECRET')`.

### 3. Strongly Typed Requests
- **Request Objects**: Use of `RegisterRequest` and `LoginRequest` classes instead of raw Maps.
- **ObjectMapper Integration**: Automatic deserialization of JSON bodies into Dart objects via registered `Deserializer`s.

### 4. Authorization Rules
- **Role-Based Access Control (RBAC)**: Enforced using `hasRole('user'|'admin')`.
- **Granular Permissions**: Fine-grained control using `hasPermission('user.delete')`.
- **Complex Rules**: Combining multiple requirements using logical operators like `.and()`.

### 5. Dependency Injection & Services
- **Service Layer**: Business logic encapsulated in `AuthService` and `UserService`.
- **DI Container**: Global management of service instances using `di.put()` and `di.find()`.

### 6. Centralized Error Handling
- Use of `ApiException` subclasses (`UnauthorizedException`, `ConflictException`, `NotFoundException`) to return consistent HTTP responses automatically.

## Defined Routes

### Public Routes
*   `POST /api/v1/register`: Registers a new user with `name`, `email`, and `password`.
*   `POST /api/v1/login`: Validates credentials and returns a JWT and user info.

### Protected Routes (Authenticated)
*   `GET /api/v1/me`: Returns the current user's profile. Requires `user` role.

### Admin Routes (Authorized)
*   `GET /api/v1/users`: Lists all registered users. Requires `admin` role and `user.list` permission.
*   `DELETE /api/v1/users/{id}`: Deletes a user by ID. Requires `admin` role and `user.delete` permission.

## How to Run

1.  **Installation**:
    ```bash
    dart pub get
    ```
2.  **Set Secret (Optional)**:
    Set the `JWT_SECRET` environment variable or the system will use a default fallback.
3.  **Execution**:
    ```bash
    dart run lib/main.dart
    ```

## Testing
Comprehensive integration tests are available in `test/auth_test.dart`. They cover:
- Successful and failed authentication flows.
- Authorization enforcement (403 Forbidden cases).
- Object mapping validation.
- CRUD operations on protected resources.
