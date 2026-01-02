import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../constants/archive_constants.dart';
import '../errors/app_exceptions.dart';

class NetworkService {
  final http.Client _client;
  final Connectivity _connectivity;

  NetworkService({http.Client? client, Connectivity? connectivity})
    : _client = client ?? http.Client(),
      _connectivity = connectivity ?? Connectivity();

  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    try {
      // Check internet connection
      if (!await isConnected) {
        throw const NoInternetException();
      }

      // Build URI with query parameters
      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      // Make request with timeout
      final response = await _client
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: ArchiveConstants.requestTimeout),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

      return _handleResponse(response);
    } on NoInternetException {
      rethrow;
    } on TimeoutException {
      throw const NetworkException(
        message: 'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );
    } on SocketException catch (e) {
      throw NetworkException(
        message: 'Connection failed. Please check your internet.',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw ParseException(
        message: 'Invalid response format',
        originalError: e,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(
        message: 'An unexpected error occurred',
        originalError: e,
      );
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        try {
          final body = response.body;
          if (body.isEmpty) {
            return {};
          }
          return json.decode(body) as Map<String, dynamic>;
        } catch (e) {
          throw ParseException(
            message: 'Failed to parse server response',
            originalError: e,
          );
        }
      case 400:
        throw const ServerException(message: 'Bad request', statusCode: 400);
      case 401:
        throw const ServerException(message: 'Unauthorized', statusCode: 401);
      case 403:
        throw const ServerException(message: 'Forbidden', statusCode: 403);
      case 404:
        throw const ServerException(
          message: 'Resource not found',
          statusCode: 404,
        );
      case 500:
      case 502:
      case 503:
        throw ServerException(
          message: 'Server error. Please try again later.',
          statusCode: response.statusCode,
        );
      default:
        throw ServerException(
          message: 'Unexpected error occurred',
          statusCode: response.statusCode,
        );
    }
  }

  void dispose() {
    _client.close();
  }
}
