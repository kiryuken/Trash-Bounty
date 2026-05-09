import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/models.dart';

final cleanupStatsProvider = FutureProvider.autoDispose.family<CleanupStats, String>((ref, period) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiEndpoints.cleanupStats,
    queryParameters: {'period': period},
  );
  final data = response.data['data'] ?? response.data;
  return CleanupStats.fromJson(data as Map<String, dynamic>);
});