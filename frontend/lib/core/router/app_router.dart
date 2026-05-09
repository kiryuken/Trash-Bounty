import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/home/home_page.dart';
import '../../features/report/report_page.dart';
import '../../features/bounty/bounty_page.dart';
import '../../features/leaderboard/leaderboard_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/history/history_page.dart';
import '../../features/profile/privacy_page.dart';
import '../../features/profile/help_support_page.dart';
import '../../features/stats/stats_page.dart';
import '../widgets/main_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/signup', builder: (_, _) => const SignupPage()),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(path: '/report', builder: (_, _) => const ReportPage()),
        GoRoute(path: '/bounty', builder: (_, _) => const BountyPage()),
        GoRoute(path: '/leaderboard', builder: (_, _) => const LeaderboardPage()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
        GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
        GoRoute(path: '/privacy', builder: (_, _) => const PrivacyPage()),
        GoRoute(path: '/help', builder: (_, _) => const HelpSupportPage()),
        GoRoute(path: '/stats', builder: (_, _) => const StatsPage()),
      ],
    ),
  ],
);
