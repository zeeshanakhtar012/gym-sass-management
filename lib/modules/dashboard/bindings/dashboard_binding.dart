import 'package:get/get.dart';
import '../controllers/dashboard_dao.dart';
import '../controllers/dashboard_repository.dart';
import '../controllers/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardDao>(() => DashboardDao());
    Get.lazyPut<DashboardRepository>(() => DashboardRepository(Get.find<DashboardDao>()));
    Get.lazyPut<DashboardController>(() => DashboardController());
  }
}
