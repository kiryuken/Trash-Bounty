import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import 'stats_provider.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _periods = ['weekly', 'monthly', 'alltime'];
  final _periodLabels = ['Mingguan', 'Bulanan', 'Semua'];
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = _periods[_tabController.index];
    final statsAsync = ref.watch(cleanupStatsProvider(period));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(cleanupStatsProvider(period)),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildTabBar()),
          statsAsync.when(
            data: (stats) => SliverToBoxAdapter(child: _buildStatsContent(stats)),
            loading: () => const SliverToBoxAdapter(child: _StatsLoading()),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _StatsError(onRetry: () => ref.invalidate(cleanupStatsProvider(period))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
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
        bottom: 16,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.leaf, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dampak Komunitas',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Statistik kebersihan lingkungan',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.green100,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.green700,
          unselectedLabelColor: AppColors.green800,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _periodLabels.map((label) => Tab(text: label, height: 38)).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsContent(CleanupStats stats) {
    final numberFormat = NumberFormat.decimalPattern('id_ID');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _MetricCard(
                title: 'Total Bounty Diselesaikan',
                value: stats.totalCompleted.toString(),
                icon: LucideIcons.checkCircle,
                color: AppColors.green600,
              ),
              _MetricCard(
                title: 'Estimasi Sampah Dibersihkan',
                value: '${stats.totalWeightKg.toStringAsFixed(1)} kg',
                icon: LucideIcons.leaf,
                color: AppColors.emerald600,
              ),
              _MetricCard(
                title: 'Total Poin Didistribusikan',
                value: numberFormat.format(stats.totalPointsAwarded),
                icon: LucideIcons.star,
                color: AppColors.amber600,
              ),
              _MetricCard(
                title: 'Total Reward',
                value: 'Rp ${numberFormat.format(stats.totalRewardIdr.round())}',
                icon: LucideIcons.wallet,
                color: AppColors.green700,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Jenis Sampah',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.gray800),
          ),
          const SizedBox(height: 10),
          if (stats.wasteTypes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gray200),
              ),
              child: const Text(
                'Belum ada data jenis sampah untuk periode ini.',
                style: TextStyle(color: AppColors.gray600),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: stats.wasteTypes.map(_buildWasteChip).toList(),
            ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.green100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Milestone Komunitas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gray800),
                ),
                const SizedBox(height: 6),
                Text(
                  stats.totalCompleted >= 1000
                      ? 'Komunitas sudah melampaui 1000 bounty selesai. Momentum ini sudah sangat kuat.'
                      : 'Komunitas sudah menyelesaikan ${stats.totalCompleted} bounty. Target berikutnya: 1000 bounty selesai.',
                  style: const TextStyle(color: AppColors.gray700, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadReport,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_isDownloading ? 'Mengunduh laporan...' : 'Unduh Laporan DOCX'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.green600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteChip(WasteTypeStat item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.wasteType,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gray800),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.count} bounty • Severity ${item.avgSeverity.toStringAsFixed(1)}/10',
            style: const TextStyle(fontSize: 12, color: AppColors.gray600),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);
    try {
      final dio = ref.read(dioProvider);
      final period = _periods[_tabController.index];
      final response = await dio.post<List<int>>(
        ApiEndpoints.reportDownload,
        queryParameters: {'period': period},
        options: Options(responseType: ResponseType.bytes),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/laporan-trashbounty-$period.docx');
      await file.writeAsBytes(response.data ?? <int>[]);
      await OpenFile.open(file.path);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh laporan: $error'),
          backgroundColor: AppColors.red600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray900.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gray900),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.gray600, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: List.generate(
          4,
          (_) => Container(
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(18),
            ),
            height: 140,
          ),
        ),
      ),
    );
  }
}

class _StatsError extends StatelessWidget {
  final VoidCallback onRetry;

  const _StatsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.red500),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat statistik komunitas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coba muat ulang setelah koneksi backend siap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}