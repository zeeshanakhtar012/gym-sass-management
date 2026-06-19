import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../core/theme/app_spacing.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hint;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    this.controller,
    required this.onChanged,
    this.hint = 'Search...',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        suffixIcon: onClear != null
            ? IconButton(
                icon: const Icon(PhosphorIconsRegular.x),
                onPressed: onClear,
              )
            : null,
      ),
    );
  }
}
