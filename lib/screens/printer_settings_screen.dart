import 'package:flutter/material.dart';
import 'package:prostock/services/printing_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrintingService _printingService = PrintingService();
  List<dynamic> _devices = [];
  bool _isLoading = false;
  String? _defaultPrinterAddress;

  @override
  void initState() {
    super.initState();
    _printingService.addListener(_updateState);
    _loadDefaultPrinterAndScan();
  }

  @override
  void dispose() {
    _printingService.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadDefaultPrinterAndScan() async {
    _defaultPrinterAddress = await _printingService.loadDefaultPrinter();
    if (_defaultPrinterAddress != null) {
      // Auto-connect logic can be tricky, for now just load the address
      // and let the user tap to connect.
      setState(() {});
    }
    _scanForPrinters();
  }

  Future<void> _scanForPrinters() async {
    setState(() => _isLoading = true);
    try {
      final devices = await _printingService.getBluetooths();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning for printers: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _selectPrinter(dynamic device) async {
    final bool connected = await _printingService.connect(device);
    if (connected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connected to ${device.name}')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${device.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          _buildConnectedDeviceSection(),
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
                ? const Center(
                    child: Text('No devices found. Tap scan to search.'),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.address ?? 'No Address'),
                        onTap: () => _selectPrinter(device),
                        trailing:
                            _printingService.connectedDeviceAddress ==
                                device.address
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceSection() {
    final isConnected = _printingService.isConnected;
    final address = _printingService.connectedDeviceAddress;
    final deviceName = _devices.firstWhere(
      (d) => d['address'] == address,
      orElse: () => {'name': 'Connected Printer'},
    )['name'];

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
          if (isConnected && address != null)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bluetooth_connected,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                address,
                                style: const TextStyle(color: Colors.grey),
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
                        TextButton(
                          onPressed: _printingService.printTest,
                          child: const Text('Test Print'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _printingService.disconnect,
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            const Text('No printer connected.'),
        ],
      ),
    );
  }
}
