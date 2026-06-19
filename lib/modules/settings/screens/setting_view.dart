import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../../widgets/app_drawer.dart';
import '../controllers/setting_controller.dart';

class SettingView extends GetView<SettingController> {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context) {
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
