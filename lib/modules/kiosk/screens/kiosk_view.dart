import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/constants/app_constants.dart';
import '../../members/controllers/member_model.dart';
import '../controllers/kiosk_controller.dart';

class KioskView extends GetView<KioskController> {
  final String gymId;
  final String gymName;
  const KioskView({super.key, this.gymId = '', this.gymName = 'GYM'});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E11),
      body: Obx(() {
        if (controller.showSuccess.value) return _buildSuccessScreen();
        return _buildKioskScreen();
      }),
    );
  }

  Widget _buildKioskScreen() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildFingerprintScanner(),
          _buildSearchBar(),
          _buildStatsRow(),
          Expanded(child: _buildMemberGrid()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
              Get.back();
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2226),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: const Color(0xFF2C3A3F)),
              ),
              child: const Icon(PhosphorIconsRegular.x, color: Color(0xFF8C9BA3), size: 24),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              children: [
                const Text(
                  '// MEMBER CHECK-IN',
                  style: TextStyle(
                    color: Color(0xFF00FF41),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  gymName,
                  style: const TextStyle(
                    color: Color(0xFF8C9BA3),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            final alive = controller.isScanning.value;
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alive ? const Color(0xFF00FF41) : const Color(0xFF8C9BA3),
                boxShadow: alive
                    ? [BoxShadow(color: const Color(0xFF00FF41).withValues(alpha: 0.6), blurRadius: 8)]
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFingerprintScanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B0D),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.3)),
      ),
      child: Obx(() {
        final hasFingerprints = controller.fingerprintMembers.isNotEmpty;
        return Row(
          children: [
            _scanningAnimation(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFingerprints ? 'SCANNING FINGERPRINT...' : 'NO FINGERPRINT DEVICE',
                    style: TextStyle(
                      color: hasFingerprints ? const Color(0xFF00FF41) : const Color(0xFF8C9BA3),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasFingerprints)
                    Text(
                      controller.detectedName.value.isNotEmpty
                          ? '> DETECTED: ${controller.detectedName.value}'
                          : '> waiting for scan...',
                      style: const TextStyle(
                        color: Color(0xFF8C9BA3),
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),
            if (hasFingerprints)
              GestureDetector(
                onTap: () => controller.autoDetectAndCheckIn(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'SIMULATE',
                    style: TextStyle(
                      color: Color(0xFF00FF41),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _scanningAnimation() {
    return Obx(() {
      final idx = controller.scanningIndex.value;
      final total = controller.fingerprintMembers.length;
      return SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.fingerprint,
              size: 28,
              color: controller.isScanning.value
                  ? const Color(0xFF00FF41)
                  : const Color(0xFF2C3A3F),
            ),
            if (total > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00FF41),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$idx',
                    style: const TextStyle(
                      color: Color(0xFF0A0E11),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: TextField(
        onChanged: (v) => controller.searchMembers(v),
        style: const TextStyle(
          color: Color(0xFF00FF41),
          fontSize: AppConstants.kioskMinBodyFont,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          hintText: '> search name or phone...',
          hintStyle: const TextStyle(color: Color(0xFF2C3A3F), fontSize: AppConstants.kioskMinBodyFont, fontFamily: 'monospace'),
          prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: Color(0xFF2C3A3F), size: 22),
          suffixIcon: Obx(() {
            if (controller.searchQuery.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(PhosphorIconsRegular.x, color: Color(0xFF2C3A3F)),
              onPressed: () => controller.searchQuery.value = '',
            );
          }),
          filled: true,
          fillColor: const Color(0xFF0D1B0D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            borderSide: BorderSide(color: const Color(0xFF00FF41).withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            borderSide: BorderSide(color: const Color(0xFF00FF41).withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            borderSide: const BorderSide(color: Color(0xFF00FF41)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
        ),
        autofocus: true,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF41).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(PhosphorIconsRegular.signIn, color: Color(0xFF00FF41), size: 18),
                const SizedBox(width: AppSpacing.sm),
                Obx(() => Text(
                  '${controller.todayCheckInCount} TODAY',
                  style: const TextStyle(
                    color: Color(0xFF00FF41),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                  ),
                )),
              ],
            ),
          ),
          const Spacer(),
          Obx(() {
            final count = controller.fingerprintMembers.length;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B0D),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: const Color(0xFF2C3A3F)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsRegular.fingerprint, color: Color(0xFF00FF41), size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$count FP ON FILE',
                    style: const TextStyle(
                      color: Color(0xFF8C9BA3),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMemberGrid() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00FF41)),
        );
      }
      final list = controller.filteredMembers;
      if (list.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsRegular.userMinus, size: 64, color: const Color(0xFF2C3A3F)),
              const SizedBox(height: AppSpacing.md),
              Text(
                controller.searchQuery.isNotEmpty ? '> NO MATCHES FOUND' : '> NO ACTIVE MEMBERS',
                style: const TextStyle(color: Color(0xFF2C3A3F), fontSize: AppConstants.kioskMinBodyFont, fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.85,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) => _buildMemberCard(list[i]),
      );
    });
  }

  Widget _buildMemberCard(MemberModel member) {
    final hasFingerprint = member.fingerprintTemplate != null;
    return GestureDetector(
      onTap: () => controller.checkInMember(gymId, member.memberId),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B0D),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: hasFingerprint
                ? const Color(0xFF00FF41).withValues(alpha: 0.3)
                : const Color(0xFF1A2226),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                _buildAvatar(member, size: 56),
                if (hasFingerprint)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00FF41),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.fingerprint,
                        size: 12,
                        color: Color(0xFF0A0E11),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                member.fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppConstants.kioskMinBodyFont,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (member.packageId != null)
              Text(
                member.packageId!,
                style: const TextStyle(
                  color: Color(0xFF00FF41),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final member = controller.checkedInMember.value;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '> ACCESS GRANTED',
              style: TextStyle(
                color: Color(0xFF00FF41),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Icon(PhosphorIconsRegular.checkCircle, size: 96, color: const Color(0xFF00FF41)),
            const SizedBox(height: AppSpacing.lg),
            if (member != null) ...[
              _buildAvatar(member, size: 120),
              const SizedBox(height: AppSpacing.lg),
              Text(
                member.fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppConstants.kioskNameFont,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'CHECKED IN',
                  style: TextStyle(
                    color: Color(0xFF00FF41),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (member.expiryDate != null) _buildExpiryInfo(member.expiryDate!),
            ],
            const SizedBox(height: AppSpacing.xxl),
            GestureDetector(
              onTap: () => controller.dismissSuccess(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2226),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: const Color(0xFF2C3A3F)),
                ),
                child: const Text(
                  '> tap to dismiss',
                  style: TextStyle(color: Color(0xFF8C9BA3), fontSize: 16, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(MemberModel member, {double size = 64}) {
    if (member.photoPath != null && member.photoPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.file(
          File(member.photoPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(size),
        ),
      );
    }
    return _buildAvatarPlaceholder(size);
  }

  Widget _buildAvatarPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2226),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2C3A3F)),
      ),
      child: Icon(
        PhosphorIconsRegular.user,
        size: size * 0.45,
        color: const Color(0xFF2C3A3F),
      ),
    );
  }

  Widget _buildExpiryInfo(String expiryDate) {
    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return const SizedBox.shrink();
    final days = expiry.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Text(
        'EXP: ${Formatters.remainingDays(days)}',
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
