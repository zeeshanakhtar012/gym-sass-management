import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/controllers/auth_service.dart';
import 'gym_repository.dart';
import 'gym_model.dart';
import '../../../widgets/popups/app_popup.dart';

class GymFormController extends GetxController {
  final GymRepository _gymRepository = Get.find<GymRepository>();
  final AuthService _authService = Get.find<AuthService>();

  GymModel? editingGym;

  final nameController = TextEditingController();
  final ownerNameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();
  final whatsappController = TextEditingController();
  final openingTimeController = TextEditingController();
  final closingTimeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxString selectedLogoPath = ''.obs;

  bool get isEditing => editingGym != null;

  @override
  void onInit() {
    super.onInit();
    log('[GymFormController] onInit');
  }

  @override
  void onClose() {
    log('[GymFormController] onClose');
    nameController.dispose();
    ownerNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    emailController.dispose();
    whatsappController.dispose();
    openingTimeController.dispose();
    closingTimeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  Future<void> loadGym(GymModel gym) async {
    log('[GymFormController] loadGym called gymId=${gym.gymId} name=${gym.name}');
    editingGym = gym;
    nameController.text = gym.name;
    ownerNameController.text = gym.ownerName ?? '';
    phoneController.text = gym.phone;
    addressController.text = gym.address ?? '';
    emailController.text = gym.email ?? '';
    whatsappController.text = gym.whatsapp ?? '';
    openingTimeController.text = gym.openingTime ?? '';
    closingTimeController.text = gym.closingTime ?? '';
    selectedLogoPath.value = gym.logoPath ?? '';
    log('[GymFormController] loadGym completed');
  }

  Future<void> pickLogo() async {
    log('[GymFormController] pickLogo called');
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      selectedLogoPath.value = result.path;
      log('[GymFormController] pickLogo - selected ${result.path}');
    } else {
      log('[GymFormController] pickLogo - no image selected');
    }
  }

  Future<void> save() async {
    log('[GymFormController] save called isEditing=$isEditing');
    if (nameController.text.trim().isEmpty) {
      log('[GymFormController] save - name empty');
      AppPopup.error('Gym name is required');
      return;
    }
    if (phoneController.text.trim().isEmpty) {
      log('[GymFormController] save - phone empty');
      AppPopup.error('Phone number is required');
      return;
    }
    if (!isEditing && passwordController.text.trim().isEmpty) {
      log('[GymFormController] save - password empty');
      AppPopup.error('Password is required for new gym');
      return;
    }
    if (!isEditing && passwordController.text != confirmPasswordController.text) {
      log('[GymFormController] save - passwords do not match');
      AppPopup.error('Passwords do not match');
      return;
    }

    isLoading.value = true;
    try {
      final now = DateTime.now().toIso8601String();

      if (isEditing) {
        final updated = editingGym!.copyWith(
          name: nameController.text.trim(),
          ownerName: ownerNameController.text.trim().isEmpty
              ? null
              : ownerNameController.text.trim(),
          phone: phoneController.text.trim(),
          address: addressController.text.trim().isEmpty
              ? null
              : addressController.text.trim(),
          email: emailController.text.trim().isEmpty
              ? null
              : emailController.text.trim(),
          whatsapp: whatsappController.text.trim().isEmpty
              ? null
              : whatsappController.text.trim(),
          openingTime: openingTimeController.text.trim().isEmpty
              ? null
              : openingTimeController.text.trim(),
          closingTime: closingTimeController.text.trim().isEmpty
              ? null
              : closingTimeController.text.trim(),
          logoPath: selectedLogoPath.value.isEmpty
              ? editingGym!.logoPath
              : selectedLogoPath.value,
          updatedAt: now,
        );
        await _gymRepository.updateGym(updated);
        log('[GymFormController] save - gym updated successfully');
        Get.back(result: true);
      } else {
        final gym = GymModel(
          gymId: '',
          name: nameController.text.trim(),
          ownerName: ownerNameController.text.trim().isEmpty
              ? null
              : ownerNameController.text.trim(),
          phone: phoneController.text.trim(),
          address: addressController.text.trim().isEmpty
              ? null
              : addressController.text.trim(),
          email: emailController.text.trim().isEmpty
              ? null
              : emailController.text.trim(),
          whatsapp: whatsappController.text.trim().isEmpty
              ? null
              : whatsappController.text.trim(),
          openingTime: openingTimeController.text.trim().isEmpty
              ? null
              : openingTimeController.text.trim(),
          closingTime: closingTimeController.text.trim().isEmpty
              ? null
              : closingTimeController.text.trim(),
          logoPath: selectedLogoPath.value.isEmpty
              ? null
              : selectedLogoPath.value,
          createdAt: now,
          updatedAt: now,
        );
        await _gymRepository.createGym(gym, passwordController.text.trim());
        log('[GymFormController] save - gym created successfully');
        Get.back(result: true);
      }
    } catch (e, stack) {
      log('[GymFormController] save failed: $e');
      log('[GymFormController] stack: $stack');
      AppPopup.error(e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
