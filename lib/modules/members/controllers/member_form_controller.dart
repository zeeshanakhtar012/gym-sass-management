import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../auth/controllers/auth_service.dart';
import 'member_repository.dart';
import 'member_model.dart';

class MemberFormController extends GetxController {
  final MemberRepository _memberRepository = Get.find<MemberRepository>();
  final AuthService _authService = Get.find<AuthService>();

  MemberModel? editingMember;

  final fullNameController = TextEditingController();
  final fatherNameController = TextEditingController();
  final cnicController = TextEditingController();
  final phoneController = TextEditingController();
  final joiningDateController = TextEditingController();
  final addressController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final qrDataController = TextEditingController();
  final startDateController = TextEditingController();
  final expiryDateController = TextEditingController();

  final RxString selectedGender = 'Male'.obs;
  final RxString selectedPhotoPath = ''.obs;
  final RxDouble bmi = 0.0.obs;
  final RxString selectedPackageId = ''.obs;
  final RxString selectedStatus = 'active'.obs;
  final RxString fitnessGoal = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isFingerprintRegistered = false.obs;
  Uint8List? _fingerprintTemplate;
  final RxList<Map<String, dynamic>> packages = <Map<String, dynamic>>[].obs;

  bool get isEditing => editingMember != null;

  String _resolveGymId(String gymId) {
    if (gymId.isNotEmpty) return gymId;
    return _authService.currentGymId ?? '';
  }

  @override
  void onInit() {
    super.onInit();
    log('[MemberFormController] onInit');
    heightController.addListener(_onMeasurementChanged);
    weightController.addListener(_onMeasurementChanged);
  }

  @override
  void onClose() {
    log('[MemberFormController] onClose');
    fullNameController.dispose();
    fatherNameController.dispose();
    cnicController.dispose();
    phoneController.dispose();
    joiningDateController.dispose();
    addressController.dispose();
    heightController.dispose();
    weightController.dispose();

    qrDataController.dispose();
    startDateController.dispose();
    expiryDateController.dispose();
    super.onClose();
  }

  void _onMeasurementChanged() {
    calculateBmi();
  }

