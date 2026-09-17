import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera-based QR scan with manual token entry fallback (emulator / denied cam).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final _manualController = TextEditingController();
  StreamSubscription<Object?>? _subscription;
  var _handling = false;
  var _showManualEntry = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );
    WidgetsBinding.instance.addObserver(this);

    // Skip starting the camera in widget tests / unsupported hosts.
    if (!_isCameraHost) {
      _showManualEntry = true;
      return;
    }

    _subscription = _controller.barcodes.listen(_onBarcode);
    unawaited(_startScanner());
  }

  bool get _isCameraHost {
    // Widget tests use a TestWidgetsFlutterBinding — skip camera there.
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('TestWidgetsFlutterBinding')) {
      return false;
    }
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _startScanner() async {
    try {
      await _controller.start();
    } catch (_) {
      if (mounted) {
        setState(() => _showManualEntry = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraHost || !_controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _subscription ??= _controller.barcodes.listen(_onBarcode);
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(_controller.stop());
    }
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_handling) {
      return;
    }
    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) {
      return;
    }
    await _openCopy(raw);
  }

  Future<void> _openCopy(String token) async {
    if (_handling || !mounted) {
      return;
    }
    setState(() => _handling = true);
    await HapticFeedback.mediumImpact();
    if (_isCameraHost) {
      unawaited(_controller.stop());
    }

    if (!mounted) {
      return;
    }
    final location = Uri(
      path: '/scan/copy',
      queryParameters: {'token': token.trim()},
    ).toString();
    await context.push(location);

    if (!mounted) {
      return;
    }
    setState(() => _handling = false);
    if (_isCameraHost && !_showManualEntry) {
      unawaited(_controller.start());
    }
  }

  Future<void> _submitManual() async {
    final token = _manualController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a QR token to look up a copy.')),
      );
      return;
    }
    await _openCopy(token);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    _manualController.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          IconButton(
            tooltip: _showManualEntry ? 'Show camera' : 'Enter token',
            onPressed: () {
              setState(() => _showManualEntry = !_showManualEntry);
            },
            icon: Icon(
              _showManualEntry ? Icons.qr_code_scanner : Icons.keyboard,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _showManualEntry || !_isCameraHost
                ? _ManualEntryPane(
                    controller: _manualController,
                    onSubmit: _submitManual,
                    busy: _handling,
                  )
                : _CameraPane(controller: _controller, handling: _handling),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Text(
                _showManualEntry
                    ? 'Paste an opaque QR token from a printed label to identify the copy.'
                    : 'Point the camera at a book QR code. Lookup uses your library account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPane extends StatelessWidget {
  const _CameraPane({required this.controller, required this.handling});

  final MobileScannerController controller;
  final bool handling;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          fit: BoxFit.cover,
          errorBuilder: (context, error) {
            return _ScannerMessage(
              icon: Icons.videocam_off_outlined,
              title: 'Camera unavailable',
              body:
                  error.errorDetails?.message ??
                  'Allow camera access or enter a token manually.',
            );
          },
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _ScanFramePainter(
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
          ),
        ),
        if (handling)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ManualEntryPane extends StatelessWidget {
  const _ManualEntryPane({
    required this.controller,
    required this.onSubmit,
    required this.busy,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Icon(
            Icons.qr_code_2,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 16),
          Text(
            'Look up by token',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Use this when the camera is unavailable (simulators) or you have a printed token.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            enabled: !busy,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'QR token',
              hintText: 'Opaque token from the label',
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : onSubmit,
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Look up copy'),
          ),
        ],
      ),
    );
  }
}

class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.muted,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.mutedForeground),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.shortestSide * 0.65,
      height: size.shortestSide * 0.65,
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 28.0;
    // Top-left
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(0, corner),
      paint,
    );
    // Top-right
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(-corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(0, corner),
      paint,
    );
    // Bottom-left
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -corner),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
