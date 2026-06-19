import 'package:get/get.dart';
import '../controllers/auth_dao.dart';
import '../controllers/auth_repository.dart';
import '../controllers/auth_service.dart';
import '../controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthDao>(() => AuthDao());
    Get.lazyPut<AuthRepository>(() => AuthRepository(Get.find<AuthDao>()));
    Get.lazyPut<AuthService>(
      () => AuthService(Get.find<AuthRepository>(), Get.find<AuthDao>()),
    );
    Get.lazyPut<AuthController>(() => AuthController());
  }
}
