import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/demand_provider.dart';

class DemandSuggestionsScreen extends StatefulWidget {
  const DemandSuggestionsScreen({super.key});

  @override
  State<DemandSuggestionsScreen> createState() =>
      _DemandSuggestionsScreenState();
}

class _DemandSuggestionsScreenState extends State<DemandSuggestionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DemandProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('High Demand Suggestions')),
      body: Consumer<DemandProvider>(
        builder: (context, dp, _) {
          if (dp.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (dp.suggestions.isEmpty) {
            return const Center(child: Text('No suggestions at the moment'));
          }
          return ListView.separated(
            itemCount: dp.suggestions.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final s = dp.suggestions[index];
              return ListTile(
                title: Text(s.product.name),
                subtitle: Text(
                  'Velocity: ${s.velocityPerDay.toStringAsFixed(1)}/day\nMin-stock: ${s.currentThreshold} → ${s.suggestedThreshold}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.snooze),
                      tooltip: 'Snooze 7 days',
                      onPressed: () async {
                        if (s.product.id != null) {
                          await context.read<DemandProvider>().snooze(
                            s.product.id!,
                          );
                        }
                      },
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (s.product.id != null) {
                          await context.read<DemandProvider>().accept(
                            s.product.id!,
                            s.suggestedThreshold,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Updated ${s.product.name} threshold to ${s.suggestedThreshold}',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Update'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
