import 'dart:developer';
import 'dart:typed_data';

import 'package:dartafis/dartafis.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/dartafis_service.dart';
import '../../../core/services/zkteco_scanner_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/controllers/auth_service.dart';
import 'member_repository.dart';
import 'member_model.dart';
import '../../../widgets/popups/app_popup.dart';

class MemberFormController extends GetxController {
  final MemberRepository _memberRepository = Get.find<MemberRepository>();
  final AuthService _authService = Get.find<AuthService>();
  final ZKTecoBiometricService _scanner = ZKTecoBiometricService();
  final DartafisService _dartafis = DartafisService();

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
  bool _isSaving = false;

  /// Stores the dartafis serialised fingerprint template.
  /// This is the only fingerprint data persisted for new enrollments.
  Uint8List? _fingerprintData;

  final RxList<Map<String, dynamic>> packages = <Map<String, dynamic>>[].obs;

  final RxInt registrationFee = 0.obs;
  final RxInt monthlyFee = 0.obs;
  final RxString paymentMethod = 'Cash'.obs;
  final RxBool collectPayment = true.obs;

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
    ever(selectedPackageId, (_) => _updateFeesFromPackage());
  }

  void _updateFeesFromPackage() {
    final pkg = packages.firstWhereOrNull(
      (p) => p['package_id'] == selectedPackageId.value,
    );
    registrationFee.value = pkg != null ? (pkg['price'] as int?) ?? 0 : 0;
    monthlyFee.value = pkg != null ? (pkg['monthly_fee'] as int?) ?? 0 : 0;
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

  /// Enroll a fingerprint using the industry-standard biometric workflow:
  ///   1. Capture raw fingerprint image from scanner.
  ///   2. Generate a dartafis biometric template (feature extraction).
  ///   3. Serialize the template for database storage.
  ///   4. Verify uniqueness: check the new template does not already
  ///      match an enrolled fingerprint above the deduplication threshold.
  ///   5. Store only the serialised template (no raw image persisted).
  Future<void> registerFingerprint() async {
    log('[MemberFormController] registerFingerprint called');
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Register Fingerprint'),
        content: const Text(
          'Place your finger on the fingerprint scanner.\n\n'
          'The system will capture and enroll your fingerprint.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Start Scan'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      log('[MemberFormController] registerFingerprint - cancelled');
      return;
    }
    try {
      _showEnrollDialog();

      Map<String, dynamic>? result;
      try {
        result = await _scanner.enrollFingerprint();
      } finally {
        Get.back();
      }

      if (result == null) {
        log('[MemberFormController] registerFingerprint - scan failed');
        AppPopup.error(
          'Fingerprint enrollment failed. Ensure the scanner is connected.',
        );
        return;
      }

      final rawImage = result['rawImage'] as List<int>?;
      if (rawImage == null || rawImage.length != AppConstants.fingerprintImageSize) {
        log('[MemberFormController] registerFingerprint - invalid raw image');
        AppPopup.error('Invalid fingerprint capture. Try again.');
        return;
      }

      log('[MemberFormController] registerFingerprint - extracting dartafis template');
      final imageBytes = Uint8List.fromList(rawImage);

      final serialisedTemplate = await _dartafis.extractAndSerialize(imageBytes);
      log('[MemberFormController] registerFingerprint - template extracted, '
          'size=${serialisedTemplate.length} bytes');

      if (!_dartafis.isValidTemplate(serialisedTemplate)) {
        log('[MemberFormController] registerFingerprint - invalid template generated');
        AppPopup.error('Failed to generate a valid fingerprint template. Try again.');
        return;
      }

      // --- Uniqueness check: verify this fingerprint is not already enrolled. ---
      final isDuplicate = await _isDuplicateTemplate(serialisedTemplate);
      if (isDuplicate) {
        log('[MemberFormController] registerFingerprint - DUPLICATE fingerprint detected');
        AppPopup.warning('This fingerprint is already registered to another member.');
        return;
      }

      _fingerprintData = serialisedTemplate;
      isFingerprintRegistered.value = true;
      log('[MemberFormController] registerFingerprint - success, '
          'templateLen=${serialisedTemplate.length}');
      AppPopup.success('Fingerprint registered (${serialisedTemplate.length} bytes)');
    } catch (e, stack) {
      log('[MemberFormController] registerFingerprint - error: $e');
      log('[MemberFormController] stack: $stack');
      AppPopup.error('Failed to register fingerprint: $e');
    }
  }

  /// Check whether [probe] already matches any stored dartafis template
  /// above the deduplication threshold.
  Future<bool> _isDuplicateTemplate(Uint8List probe) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('members',
        columns: ['fingerprint_data'],
        where: 'fingerprint_data IS NOT NULL',
      );
      if (rows.isEmpty) return false;

      final existingTemplates = rows
          .map((r) => r['fingerprint_data'] as Uint8List?)
          .whereType<Uint8List>()
          .toList();

      if (existingTemplates.isEmpty) return false;

      log('[MemberFormController] _isDuplicateTemplate: checking against '
          '${existingTemplates.length} existing templates');
      for (final t in existingTemplates) {
        try {
          final candidate = _dartafis.deserializeTemplate(t);
          final probeTpl = _dartafis.deserializeTemplate(probe);
          final matcher = SearchMatcher(probeTpl);
          final score = await matcher.match(candidate);
          if (score >= AppConstants.fingerprintEnrollDedupeThreshold) {
            log('[MemberFormController] _isDuplicateTemplate: DUPLICATE '
                'score=${score.toStringAsFixed(1)}');
            return true;
          }
        } catch (_) {
          continue;
        }
      }
      return false;
    } catch (e) {
      log('[MemberFormController] _isDuplicateTemplate error: $e');
      return false;
    }
  }

  void _showEnrollDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Registering Fingerprint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsRegular.fingerprint, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Place your finger on the scanner and hold steady.'),
            const SizedBox(height: 8),
            Text('Biometric template extraction in progress...',
              style: AppTextStyles.bodySm),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Reset ALL form fields and state to initial values.
  /// Called after a successful member creation so no previous data lingers.
  void resetForm() {
    log('[MemberFormController] resetForm');
    fullNameController.clear();
    fatherNameController.clear();
    cnicController.clear();
    phoneController.clear();
    joiningDateController.clear();
    addressController.clear();
    heightController.clear();
    weightController.clear();
    qrDataController.clear();
    startDateController.clear();
    expiryDateController.clear();

    selectedGender.value = 'Male';
    selectedPhotoPath.value = '';
    bmi.value = 0.0;
    selectedPackageId.value = '';
    selectedStatus.value = 'active';
    fitnessGoal.value = '';
    isLoading.value = false;

    _fingerprintData = null;
    isFingerprintRegistered.value = false;

    registrationFee.value = 0;
    monthlyFee.value = 0;
    paymentMethod.value = 'Cash';
    collectPayment.value = true;

    editingMember = null;
    log('[MemberFormController] resetForm completed');
  }

  Future<void> clearFingerprint() async {
    log('[MemberFormController] clearFingerprint called');
    _fingerprintData = null;
    isFingerprintRegistered.value = false;
    log('[MemberFormController] clearFingerprint completed');
  }

  Future<void> loadPackages(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[MemberFormController] loadPackages called gymId=$gymId');
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('packages', where: 'gym_id = ?', whereArgs: [gymId]);
    packages.value = result;
    if (result.isNotEmpty && selectedPackageId.value.isEmpty) {
      selectedPackageId.value = result.first['package_id'] as String;
    }
    _updateFeesFromPackage();
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
    _fingerprintData = member.fingerprintData;
    isFingerprintRegistered.value = member.fingerprintData != null;
    _updateFeesFromPackage();
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
      AppPopup.error('Full name is required');
      return;
    }
    if (phoneController.text.trim().isEmpty) {
      AppPopup.error('Phone number is required');
      return;
    }

    if (_isSaving) return;
    _isSaving = true;
    isLoading.value = true;

    bool didCreate = false;
    bool didUpdate = false;

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
          fingerprintData: _fingerprintData,
          qrData: qrDataController.text.trim().isEmpty ? null : qrDataController.text.trim(),
          packageId: selectedPackageId.value.isEmpty ? null : selectedPackageId.value,
          startDate: startDate,
          expiryDate: expiryDate,
          status: selectedStatus.value,
          updatedAt: now,
        );
        await _memberRepository.updateMember(updated);
        log('[MemberFormController] save - member updated successfully '
            'memberId=${updated.memberId} name="${updated.fullName}"');
        AppPopup.success('Member "${updated.fullName}" updated successfully');
        didUpdate = true;
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
          fingerprintData: _fingerprintData,
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
        log('[MemberFormController] save - member created successfully '
            'memberId=${created.memberId} name="${created.fullName}"');
        AppPopup.success('Member "${created.fullName}" added successfully');
        await _recordPayment(created, gymId);
        didCreate = true;
      }
    } catch (e, stack) {
      log('[MemberFormController] save failed: $e');
      log('[MemberFormController] stack: $stack');
      AppPopup.error(e.toString());
    } finally {
      _isSaving = false;
      isLoading.value = false;
      if (didCreate) {
        resetForm();
        log('[MemberFormController] save - navigating back after creation');
        Get.back(result: true);
      } else if (didUpdate) {
        log('[MemberFormController] save - navigating back after update');
        Get.back(result: true);
      }
    }
  }

  Future<void> saveWithFingerprint(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[MemberFormController] saveWithFingerprint called gymId=$gymId');

    // If fingerprint already registered, save directly
    if (_fingerprintData != null) {
      log('[MemberFormController] saveWithFingerprint - fingerprint already captured, saving');
      await save(gymId);
      return;
    }

    final connected = await _scanner.isScannerConnected();
    if (!connected) {
      log('[MemberFormController] saveWithFingerprint - no scanner, saving without fingerprint');
      await save(gymId);
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Register Fingerprint'),
        content: const Text('Place your finger on the scanner to register your fingerprint.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Skip')),
          ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('Scan')),
        ],
      ),
    );

    if (confirmed != true) {
      log('[MemberFormController] saveWithFingerprint - user skipped fingerprint');
      await save(gymId);
      return;
    }

    _showEnrollDialog();

    Map<String, dynamic>? result;
    try {
      result = await _scanner.enrollFingerprint();
    } finally {
      Get.back();
    }

    if (result != null) {
      final rawImage = result['rawImage'] as List<int>?;
      if (rawImage != null && rawImage.length == AppConstants.fingerprintImageSize) {
        final imageBytes = Uint8List.fromList(rawImage);
        final serialised = await _dartafis.extractAndSerialize(imageBytes);
        if (_dartafis.isValidTemplate(serialised)) {
          final isDup = await _isDuplicateTemplate(serialised);
          if (isDup) {
            log('[MemberFormController] saveWithFingerprint - DUPLICATE fingerprint');
            AppPopup.warning('This fingerprint is already registered to another member.');
            await save(gymId);
            return;
          }
          _fingerprintData = serialised;
          isFingerprintRegistered.value = true;
          log('[MemberFormController] saveWithFingerprint - '
              'template extracted, len=${serialised.length}');
          AppPopup.success('Fingerprint captured (${serialised.length} bytes)');
        } else {
          log('[MemberFormController] saveWithFingerprint - invalid template');
          AppPopup.warning('Fingerprint template invalid, saving without fingerprint');
        }
      } else {
        log('[MemberFormController] saveWithFingerprint - invalid raw image');
        AppPopup.warning('Fingerprint data invalid, saving without fingerprint');
      }
    } else {
      log('[MemberFormController] saveWithFingerprint - scan failed, saving without');
      AppPopup.warning('Fingerprint scan failed, saving member without fingerprint');
    }

    await save(gymId);
  }

  Future<void> _recordPayment(MemberModel member, String gymId) async {
    if (!collectPayment.value) {
      log('[MemberFormController] _recordPayment - skipped (collectPayment off)');
      return;
    }
    if (selectedPackageId.value.isEmpty) {
      log('[MemberFormController] _recordPayment - no package selected, skipping');
      return;
    }
    gymId = _resolveGymId(gymId);
    log('[MemberFormController] _recordPayment memberId=${member.memberId}');

    final total = registrationFee.value + monthlyFee.value;
    if (total <= 0) {
      log('[MemberFormController] _recordPayment - total is 0, skipping');
      return;
    }

    try {
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final paymentId = const Uuid().v4();
      final db = await DatabaseHelper.instance.database;

      await db.insert('payments', {
        'payment_id': paymentId,
        'gym_id': gymId,
        'member_id': member.memberId,
        'package_id': member.packageId,
        'amount': total,
        'discount': 0,
        'tax': 0,
        'total': total,
        'method': paymentMethod.value,
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
      final pkg = packages.firstWhereOrNull(
        (p) => p['package_id'] == member.packageId,
      );
      final pkgName = pkg != null ? (pkg['name'] as String? ?? '') : '';

      await db.insert('invoices', {
        'invoice_id': invoiceId,
        'gym_id': gymId,
        'member_id': member.memberId,
        'payment_id': paymentId,
        'invoice_number': invoiceNumber,
        'package_name': pkgName,
        'amount': total,
        'discount': 0,
        'tax': 0,
        'total': total,
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

      log('[MemberFormController] _recordPayment - payment recorded invoice=$invoiceNumber');
      AppPopup.success('Payment collected successfully');
    } catch (e, stack) {
      log('[MemberFormController] _recordPayment - error: $e');
      log('[MemberFormController] stack: $stack');
      AppPopup.error('Failed to record payment: $e');
    }
  }
}
