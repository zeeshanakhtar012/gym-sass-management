import 'package:get/get.dart';
import '../controllers/member_dao.dart';
import '../controllers/member_stats_dao.dart';
import '../controllers/member_repository.dart';
import '../controllers/member_list_controller.dart';

class MemberBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MemberDao>(() => MemberDao());
    Get.lazyPut<MemberStatsDao>(() => MemberStatsDao());
    Get.lazyPut<MemberRepository>(
      () => MemberRepository(Get.find<MemberDao>(), Get.find<MemberStatsDao>()),
    );
    Get.lazyPut<MemberListController>(() => MemberListController());
  }
}
