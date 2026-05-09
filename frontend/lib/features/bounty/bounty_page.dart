import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_badge.dart';
import '../../data/models/models.dart';

final bountyListProvider = FutureProvider.autoDispose<List<BountyModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.bounties, queryParameters: {'status': 'open'});
  return (response.data['data'] as List?)?.map((e) => BountyModel.fromJson(e)).toList() ?? [];
});

final recommendedBountyListProvider = FutureProvider.autoDispose
    .family<List<BountyModel>, ({double lat, double lon})>((ref, location) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiEndpoints.bountiesRecommended,
    queryParameters: {
      'lat': location.lat,
      'lon': location.lon,
      'limit': 10,
    },
  );
  return (response.data['data'] as List?)?.map((e) => BountyModel.fromJson(e)).toList() ?? [];
});

final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class BountyPage extends ConsumerStatefulWidget {
  const BountyPage({super.key});

  @override
  ConsumerState<BountyPage> createState() => _BountyPageState();
}

class _BountyPageState extends ConsumerState<BountyPage> {
  String _searchQuery = '';
  int _selectedTab = 0;
  double? _latitude;
  double? _longitude;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationError = 'Izin lokasi dibutuhkan untuk rekomendasi');
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _locationError = null;
        });
      }
    } catch (error, stackTrace) {
      logAppError('Failed to detect bounty location', error, stackTrace);
      if (mounted) {
        setState(() => _locationError = 'Gagal mendeteksi lokasi');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bountiesAsync = ref.watch(bountyListProvider);
    final recommendedAsync = (_latitude != null && _longitude != null)
        ? ref.watch(recommendedBountyListProvider((lat: _latitude!, lon: _longitude!)))
        : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bountyListProvider);
        if (_latitude != null && _longitude != null) {
          ref.invalidate(recommendedBountyListProvider((lat: _latitude!, lon: _longitude!)));
        }
        await _detectLocation();
      },
      child: CustomScrollView(
        slivers: [
          // Header
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
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      const Expanded(
                        child: Text('Pasar Bounty', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Temukan tugas pembersihan terdekat', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  // Search
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: AppColors.gray800),
                      decoration: const InputDecoration(
                        hintText: 'Cari lokasi...',
                        prefixIcon: Icon(LucideIcons.search, size: 18, color: AppColors.gray400),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _BountyTabButton(
                            label: 'Semua Bounty',
                            selected: _selectedTab == 0,
                            onTap: () => setState(() => _selectedTab = 0),
                          ),
                        ),
                        Expanded(
                          child: _BountyTabButton(
                            label: 'Rekomendasi Lumi',
                            selected: _selectedTab == 1,
                            onTap: () => setState(() => _selectedTab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bounty list
          (_selectedTab == 0 ? bountiesAsync : recommendedAsync ?? const AsyncLoading<List<BountyModel>>()).when(
            data: (bounties) {
              final filtered = bounties.where((b) => b.location.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              if (_selectedTab == 1 && _latitude == null && _longitude == null) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.navigation, size: 48, color: AppColors.gray300),
                          const SizedBox(height: 12),
                          Text(
                            _locationError ?? 'Menunggu lokasi untuk menyiapkan rekomendasi Lumi',
                            style: const TextStyle(color: AppColors.gray500),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _detectLocation,
                            icon: const Icon(LucideIcons.refreshCw, size: 16),
                            label: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.mapPin, size: 48, color: AppColors.gray300),
                        const SizedBox(height: 12),
                        const Text('Tidak ada bounty ditemukan', style: TextStyle(color: AppColors.gray500)),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _BountyCard(bounty: filtered[i], ref: ref, highlighted: _selectedTab == 1),
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (_, _) => SliverFillRemaining(
              child: Center(
                child: Text(_selectedTab == 1 ? 'Gagal memuat rekomendasi bounty' : 'Gagal memuat bounty'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BountyCard extends StatelessWidget {
  final BountyModel bounty;
  final WidgetRef ref;
  final bool highlighted;
  const _BountyCard({required this.bounty, required this.ref, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlighted ? AppColors.green300 : AppColors.gray100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showBountyDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.green100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.mapPin, color: AppColors.green600, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bounty.location, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (bounty.address != null) ...[
                        const SizedBox(height: 2),
                        Text(bounty.address!, style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (highlighted && bounty.score != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.green50,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Lumi ${(bounty.score! * 10).clamp(0, 999).toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green700),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (bounty.distance != null) ...[
                            const Icon(LucideIcons.navigation, size: 12, color: AppColors.gray400),
                            const SizedBox(width: 4),
                            Text(bounty.distance!, style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
                            const SizedBox(width: 8),
                          ],
                          if (bounty.estimatedTime != null) ...[
                            const Icon(LucideIcons.clock, size: 12, color: AppColors.gray400),
                            const SizedBox(width: 4),
                            Text('${bounty.estimatedTime} min', style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
                            const SizedBox(width: 8),
                          ],
                          AppBadge.severity(bounty.severity),
                        ],
                      ),
                      if (highlighted && bounty.reasoning != null && bounty.reasoning!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bounty.reasoning!,
                          style: const TextStyle(fontSize: 12, color: AppColors.gray600, height: 1.35),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFmt.format(bounty.reward),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green600, fontSize: 14),
                    ),
                    if (bounty.rewardPoints != null)
                      Text(
                        '${bounty.rewardPoints} poin',
                        style: const TextStyle(fontSize: 11, color: AppColors.amber600, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 4),
                    const Text('Reward', style: TextStyle(fontSize: 11, color: AppColors.gray400)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBountyDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.gray300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(bounty.location, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.gray800)),
              if (bounty.address != null) ...[
                const SizedBox(height: 4),
                Text(bounty.address!, style: const TextStyle(color: AppColors.gray500)),
              ],
              const SizedBox(height: 16),
              // Info grid
              Row(
                children: [
                  _infoChip(LucideIcons.alertTriangle, 'Severity', '${bounty.severity}/10'),
                  const SizedBox(width: 8),
                  _infoChip(
                    LucideIcons.coins,
                    'Reward',
                    bounty.rewardPoints != null
                        ? '${bounty.rewardPoints} poin\n${currencyFmt.format(bounty.reward)}'
                        : currencyFmt.format(bounty.reward),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '10 poin = Rp 1. Reward moderat dibatasi sampai Rp 10.000.',
                style: TextStyle(fontSize: 12, color: AppColors.gray500, height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (bounty.distance != null) _infoChip(LucideIcons.navigation, 'Jarak', bounty.distance!),
                  if (bounty.estimatedTime != null) ...[
                    const SizedBox(width: 8),
                    _infoChip(LucideIcons.clock, 'Estimasi', '${bounty.estimatedTime} min'),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _takeBounty(ctx),
                  icon: const Icon(LucideIcons.mapPin, size: 20),
                  label: const Text('Ambil Bounty'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.green600),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.gray400)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.gray800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takeBounty(BuildContext context) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiEndpoints.bountyTake(bounty.id));
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bounty berhasil diambil!')),
        );
        ref.invalidate(bountyListProvider);
      }
    } catch (error, stackTrace) {
      logAppError('Failed to take bounty', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              extractErrorMessage(
                error,
                fallbackMessage: 'Gagal mengambil bounty',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _BountyTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BountyTabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.green700 : Colors.white,
          ),
        ),
      ),
    );
  }
}
