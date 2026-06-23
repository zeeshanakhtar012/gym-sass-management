import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/validators.dart';
import '../../../widgets/app_drawer.dart';
import '../../auth/controllers/auth_service.dart';
import '../controllers/setting_controller.dart';

class SettingView extends GetView<SettingController> {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = Get.find<AuthService>().isSuperAdmin;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => controller.loadSettings(''),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPasswordSection(),
              const SizedBox(height: AppSpacing.lg),
              if (isSuperAdmin) ...[
                _buildGymResetSection(),
                const SizedBox(height: AppSpacing.lg),
              ],
              _buildAppearanceSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildCurrencySection(),
              const SizedBox(height: AppSpacing.lg),
              _buildBackupSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildReceiptSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildNotificationSection(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(title, style: AppTextStyles.headingMd),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final obscureOld = true.obs;
    final obscureNew = true.obs;
    final obscureConfirm = true.obs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Password', PhosphorIconsRegular.lock),
        const Divider(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Obx(() => TextFormField(
                    controller: oldPwdCtrl,
                    obscureText: obscureOld.value,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(PhosphorIconsRegular.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld.value ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
                          size: 18,
                        ),
                        onPressed: () => obscureOld.toggle(),
                      ),
                      isDense: true,
                    ),
                    validator: (v) => Validators.required(v, 'Current password'),
                  )),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() => TextFormField(
                    controller: newPwdCtrl,
                    obscureText: obscureNew.value,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(PhosphorIconsRegular.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew.value ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
                          size: 18,
                        ),
                        onPressed: () => obscureNew.toggle(),
                      ),
                      isDense: true,
                    ),
                    validator: (v) => Validators.minLength(v, 6, 'New password'),
                  )),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() => TextFormField(
                    controller: confirmPwdCtrl,
                    obscureText: obscureConfirm.value,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(PhosphorIconsRegular.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm.value ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
                          size: 18,
                        ),
                        onPressed: () => obscureConfirm.toggle(),
                      ),
                      isDense: true,
                    ),
                    validator: (v) {
                      if (v != newPwdCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  )),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() {
                    if (controller.passwordChangeSuccess.value) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          'Password changed successfully',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.success),
                        ),
                      );
                    }
                    if (controller.passwordError.value.isNotEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          controller.passwordError.value,
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.danger),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: controller.isChangingPassword.value
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              await controller.changeMyPassword(
                                oldPwdCtrl.text, newPwdCtrl.text,
                              );
                              if (controller.passwordChangeSuccess.value) {
                                oldPwdCtrl.clear();
                                newPwdCtrl.clear();
                                confirmPwdCtrl.clear();
                              }
                            },
                      icon: controller.isChangingPassword.value
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(PhosphorIconsRegular.check, size: 18),
                      label: const Text('Update Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGymResetSection() {
    final newPwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Reset Gym Password', PhosphorIconsRegular.buildings),
        const Divider(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset a gym owner\'s password (no old password required)',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondaryD),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() => DropdownButtonFormField<String>(
                    value: controller.selectedGymId.value.isEmpty
                        ? null
                        : controller.selectedGymId.value,
                    decoration: const InputDecoration(
                      labelText: 'Select Gym',
                      prefixIcon: Icon(PhosphorIconsRegular.buildings, size: 18),
                      isDense: true,
                    ),
                    items: controller.allGyms.map((g) {
                      final name = g['name'] as String? ?? '';
                      final phone = g['phone'] as String? ?? '';
                      final gymId = g['gym_id'] as String? ?? '';
                      return DropdownMenuItem(
                        value: gymId,
                        child: Text('$name ($phone)'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) controller.selectedGymId.value = v;
                    },
                    validator: (v) => v == null || v.isEmpty ? 'Please select a gym' : null,
                  )),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: newPwdCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(PhosphorIconsRegular.lock, size: 18),
                      isDense: true,
                    ),
                    validator: (v) => Validators.minLength(v, 6, 'New password'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() {
                    if (controller.gymResetSuccess.value) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          'Gym password reset successfully',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.success),
                        ),
                      );
                    }
                    if (controller.gymResetError.value.isNotEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          controller.gymResetError.value,
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.danger),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: controller.isResettingGymPassword.value
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              await controller.resetGymPassword(newPwdCtrl.text);
                              if (controller.gymResetSuccess.value) {
                                newPwdCtrl.clear();
                              }
                            },
                      icon: controller.isResettingGymPassword.value
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(PhosphorIconsRegular.check, size: 18),
                      label: const Text('Reset Gym Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    final settings = controller.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Appearance', PhosphorIconsRegular.palette),
        const Divider(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                Obx(() => Column(
                  children: ['light', 'dark', 'system'].map((mode) {
                    final selected = settings['theme'] == mode;
                    final label = mode == 'light' ? 'Light'
                        : mode == 'dark' ? 'Dark' : 'System';
                    final icon = mode == 'light' ? PhosphorIconsRegular.sun
                        : mode == 'dark' ? PhosphorIconsRegular.moon
                        : PhosphorIconsRegular.cellSignalFull;
                    return RadioListTile<String>(
                      value: mode,
                      groupValue: settings['theme'] as String? ?? 'system',
                      onChanged: (v) {
                        if (v != null) controller.updateTheme('', v);
                      },
                      title: Row(
                        children: [
                          Icon(icon, size: 18, color: selected ? AppColors.primary : null),
                          const SizedBox(width: AppSpacing.sm),
                          Text(label),
                        ],
                      ),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }).toList(),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencySection() {
    final settings = controller.settings;
    final currencies = ['PKR', 'USD', 'EUR', 'GBP', 'INR', 'AED', 'SAR', 'CAD', 'AUD'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Currency', PhosphorIconsRegular.currencyCircleDollar),
        const Divider(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Obx(() => DropdownButtonFormField<String>(
              value: settings['currency'] as String? ?? 'PKR',
              decoration: const InputDecoration(
                labelText: 'Currency',
                prefixIcon: Icon(PhosphorIconsRegular.coin),
              ),
              items: currencies.map((c) =>
                DropdownMenuItem(value: c, child: Text(c))
              ).toList(),
              onChanged: (v) {
                if (v != null) controller.updateCurrency('', v);
              },
            )),
          ),
        ),
      ],
    );
  }

  Widget _buildBackupSection() {
    final settings = controller.settings;
    final frequencies = ['daily', 'weekly', 'monthly'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Database', PhosphorIconsRegular.database),
        const Divider(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backup Frequency', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                Obx(() => DropdownButtonFormField<String>(
                  value: settings['backup_frequency'] as String? ?? 'daily',
                  decoration: const InputDecoration(
                    prefixIcon: Icon(PhosphorIconsRegular.clock),
                  ),
                  items: frequencies.map((f) =>
                    DropdownMenuItem(
                      value: f,
                      child: Text(f[0].toUpperCase() + f.substring(1)),
                    )
                  ).toList(),
                  onChanged: (v) {
                    if (v != null) controller.updateBackupFrequency('', v);
                  },
                )),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => controller.exportDatabase(),
                        icon: const Icon(PhosphorIconsRegular.download),
                        label: const Text('Export DB'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => controller.importDatabase(),
                        icon: const Icon(PhosphorIconsRegular.upload),
                        label: const Text('Import DB'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptSection() {
    final settings = controller.settings;
    final headerCtrl = TextEditingController(
      text: settings['receipt_header'] as String? ?? '',
    );
    final footerCtrl = TextEditingController(
      text: settings['receipt_footer'] as String? ?? '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Receipt', PhosphorIconsRegular.receipt),
        const Divider(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                TextField(
                  controller: headerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Receipt Header',
                    hintText: 'e.g. Thank you for your payment',
                    prefixIcon: Icon(PhosphorIconsRegular.textAa),
                  ),
                  maxLines: 2,
                  onChanged: (v) => controller.updateSetting(
                    '', 'receipt_header', v,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: footerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Receipt Footer',
                    hintText: 'e.g. Visit again!',
                    prefixIcon: Icon(PhosphorIconsRegular.textAa),
                  ),
                  maxLines: 2,
                  onChanged: (v) => controller.updateSetting(
                    '', 'receipt_footer', v,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    final settings = controller.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notifications', PhosphorIconsRegular.bell),
        const Divider(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Obx(() {
              final days = settings['expiry_warning_days'] as int? ?? 7;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Expiry Warning Days', style: AppTextStyles.label),
                      Text('$days days',
                          style: AppTextStyles.headingSm.copyWith(color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Slider(
                    value: days.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: AppColors.primary,
                    label: '$days days',
                    onChanged: (v) {
                      final intVal = v.round();
                      controller.updateSetting('', 'expiry_warning_days', intVal);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1', style: AppTextStyles.bodySm),
                      Text('30', style: AppTextStyles.bodySm),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
