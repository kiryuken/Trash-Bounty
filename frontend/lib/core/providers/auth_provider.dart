import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import '../network/secure_storage_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<UserModel?> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(null);

  Dio get _dio => _ref.read(dioProvider);

  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    final authResponse = AuthResponse.fromJson(response.data['data']);
    await SecureStorageService.saveTokens(authResponse.token, authResponse.refreshToken);
    state = authResponse.user;
  }

  Future<void> register(String name, String email, String password, String role) async {
    final response = await _dio.post(
      ApiEndpoints.register,
      data: {'name': name, 'email': email, 'password': password, 'role': role},
    );
    final authResponse = AuthResponse.fromJson(response.data['data']);
    await SecureStorageService.saveTokens(authResponse.token, authResponse.refreshToken);
    state = authResponse.user;
  }

  Future<bool> tryAutoLogin({Duration? timeout}) async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null) return false;
    try {
      final response = await _dio.get(
        ApiEndpoints.me,
        options: timeout == null
            ? null
            : Options(
                connectTimeout: timeout,
                receiveTimeout: timeout,
              ),
      );
      state = UserModel.fromJson(response.data['data']);
      return true;
    } catch (error, stackTrace) {
      logAppError('Auto login failed', error, stackTrace);
      await SecureStorageService.clearAll();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post(ApiEndpoints.logout, data: {'refresh_token': refreshToken});
      }
    } catch (error, stackTrace) {
      logAppError('Logout request failed', error, stackTrace);
    }
    await SecureStorageService.clearAll();
    state = null;
  }

  void setUser(UserModel user) => state = user;
}
