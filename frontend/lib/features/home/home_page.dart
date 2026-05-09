import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_badge.dart';
import '../../data/models/models.dart';

final _dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.homeStats);
  return response.data['data'] as Map<String, dynamic>;
});

final homeStatsProvider = FutureProvider.autoDispose<HomeStats>((ref) async {
  final dashboard = await ref.watch(_dashboardProvider.future);
  return HomeStats.fromJson(dashboard['stats'] as Map<String, dynamic>);
});

final recentReportsProvider = FutureProvider.autoDispose<List<ReportModel>>((ref) async {
  final dashboard = await ref.watch(_dashboardProvider.future);
  return (dashboard['recent_reports'] as List?)?.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
});

final availableBountiesProvider = FutureProvider.autoDispose<List<BountyModel>>((ref) async {
  final dashboard = await ref.watch(_dashboardProvider.future);
  return (dashboard['recent_bounties'] as List?)?.map((e) => BountyModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
});

final notificationsProvider = FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.notifications);
  return (response.data['data'] as List?)?.map((e) => NotificationModel.fromJson(e)).toList() ?? [];
});

final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final statsAsync = ref.watch(homeStatsProvider);
    final isReporter = user?.role != 'executor';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeStatsProvider);
        ref.invalidate(recentReportsProvider);
        ref.invalidate(availableBountiesProvider);
        ref.invalidate(notificationsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo, ${user?.name ?? 'User'}! 👋',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isReporter ? '📸 Pelapor' : '🛠️ Eksekutor',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _NotificationBell(ref: ref),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats
                  statsAsync.when(
                    data: (stats) => _StatsGrid(stats: stats, isReporter: isReporter),
                    loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                    error: (_, _) => const SizedBox(height: 80, child: Center(child: Text('Error loading stats', style: TextStyle(color: Colors.white)))),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Wallet
            statsAsync.when(
              data: (stats) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.amber500, AppColors.amber600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.amber500.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.wallet, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Saldo Dompet', style: TextStyle(color: Colors.white, fontSize: 12)),
                            Text(
                              currencyFormat.format(stats.walletBalance),
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: () => context.push('/stats'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.green700.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.leaf, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dampak Komunitas',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Lihat statistik sampah yang sudah dibersihkan',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Recent items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isReporter ? 'Laporan Terbaru' : 'Bounty Tersedia',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray800),
              ),
            ),
            const SizedBox(height: 12),

            if (isReporter) _RecentReportsList(ref: ref) else _AvailableBountiesList(ref: ref),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final WidgetRef ref;
  const _NotificationBell({required this.ref});

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);
    final unreadCount = notifAsync.whenOrNull(
      data: (list) => list.where((n) => !n.isRead).length,
    ) ?? 0;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(LucideIcons.bell, color: Colors.white, size: 24),
          onPressed: () => _showNotifications(context, ref),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: AppColors.red500, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.read(notificationsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.gray300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Divider(height: 24),
            Expanded(
              child: notifAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(child: Text('Belum ada notifikasi', style: TextStyle(color: AppColors.gray500)));
                  }
                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final n = list[i];
                      return ListTile(
                        leading: _notifIcon(n.type),
                        title: Text(n.message, style: TextStyle(fontSize: 14, fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600)),
                        subtitle: Text(n.createdAt, style: const TextStyle(fontSize: 12, color: AppColors.gray400)),
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Text('Error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifIcon(String type) {
    switch (type) {
      case 'success':
        return const CircleAvatar(radius: 18, backgroundColor: AppColors.green100, child: Icon(LucideIcons.checkCircle, size: 18, color: AppColors.green600));
      case 'reward':
        return const CircleAvatar(radius: 18, backgroundColor: AppColors.amber100, child: Icon(LucideIcons.coins, size: 18, color: AppColors.amber600));
      case 'warning':
        return const CircleAvatar(radius: 18, backgroundColor: AppColors.red100, child: Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.red500));
      default:
        return const CircleAvatar(radius: 18, backgroundColor: AppColors.blue100, child: Icon(LucideIcons.info, size: 18, color: AppColors.blue600));
    }
  }
}

class _StatsGrid extends StatelessWidget {
  final HomeStats stats;
  final bool isReporter;
  const _StatsGrid({required this.stats, required this.isReporter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: LucideIcons.fileText,
          label: isReporter ? 'Laporan' : 'Bounty',
          value: '${isReporter ? stats.totalReports : stats.pendingBounties}',
        ),
        const SizedBox(width: 8),
        _StatCard(icon: LucideIcons.star, label: 'Poin', value: '${stats.totalPoints}'),
        const SizedBox(width: 8),
        _StatCard(icon: LucideIcons.trophy, label: 'Peringkat', value: stats.currentRank != null ? '#${stats.currentRank}' : '-'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RecentReportsList extends StatelessWidget {
  final WidgetRef ref;
  const _RecentReportsList({required this.ref});

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(recentReportsProvider);
    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.fileText, size: 48, color: AppColors.gray300),
                  const SizedBox(height: 12),
                  const Text('Belum ada laporan', style: TextStyle(color: AppColors.gray500)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/report'),
                    icon: const Icon(LucideIcons.camera, size: 16),
                    label: const Text('Buat Laporan'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: reports.length,
          itemBuilder: (_, i) {
            final r = reports[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.locationText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            AppBadge.status(r.status),
                            const SizedBox(width: 8),
                            AppBadge.severity(r.severity),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (r.rewardIdr != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(currencyFormat.format(r.rewardIdr), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.green600, fontSize: 13)),
                        if (r.pointsEarned != null)
                          Text('${r.pointsEarned} poin', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.amber600, fontSize: 11)),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Gagal memuat data'))),
    );
  }
}

class _AvailableBountiesList extends StatelessWidget {
  final WidgetRef ref;
  const _AvailableBountiesList({required this.ref});

  @override
  Widget build(BuildContext context) {
    final bountiesAsync = ref.watch(availableBountiesProvider);
    return bountiesAsync.when(
      data: (bounties) {
        if (bounties.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.mapPin, size: 48, color: AppColors.gray300),
                  const SizedBox(height: 12),
                  const Text('Belum ada bounty tersedia', style: TextStyle(color: AppColors.gray500)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: bounties.length,
          itemBuilder: (_, i) {
            final b = bounties[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray100),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(LucideIcons.mapPin, color: AppColors.green600, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.location, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (b.distance != null) ...[
                              const Icon(LucideIcons.navigation, size: 12, color: AppColors.gray400),
                              const SizedBox(width: 4),
                              Text(b.distance!, style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
                              const SizedBox(width: 8),
                            ],
                            AppBadge.severity(b.severity),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(currencyFormat.format(b.reward), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.green600, fontSize: 13)),
                      if (b.rewardPoints != null)
                        Text('${b.rewardPoints} poin', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.amber600, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Gagal memuat data'))),
    );
  }
}
