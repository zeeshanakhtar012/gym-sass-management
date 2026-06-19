import 'package:get/get.dart';
import '../controllers/gym_dao.dart';
import '../controllers/gym_repository.dart';
import '../controllers/gym_list_controller.dart';

class GymBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GymDao>(() => GymDao());
    Get.lazyPut<GymRepository>(() => GymRepository(Get.find<GymDao>()));
    Get.lazyPut<GymListController>(() => GymListController());
  }
}
