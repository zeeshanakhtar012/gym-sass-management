import 'package:get/get.dart';
import '../controllers/kiosk_controller.dart';

class KioskBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<KioskController>(() => KioskController());
  }
}
