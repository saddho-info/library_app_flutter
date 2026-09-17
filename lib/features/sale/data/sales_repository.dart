import 'package:dio/dio.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/sale/domain/sale.dart';

class SalesException implements Exception {
  SalesException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Server conflict code when present (`ALREADY_SOLD`, `INVALID_COPY`, …).
  final String? code;

  bool get isAlreadySold => code == 'ALREADY_SOLD';
  bool get isInvalidCopy => code == 'INVALID_COPY';

  @override
  String toString() => message;
}

class CreateSaleRequest {
  const CreateSaleRequest({
    required this.idempotencyKey,
    this.copyId,
    this.qrToken,
    this.unitPriceCents,
    this.notes,
  }) : assert(copyId != null || qrToken != null, 'Provide copyId or qrToken');

  final String idempotencyKey;
  final String? copyId;
  final String? qrToken;
  final int? unitPriceCents;
  final String? notes;
}

abstract class SalesRepository {
  Future<Sale> createSale(CreateSaleRequest request);
  Future<PaginatedSales> listSales({int page = 1, int limit = 20});
  Future<SaleSummary> getSummary();
  Future<Sale> getSale(String id);
}

class ApiSalesRepository implements SalesRepository {
  ApiSalesRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<Sale> createSale(CreateSaleRequest request) async {
    final item = <String, dynamic>{
      if (request.copyId != null) 'copyId': request.copyId,
      if (request.qrToken != null) 'qrToken': request.qrToken,
      if (request.unitPriceCents != null)
        'unitPriceCents': request.unitPriceCents,
    };

    try {
      final response = await _api.raw.post<Map<String, dynamic>>(
        '/api/v1/sales',
        data: {
          'items': [item],
          if (request.notes != null && request.notes!.trim().isNotEmpty)
            'notes': request.notes!.trim(),
        },
        options: Options(headers: {'Idempotency-Key': request.idempotencyKey}),
      );
      final data = response.data;
      if (data == null) {
        throw SalesException('Sale create returned no data.');
      }
      return Sale.fromJson(data);
    } on DioException catch (error) {
      throw _fromDio(error, fallback: 'Unable to record this sale.');
    }
  }

  @override
  Future<PaginatedSales> listSales({int page = 1, int limit = 20}) async {
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/sales',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data;
      if (data == null) {
        throw SalesException('Sales list returned no data.');
      }
      return PaginatedSales.fromJson(data);
    } on DioException catch (error) {
      throw _fromDio(error, fallback: 'Unable to load sales.');
    }
  }

  @override
  Future<SaleSummary> getSummary() async {
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/sales/summary',
      );
      final data = response.data;
      if (data == null) {
        throw SalesException('Sales summary returned no data.');
      }
      return SaleSummary.fromJson(data);
    } on DioException catch (error) {
      throw _fromDio(error, fallback: 'Unable to load sales summary.');
    }
  }

  @override
  Future<Sale> getSale(String id) async {
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/sales/$id',
      );
      final data = response.data;
      if (data == null) {
        throw SalesException('Sale detail returned no data.');
      }
      return Sale.fromJson(data);
    } on DioException catch (error) {
      throw _fromDio(error, fallback: 'Unable to load this sale.');
    }
  }

  SalesException _fromDio(DioException error, {required String fallback}) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? code;
    String message = fallback;

    if (data is Map) {
      final rawCode = data['error'];
      if (rawCode is String && rawCode.isNotEmpty) {
        code = rawCode;
      }
      final rawMessage = data['message'];
      if (rawMessage is List) {
        message = rawMessage.join(' ');
      } else if (rawMessage != null) {
        message = rawMessage.toString();
      }
    }

    if (code == 'ALREADY_SOLD') {
      message = 'This copy has already been sold.';
    } else if (code == 'INVALID_COPY') {
      message = message.contains('cannot be sold')
          ? message
          : 'This copy cannot be sold (missing, wrong library, or not in stock).';
    } else if (status == 403) {
      message = 'You do not have permission to record sales.';
    } else if (error.type == DioExceptionType.connectionError) {
      message =
          'Unable to reach the server. Check your connection and try again.';
    }

    return SalesException(message, statusCode: status, code: code);
  }
}
