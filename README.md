# Winter Framework ❄️

**Winter** is a lightweight, modular, and developer-friendly backend framework for Dart enthusiasts.

It aims to simplify the creation of RESTful APIs and
microservices while maintaining a low learning curve.

---

## Table of Contents

1. [About the Project](#1)
2. [Getting Started](#2)
3. [Core Pillars](#3)
    - [Modular Routing](#3.1)
    - [Dependency Injection](#3.2)
    - [Filter Chain (Middleware)](#3.3)
    - [Validation & Error Handling](#3.4)
    - [Annotation-Based Configuration](#3.5)
4. [Security & Utilities](#4)
5. [Future Roadmap](#5)
6. [Contributing](#6)

---

## <a name="1"></a> About the Project

Winter is currently an **experimental** hobby project. It is designed for developers who want to
build backend services using Dart with a familiar architectural pattern (DI, Filters, Controllers).

- **Lightweight**: Minimum overhead for maximum performance.
- **Developer Experience**: Simple API and clear abstractions.
- **Scalable Design**: Inspired by enterprise-grade frameworks.

> ⚠️ **Disclaimer:** This project is not yet production-ready. Use it at your own discretion.

---

## <a name="2"></a> Getting Started

### Installation

Add `winter` to your `pubspec.yaml`:

```yaml
dependencies:
  winter: ^latest_version
```

### Basic Usage

```dart
import 'package:winter/winter.dart';

void main() async {
  await Winter.start(
    router: WinterRouter(
      routes: [
        Route.get(
          path: '/hello',
          handler: (request) => ResponseEntity.ok(body: 'Hello Winter!'),
        ),
      ],
    ),
  );
}
```

Check out our [examples](./examples) directory for more advanced use cases.

---

## <a name="3"></a> Core Pillars

### <a name="3.1"></a> 1. Modular Routing

Winter provides flexible routing options, from the simple `ServeRouter` to the more advanced
`WinterRouter` with support for regex paths and specific HTTP methods.

### <a name="3.2"></a> 2. Dependency Injection

A core feature that allows for better decoupling and testability by managing the lifecycle and
injection of your services and components.

### <a name="3.3"></a> 3. Filter Chain

Intercept and process requests or responses globally or locally. Ideal for logging, authentication,
and data transformation.

### <a name="3.4"></a> 4. Validation & Error Handling

Built-in mechanisms to validate incoming data and a centralized exception handling system to ensure
consistent API responses.

### <a name="3.5"></a> 5. Annotation-Based Configuration

Leverage Dart's metadata to configure your server declaratively, reducing boilerplate code (inspired
by Spring's Decorators).

---

## <a name="4"></a> Security & Utilities

- **Rate Limiter**: Protect your API from brute-force and DDoS attacks.
- **Object Mapping**: Seamlessly convert JSON to Dart objects and vice versa.
- **HTTP Utils**: Constants and helpers for common HTTP headers and status codes.

---

## <a name="5"></a> Future Roadmap

- [ ] Full Security module (JWT, OAuth2).
- [ ] Cron & Scheduled Tasks.
- [ ] Multipart/File Upload support.
- [ ] WebSockets integration.
- [ ] Automated Package Scanning for configuration.
