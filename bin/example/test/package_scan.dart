import 'dart:mirrors';

// Definir una anotación
class MyAnnotation {
  const MyAnnotation();
}

@MyAnnotation()
class AnnotatedClass {}

class NonAnnotatedClass {}

int foo = 5;

void main() {
  // Obtener el MirrorSystem
  MirrorSystem mirrorSystem = currentMirrorSystem();

  // Iterar sobre todas las librerías cargadas
  mirrorSystem.libraries.forEach((uri, libMirror) {
    print('-----------------------');
    print(uri);
    libMirror.declarations.forEach((symbol, declaration) {
      print('                  ');
      print(symbol);
      print(declaration);
      if (declaration is ClassMirror) {
        // Verificar si la clase tiene la anotación MyAnnotation
        if (declaration.metadata.any((metadata) =>
        metadata.reflectee.runtimeType == MyAnnotation)) {
          print("Clase anotada encontrada: ${MirrorSystem.getName(symbol)}");
        }
      }
    });
  });
}
