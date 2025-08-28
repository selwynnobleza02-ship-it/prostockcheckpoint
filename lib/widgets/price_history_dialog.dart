import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prostock/models/price_history.dart';
import 'package:prostock/services/firestore_service.dart';

class PriceHistoryDialog extends StatefulWidget {
  final String productId;

  const PriceHistoryDialog({super.key, required this.productId});

  @override
  PriceHistoryDialogState createState() => PriceHistoryDialogState();
}

class PriceHistoryDialogState extends State<PriceHistoryDialog> {
  late Future<List<PriceHistory>> _priceHistoryFuture;

  @override
  void initState() {
    super.initState();
    _priceHistoryFuture = FirestoreService.instance.getPriceHistory(
      widget.productId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Price History'),
      content: FutureBuilder<List<PriceHistory>>(
        future: _priceHistoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading price history.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No price history found.'));
          }

          final priceHistory = snapshot.data!;

          return SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: priceHistory.length,
              itemBuilder: (context, index) {
                final history = priceHistory[index];
                return ListTile(
                  title: Text(
                    'Price: ₱${history.price.toStringAsFixed(2)}', // Using Peso symbol
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    DateFormat.yMMMd().add_jm().format(history.timestamp),
                  ),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
