import 'dart:developer';

import 'package:get/get.dart';
import 'gym_repository.dart';
import 'gym_model.dart';
import '../../../widgets/popups/app_popup.dart';

class GymListController extends GetxController {
  final GymRepository _gymRepository = Get.find<GymRepository>();

  final RxList<GymModel> gyms = <GymModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    log('[GymListController] onInit');
    loadGyms();
  }

  @override
  void onClose() {
    log('[GymListController] onClose');
    super.onClose();
  }

  Future<void> loadGyms() async {
    log('[GymListController] loadGyms called');
    isLoading.value = true;
    try {
      final data = await _gymRepository.getAllGyms();
      gyms.value = data;
      log('[GymListController] loadGyms loaded ${data.length} gyms');
    } catch (e, stack) {
      log('[GymListController] loadGyms failed: $e');
      log('[GymListController] stack: $stack');
      AppPopup.error('Failed to load gyms');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleStatus(String id) async {
    log('[GymListController] toggleStatus called id=$id');
    try {
      await _gymRepository.toggleGymStatus(id);
      log('[GymListController] toggleStatus successful');
      await loadGyms();
    } catch (e, stack) {
      log('[GymListController] toggleStatus failed: $e');
      log('[GymListController] stack: $stack');
      AppPopup.error('Failed to toggle gym status');
    }
  }

  Future<void> deleteGym(String id) async {
    log('[GymListController] deleteGym called id=$id');
    try {
      final success = await _gymRepository.deleteGym(id);
      if (success) {
        gyms.removeWhere((g) => g.gymId == id);
        log('[GymListController] deleteGym successful');
        AppPopup.success('Gym deleted successfully');
      } else {
        log('[GymListController] deleteGym failed - repository returned false');
        AppPopup.error('Failed to delete gym');
      }
    } catch (e, stack) {
      log('[GymListController] deleteGym failed: $e');
      log('[GymListController] stack: $stack');
      AppPopup.error('Failed to delete gym');
    }
  }

  List<GymModel> get filteredGyms {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return gyms;
    return gyms.where((g) {
      return g.name.toLowerCase().contains(query) ||
          g.phone.contains(query) ||
          (g.ownerName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }
}
