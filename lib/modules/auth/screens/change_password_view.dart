import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/helpers/validators.dart';
import '../controllers/auth_controller.dart';
import '../../dashboard/screens/dashboard_view.dart';
import '../../dashboard/bindings/dashboard_binding.dart';

class ChangePasswordView extends GetView<AuthController> {
  const ChangePasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final obscureOld = true.obs;
    final obscureNew = true.obs;
    final obscureConfirm = true.obs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () {
            DashboardBinding().dependencies();
            Get.off(() => const DashboardView());
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    PhosphorIconsRegular.lock,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Set New Password',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headingMd,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your password must be at least 6 characters',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Obx(() => TextFormField(
                    controller: oldPwdCtrl,
                    obscureText: obscureOld.value,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(PhosphorIconsRegular.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld.value ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
                        ),
                        onPressed: () => obscureOld.toggle(),
                      ),
                    ),
                    validator: (v) {
                      if (Validators.required(v) != null) return 'Current password is required';
                      return null;
                    },
                  )),
                  const SizedBox(height: AppSpacing.md),

                  Obx(() => TextFormField(
                    controller: newPwdCtrl,
                    obscureText: obscureNew.value,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(PhosphorIconsRegular.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew.value ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
                        ),
                        onPressed: () => obscureNew.toggle(),
                      ),
                    ),
                    validator: (v) => Validators.minLength(v, 6, 'New password'),
                  )),
                  const SizedBox(height: AppSpacing.md),

                  Obx(() => TextFormField(
                    controller: confirmPwdCtrl,
                    obscureText: obscureConfirm.value,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(PhosphorIconsRegular.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm.value ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
                        ),
                        onPressed: () => obscureConfirm.toggle(),
                      ),
                    ),
                    validator: (v) {
                      if (v != newPwdCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  )),
                  const SizedBox(height: AppSpacing.lg),

                  Obx(() => SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              controller.isLoading.value = true;
                              try {
                                final success = await controller
                                    .authService
                                    .changePassword(oldPwdCtrl.text, newPwdCtrl.text);
                                if (success) {
                                  DashboardBinding().dependencies();
                                  Get.offAll(() => const DashboardView());
                                } else {
                                  Get.snackbar(
                                    'Error',
                                    'Current password is incorrect',
                                    backgroundColor: AppColors.danger,
                                    colorText: Colors.white,
                                  );
                                }
                              } catch (e) {
                                Get.snackbar(
                                  'Error',
                                  e.toString(),
                                  backgroundColor: AppColors.danger,
                                  colorText: Colors.white,
                                );
                              } finally {
                                controller.isLoading.value = false;
                              }
                            },
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
                              'Change Password',
                              style: AppTextStyles.bodyLg.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
