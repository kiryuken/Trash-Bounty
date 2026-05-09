import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static const _releaseBaseUrl = 'https://trashbounty.kiryuken.my.id/v1';
  static const _localDesktopBaseUrl = 'http://127.0.0.1:8080/v1';
  static const _localAndroidEmulatorBaseUrl = 'http://10.0.2.2:8080/v1';
  static const _configuredBaseUrl = String.fromEnvironment('BASE_URL');

  // BASE_URL can be overridden at build time:
  //   flutter build apk --dart-define=BASE_URL=https://api.example.com/v1
  // Release builds default to the public Cloudflare tunnel.
  // Debug builds default to the canonical local backend port 8080.
  // Physical-device testing can still override with --dart-define=BASE_URL=http://<LAN-IP>:8080/v1
  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (kReleaseMode) {
      return _releaseBaseUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _localAndroidEmulatorBaseUrl;
    }
    return _localDesktopBaseUrl;
  }

  // Auth
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';

  // Home
  static const homeStats = '/home/stats';
  static const cleanupStats = '/stats/cleanup';
  static const reportDownload = '/stats/report/download';
  static const reports = '/reports';
  static const reportsRecent = '/reports/recent';
  static const reportsMine = '/reports/mine';
  static const bounties = '/bounties';
  static const bountiesRecommended = '/bounties/recommended';
  static const bountiesMine = '/bounties/mine';
  static const notifications = '/notifications';
  static const notificationsReadAll = '/notifications/read-all';
  static const supportChat = '/support/chat';
  static const telegramToken = '/telegram/token';
  static const telegramLink = '/telegram/link';

  // Dynamic
  static String reportStatus(String id) => '/reports/$id/status';
  static String reportDetail(String id) => '/reports/$id';
  static String bountyDetail(String id) => '/bounties/$id';
  static String bountyTake(String id) => '/bounties/$id/take';
  static String bountyComplete(String id) => '/bounties/$id/complete';
  static String notifRead(String id) => '/notifications/$id/read';

  // User
  static const me = '/users/me';
  static const achievements = '/users/me/achievements';
  static const history = '/users/me/history';
  static const transactions = '/users/me/transactions';
  static const privacy = '/users/me/privacy';
  static const changePassword = '/users/me/change-password';
  static const leaderboard = '/leaderboard';
}
