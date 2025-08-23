import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/inventory_provider.dart';
import '../providers/sales_provider.dart';
import '../models/product.dart';
import 'barcode_product_dialog.dart';

enum ScannerMode {
  normal, // Default mode for sales/finding products
  receiveStock, // Mode for receiving/adding stock
  removeStock, // Mode for removing stock
}

class BarcodeScannerWidget extends StatefulWidget {
  final ScannerMode mode;

  const BarcodeScannerWidget({super.key, this.mode = ScannerMode.normal});

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  MobileScannerController cameraController = MobileScannerController(
    autoStart: false,
  );
  bool _isProcessing = false;
  bool _hasPermission = false;
  bool _isInitializing = true;
  String? _errorMessage;

  // Track torch and camera state manually
  bool _isTorchOn = false;
  bool _isBackCamera = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        if (result.isDenied) {
          setState(() {
            _errorMessage = 'Camera permission is required to scan barcodes';
            _isInitializing = false;
          });
          return;
        }
      }

      if (status.isPermanentlyDenied) {
        setState(() {
          _errorMessage =
              'Camera permission is permanently denied. Please enable it in settings.';
          _isInitializing = false;
        });
        return;
      }

      setState(() {
        _hasPermission = true;
        _isInitializing = false;
      });

      await cameraController.start();
    } catch (e, s) {
      ErrorLogger.logError(
        'Failed to initialize camera',
        error: e,
        stackTrace: s,
      );
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasPermission && !_isInitializing) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  _isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: _isTorchOn ? Colors.amber : Colors.white70,
                ),
                onPressed: () async {
                  try {
                    await cameraController.toggleTorch();
                    setState(() {
                      _isTorchOn = !_isTorchOn;
                    });
                  } catch (e, s) {
                    ErrorLogger.logError(
                      'Torch toggle error',
                      error: e,
                      stackTrace: s,
                    );
                    // Handle error silently or show snackbar
                    print('Torch toggle error: $e');
                  }
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  _isBackCamera ? Icons.camera_rear : Icons.camera_front,
                  color: Colors.white70,
                ),
                onPressed: () async {
                  try {
                    await cameraController.switchCamera();
                    setState(() {
                      _isBackCamera = !_isBackCamera;
                    });
                  } catch (e, s) {
                    ErrorLogger.logError(
                      'Camera switch error',
                      error: e,
                      stackTrace: s,
                    );
                    // Handle error silently or show snackbar
                    print('Camera switch error: $e');
                  }
                },
              ),
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  String _getAppBarTitle() {
    switch (widget.mode) {
      case ScannerMode.receiveStock:
        return 'Receive Stock';
      case ScannerMode.removeStock:
        return 'Remove Stock';
      case ScannerMode.normal:
        return 'Scan Barcode';
    }
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (_errorMessage!.contains('permanently denied')) {
                    openAppSettings();
                  } else {
                    if (mounted) {
                      setState(() {
                        _errorMessage = null;
                        _isInitializing = true;
                      });
                    }
                    _initializeCamera();
                  }
                },
                child: Text(
                  _errorMessage!.contains('permanently denied')
                      ? 'Open Settings'
                      : 'Retry',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasPermission) {
      return const Center(
        child: Text(
          'Camera permission not granted',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        ClipRect(
          child: MobileScanner(
            controller: cameraController,
            onDetect: _onBarcodeDetected,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Error: ${error.errorDetails?.message ?? 'Unknown error'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _isInitializing = true;
                          });
                        }
                        _initializeCamera();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          decoration: ShapeDecoration(
            shape: ModernScannerOverlay(
              borderColor: _getBorderColor(),
              borderWidth: 3.0,
              overlayColor: Colors.black.withOpacity(0.3),
              borderRadius: 16,
              borderLength: 40,
              cutOutSize: 280,
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getBorderColor().withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getModeIcon(), color: _getBorderColor(), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      _getModeTitle(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getModeDescription(),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Processing barcode...',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _getBorderColor() {
    switch (widget.mode) {
      case ScannerMode.receiveStock:
        return Colors.green;
      case ScannerMode.removeStock:
        return Colors.red;
      case ScannerMode.normal:
        return Colors.blue;
    }
  }

  IconData _getModeIcon() {
    switch (widget.mode) {
      case ScannerMode.receiveStock:
        return Icons.add_box;
      case ScannerMode.removeStock:
        return Icons.remove_circle;
      case ScannerMode.normal:
        return Icons.qr_code_scanner;
    }
  }

  String _getModeTitle() {
    switch (widget.mode) {
      case ScannerMode.receiveStock:
        return 'Scan to Receive Stock';
      case ScannerMode.removeStock:
        return 'Scan to Remove Stock';
      case ScannerMode.normal:
        return 'Position barcode in the frame';
    }
  }

  String _getModeDescription() {
    switch (widget.mode) {
      case ScannerMode.receiveStock:
        return 'Scan products to add them to inventory';
      case ScannerMode.removeStock:
        return 'Scan products to remove from inventory';
      case ScannerMode.normal:
        return 'Camera will automatically scan when detected';
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _handleBarcodeScanned(barcode.rawValue!);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleBarcodeScanned(String barcodeValue) async {
    final inventoryProvider = Provider.of<InventoryProvider>(
      context,
      listen: false,
    );
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    print('BarcodeScannerWidget: Scanned barcodeValue: $barcodeValue');
    print('BarcodeScannerWidget: Products in inventory:');
    for (var p in inventoryProvider.products) {
      print('  - Product ID: ${p.id}, Barcode: ${p.barcode}, Name: ${p.name}');
    }

    final existingProduct = inventoryProvider.products
        .where((product) => product.barcode == barcodeValue)
        .firstOrNull;

    if (existingProduct != null) {
      switch (widget.mode) {
        case ScannerMode.receiveStock:
          await _handleReceiveStock(existingProduct);
          break;
        case ScannerMode.removeStock:
          await _handleRemoveStock(existingProduct);
          break;
        case ScannerMode.normal:
          await _handleExistingProduct(existingProduct, salesProvider);
          break;
      }
    } else {
      await _handleNewProduct(barcodeValue);
    }
  }

  Future<void> _handleReceiveStock(Product product) async {
    await cameraController.stop();
    if (!mounted) return;

    final quantity = await _showStockUpdateDialog(
      context: context,
      product: product,
      title: 'Receive Stock: ${product.name}',
      labelText: 'Quantity to Receive',
      buttonText: 'Receive',
      validation: (qty) => qty > 0,
    );

    if (quantity != null && quantity > 0) {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      await inventoryProvider.receiveStock(product.id!, quantity);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Received $quantity units of ${product.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await cameraController.start();
    }
  }

  Future<void> _handleRemoveStock(Product product) async {
    await cameraController.stop();
    if (!mounted) return;

    final quantity = await _showStockUpdateDialog(
      context: context,
      product: product,
      title: 'Remove Stock: ${product.name}',
      labelText: 'Quantity to Remove',
      buttonText: 'Remove',
      buttonColor: Colors.red,
      validation: (qty) => qty > 0 && qty <= product.stock,
    );

    if (quantity != null && quantity > 0) {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      final success = await inventoryProvider.reduceStock(
        product.id!,
        quantity,
        reason: 'Stock removed via barcode scanner',
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed $quantity units of ${product.name}'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Insufficient stock to remove'),
              backgroundColor: Colors.red,
            ),
          );
          await cameraController.start();
        }
      }
    } else {
      await cameraController.start();
    }
  }

  Future<int?> _showStockUpdateDialog({
    required BuildContext context,
    required Product product,
    required String title,
    required String labelText,
    required String buttonText,
    Color? buttonColor,
    required bool Function(int) validation,
  }) async {
    final quantityController = TextEditingController(text: '1');

    return await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock: ${product.stock}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: labelText,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text);
              if (qty != null && validation(qty)) {
                Navigator.pop(context, qty);
              }
            },
            style: buttonColor != null
                ? ElevatedButton.styleFrom(backgroundColor: buttonColor)
                : null,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExistingProduct(
    Product product,
    SalesProvider salesProvider,
  ) async {
    await cameraController.stop();

    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Product Found: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: ₱${product.price.toStringAsFixed(2)}'),
            Text('Stock: ${product.stock} available'),
            if (product.isLowStock)
              const Text(
                'Low Stock!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          if (product.stock > 0)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'add_to_cart'),
              child: const Text('Add to Cart'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'view_details'),
            child: const Text('View Details'),
          ),
        ],
      ),
    );

    if (action == 'add_to_cart' && product.stock > 0) {
      salesProvider.addItemToCurrentSale(product, 1);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added to cart'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (action == 'view_details') {
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      await cameraController.start();
    }
  }

  Future<void> _handleNewProduct(String barcodeValue) async {
    await cameraController.stop();

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BarcodeProductDialog(barcode: barcodeValue),
    );

    if (result == true) {
      if (mounted) {
        // Show success overlay before closing
        _showSuccessOverlay();

        // Close scanner after showing success
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        await cameraController.start();
      }
    }
  }

  void _showSuccessOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Product Added!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Successfully added to inventory',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-close the success overlay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    try {
      cameraController.dispose();
    } catch (e, s) {
      ErrorLogger.logError(
        'Error disposing camera controller',
        error: e,
        stackTrace: s,
      );
      // Handle disposal error silently
    }
    super.dispose();
  }
}

