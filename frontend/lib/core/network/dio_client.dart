import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_endpoints.dart';
import 'secure_storage_service.dart';

const _productionPinnedHost = 'trashbounty.kiryuken.my.id';
const _defaultProductionPinSha256 = 'fe3a3830ef1896e6cb9f7e2fc85a51950b3ddfa077753ef1214d587427fb92ec';
const _configuredSslPins = String.fromEnvironment('SSL_PIN_SHA256');

Set<String> _certificatePinsForHost(String host) {
  if (host != _productionPinnedHost) {
    return const {};
  }

  if (_configuredSslPins.trim().isEmpty) {
    return {_defaultProductionPinSha256};
  }

  return _configuredSslPins
      .split(',')
      .map((pin) => pin.trim().toLowerCase())
      .where((pin) => pin.isNotEmpty)
      .toSet();
}

void logAppError(String context, Object error, StackTrace stackTrace) {
  developer.log(
    context,
    name: 'trashbounty.app',
    error: error,
    stackTrace: stackTrace,
  );
}

String extractErrorMessage(
  Object error, {
  required String fallbackMessage,
}) {
  if (error is DioException) {
    final responseData = error.response?.data;
    if (responseData is Map) {
      final serverError = responseData['error'];
      if (serverError is String && serverError.trim().isNotEmpty) {
        return serverError.trim();
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi ke server timeout. Coba lagi.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      case DioExceptionType.badCertificate:
        return 'Sertifikat server tidak valid.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
    }
  }

  return fallbackMessage;
}

Dio _buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      return client;
    },
    validateCertificate: (certificate, host, port) {
      final pins = _certificatePinsForHost(host);
      if (pins.isEmpty) {
        return true;
      }
      if (certificate == null) {
        return false;
      }

      final fingerprint = sha256.convert(certificate.der).toString();
      final isPinned = pins.contains(fingerprint);
      if (!isPinned) {
        developer.log(
          'TLS pin mismatch for $host:$port',
          name: 'trashbounty.security',
          error: fingerprint,
        );
      }
      return isPinned;
    },
  );

  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final dio = _buildDio();

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await SecureStorageService.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        final refreshToken = await SecureStorageService.getRefreshToken();
        if (refreshToken != null) {
          try {
            final refreshDio = _buildDio();
            final response = await refreshDio.post(
              ApiEndpoints.refresh,
              data: {'refresh_token': refreshToken},
            );
            final newToken = response.data['data']['token'] as String;
            await SecureStorageService.saveTokens(newToken, refreshToken);
            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            return handler.resolve(await dio.fetch(error.requestOptions));
          } catch (refreshError, stackTrace) {
            logAppError('Failed to refresh access token', refreshError, stackTrace);
            await SecureStorageService.clearAll();
          }
        }
      }
      handler.next(error);
    },
  ));

  return dio;
});
