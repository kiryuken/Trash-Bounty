import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trash_bounty/core/network/api_endpoints.dart';

void main() {
  test('uses the canonical local debug base URL defaults', () {
    if (kReleaseMode) {
      expect(ApiEndpoints.baseUrl, 'https://trashbounty.kiryuken.my.id/v1');
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      expect(ApiEndpoints.baseUrl, 'http://10.0.2.2:8080/v1');
      return;
    }

    expect(ApiEndpoints.baseUrl, 'http://127.0.0.1:8080/v1');
  });
}