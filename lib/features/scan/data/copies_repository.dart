import 'package:dio/dio.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';

class CopiesException implements Exception {
  CopiesException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract class CopiesRepository {
  Future<BookCopy> findByQrToken(String token);
}

class ApiCopiesRepository implements CopiesRepository {
  ApiCopiesRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<BookCopy> findByQrToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw CopiesException('Scan a QR code or enter a token.');
    }

    try {
      // Encode the opaque token once as a path segment (base64url-safe).
      final encoded = Uri.encodeComponent(trimmed);
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/copies/by-qr/$encoded',
      );
      final data = response.data;
      if (data == null) {
        throw CopiesException('Copy lookup returned no data.');
      }
      return BookCopy.fromJson(data);
    } on DioException catch (error) {
      throw CopiesException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  String _messageFrom(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is List) {
        return message.join(' ');
      }
      return message.toString();
    }
    if (status == 404) {
      return 'No copy found for this QR code.';
    }
    if (status == 403) {
      return 'You do not have access to this copy.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to reach the server.';
    }
    return 'Unable to look up this QR code.';
  }
}
