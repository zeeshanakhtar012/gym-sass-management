import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusBadge(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? _colorForStatus(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.bodySm.copyWith(
          color: c,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
      case 'new':
      case 'in use':
        return AppColors.success;
      case 'expired':
      case 'cancelled':
      case 'retired':
      case 'needs repair':
        return AppColors.danger;
      case 'paused':
      case 'pending':
      case 'fair':
      case 'under maintenance':
        return AppColors.warning;
      case 'good':
        return AppColors.info;
      default:
        return AppColors.neutralGray;
    }
  }
}
