import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../core/theme/app_colors.dart';

enum PopupType { success, error, warning, info }

class AppPopup {
  static OverlayEntry? _entry;

  static void success(String message, {Duration? duration}) {
    _show(
      message: message,
      type: PopupType.success,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void error(String message, {Duration? duration}) {
    _show(
      message: message,
      type: PopupType.error,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  static void warning(String message, {Duration? duration}) {
    _show(
      message: message,
      type: PopupType.warning,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  static void info(String message, {Duration? duration}) {
    _show(
      message: message,
      type: PopupType.info,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void _show({
    required String message,
    required PopupType type,
    required Duration duration,
  }) {
    try {
      _entry?.remove();
      _entry = null;

      final ctx = Get.context;
      if (ctx == null) return;

      final overlay = Overlay.of(ctx, rootOverlay: true);

      _entry = OverlayEntry(
        builder: (_) => _PopupOverlay(
          message: message,
          type: type,
          duration: duration,
          onDismiss: () {
            _entry?.remove();
            _entry = null;
          },
        ),
      );

      overlay.insert(_entry!);
    } catch (_) {}
  }
}

class _PopupOverlay extends StatefulWidget {
  final String message;
  final PopupType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _PopupOverlay({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_PopupOverlay> createState() => _PopupOverlayState();
}

class _PopupOverlayState extends State<_PopupOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildPopup(),
        ),
      ),
    );
  }

  Color get _accentColor {
    return switch (widget.type) {
      PopupType.success => AppColors.success,
      PopupType.error => AppColors.danger,
      PopupType.warning => AppColors.warning,
      PopupType.info => AppColors.info,
    };
  }

  IconData get _icon {
    return switch (widget.type) {
      PopupType.success => PhosphorIconsRegular.checkCircle,
      PopupType.error => PhosphorIconsRegular.xCircle,
      PopupType.warning => PhosphorIconsRegular.warning,
      PopupType.info => PhosphorIconsRegular.info,
    };
  }

  String get _label {
    return switch (widget.type) {
      PopupType.success => 'Success',
      PopupType.error => 'Error',
      PopupType.warning => 'Warning',
      PopupType.info => 'Info',
    };
  }

  Widget _buildPopup() {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _dismiss,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _accentColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: _accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF5F5F0),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFA09890),
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    PhosphorIconsRegular.x,
                    size: 14,
                    color: Color(0xFF6B6560),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
