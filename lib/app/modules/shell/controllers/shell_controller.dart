import 'package:get/get.dart';

class ShellController extends GetxController {
  int index = 0;

  void select(int i) {
    index = i;
    update();
  }
}
