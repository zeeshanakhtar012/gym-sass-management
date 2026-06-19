import 'dart:developer';

import 'package:get/get.dart';
import '../../auth/controllers/auth_service.dart';
import 'package_repository.dart';
import 'package_model.dart';

class PackageController extends GetxController {
  final PackageRepository _repository = Get.find<PackageRepository>();
  final AuthService _authService = Get.find<AuthService>();

  final RxList<PackageModel> packages = <PackageModel>[].obs;
  final RxBool isLoading = true.obs;

  String _resolveGymId(String gymId) {
    if (gymId.isNotEmpty) return gymId;
    return _authService.currentGymId ?? '';
  }

  @override
  void onInit() {
    super.onInit();
    log('[PackageController] onInit');
    loadPackages('');
  }

  @override
  void onClose() {
    log('[PackageController] onClose');
    super.onClose();
  }

  Future<void> loadPackages(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[PackageController] loadPackages called gymId=$gymId');
    isLoading.value = true;
    try {
      final data = await _repository.getAll(gymId);
      packages.value = data;
      log('[PackageController] loadPackages loaded ${data.length} packages');
    } catch (e, stack) {
      log('[PackageController] loadPackages failed: $e');
      log('[PackageController] stack: $stack');
      Get.snackbar('Error', 'Failed to load packages');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createPackage(PackageModel pkg) async {
    log('[PackageController] createPackage called name=${pkg.name}');
    final resolved = pkg.copyWith(gymId: _resolveGymId(pkg.gymId));
    if (resolved.gymId.isEmpty) {
      log('[PackageController] createPackage - no gymId');
      Get.snackbar('Error', 'No gym selected');
      return;
    }
    try {
      final created = await _repository.create(resolved);
      packages.insert(0, created);
      log('[PackageController] createPackage successful id=${created.packageId}');
      Get.snackbar('Success', 'Package created successfully');
    } catch (e, stack) {
      log('[PackageController] createPackage failed: $e');
      log('[PackageController] stack: $stack');
      Get.snackbar('Error', 'Failed to create package');
    }
  }

  Future<void> updatePackage(PackageModel pkg) async {
    log('[PackageController] updatePackage called id=${pkg.packageId}');
    final resolved = pkg.copyWith(gymId: _resolveGymId(pkg.gymId));
    if (resolved.gymId.isEmpty) {
      log('[PackageController] updatePackage - no gymId');
      Get.snackbar('Error', 'No gym selected');
      return;
    }
    try {
      await _repository.update(resolved);
      final index = packages.indexWhere((p) => p.packageId == resolved.packageId);
      if (index != -1) packages[index] = resolved;
      log('[PackageController] updatePackage successful');
      Get.snackbar('Success', 'Package updated successfully');
    } catch (e, stack) {
      log('[PackageController] updatePackage failed: $e');
      log('[PackageController] stack: $stack');
      Get.snackbar('Error', 'Failed to update package');
    }
  }

  Future<bool> deletePackage(String id) async {
    log('[PackageController] deletePackage called id=$id');
    try {
      final canDelete = await _repository.delete(id);
      if (canDelete) {
        packages.removeWhere((p) => p.packageId == id);
        log('[PackageController] deletePackage successful');
        Get.snackbar('Success', 'Package deleted successfully');
      } else {
        log('[PackageController] deletePackage - has active members');
        Get.snackbar('Error', 'Cannot delete: package has active members');
      }
      return canDelete;
    } catch (e, stack) {
      log('[PackageController] deletePackage failed: $e');
      log('[PackageController] stack: $stack');
      Get.snackbar('Error', 'Failed to delete package');
      return false;
    }
  }
}
