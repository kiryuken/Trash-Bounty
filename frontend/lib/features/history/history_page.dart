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

final historyProvider = FutureProvider.autoDispose<List<HistoryItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.history);
  return (response.data['data'] as List?)?.map((e) => HistoryItem.fromJson(e)).toList() ?? [];
});

final currFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
const Set<String> _reportEarningStatuses = {'approved', 'bounty_created', 'completed'};
const Set<String> _bountyEarningStatuses = {'taken', 'in_progress', 'completed'};

bool _showsEarnings(HistoryItem item) {
  final normalizedStatus = AppBadge.normalizeStatus(item.status);
  switch (item.type) {
    case 'report':
      return _reportEarningStatuses.contains(normalizedStatus);
    case 'bounty':
      return _bountyEarningStatuses.contains(normalizedStatus);
    default:
      return false;
  }
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final histAsync = ref.watch(historyProvider);
    final isReporter = user?.role != 'executor';

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(historyProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Riwayat',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isReporter ? 'Laporan yang telah Anda buat' : 'Bounty yang telah Anda kerjakan',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Stats summary
          histAsync.when(
            data: (items) {
              final earningItems = items.where(_showsEarnings).toList();
              final completed = items.where((i) => i.status == 'completed').length;
              final totalPts = earningItems.fold<int>(0, (sum, i) => sum + (i.pointsEarned ?? 0));
              final totalReward = earningItems.fold<double>(0, (sum, i) => sum + i.reward);
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray100),
                    ),
                    child: Row(
                      children: [
                        _summaryItem('Selesai', '$completed', AppColors.green600),
                        _summaryItem('Total Poin', '$totalPts', AppColors.amber600),
                        _summaryItem('Total Reward', currFmt.format(totalReward), AppColors.blue600),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (error, stackTrace) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // List
          histAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.history, size: 48, color: AppColors.gray300),
                        const SizedBox(height: 12),
                        const Text('Belum ada riwayat', style: TextStyle(color: AppColors.gray500)),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _HistoryCard(item: items[index]),
                    childCount: items.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (error, stackTrace) => const SliverFillRemaining(child: Center(child: Text('Gagal memuat riwayat'))),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final showEarnings = _showsEarnings(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.mapPin, size: 18, color: AppColors.green600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.location, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showEarnings && item.pointsEarned != null && item.pointsEarned! > 0)
                    Text('+${item.pointsEarned} poin', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.amber600)),
                  if (showEarnings && item.reward > 0)
                    Text(currFmt.format(item.reward), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.green600, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statusBadge(item.status),
              const SizedBox(width: 8),
              AppBadge.severity(item.severity),
              const Spacer(),
              if (item.date != null || item.createdAt != null)
                Text(
                  item.date ?? item.createdAt ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.gray400),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final normalizedStatus = AppBadge.normalizeStatus(status);
    Color bg;
    Color text;
    final label = AppBadge.statusLabel(status);
    switch (normalizedStatus) {
      case 'completed':
      case 'approved':
      case 'bounty_created':
        bg = AppColors.green100;
        text = AppColors.green700;
      case 'taken':
      case 'in_progress':
      case 'ai_analyzing':
        bg = AppColors.blue100;
        text = AppColors.blue600;
      case 'open':
      case 'pending':
        bg = AppColors.amber100;
        text = AppColors.amber600;
      case 'rejected':
      case 'disputed':
      case 'cancelled':
        bg = AppColors.red100;
        text = AppColors.red600;
      default:
        bg = AppColors.gray100;
        text = AppColors.gray600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: text)),
    );
  }
}
