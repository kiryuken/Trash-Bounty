import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  static const tabs = [
    '/home',
    '/history',
    '/report',  // reporter: report, executor: bounty
    '/leaderboard',
    '/profile',
  ];

  int _currentIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/report') || location.startsWith('/bounty')) return 2;
    if (location.startsWith('/leaderboard')) return 3;
    if (
      location.startsWith('/profile') ||
      location.startsWith('/privacy') ||
      location.startsWith('/help')
    ) {
      return 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final location = GoRouterState.of(context).uri.path;
    final isExecutor = user?.role == 'executor';

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: LucideIcons.home,
                  label: 'Beranda',
                  isActive: _currentIndex(location) == 0,
                  onTap: () => context.go('/home'),
                ),
                _NavItem(
                  icon: LucideIcons.history,
                  label: 'Riwayat',
                  isActive: _currentIndex(location) == 1,
                  onTap: () => context.go('/history'),
                ),
                _NavItem(
                  icon: isExecutor ? LucideIcons.mapPin : LucideIcons.camera,
                  label: isExecutor ? 'Bounty' : 'Lapor',
                  isActive: _currentIndex(location) == 2,
                  onTap: () => context.go(isExecutor ? '/bounty' : '/report'),
                ),
                _NavItem(
                  icon: LucideIcons.trophy,
                  label: 'Peringkat',
                  isActive: _currentIndex(location) == 3,
                  onTap: () => context.go('/leaderboard'),
                ),
                _NavItem(
                  icon: LucideIcons.user,
                  label: 'Profil',
                  isActive: _currentIndex(location) == 4,
                  onTap: () => context.go('/profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.green600 : AppColors.gray400,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.green600 : AppColors.gray400,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
