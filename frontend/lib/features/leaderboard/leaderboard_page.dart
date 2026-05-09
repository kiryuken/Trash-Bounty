import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

final leaderboardProvider = FutureProvider.autoDispose.family<LeaderboardResponse, String>((ref, period) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.leaderboard, queryParameters: {'period': period});
  return LeaderboardResponse.fromJson(response.data['data']);
});

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _periods = ['weekly', 'monthly', 'alltime'];
  final _periodLabels = ['Mingguan', 'Bulanan', 'Semua'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = _periods[_tabController.index];
    final lbAsync = ref.watch(leaderboardProvider(period));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(leaderboardProvider(period)),
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.amber500, AppColors.amber600]),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 16,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.trophy, size: 32, color: Colors.white),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Leaderboard', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                          Text('Top kontributor', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.amber600,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: _periodLabels.map((l) => Tab(text: l, height: 36)).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Podium
          lbAsync.when(
            data: (lb) {
              final entries = lb.entries;
              if (entries.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text('Belum ada data')));
              }
              return SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Top 3 podium
                    if (entries.length >= 3) _buildPodium(entries.sublist(0, 3)),
                    const SizedBox(height: 8),
                    // Remaining
                    ...entries.skip(3).map((e) => _buildEntry(e)),
                    // Current user
                    if (lb.currentUserRank != null && !entries.any((e) => e.isCurrentUser)) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(),
                      ),
                      _buildEntry(lb.currentUserRank!, highlight: true),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (error, stackTrace) => const SliverFillRemaining(child: Center(child: Text('Gagal memuat data'))),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _podiumItem(top3[1], 2, 90)),
          const SizedBox(width: 8),
          Expanded(child: _podiumItem(top3[0], 1, 110)),
          const SizedBox(width: 8),
          Expanded(child: _podiumItem(top3[2], 3, 80)),
        ],
      ),
    );
  }

  Widget _podiumItem(LeaderboardEntry entry, int rank, double height) {
    final colors = {
      1: [AppColors.amber500, AppColors.amber600],
      2: [AppColors.gray400, AppColors.gray500],
      3: [const Color(0xFFCD7F32), const Color(0xFFB87333)],
    };
    final icons = {1: LucideIcons.crown, 2: LucideIcons.medal, 3: LucideIcons.medal};

    return Column(
      children: [
        CircleAvatar(
          radius: rank == 1 ? 32 : 26,
          backgroundColor: colors[rank]![0],
          child: Text(
            entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontSize: rank == 1 ? 24 : 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Icon(icons[rank]!, size: 18, color: colors[rank]![0]),
        const SizedBox(height: 4),
        Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        Text('${entry.points} pts', style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors[rank]![0].withValues(alpha: 0.3), colors[rank]![0].withValues(alpha: 0.1)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Center(
            child: Text('#$rank', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors[rank]![0])),
          ),
        ),
      ],
    );
  }

  Widget _buildEntry(LeaderboardEntry entry, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.green50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? AppColors.green200 : AppColors.gray100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(fontWeight: FontWeight.w600, color: highlight ? AppColors.green600 : AppColors.gray500),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: highlight ? AppColors.green200 : AppColors.gray200,
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.w600, color: highlight ? AppColors.green700 : AppColors.gray600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isCurrentUser ? '${entry.name} (Anda)' : entry.name,
                  style: TextStyle(fontWeight: FontWeight.w600, color: highlight ? AppColors.green700 : AppColors.gray800),
                ),
                Text('${entry.tasks} tugas', style: const TextStyle(fontSize: 12, color: AppColors.gray400)),
              ],
            ),
          ),
          Text('${entry.points}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: highlight ? AppColors.green600 : AppColors.amber600)),
          const SizedBox(width: 4),
          const Text('pts', style: TextStyle(fontSize: 12, color: AppColors.gray400)),
        ],
      ),
    );
  }
}
