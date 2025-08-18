
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/connectivity_provider.dart';

class ConnectivityStatus extends StatelessWidget {
  const ConnectivityStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);

    return Container(
      width: double.infinity,
      color: connectivityProvider.isOnline ? Colors.green : Colors.red,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        connectivityProvider.isOnline ? 'Online' : 'Offline',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
