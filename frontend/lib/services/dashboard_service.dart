import '../core/constants/api_constants.dart';
import '../models/dashboard_metrics_model.dart';
import 'api_client.dart';

class DashboardService {
  final ApiClient _apiClient;

  DashboardService(this._apiClient);

  Future<DashboardMetricsModel> getMetrics() async {
    final response = await _apiClient.get(ApiConstants.dashboardMetrics);
    return DashboardMetricsModel.fromJson(response as Map<String, dynamic>);
  }
}
