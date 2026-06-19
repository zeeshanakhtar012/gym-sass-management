import 'package:get/get.dart';
import '../controllers/package_dao.dart';
import '../controllers/package_repository.dart';
import '../controllers/package_controller.dart';

class PackageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PackageDao>(() => PackageDao());
    Get.lazyPut<PackageRepository>(() => PackageRepository(Get.find<PackageDao>()));
    Get.lazyPut<PackageController>(() => PackageController());
  }
}
