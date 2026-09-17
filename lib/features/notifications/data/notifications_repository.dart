import 'dart:io';

import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/notifications/domain/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppNotification>> list() async {
    final response = await _apiClient.raw.get<Map<String, dynamic>>(
      '/api/v1/notifications',
    );
    final rows = response.data?['data'] as List<dynamic>? ?? const [];
    return rows
        .map(
          (row) =>
              AppNotification.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> markRead(String id) async {
    await _apiClient.raw.patch<void>('/api/v1/notifications/$id/read');
  }

  Future<void> registerDevice(String token) async {
    await _apiClient.raw.post<void>(
      '/api/v1/notifications/devices',
      data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
    );
  }

  Future<void> unregisterDevice(String token) async {
    await _apiClient.raw.delete<void>(
      '/api/v1/notifications/devices',
      data: {'token': token},
    );
  }
}
