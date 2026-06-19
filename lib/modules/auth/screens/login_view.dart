import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/helpers/responsive.dart';
import '../controllers/auth_controller.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Responsive(
              mobile: _buildLoginForm(context, isMobile: true),
              desktop: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildLoginForm(context, isMobile: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, {required bool isMobile}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: const Icon(
              PhosphorIconsRegular.barbell,
              size: 44,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Gym ERP',
          textAlign: TextAlign.center,
          style: AppTextStyles.displayLg.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Offline-First Gym Management',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondaryL),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Toggle Cards
        Row(
          children: [
            Expanded(child: _buildToggleCard('Super Admin', false)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildToggleCard('Gym Login', true)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Error Banner
        Obx(() {
          if (controller.errorMessage.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsRegular.warningCircle, color: AppColors.danger, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    controller.errorMessage.value,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.danger),
                  ),
                ),
                GestureDetector(
                  onTap: controller.clearError,
                  child: const Icon(PhosphorIconsRegular.x, color: AppColors.danger, size: 16),
                ),
              ],
            ),
          );
        }),

        // Username / Phone Field
        Obx(() => TextField(
          controller: controller.usernameController,
          decoration: InputDecoration(
            labelText: controller.isGymLogin.value ? 'Phone Number' : 'Username',
            hintText: controller.isGymLogin.value ? 'Enter gym phone number' : 'Enter username',
            prefixIcon: Icon(
              controller.isGymLogin.value ? PhosphorIconsRegular.phone : PhosphorIconsRegular.user,
            ),
          ),
          textInputAction: TextInputAction.next,
          keyboardType: controller.isGymLogin.value ? TextInputType.phone : TextInputType.text,
        )),
        const SizedBox(height: AppSpacing.md),

        // Password Field
        Obx(() => TextField(
          controller: controller.passwordController,
          obscureText: !controller.isPasswordVisible.value,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(PhosphorIconsRegular.lock),
            suffixIcon: IconButton(
              icon: Icon(
                controller.isPasswordVisible.value
                    ? PhosphorIconsRegular.eyeSlash
                    : PhosphorIconsRegular.eye,
              ),
              onPressed: controller.togglePasswordVisibility,
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.login(),
        )),
        const SizedBox(height: AppSpacing.sm),

        // Remember Me
        Obx(() => Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: controller.rememberMe.value,
                onChanged: (v) => controller.rememberMe.value = v ?? false,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Remember Me', style: AppTextStyles.bodyMd),
          ],
        )),
        const SizedBox(height: AppSpacing.lg),

        // Login Button
        Obx(() => SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: controller.isLoading.value ? null : controller.login,
            child: controller.isLoading.value
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Login',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        )),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildToggleCard(String label, bool isGymMode) {
    return Obx(() {
      final selected = controller.isGymLogin.value == isGymMode;
      return GestureDetector(
        onTap: controller.toggleLoginMode,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isGymMode ? PhosphorIconsRegular.buildings : PhosphorIconsRegular.shieldStar,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondaryL,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: selected ? AppColors.primary : AppColors.textSecondaryL,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
