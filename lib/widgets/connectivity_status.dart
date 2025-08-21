
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/services/offline_manager.dart';

class ConnectivityStatus extends StatelessWidget {
  const ConnectivityStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final offlineManager = Provider.of<OfflineManager>(context);

    return Container(
      width: double.infinity,
      color: offlineManager.isOnline ? Colors.green : Colors.red,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        offlineManager.isOnline ? 'Online' : 'Offline',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
