import 'package:flutter/foundation.dart';
import 'package:prostock/services/demand_analysis_service.dart';

class DemandProvider extends ChangeNotifier {
  final DemandAnalysisService _service;
  bool _loading = false;
  List<DemandSuggestion> _suggestions = [];

  DemandProvider(this._service);

  bool get isLoading => _loading;
  List<DemandSuggestion> get suggestions => _suggestions;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _suggestions = await _service.computeSuggestions();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> snooze(String productId) async {
    await _service.snooze(productId);
    await refresh();
  }

  Future<void> accept(String productId, int threshold) async {
    await _service.acceptSuggestion(productId, threshold);
    await refresh();
  }
}
