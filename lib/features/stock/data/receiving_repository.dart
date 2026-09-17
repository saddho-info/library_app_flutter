import 'package:dio/dio.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/stock/domain/receiving.dart';

class ReceivingException implements Exception {
  const ReceivingException(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;
  @override
  String toString() => message;
}

abstract class ReceivingRepository {
  Future<PaginatedShipments> listInbound();
  Future<Shipment> getShipment(String id);
  Future<ReceiptSummary> getSummary();
  Future<StockReceipt> getReceipt(String id);
  Future<StockReceipt> confirmShipment({
    required String distributionId,
    required String idempotencyKey,
    required List<ReceiptCopySelection> items,
    String? notes,
  });
}

class ApiReceivingRepository implements ReceivingRepository {
  ApiReceivingRepository({required ApiClient apiClient}) : _api = apiClient;
  final ApiClient _api;

  @override
  Future<PaginatedShipments> listInbound() async {
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/distributions',
        queryParameters: {'receivable': true, 'page': 1, 'limit': 50},
      );
      return PaginatedShipments.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _error(error, 'Unable to load inbound shipments.');
    }
  }

  @override
  Future<Shipment> getShipment(String id) async {
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/distributions/$id',
      );
      return Shipment.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _error(error, 'Unable to load this shipment.');
    }
  }

  @override
  Future<ReceiptSummary> getSummary() async {
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/stock-receipts/summary',
      );
      return ReceiptSummary.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _error(error, 'Unable to load receiving summary.');
    }
  }

  @override
  Future<StockReceipt> getReceipt(String id) async {
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/stock-receipts/$id',
      );
      return StockReceipt.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _error(error, 'Unable to load this receipt.');
    }
  }

  @override
  Future<StockReceipt> confirmShipment({
    required String distributionId,
    required String idempotencyKey,
    required List<ReceiptCopySelection> items,
    String? notes,
  }) async {
    try {
      final response = await _api.raw.post<Map<String, dynamic>>(
        '/api/v1/stock-receipts',
        data: {
          'distributionId': distributionId,
          'confirm': true,
          'idempotencyKey': idempotencyKey,
          'items': [
            for (final item in items)
              {
                'copyId': item.copyId,
                'received': item.received,
                'discrepancy': item.discrepancy.apiValue,
              },
          ],
          if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return StockReceipt.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _error(error, 'Unable to confirm this receipt.');
    }
  }

  ReceivingException _error(DioException error, String fallback) {
    final data = error.response?.data;
    var message = fallback;
    String? code;
    if (data is Map) {
      code = data['error'] as String?;
      final raw = data['message'];
      message = raw is List ? raw.join(' ') : raw?.toString() ?? fallback;
    }
    if (code == 'INVALID_COPY') {
      message =
          'A selected copy is no longer receivable. Refresh and try again.';
    } else if (error.response?.statusCode == 403) {
      message = 'You do not have permission to receive stock.';
    } else if (error.type == DioExceptionType.connectionError) {
      message =
          'Unable to reach the server. Check your connection and try again.';
    }
    return ReceivingException(
      message,
      code: code,
      statusCode: error.response?.statusCode,
    );
  }
}
