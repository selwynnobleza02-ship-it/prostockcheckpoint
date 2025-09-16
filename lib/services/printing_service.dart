import 'package:bluetooth_thermal_printer_plus/bluetooth_thermal_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:prostock/models/bluetooth_device.dart';
import 'package:prostock/models/receipt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrintingService with ChangeNotifier {
  static final PrintingService _instance = PrintingService._internal();
  factory PrintingService() => _instance;
  PrintingService._internal();

  bool _isConnected = false;
  String? _connectedDeviceAddress;
  String? _connectedDeviceName;
  PaperSize _paperSize = PaperSize.mm80;

  bool get isConnected => _isConnected;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  String? get connectedDeviceName => _connectedDeviceName;
  PaperSize get paperSize => _paperSize;

  Future<void> loadPaperSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paperSizeName = prefs.getString('paper_size');

      if (paperSizeName == 'mm58') {
        _paperSize = PaperSize.mm58;
      } else {
        _paperSize = PaperSize.mm80; // default
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading paper size: $e');
      }
    }
    notifyListeners();
  }

  Future<void> savePaperSize(PaperSize paperSize) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String paperSizeName;
      if (paperSize == PaperSize.mm58) {
        paperSizeName = 'mm58';
      } else {
        paperSizeName = 'mm80';
      }

      await prefs.setString('paper_size', paperSizeName);
      _paperSize = paperSize;

      if (kDebugMode) {
        print('Saved paper size: $paperSizeName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving paper size: $e');
      }
    }
    notifyListeners();
  }

  Future<List<BluetoothDevice>> getBluetooths() async {
    try {
      final devices = await BluetoothThermalPrinter.getBluetooths ?? [];
      return devices.map((device) {
        String name = 'Unknown Device';
        String address = '';
        if (device is String && device.contains('#')) {
          final parts = device.split('#');
          if (parts.length == 2) {
            name = parts[0];
            address = parts[1];
          }
        } else if (device is Map) {
          name = device['name'] ?? 'Unknown Device';
          address = device['address'] ?? '';
        }
        return BluetoothDevice(name: name, address: address);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting bluetooth devices: $e');
      }
      rethrow; // Re-throw to allow UI to handle the error
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (kDebugMode) {
      print('Connect called with device: ${device.name}');
    }

    if (device.address.isEmpty) {
      if (kDebugMode) {
        print('Device address is null or empty for device: ${device.name}');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        print('Attempting to connect to: ${device.name} (${device.address})');
      }

      final result = await BluetoothThermalPrinter.connect(device.address);
      if (kDebugMode) {
        print('Connection result: $result');
      }

      if (result == 'true') {
        _isConnected = true;
        _connectedDeviceAddress = device.address;
        _connectedDeviceName = device.name;
        await saveDefaultPrinter(device.address);
        notifyListeners();

        if (kDebugMode) {
          print('Successfully connected to ${device.name}');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Connection failed with result: $result');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to printer: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      // Reset connection state on error
      _isConnected = false;
      _connectedDeviceAddress = null;
      _connectedDeviceName = null;
      notifyListeners();
    }
    return false;
  }

  Future<void> disconnect() async {
    try {
      await BluetoothThermalPrinter.disconnect(); // Fixed: Added parentheses
      if (kDebugMode) {
        print('Disconnected from printer');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting: $e');
      }
    } finally {
      // Always reset the connection state
      _isConnected = false;
      _connectedDeviceAddress = null;
      _connectedDeviceName = null;
      notifyListeners();
    }
  }

  Future<void> saveDefaultPrinter(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('default_printer_address', address);
      if (kDebugMode) {
        print('Saved default printer: $address');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving default printer: $e');
      }
    }
  }

  Future<String?> loadDefaultPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('default_printer_address');
      if (kDebugMode) {
        print('Loaded default printer: $address');
      }
      return address;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading default printer: $e');
      }
      return null;
    }
  }

  Future<bool> printTest() async {
    if (!_isConnected) {
      if (kDebugMode) {
        print('Cannot print: No printer connected');
      }
      return false;
    }

    try {
      final List<int> bytes = await _generateTestTicket();
      await BluetoothThermalPrinter.writeBytes(bytes);
      if (kDebugMode) {
        print('Test print sent successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error printing test: $e');
      }
      return false;
    }
  }

  Future<bool> printReceipt(
    Receipt receipt, {
    double? cashTendered,
    double? change,
  }) async {
    if (!_isConnected) {
      if (kDebugMode) {
        print('Cannot print receipt: No printer connected');
      }
      return false;
    }

    try {
      final List<int> bytes = await _generateReceiptTicket(
        receipt,
        cashTendered: cashTendered,
        change: change,
      );
      await BluetoothThermalPrinter.writeBytes(bytes);
      if (kDebugMode) {
        print('Receipt printed successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error printing receipt: $e');
      }
      return false;
    }
  }

  Future<List<int>> _generateTestTicket() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];

    bytes += generator.text(
      'ProStock POS',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      'Test Print',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      'Connection Successful!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      'Printer: $_connectedDeviceName',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Address: $_connectedDeviceAddress',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      DateTime.now().toString(),
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> _generateReceiptTicket(
    Receipt receipt, {
    double? cashTendered,
    double? change,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.text(
      'RETAIL CREDIT MANAGER',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      'Receipt: ${receipt.formattedReceiptNumber}',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      receipt.formattedTimestamp,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    // Customer and Payment Info - Single line format for 58mm
    bytes += generator.text(
      'Customer: ${receipt.customerName ?? 'Walk-in Customer'}',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += generator.text(
      'Payment: ${receipt.paymentMethod.toUpperCase()}',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += generator.hr();

    // Items - Simplified format for 58mm
    bytes += generator.text(
      'ITEMS',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.hr(ch: '-');

    // Each item on multiple lines for better readability on 58mm
    for (final item in receipt.items) {
      // Product name
      bytes += generator.text(
        item.productName,
        styles: const PosStyles(bold: true),
      );

      // Quantity, price, and total on one line
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity} x PHP${item.unitPrice.toStringAsFixed(2)}',
          width: 8,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: 'PHP${item.totalPrice.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.feed(1);
    }

    bytes += generator.hr();

    // Totals - Right aligned for 58mm
    bytes += generator.row([
      PosColumn(
        text: 'Subtotal',
        width: 8,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: 'PHP${receipt.subtotal.toStringAsFixed(2)}',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 8,
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        text: 'PHP${receipt.total.toStringAsFixed(2)}',
        width: 4,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    // Cash and change information
    if (cashTendered != null && cashTendered > 0) {
      bytes += generator.row([
        PosColumn(
          text: 'Cash Tendered',
          width: 8,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: 'PHP${cashTendered.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (change != null && change > 0) {
      bytes += generator.row([
        PosColumn(
          text: 'Change',
          width: 8,
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'PHP${change.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
    }

    bytes += generator.hr(ch: '=');

    // Footer
    bytes += generator.feed(1);
    bytes += generator.text(
      'Thank you for your business!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}
