import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';

class SimpleBarChart extends StatelessWidget {
  final List<BarData> data;
  final double height;
  final String? title;

  const SimpleBarChart({
    super.key,
    required this.data,
    this.height = 200,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final max = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: AppTextStyles.headingSm),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final ratio = max > 0 ? d.value / max : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${d.value}',
                        style: AppTextStyles.bodySm.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: ratio * (height - 40),
                        decoration: BoxDecoration(
                          color: d.color ?? AppColors.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.label,
                        style: AppTextStyles.bodySm.copyWith(fontSize: 9),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class BarData {
  final String label;
  final int value;
  final Color? color;

  const BarData(this.label, this.value, {this.color});
}
