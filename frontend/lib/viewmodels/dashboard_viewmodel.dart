import 'package:flutter/material.dart';
import '../models/dashboard_metrics_model.dart';
import '../repositories/dashboard_repository.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardRepository _dashboardRepository;

  DashboardMetricsModel? _metrics;
  bool _isLoading = false;
  String? _errorMessage;

  DashboardViewModel(this._dashboardRepository);

  DashboardMetricsModel? get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMetrics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _metrics = await _dashboardRepository.getMetrics();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
