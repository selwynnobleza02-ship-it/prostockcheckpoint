import 'package:flutter/material.dart';
import 'package:prostock/utils/currency_utils.dart';

class LossBreakdownList extends StatelessWidget {
  final Map<String, double> lossBreakdown;

  const LossBreakdownList({super.key, required this.lossBreakdown});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Loss Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lossBreakdown.keys.length,
          itemBuilder: (context, index) {
            final reason = lossBreakdown.keys.elementAt(index);
            final totalLoss = lossBreakdown[reason]!;
            return ListTile(
              title: Text(reason),
              trailing: Text(
                CurrencyUtils.formatCurrency(totalLoss),
                style: const TextStyle(color: Colors.red),
              ),
            );
          },
        ),
      ],
    );
  }
}
