import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final List<InfoRow> rows;
  final Widget? trailing;
  final Widget? bottom;

  const InfoCard({
    super.key,
    required this.title,
    required this.rows,
    this.trailing,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.headingSm)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(row.label, style: AppTextStyles.bodySm),
                  ),
                  Expanded(
                    child: Text(row.value, style: AppTextStyles.bodyMd.copyWith(
                      color: row.color ?? AppColors.textPrimaryL,
                      fontWeight: row.isBold ? FontWeight.w600 : null,
                    )),
                  ),
                ],
              ),
            )),
            if (bottom != null) ...[
              const SizedBox(height: AppSpacing.sm),
              bottom!,
            ],
          ],
        ),
      ),
    );
  }
}

class InfoRow {
  final String label;
  final String value;
  final Color? color;
  final bool isBold;

  const InfoRow(this.label, this.value, {this.color, this.isBold = false});
}