class ModernScannerOverlay extends ShapeBorder {
  const ModernScannerOverlay({
    this.borderColor = Colors.blue,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 30),
    this.borderRadius = 16,
    this.borderLength = 40,
    this.cutOutSize = 280,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + borderRadius,
          rect.top,
        )
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutWidth = cutOutSize < width ? cutOutSize : width - borderWidth;
    final cutOutHeight = cutOutSize < height
        ? cutOutSize
        : height - borderWidth;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutWidth) / 2 + borderWidth,
      rect.top + (height - cutOutHeight) / 2 + borderWidth,
      cutOutWidth - borderWidth * 2,
      cutOutHeight - borderWidth * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = borderColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * 2
      ..strokeCap = StrokeCap.round;

    final glowPath = Path()
      ..moveTo(cutOutRect.left - borderLength, cutOutRect.top)
      ..lineTo(cutOutRect.left, cutOutRect.top)
      ..lineTo(cutOutRect.left, cutOutRect.top + borderLength)
      ..moveTo(cutOutRect.right + borderLength, cutOutRect.top)
      ..lineTo(cutOutRect.right, cutOutRect.top)
      ..lineTo(cutOutRect.right, cutOutRect.top + borderLength)
      ..moveTo(cutOutRect.left - borderLength, cutOutRect.bottom)
      ..lineTo(cutOutRect.left, cutOutRect.bottom)
      ..lineTo(cutOutRect.left, cutOutRect.bottom - borderLength)
      ..moveTo(cutOutRect.right + borderLength, cutOutRect.bottom)
      ..lineTo(cutOutRect.right, cutOutRect.bottom)
      ..lineTo(cutOutRect.right, cutOutRect.bottom - borderLength);

    canvas.drawPath(glowPath, glowPaint);

    final borderPath = Path()
      ..moveTo(cutOutRect.left - borderLength, cutOutRect.top)
      ..lineTo(cutOutRect.left, cutOutRect.top)
      ..lineTo(cutOutRect.left, cutOutRect.top + borderLength)
      ..moveTo(cutOutRect.right + borderLength, cutOutRect.top)
      ..lineTo(cutOutRect.right, cutOutRect.top)
      ..lineTo(cutOutRect.right, cutOutRect.top + borderLength)
      ..moveTo(cutOutRect.left - borderLength, cutOutRect.bottom)
      ..lineTo(cutOutRect.left, cutOutRect.bottom)
      ..lineTo(cutOutRect.left, cutOutRect.bottom - borderLength)
      ..moveTo(cutOutRect.right + borderLength, cutOutRect.bottom)
      ..lineTo(cutOutRect.right, cutOutRect.bottom)
      ..lineTo(cutOutRect.right, cutOutRect.bottom - borderLength);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return ModernScannerOverlay(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
      borderRadius: borderRadius,
      borderLength: borderLength,
      cutOutSize: cutOutSize,
    );
  }
}
