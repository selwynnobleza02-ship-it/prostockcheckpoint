import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/bluetooth_device.dart';
import 'package:prostock/services/printing_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late PrintingService _printingService;
  List<BluetoothDevice> _devices = [];
  bool _isLoading = false;
  bool _isConnecting = false;
  String? _defaultPrinterAddress;

  @override
  void initState() {
    super.initState();
    _printingService = Provider.of<PrintingService>(context, listen: false);
    _printingService.loadPaperSize();
    _loadDefaultPrinterAndScan();
  }

  Future<void> _loadDefaultPrinterAndScan() async {
    _defaultPrinterAddress = await _printingService.loadDefaultPrinter();
    if (mounted && _defaultPrinterAddress != null) {
      setState(() {});
      // Non-blocking call to attempt auto-reconnect
      _attemptAutoReconnect();
    }
    // Initial scan is now non-blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scanForPrinters();
      }
    });
  }

  Future<void> _attemptAutoReconnect() async {
    if (_defaultPrinterAddress == null || _printingService.isConnected) return;

    await _scanForPrinters();

    BluetoothDevice? defaultDevice;

    for (final device in _devices) {
      if (device.address == _defaultPrinterAddress) {
        defaultDevice = device;
        break;
      }
    }

    if (defaultDevice != null) {
      await _selectPrinter(defaultDevice, showMessages: false);
    }
  }

  Future<void> _scanForPrinters() async {
    if (await _requestPermissions()) {
      setState(() => _isLoading = true);
      try {
        final devices = await _printingService.getBluetooths();
        if (kDebugMode) {
          print('Raw devices found: $devices');
        }
        setState(() {
          _devices = devices;
        });
      } catch (e) {
        if (kDebugMode) {
          print('Error scanning for printers: $e');
        }
        if (!mounted) return;
        _showSnackBar('Error scanning for printers: $e', isError: true);
      }
      setState(() => _isLoading = false);
    } else {
      _showSnackBar('Bluetooth permissions are required to scan for printers.',
          isError: true);
    }
  }

  Future<bool> _requestPermissions() async {
    var status = await Permission.bluetoothScan.status;
    if (status.isDenied) {
      await Permission.bluetoothScan.request();
    }
    status = await Permission.bluetoothConnect.status;
    if (status.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    return await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted;
  }

  Future<void> _selectPrinter(
    BluetoothDevice device, {
    bool showMessages = true,
  }) async {
    if (_isConnecting) return;

    setState(() => _isConnecting = true);

    try {
      final bool connected = await _printingService.connect(device);
      if (connected && showMessages) {
        _showSnackBar('Connected to ${device.name}');
      } else if (!connected && showMessages) {
        _showSnackBar('Failed to connect to ${device.name}', isError: true);
      }
    } catch (e) {
      if (showMessages) {
        _showSnackBar('Error connecting: $e', isError: true);
      }
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrintingService>(
      builder: (context, printingService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Printer Settings'),
            actions: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _scanForPrinters,
                  tooltip: 'Scan for Printers',
                ),
            ],
          ),
          body: Column(
            children: [
              _buildConnectedDeviceSection(printingService),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Available Devices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.bluetooth_searching,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text('No devices found.'),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _scanForPrinters,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Scan for Printers'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isConnected =
                              printingService.connectedDeviceAddress ==
                              device.address;
                          final isDefault =
                              _defaultPrinterAddress == device.address;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.bluetooth,
                                color: isConnected ? Colors.green : null,
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(device.name)),
                                  if (isDefault)
                                    const Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                device.address.isEmpty
                                    ? 'No Address'
                                    : device.address,
                              ),
                              onTap: _isConnecting
                                  ? null
                                  : () => _selectPrinter(device),
                              trailing:
                                  _isConnecting &&
                                      device.address ==
                                          printingService.connectedDeviceAddress
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(),
                                    )
                                  : isConnected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectedDeviceSection(PrintingService printingService) {
    final isConnected = printingService.isConnected;
    final address = printingService.connectedDeviceAddress;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (isConnected && address != null) ...[
            Card(
              elevation: 2,
              color: Colors.green.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bluetooth_connected,
                          color: Colors.green,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                printingService.connectedDeviceName ??
                                    'Connected Printer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                address,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Connected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: printingService.printTest,
                          icon: const Icon(Icons.print),
                          label: const Text('Test Print'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: printingService.disconnect,
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: const Text('Disconnect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              elevation: 2,
              color: Colors.grey.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      color: Colors.grey[600],
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No printer connected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan for devices and tap to connect',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Paper Size:'),
              const SizedBox(width: 16),
              DropdownButton<PaperSize>(
                value: printingService.paperSize,
                items: const [
                  DropdownMenuItem(value: PaperSize.mm58, child: Text('58 mm')),
                  DropdownMenuItem(value: PaperSize.mm80, child: Text('80 mm')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    printingService.savePaperSize(value);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
