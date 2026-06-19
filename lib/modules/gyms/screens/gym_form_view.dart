import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../../core/helpers/validators.dart';
import '../controllers/gym_form_controller.dart';

class GymFormView extends GetView<GymFormController> {
  const GymFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit Gym' : 'Add Gym'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Responsive(
          mobile: _buildForm(context, isWide: false),
          desktop: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildForm(context, isWide: true),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool isWide}) {
    final fields = _buildFields(context);

    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo Picker
          Center(child: _buildLogoPicker()),
          const SizedBox(height: AppSpacing.xl),

          if (isWide)
            _buildDesktopFields(fields)
          else
            ...fields,

          if (!controller.isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            _buildPasswordFields(context),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Save Button
          Obx(() => SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: controller.isLoading.value ? null : controller.save,
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
                      controller.isEditing ? 'Update Gym' : 'Create Gym',
                      style: AppTextStyles.bodyLg.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDesktopFields(List<Widget> fields) {
    final inputs = fields.where((w) => w is! SizedBox).toList();
    final rows = <Widget>[];
    for (var i = 0; i < inputs.length; i += 2) {
      if (i + 1 < inputs.length) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: inputs[i]),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: inputs[i + 1]),
              ],
            ),
          ),
        );
      } else {
        rows.add(inputs[i]);
      }
    }
    return Column(children: rows);
  }

  List<Widget> _buildFields(BuildContext context) {
    return [
      TextFormField(
        controller: controller.nameController,
        decoration: const InputDecoration(
          labelText: 'Gym Name *',
          prefixIcon: Icon(PhosphorIconsRegular.buildings),
        ),
        validator: (v) => Validators.required(v, 'Gym name'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: controller.ownerNameController,
        decoration: const InputDecoration(
          labelText: 'Owner Name',
          prefixIcon: Icon(PhosphorIconsRegular.user),
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
        validator: (v) => Validators.required(v, 'Phone number'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: controller.emailController,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(PhosphorIconsRegular.envelope),
        ),
        keyboardType: TextInputType.emailAddress,
        validator: (v) => v != null && v.isNotEmpty ? Validators.email(v) : null,
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: controller.whatsappController,
        decoration: const InputDecoration(
          labelText: 'WhatsApp',
          prefixIcon: Icon(PhosphorIconsRegular.whatsappLogo),
        ),
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
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller.openingTimeController,
              decoration: const InputDecoration(
                labelText: 'Opening Time',
                prefixIcon: Icon(PhosphorIconsRegular.clock),
                hintText: '09:00 AM',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextFormField(
              controller: controller.closingTimeController,
              decoration: const InputDecoration(
                labelText: 'Closing Time',
                prefixIcon: Icon(PhosphorIconsRegular.clock),
                hintText: '10:00 PM',
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildPasswordFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Account Credentials', style: AppTextStyles.headingSm),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: controller.passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password *',
            prefixIcon: Icon(PhosphorIconsRegular.lock),
          ),
          validator: (v) => Validators.minLength(v, 6, 'Password'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: controller.confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm Password *',
            prefixIcon: Icon(PhosphorIconsRegular.lock),
          ),
          validator: (v) {
            if (v != controller.passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    return GestureDetector(
      onTap: controller.pickLogo,
      child: Obx(() {
        final path = controller.selectedLogoPath.value;
        return Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primarySurface,
              backgroundImage: path.isNotEmpty ? FileImage(File(path)) : null,
              child: path.isEmpty
                  ? const Icon(
                      PhosphorIconsRegular.buildings,
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
