import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/member_model.dart';
import '../controllers/member_form_controller.dart';

class MemberFormView extends StatefulWidget {
  final String gymId;
  final MemberModel? member;
  const MemberFormView({super.key, this.gymId = '', this.member});

  @override
  State<MemberFormView> createState() => _MemberFormViewState();
}

class _MemberFormViewState extends State<MemberFormView> {
  late final MemberFormController controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controller = Get.put(MemberFormController());
    controller.loadPackages(widget.gymId);
    if (widget.member != null) {
      controller.loadMember(widget.member!);
    }
  }

  @override
  void dispose() {
    Get.delete<MemberFormController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(controller.isEditing ? 'Edit Member' : 'Add Member'),
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            onPressed: () => Get.back(),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Personal Info'),
              Tab(text: 'Physical'),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            children: [
              _buildPersonalInfoTab(context),
              _buildPhysicalTab(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Responsive(
        mobile: _buildPersonalForm(false),
        desktop: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _buildPersonalForm(true),
        ),
      ),
    );
  }

  Widget _buildPersonalForm(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _buildPhotoPicker()),
        const SizedBox(height: AppSpacing.xl),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildFieldColumn1()),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildFieldColumn2()),
            ],
          )
        else ...[
          _buildFieldColumn1(),
          const SizedBox(height: AppSpacing.md),
          _buildFieldColumn2(),
        ],
        const SizedBox(height: AppSpacing.md),
        _buildPackageSection(isWide),
        const SizedBox(height: AppSpacing.md),
        _buildPaymentSection(),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        _buildQrField(),
        const SizedBox(height: AppSpacing.lg),
        _buildFingerprintSection(),
        const SizedBox(height: AppSpacing.md),
        if (controller.isEditing) ...[
          _buildStatusDropdown(),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.lg),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildFieldColumn1() {
    return Column(
      children: [
        TextFormField(
          controller: controller.fullNameController,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            prefixIcon: Icon(PhosphorIconsRegular.user),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: controller.fatherNameController,
          decoration: const InputDecoration(
            labelText: 'Father Name',
            prefixIcon: Icon(PhosphorIconsRegular.user),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: controller.cnicController,
          decoration: const InputDecoration(
            labelText: 'CNIC',
            prefixIcon: Icon(PhosphorIconsRegular.identificationCard),
            hintText: 'XXXXX-XXXXXXX-X',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: controller.phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number *',
            prefixIcon: Icon(PhosphorIconsRegular.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Phone number is required'
              : null,
        ),
      ],
    );
  }

  Widget _buildFieldColumn2() {
    return Column(
      children: [
        Obx(
          () => DropdownButtonFormField<String>(
            value: controller.selectedGender.value,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(PhosphorIconsRegular.genderIntersex),
            ),
            items: AppConstants.genders
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) {
              if (v != null) controller.selectedGender.value = v;
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: controller.joiningDateController,
          decoration: const InputDecoration(
            labelText: 'Joining Date',
            prefixIcon: Icon(PhosphorIconsRegular.calendar),
            suffixIcon: Icon(PhosphorIconsRegular.caretDown),
          ),
          readOnly: true,
          onTap: () => controller.pickDate(controller.joiningDateController),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: controller.addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: Icon(PhosphorIconsRegular.mapPin),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildPhysicalTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Responsive(
        mobile: _buildPhysicalForm(false),
        desktop: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildPhysicalForm(true),
        ),
      ),
    );
  }

  Widget _buildPhysicalForm(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWide)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller.heightController,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    prefixIcon: Icon(PhosphorIconsRegular.ruler),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: controller.weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: Icon(PhosphorIconsRegular.scales),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          )
        else ...[
          TextFormField(
            controller: controller.heightController,
            decoration: const InputDecoration(
              labelText: 'Height (cm)',
              prefixIcon: Icon(PhosphorIconsRegular.ruler),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: controller.weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              prefixIcon: Icon(PhosphorIconsRegular.scales),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Obx(
          () => Card(
            color: AppColors.primarySurface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.heart, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('BMI: ', style: AppTextStyles.bodyMd),
                  Text(
                    controller.bmi.value > 0
                        ? '${controller.bmi.value.toStringAsFixed(1)} '
                              '(${_bmiCategory(controller.bmi.value)})'
                        : 'Enter height & weight',
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Obx(
          () => DropdownButtonFormField<String>(
            value: controller.fitnessGoal.value.isNotEmpty
                ? controller.fitnessGoal.value
                : null,
            decoration: const InputDecoration(
              labelText: 'Fitness Goal',
              prefixIcon: Icon(PhosphorIconsRegular.target),
            ),
            items: AppConstants.fitnessGoals
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) {
              if (v != null) controller.fitnessGoal.value = v;
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildSaveButton(),
      ],
    );
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Widget _buildPackageSection(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Package', style: AppTextStyles.headingSm),
        const SizedBox(height: AppSpacing.sm),
        Obx(() {
          final items = controller.packages
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p['package_id'] as String?,
                  child: Text(p['name'] as String? ?? ''),
                ),
              )
              .toList();
          items.insert(
            0,
            const DropdownMenuItem(value: '', child: Text('No Package')),
          );
          return DropdownButtonFormField<String>(
            value: controller.selectedPackageId.value.isEmpty
                ? ''
                : items.any((i) => i.value == controller.selectedPackageId.value)
                    ? controller.selectedPackageId.value
                    : '',
            decoration: const InputDecoration(
              labelText: 'Select Package',
              prefixIcon: Icon(PhosphorIconsRegular.tag),
            ),
            items: items,
            onChanged: (v) => controller.selectedPackageId.value = v ?? '',
          );
        }),
      ],
    );
  }

  Widget _buildPaymentSection() {
    if (controller.isEditing) return const SizedBox.shrink();
    return Obx(() {
      return Card(

        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Payment', style: AppTextStyles.headingSm),
                  const Spacer(),
                  Text('Collect Payment', style: AppTextStyles.bodyMd),
                  const SizedBox(width: AppSpacing.sm),
                  Switch(
                    value: controller.collectPayment.value,
                    onChanged: (v) => controller.collectPayment.value = v,
                  ),
                ],
              ),
              if (controller.collectPayment.value) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Registration Fee',
                          prefixText: 'Rs. ',
                        ),
                        controller: TextEditingController(
                          text: controller.registrationFee.value.toString(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Monthly Fee',
                          prefixText: 'Rs. ',
                        ),
                        controller: TextEditingController(
                          text: controller.monthlyFee.value.toString(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text('Total: Rs. ${controller.registrationFee.value + controller.monthlyFee.value}',
                      style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: controller.paymentMethod.value,
                        decoration: const InputDecoration(
                          labelText: 'Method',
                          prefixIcon: Icon(PhosphorIconsRegular.coin, size: 18),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                          DropdownMenuItem(value: 'EasyPaisa', child: Text('EasyPaisa')),
                          DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
                        ],
                        onChanged: (v) {
                          if (v != null) controller.paymentMethod.value = v;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildQrField() {
    return TextFormField(
      controller: controller.qrDataController,
      decoration: const InputDecoration(
        labelText: 'QR Data (optional)',
        prefixIcon: Icon(PhosphorIconsRegular.qrCode),
      ),
      maxLines: 2,
    );
  }

  Widget _buildStatusDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: controller.selectedStatus.value,
        decoration: const InputDecoration(
          labelText: 'Status',
          prefixIcon: Icon(PhosphorIconsRegular.info),
        ),
        items: ['active', 'expired', 'paused', 'blocked']
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(s.capitalizeFirst ?? s),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) controller.selectedStatus.value = v;
        },
      ),
    );
  }

  Widget _buildFingerprintSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Obx(
                  () => Icon(
                    controller.isFingerprintRegistered.value
                        ? PhosphorIconsRegular.fingerprint
                        : PhosphorIconsRegular.fingerprint,
                    size: 32,
                    color: controller.isFingerprintRegistered.value
                        ? AppColors.success
                        : AppColors.neutralGray,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fingerprint',
                        style: AppTextStyles.headingSm,
                      ),
                      Obx(
                        () => Text(
                          controller.isFingerprintRegistered.value
                              ? 'Fingerprint registered'
                              : 'No fingerprint registered',
                          style: AppTextStyles.bodySm.copyWith(
                            color: controller.isFingerprintRegistered.value
                                ? AppColors.success
                                : AppColors.textSecondaryD,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => IconButton(
                    onPressed: controller.isFingerprintRegistered.value
                        ? controller.clearFingerprint
                        : controller.registerFingerprint,
                    icon: Icon(
                      controller.isFingerprintRegistered.value
                          ? PhosphorIconsRegular.trash
                          : PhosphorIconsRegular.plus,
                      color: controller.isFingerprintRegistered.value
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                    tooltip: controller.isFingerprintRegistered.value
                        ? 'Remove fingerprint'
                        : 'Register fingerprint',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Obx(
      () => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: controller.isLoading.value ? null : _save,
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
                  controller.isEditing ? 'Update Member' : 'Create Member',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (controller.isEditing) {
        controller.save(widget.gymId);
      } else {
        controller.saveWithFingerprint(widget.gymId);
      }
    }
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: controller.pickPhoto,
      child: Obx(() {
        final path = controller.selectedPhotoPath.value;
        return Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primarySurface,
              backgroundImage: path.isNotEmpty ? FileImage(File(path)) : null,
              child: path.isEmpty
                  ? const Icon(
                      PhosphorIconsRegular.user,
                      size: 44,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsRegular.camera,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
