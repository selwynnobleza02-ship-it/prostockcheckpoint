import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/demand_provider.dart';
import 'package:prostock/services/demand_analysis_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/notification_service.dart';

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
      appBar: AppBar(
        title: const Text('High Demand Suggestions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('🔄 Manual refresh triggered');
              context.read<DemandProvider>().refresh();
            },
          ),
        ],
      ),
      body: Consumer<DemandProvider>(
        builder: (context, dp, _) {
          if (dp.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (dp.suggestions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No suggestions at the moment'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      print('🧪 Manual demand analysis test...');
                      // Create a test demand analysis service
                      final demandService = DemandAnalysisService(
                        LocalDatabaseService.instance,
                        NotificationService(),
                      );
                      final suggestions = await demandService
                          .computeSuggestions();
                      print('🧪 Test found ${suggestions.length} suggestions');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Test found ${suggestions.length} suggestions. Check console for details.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Test Demand Analysis'),
                  ),
                ],
              ),
            );
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
