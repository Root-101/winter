import '../../winter.dart';

class Injectable extends ScanComponent {
  final String? tag;

  const Injectable({this.tag, super.order});
}

class Injected {
  final String? tag;

  const Injected({this.tag});
}
