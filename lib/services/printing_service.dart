import 'package:bluetooth_thermal_printer_plus/bluetooth_thermal_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:prostock/models/receipt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrintingService with ChangeNotifier {
  static final PrintingService _instance = PrintingService._internal();
  factory PrintingService() => _instance;
  PrintingService._internal();

  bool _isConnected = false;
  String? _connectedDeviceAddress;

  bool get isConnected => _isConnected;
  String? get connectedDeviceAddress => _connectedDeviceAddress;

  Future<List<dynamic>> getBluetooths() async {
    try {
      return await BluetoothThermalPrinter.getBluetooths ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting bluetooth devices: $e');
      }
      return [];
    }
  }

  Future<bool> connect(dynamic device) async {
    if (device['address'] == null) return false;
    try {
      final result = await BluetoothThermalPrinter.connect(device['address']!);
      if (result == 'true') {
        _isConnected = true;
        _connectedDeviceAddress = device['address'];
        await saveDefaultPrinter(device['address']!);
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to printer: $e');
      }
    }
    return false;
  }

  Future<void> disconnect() async {
    BluetoothThermalPrinter.disconnect;
    _isConnected = false;
    _connectedDeviceAddress = null;
    notifyListeners();
  }

  Future<void> saveDefaultPrinter(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_printer_address', address);
  }

  Future<String?> loadDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_printer_address');
  }

  Future<void> printTest() async {
    if (!_isConnected) return;
    final List<int> bytes = await _generateTestTicket();
    await BluetoothThermalPrinter.writeBytes(bytes);
  }

  Future<void> printReceipt(Receipt receipt) async {
    if (!_isConnected) return;
    final List<int> bytes = await _generateReceiptTicket(receipt);
    await BluetoothThermalPrinter.writeBytes(bytes);
  }

  Future<List<int>> _generateTestTicket() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text(
      'Test Print',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text('Connection Successful!');
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> _generateReceiptTicket(Receipt receipt) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text(
      'ProStock POS',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.hr();
    bytes += generator.text(
      'Receipt: ${receipt.receiptNumber}',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Date: ${receipt.formattedTimestamp}',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    for (final item in receipt.items) {
      bytes += generator.row([
        PosColumn(text: item.productName, width: 6),
        PosColumn(
          text: 'x${item.quantity}',
          width: 1,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: item.totalPrice.toStringAsFixed(2),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: receipt.total.toStringAsFixed(2),
        width: 6,
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.right,
        ),
      ),
    ]);
    bytes += generator.hr(ch: '=');

    bytes += generator.feed(2);
    bytes += generator.text(
      'Thank you!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }
}
