import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../controllers/fingerprint_test_controller.dart';

class FingerprintTestView extends StatefulWidget {
  const FingerprintTestView({super.key});

  @override
  State<FingerprintTestView> createState() => _FingerprintTestViewState();
}

class _FingerprintTestViewState extends State<FingerprintTestView> {
  final controller = Get.put(FingerprintTestController());
  final _scrollCtrl = ScrollController();
  ui.Image? _displayImage;

  @override
  void initState() {
    super.initState();
    ever(controller.rawImageBytes, (Uint8List? bytes) {
      if (bytes != null) _updateImage(bytes);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _displayImage?.dispose();
    super.dispose();
  }

  Future<void> _updateImage(Uint8List grayscale) async {
    final rgba = Uint8List(grayscale.length * 4);
    for (int i = 0; i < grayscale.length; i++) {
      final b = grayscale[i];
      final j = i * 4;
      rgba[j] = b;
      rgba[j + 1] = b;
      rgba[j + 2] = b;
      rgba[j + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, 300, 375, ui.PixelFormat.rgba8888, (img) {
      completer.complete(img);
    });
    final img = await completer.future;
    if (!mounted) return;
    setState(() {
      _displayImage?.dispose();
      _displayImage = img;
    });
  }

  Widget _buildImagePreview() {
    if (controller.rawImageBytes.value == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2C3A3F)),
        ),
        child: const Center(
          child: Text('No image captured', style: TextStyle(color: Color(0xFF8C9BA3))),
        ),
      );
    }

    if (_displayImage == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C3A3F)),
      ),
      child: Center(
        child: RawImage(
          image: _displayImage!,
          width: 300,
          height: 375,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  String _resultCode(int result) {
    if (result == 0) return 'ZKFP_ERR_OK (0)';
    if (result == -7) return 'ZKFP_ERR_EXTRACT (-7)';
    if (result == -8) return 'ZKFP_ERR_CAPTURE (-8)';
    return '$result';
  }

  Color _resultColor(int result) {
    if (result == 0) return const Color(0xFF00FF41);
    return const Color(0xFFFF4444);
  }

  Widget _build() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E11),
        title: const Text('Fingerprint Test',
          style: TextStyle(color: Color(0xFF00FF41), fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft, color: Color(0xFF8C9BA3)),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 16),
            _buildImagePreview(),
            const SizedBox(height: 16),
            _buildResults(),
            const SizedBox(height: 16),
            _buildLog(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _build();

  Widget _buildStatusCard() {
    return Obx(() => Card(
      color: const Color(0xFF1A2226),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: controller.connected.value ? const Color(0xFF00FF41) : const Color(0xFFFF4444),
                boxShadow: controller.connected.value
                    ? [BoxShadow(color: const Color(0xFF00FF41).withValues(alpha: 0.6), blurRadius: 8)]
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              controller.connected.value ? 'DEVICE CONNECTED' : 'DEVICE DISCONNECTED',
              style: TextStyle(
                color: controller.connected.value ? const Color(0xFF00FF41) : const Color(0xFFFF4444),
                fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Obx(() => ElevatedButton.icon(
                onPressed: controller.isCapturing.value ? null : controller.checkConnection,
                icon: const Icon(PhosphorIconsRegular.plug),
                label: const Text('Check Device'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2226),
                  foregroundColor: const Color(0xFF8C9BA3),
                  side: const BorderSide(color: Color(0xFF2C3A3F)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => ElevatedButton.icon(
                onPressed: controller.isCapturing.value ? null : controller.capture,
                icon: controller.isCapturing.value
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF41)))
                    : const Icon(PhosphorIconsRegular.fingerprint),
                label: Text(controller.isCapturing.value ? 'Capturing...' : 'Capture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF41).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF00FF41),
                  side: BorderSide(color: const Color(0xFF00FF41).withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final text = controller.logs.join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  Get.snackbar('Copied', '${controller.logs.length} log lines copied to clipboard',
                    backgroundColor: const Color(0xFF1A2226), colorText: const Color(0xFF00FF41),
                    duration: const Duration(seconds: 2));
                },
                icon: const Icon(PhosphorIconsRegular.copy),
                label: const Text('Copy Logs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2226),
                  foregroundColor: const Color(0xFF8C9BA3),
                  side: const BorderSide(color: Color(0xFF2C3A3F)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => controller.logs.clear(),
                icon: const Icon(PhosphorIconsRegular.trash),
                label: const Text('Clear Log'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2226),
                  foregroundColor: const Color(0xFF8C9BA3),
                  side: const BorderSide(color: Color(0xFF2C3A3F)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Obx(() => ElevatedButton.icon(
                onPressed: controller.isCapturing.value ? null : controller.testMatching,
                icon: controller.isCapturing.value
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFAA00)))
                    : const Icon(PhosphorIconsRegular.magnifyingGlass),
                label: Text(controller.isCapturing.value ? 'Matching...' : 'Test Matching'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFAA00).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFFFFAA00),
                  side: BorderSide(color: const Color(0xFFFFAA00).withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => ElevatedButton.icon(
                onPressed: controller.isCapturing.value ? null : controller.identify,
                icon: controller.isCapturing.value
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF41)))
                    : const Icon(PhosphorIconsRegular.user),
                label: Text(controller.isCapturing.value ? 'Scanning...' : 'Identify'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF41).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF00FF41),
                  side: BorderSide(color: const Color(0xFF00FF41).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResults() {
    return Obx(() {
      if (controller.testResults.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('EXTRACTION RESULTS',
            style: TextStyle(color: Color(0xFF00FF41), fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 2)),
          const SizedBox(height: 8),
          ...controller.testResults.map((r) => _buildResultCard(r)),
        ],
      );
    });
  }

  List<int> _toIntList(dynamic v) {
    if (v is Uint8List) return v.toList();
    if (v is List<int>) return v;
    if (v is List<dynamic>) return v.cast<int>();
    return <int>[];
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final method = r['method'] as String;
    final result = r['result'] as int;
    final rawLen = r['rawLen'] as int;
    final trimmedLen = r['trimmedLen'] as int;
    final firstBytes = _toIntList(r['firstBytes']);
    final hexPreview = firstBytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

    return Card(
      color: const Color(0xFF1A2226),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(method,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _resultColor(result).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _resultColor(result).withValues(alpha: 0.4)),
                  ),
                  child: Text(_resultCode(result),
                    style: TextStyle(color: _resultColor(result), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('rawLen=$rawLen  trimmedLen=$trimmedLen',
              style: const TextStyle(color: Color(0xFF8C9BA3), fontFamily: 'monospace', fontSize: 11)),
            if (trimmedLen > 0) ...[
              const SizedBox(height: 4),
              Text('hex: $hexPreview',
                style: const TextStyle(color: Color(0xFF8C9BA3), fontFamily: 'monospace', fontSize: 10)),
            ],
            if (trimmedLen > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => controller.saveTemplateFromResult(controller.testResults.indexOf(r)),
                  child: const Text('SHOW FULL DATA',
                    style: TextStyle(color: Color(0xFF00FF41), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLog() {
    return Obx(() {
      if (controller.logs.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('LOG',
                style: TextStyle(color: Color(0xFF00FF41), fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 2)),
              const Spacer(),
              Text('${controller.logs.length} lines',
                style: const TextStyle(color: Color(0xFF8C9BA3), fontFamily: 'monospace', fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C3A3F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.logs.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(line,
                  style: const TextStyle(color: Color(0xFF8C9BA3), fontFamily: 'monospace', fontSize: 10)),
              )).toList(),
            ),
          ),
        ],
      );
    });
  }
}
