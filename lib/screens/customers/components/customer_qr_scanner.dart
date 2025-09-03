import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prostock/utils/error_logger.dart';

class CustomerQRScanner extends StatefulWidget {
  const CustomerQRScanner({super.key});

  @override
  State<CustomerQRScanner> createState() => _CustomerQRScannerState();
}

class _CustomerQRScannerState extends State<CustomerQRScanner> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
      log('Scanned QR code with value: \${barcode.rawValue}');
      Navigator.of(context).pop(barcode.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Customer QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: FutureBuilder<PermissionStatus>(
        future: Permission.camera.request(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!.isGranted) {
              return MobileScanner(
                controller: _cameraController,
                onDetect: _onBarcodeDetected,
                errorBuilder: (context, error) {
                  ErrorLogger.logError('Error with QR scanner', error: error);
                  return Center(child: Text('An error occurred: $error'));
                },
              );
            } else {
              return const Center(
                child: Text('Camera permission is required to scan QR codes.'),
              );
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