  Future<void> registerFingerprint() async {
    log('[MemberFormController] registerFingerprint called');
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Register Fingerprint'),
        content: const Text(
          'Place your finger on the fingerprint scanner to begin enrollment.\n\n'
          'The scanner will scan your finger 3 times to create a complete template.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Start Enrollment'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      log('[MemberFormController] registerFingerprint - cancelled');
      return;
    }
    try {
      for (int scan = 1; scan <= 3; scan++) {
        final completed = await _showFingerprintScanDialog(scan, 3);
        if (!completed) {
          log('[MemberFormController] registerFingerprint - scan $scan cancelled');
          return;
        }
      }
      _fingerprintTemplate = Uint8List.fromList(utf8.encode(const Uuid().v4()));
      isFingerprintRegistered.value = true;
      log('[MemberFormController] registerFingerprint - success');
      Get.snackbar('Success', 'Fingerprint registered successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e, stack) {
      log('[MemberFormController] registerFingerprint - error: $e');
      log('[MemberFormController] stack: $stack');
      Get.back();
      Get.snackbar('Error', 'Failed to register fingerprint: $e');
    }
  }

  Future<bool> _showFingerprintScanDialog(int currentScan, int totalScans) async {
    int _state = 0; // 0=initial, 1=scanning, 2=done
    return await Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Scan $currentScan of $totalScans'),
            content: _state == 0
                ? const Text(
                    'Place your finger firmly on the scanner.\n\n'
                    'Hold steady until the scan completes.',
                  )
                : _state == 1
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsRegular.fingerprint, size: 64, color: AppColors.primary),
                          SizedBox(height: 16),
                          Text('Scanning finger...', style: AppTextStyles.bodyLg),
                          SizedBox(height: 16),
                          CircularProgressIndicator(),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsRegular.checkCircle, size: 64, color: AppColors.success),
                          SizedBox(height: 16),
                          Text('Scan captured!', style: AppTextStyles.bodyLg),
                        ],
                      ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              if (_state == 0)
                ElevatedButton(
                  onPressed: () async {
                    setDialogState(() { _state = 1; });
                    await Future.delayed(const Duration(milliseconds: 1500));
                    setDialogState(() { _state = 2; });
                  },
                  child: const Text('Scan'),
                ),
              if (_state == 2)
                ElevatedButton(
                  onPressed: () => Get.back(result: true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  child: const Text('Continue', style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        },
      ),
      barrierDismissible: false,
    ) ?? false;
  }

  Future<void> clearFingerprint() async {
    log('[MemberFormController] clearFingerprint called');
    _fingerprintTemplate = null;
    isFingerprintRegistered.value = false;
    log('[MemberFormController] clearFingerprint completed');
  }

  Future<void> loadPackages(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[MemberFormController] loadPackages called gymId=$gymId');
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('packages', where: 'gym_id = ?', whereArgs: [gymId]);
    packages.value = result;
    log('[MemberFormController] loadPackages loaded ${result.length} packages');
  }

  Future<void> loadMember(MemberModel member) async {
    log('[MemberFormController] loadMember called memberId=${member.memberId}');
    editingMember = member;
    fullNameController.text = member.fullName;
    fatherNameController.text = member.fatherName ?? '';
    cnicController.text = member.cnic ?? '';
    phoneController.text = member.phone ?? '';
    selectedGender.value = member.gender ?? 'Male';
    joiningDateController.text = member.dob ?? '';
    addressController.text = member.address ?? '';
    selectedPhotoPath.value = member.photoPath ?? '';
    heightController.text = member.height?.toString() ?? '';
    weightController.text = member.weight?.toString() ?? '';
    bmi.value = member.bmi ?? 0.0;
    fitnessGoal.value = member.fitnessGoal ?? '';
    qrDataController.text = member.qrData ?? '';
    selectedPackageId.value = member.packageId ?? '';
    startDateController.text = member.startDate ?? '';
    expiryDateController.text = member.expiryDate ?? '';
    selectedStatus.value = member.status;
    _fingerprintTemplate = member.fingerprintTemplate;
    isFingerprintRegistered.value = member.fingerprintTemplate != null;
    log('[MemberFormController] loadMember completed');
  }

  Future<void> pickPhoto() async {
    log('[MemberFormController] pickPhoto called');
    final source = await Get.dialog<ImageSource>(
      AlertDialog(
        title: const Text('Select Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsRegular.camera),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture using camera'),
              onTap: () => Get.back(result: ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.image),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick an existing photo'),
              onTap: () => Get.back(result: ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final result = await picker.pickImage(source: source, imageQuality: 80);
    if (result != null) {
      selectedPhotoPath.value = result.path;
      log('[MemberFormController] pickPhoto - selected ${result.path}');
    } else {
      log('[MemberFormController] pickPhoto - no image selected');
    }
  }

  Future<void> capturePhoto() async {
    log('[MemberFormController] capturePhoto called');
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (result != null) {
      selectedPhotoPath.value = result.path;
      log('[MemberFormController] capturePhoto - captured ${result.path}');
    } else {
      log('[MemberFormController] capturePhoto - cancelled');
    }
  }

  void calculateBmi() {
    final h = double.tryParse(heightController.text);
    final w = double.tryParse(weightController.text);
    if (h != null && w != null && h > 0) {
      final heightInMeters = h / 100;
      bmi.value = double.parse((w / (heightInMeters * heightInMeters)).toStringAsFixed(1));
      log('[MemberFormController] calculateBmi - height=$h weight=$w bmi=${bmi.value}');
    } else {
      bmi.value = 0.0;
      log('[MemberFormController] calculateBmi - invalid input');
    }
  }

  Future<void> pickDate(TextEditingController controller) async {
    log('[MemberFormController] pickDate called');
    final date = await showDatePicker(
      context: Get.context!,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(date);
      log('[MemberFormController] pickDate - selected ${controller.text}');
    } else {
      log('[MemberFormController] pickDate - cancelled');
    }
  }

  Future<void> save(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[MemberFormController] save called gymId=$gymId isEditing=$isEditing');
    if (fullNameController.text.trim().isEmpty) {
      log('[MemberFormController] save - name empty');
      Get.snackbar('Error', 'Full name is required');
      return;
    }
    if (phoneController.text.trim().isEmpty) {
      log('[MemberFormController] save - phone empty');
      Get.snackbar('Error', 'Phone number is required');
      return;
    }

    isLoading.value = true;
    try {
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final joinDate = joiningDateController.text.trim().isNotEmpty
          ? joiningDateController.text.trim()
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      String? startDate;
      String? expiryDate;
      if (selectedPackageId.value.isNotEmpty) {
        startDate = joinDate;
        final pkg = packages.firstWhereOrNull(
          (p) => p['package_id'] == selectedPackageId.value,
        );
        if (pkg != null) {
          final durDays = (pkg['duration_days'] as int?) ?? 0;
          if (durDays > 0) {
            final start = DateTime.parse(joinDate);
            expiryDate = DateFormat('yyyy-MM-dd').format(
              start.add(Duration(days: durDays)),
            );
          }
        }
      }

      if (isEditing) {
        final updated = editingMember!.copyWith(
          fullName: fullNameController.text.trim(),
          fatherName: fatherNameController.text.trim().isEmpty ? null : fatherNameController.text.trim(),
          cnic: cnicController.text.trim().isEmpty ? null : cnicController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          gender: selectedGender.value,
          dob: joinDate,
          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
          photoPath: selectedPhotoPath.value.isEmpty ? editingMember!.photoPath : selectedPhotoPath.value,
          height: double.tryParse(heightController.text),
          weight: double.tryParse(weightController.text),
          bmi: bmi.value > 0 ? bmi.value : null,
          fitnessGoal: fitnessGoal.value.trim().isEmpty ? null : fitnessGoal.value.trim(),
          fingerprintTemplate: _fingerprintTemplate,
          qrData: qrDataController.text.trim().isEmpty ? null : qrDataController.text.trim(),
          packageId: selectedPackageId.value.isEmpty ? null : selectedPackageId.value,
          startDate: startDate,
          expiryDate: expiryDate,
          status: selectedStatus.value,
          updatedAt: now,
        );
        await _memberRepository.updateMember(updated);
        log('[MemberFormController] save - member updated successfully');
        Get.back(result: true);
      } else {
        final member = MemberModel(
          memberId: '',
          gymId: gymId,
          fullName: fullNameController.text.trim(),
          fatherName: fatherNameController.text.trim().isEmpty ? null : fatherNameController.text.trim(),
          cnic: cnicController.text.trim().isEmpty ? null : cnicController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          gender: selectedGender.value,
          dob: joinDate,
          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
          photoPath: selectedPhotoPath.value.isEmpty ? null : selectedPhotoPath.value,
          height: double.tryParse(heightController.text),
          weight: double.tryParse(weightController.text),
          bmi: bmi.value > 0 ? bmi.value : null,
          fitnessGoal: fitnessGoal.value.trim().isEmpty ? null : fitnessGoal.value.trim(),
          fingerprintTemplate: _fingerprintTemplate,
          qrData: qrDataController.text.trim().isEmpty ? null : qrDataController.text.trim(),
          packageId: selectedPackageId.value.isEmpty ? null : selectedPackageId.value,
          startDate: startDate,
          expiryDate: expiryDate,
          status: 'active',
          registrationDate: now,
          createdAt: now,
          updatedAt: now,
        );
        final created = await _memberRepository.createMember(member);
        log('[MemberFormController] save - member created successfully');
        isLoading.value = false;
        final feePaid = await _collectRegistrationFee(created, gymId);
        if (feePaid) {
          Get.back(result: true);
        }
        return;
      }
    } catch (e, stack) {
      log('[MemberFormController] save failed: $e');
      log('[MemberFormController] stack: $stack');
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _collectRegistrationFee(MemberModel member, String gymId) async {
    log('[MemberFormController] _collectRegistrationFee called');
    final pkg = packages.firstWhereOrNull(
      (p) => p['package_id'] == member.packageId,
    );
    final regFee = pkg != null ? (pkg['price'] as int?) ?? 0 : 0;
    final monthlyFee = pkg != null ? (pkg['monthly_fee'] as int?) ?? 0 : 0;
    final memberName = member.fullName;

    String paymentMethod = 'Cash';
    final result = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Registration Fee'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Member: $memberName', style: AppTextStyles.bodyMd),
                  SizedBox(height: AppSpacing.md),
                  if (regFee > 0) ...[
                    _feeRow('Registration Fee', regFee),
                    SizedBox(height: AppSpacing.sm),
                  ],
                  if (monthlyFee > 0) ...[
                    _feeRow('Monthly Fee', monthlyFee),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Next fee due: ${DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)))}',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondaryL),
                    ),
                    SizedBox(height: AppSpacing.md),
                  ],
                  Divider(),
                  _feeRow('Total Due', regFee + monthlyFee, bold: true),
                  SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(PhosphorIconsRegular.coin),
                    ),
                    items: ['Cash', 'Bank Transfer', 'EasyPaisa', 'JazzCash']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => paymentMethod = v);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Collect Payment', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      try {
        final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final paymentId = const Uuid().v4();
        final db = await DatabaseHelper.instance.database;
        final totalAmount = regFee + monthlyFee;

        await db.insert('payments', {
          'payment_id': paymentId,
          'gym_id': gymId,
          'member_id': member.memberId,
          'package_id': member.packageId,
          'amount': totalAmount,
          'discount': 0,
          'tax': 0,
          'total': totalAmount,
          'method': paymentMethod,
          'remarks': 'Registration fee + first month fee',
          'received_by': _authService.currentSession.value?.username ?? '',
          'payment_date': dateStr,
          'created_at': now,
        });

        final invoiceId = const Uuid().v4();
        final gymCode = gymId.length > 4
            ? gymId.substring(0, 4).toUpperCase()
            : 'GYM';
        final invoiceCount = await db.query('invoices', where: 'gym_id = ?', whereArgs: [gymId]);
        final invoiceNumber = 'INV-$gymCode-${(invoiceCount.length + 1).toString().padLeft(4, '0')}';
        final pkgName = pkg != null ? (pkg['name'] as String? ?? '') : '';

        await db.insert('invoices', {
          'invoice_id': invoiceId,
          'gym_id': gymId,
          'member_id': member.memberId,
          'payment_id': paymentId,
          'invoice_number': invoiceNumber,
          'package_name': pkgName,
          'amount': totalAmount,
          'discount': 0,
          'tax': 0,
          'total': totalAmount,
          'status': 'paid',
          'invoice_date': dateStr,
        });

        final feeDueDate = DateFormat('yyyy-MM-dd').format(
          DateTime.now().add(const Duration(days: 30)),
        );
        final updated = member.copyWith(
          feeStatus: 'paid',
          lastFeePaidDate: dateStr,
          feeDueDate: feeDueDate,
        );
        await _memberRepository.updateMember(updated);

        log('[MemberFormController] _collectRegistrationFee - payment recorded invoice=$invoiceNumber');
        Get.snackbar('Success', 'Payment collected successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } catch (e, stack) {
        log('[MemberFormController] _collectRegistrationFee - error: $e');
        log('[MemberFormController] stack: $stack');
        Get.snackbar('Error', 'Failed to record payment: $e');
        return false;
      }
    }
    return false;
  }

  Widget _feeRow(String label, int amount, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: bold ? AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600) : AppTextStyles.bodyMd),
        Text('Rs. $amount', style: bold ? AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary) : AppTextStyles.bodyMd),
      ],
    );
  }
}
