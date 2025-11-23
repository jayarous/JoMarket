import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'delivery_models.dart';
import 'delivery_service.dart';

/// Barcode scanner screen for delivery operations
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({
    required this.shipmentId,
    required this.staffId,
    required this.scanType,
    required this.service,
    super.key,
  });

  final String shipmentId;
  final String staffId;
  final String scanType; // pickup, delivery, return
  final DeliveryService service;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      // Get current location if possible
      double? latitude;
      double? longitude;

      final BarcodeScan scan = await widget.service.recordBarcodeScan(
        shipmentId: widget.shipmentId,
        staffId: widget.staffId,
        barcodeValue: barcode.rawValue!,
        scanType: widget.scanType,
        latitude: latitude,
        longitude: longitude,
      );

      setState(() {
        _error = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode scanned: ${barcode.rawValue}'),
            backgroundColor: Colors.green,
          ),
        );

        // Wait a moment then return with success
        await Future<void>.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop(scan);
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan ${widget.scanType.toUpperCase()}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller?.toggleTorch(),
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller?.switchCamera(),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_controller != null)
            MobileScanner(controller: _controller, onDetect: _handleBarcode)
          else
            const Center(child: CircularProgressIndicator()),
          // Overlay with scan frame
          CustomPaint(painter: _ScanOverlayPainter(), child: Container()),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Position barcode within frame',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scanning for ${widget.scanType}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Processing scan...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Error display
          if (_error != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Manual barcode entry screen (fallback)
class ManualBarcodeEntryScreen extends StatefulWidget {
  const ManualBarcodeEntryScreen({
    required this.shipmentId,
    required this.staffId,
    required this.scanType,
    required this.service,
    super.key,
  });

  final String shipmentId;
  final String staffId;
  final String scanType;
  final DeliveryService service;

  @override
  State<ManualBarcodeEntryScreen> createState() =>
      _ManualBarcodeEntryScreenState();
}

class _ManualBarcodeEntryScreenState extends State<ManualBarcodeEntryScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final BarcodeScan scan = await widget.service.recordBarcodeScan(
        shipmentId: widget.shipmentId,
        staffId: widget.staffId,
        barcodeValue: _controller.text.trim(),
        scanType: widget.scanType,
      );

      if (mounted) {
        Navigator.of(context).pop(scan);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record barcode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Barcode Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter Barcode for ${widget.scanType.toUpperCase()}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Barcode Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a barcode';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for scan overlay
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final framePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // Calculate scan frame
    final frameWidth = size.width * 0.7;
    final frameHeight = frameWidth * 0.6;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    final scanRect = Rect.fromLTWH(left, top, frameWidth, frameHeight);

    // Draw overlay (everything except scan frame)
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRect(scanRect)
        ..fillType = PathFillType.evenOdd,
      paint,
    );

    // Draw frame border
    canvas.drawRect(scanRect, framePaint);

    // Draw corner brackets
    const cornerLength = 30.0;
    final corners = [
      // Top-left
      [
        Offset(left, top),
        Offset(left + cornerLength, top),
        Offset(left, top),
        Offset(left, top + cornerLength),
      ],
      // Top-right
      [
        Offset(left + frameWidth, top),
        Offset(left + frameWidth - cornerLength, top),
        Offset(left + frameWidth, top),
        Offset(left + frameWidth, top + cornerLength),
      ],
      // Bottom-left
      [
        Offset(left, top + frameHeight),
        Offset(left + cornerLength, top + frameHeight),
        Offset(left, top + frameHeight),
        Offset(left, top + frameHeight - cornerLength),
      ],
      // Bottom-right
      [
        Offset(left + frameWidth, top + frameHeight),
        Offset(left + frameWidth - cornerLength, top + frameHeight),
        Offset(left + frameWidth, top + frameHeight),
        Offset(left + frameWidth, top + frameHeight - cornerLength),
      ],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
      canvas.drawLine(corner[2], corner[3], cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
