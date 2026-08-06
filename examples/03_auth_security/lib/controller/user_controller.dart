import 'package:winter/winter.dart';

import '../service/user_service.dart';

class UserController {
  final UserService userService;

  UserController({required this.userService});

  Route get routing {
    return Route.parent(
      path: '/',
      routes: [
        Route.get(
          path: '/me',
          filterConfig: hasRole('user').toFilterConfig(),
          handler: getMe,
        ),
        Route.get(
          path: '/users',
          filterConfig: (hasRole('admin') & hasPermission('user.list'))
              .toFilterConfig(),
          handler: getAllUsers,
        ),
        Route.delete(
          path: '/users/{id}',
          filterConfig: (hasRole('admin') & hasPermission('user.delete'))
              .toFilterConfig(),
          handler: deleteUser,
        ),
      ],
    );
  }

  Future<ResponseEntity> getMe(RequestEntity request) async {
    final userId = request.securityContext.authentication!.principal as int;
    return ResponseEntity.ok(body: userService.getById(userId));
  }

  Future<ResponseEntity> getAllUsers(RequestEntity request) async {
    return ResponseEntity.ok(body: userService.getAll());
  }

  Future<ResponseEntity> deleteUser(RequestEntity request) async {
    final id = int.tryParse(request.pathParams['id'] ?? '') ?? 0;
    return ResponseEntity.ok(body: userService.delete(id));
  }
}
