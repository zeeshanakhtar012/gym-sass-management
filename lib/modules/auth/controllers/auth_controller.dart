import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_service.dart';
import '../../dashboard/screens/dashboard_view.dart';
import '../../dashboard/bindings/dashboard_binding.dart';

class AuthController extends GetxController {
  final AuthService authService = Get.find<AuthService>();

  final RxBool isLoading = false.obs;
  final RxBool isPasswordVisible = false.obs;
  final RxBool isGymLogin = true.obs;
  final RxString errorMessage = ''.obs;

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final rememberMe = false.obs;

  @override
  void onInit() {
    super.onInit();
    log('[AuthController] onInit');
  }

  @override
  void onClose() {
    log('[AuthController] onClose');
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> login() async {
    log('[AuthController] login called');
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty) {
      log('[AuthController] login - empty username');
      errorMessage.value = 'Please enter your username or phone';
      return;
    }
    if (password.isEmpty) {
      log('[AuthController] login - empty password');
      errorMessage.value = 'Please enter your password';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    log('[AuthController] login - loading isGymLogin=${isGymLogin.value}');

    try {
      await authService.login(username, password, isGym: isGymLogin.value);
      log('[AuthController] login successful');
      DashboardBinding().dependencies();
      Get.off(() => const DashboardView());
    } catch (e, stack) {
      log('[AuthController] login failed: $e');
      log('[AuthController] stack: $stack');
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
      log('[AuthController] login completed');
    }
  }

  void toggleLoginMode() {
    log('[AuthController] toggleLoginMode - was isGymLogin=${isGymLogin.value}');
    isGymLogin.toggle();
    errorMessage.value = '';
    usernameController.clear();
    passwordController.clear();
    log('[AuthController] toggleLoginMode - now isGymLogin=${isGymLogin.value}');
  }

  void togglePasswordVisibility() {
    log('[AuthController] togglePasswordVisibility - was ${isPasswordVisible.value}');
    isPasswordVisible.toggle();
  }

  void clearError() {
    log('[AuthController] clearError');
    errorMessage.value = '';
  }
}
