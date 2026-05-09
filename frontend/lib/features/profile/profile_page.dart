import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.me);
  return UserProfile.fromJson(response.data['data']);
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final profileAsync = ref.watch(profileProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(profileProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
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
                      IconButton(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Profil', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.name ?? 'User', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user?.role == 'executor' ? '🛠️ Eksekutor' : '📸 Pelapor',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Transform.translate(
              offset: const Offset(0, -16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: profileAsync.when(
                  data: (profile) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        _stat('Laporan', '${profile.totalReports}', AppColors.green600),
                        _divider(),
                        _stat('Bounty', '${profile.totalBounties}', AppColors.emerald600),
                        _divider(),
                        _stat('Poin', '${profile.points}', AppColors.amber600),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Achievements
            profileAsync.when(
              data: (profile) {
                if (profile.achievements.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pencapaian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray800)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.achievements.map((a) => _achievementChip(a)).toList(),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: profileAsync.when(
                data: (profile) => _telegramCard(context, ref, profile),
                loading: () => _telegramCard(context, ref, null),
                error: (_, _) => _telegramCard(context, ref, null),
              ),
            ),

            const SizedBox(height: 16),

            // Menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _menuItem(context, LucideIcons.shield, 'Privasi & Keamanan', () => context.go('/privacy')),
                  _menuItem(context, LucideIcons.helpCircle, 'Bantuan', () => context.go('/help')),
                  const SizedBox(height: 8),
                  _menuItem(
                    context,
                    LucideIcons.logOut,
                    'Keluar',
                    () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
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

  Widget _divider() {
    return Container(width: 1, height: 40, color: AppColors.gray200);
  }

  IconData _achievementIcon(String type) {
    switch (type) {
      case 'first_report':
        return LucideIcons.camera;
      case 'first_bounty':
        return LucideIcons.mapPin;
      case 'top_10_weekly':
      case 'top_10_monthly':
        return LucideIcons.trophy;
      case 'top_3_alltime':
        return LucideIcons.award;
      default:
        if (type.startsWith('reports_')) {
          return LucideIcons.clipboardCheck;
        }
        if (type.startsWith('bounties_')) {
          return LucideIcons.checkCircle;
        }
        if (type.startsWith('points_')) {
          return LucideIcons.star;
        }
        if (type.startsWith('top_')) {
          return LucideIcons.trophy;
        }
        return LucideIcons.medal;
    }
  }

  Widget _achievementChip(Achievement a) {
    final iconColor = a.unlocked ? AppColors.amber600 : AppColors.gray400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: a.unlocked ? AppColors.amber50 : AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: a.unlocked ? AppColors.amber200 : AppColors.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: a.unlocked ? AppColors.amber100 : Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_achievementIcon(a.type), size: 16, color: iconColor),
          ),
          const SizedBox(width: 6),
          Text(
            a.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: a.unlocked ? AppColors.gray700 : AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _telegramCard(BuildContext context, WidgetRef ref, UserProfile? profile) {
    final connected = profile?.telegramConnected ?? false;
    final linkedAt = _formatTelegramLinkedAt(profile?.telegramLinkedAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Hubungkan Telegram',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (connected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Terhubung',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      connected
                          ? 'Telegram sudah terhubung${linkedAt != null ? ' sejak $linkedAt' : ''}. Kamu bisa buat token baru jika ingin re-link.'
                          : 'Generate token lalu kirim /link <token> ke bot TrashBounty',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (connected)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTelegramToken(context, ref),
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: const Text('Generate Token Ulang'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _unlinkTelegram(context, ref),
                    icon: const Icon(LucideIcons.link2Off, size: 18),
                    label: const Text('Putuskan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showTelegramToken(context, ref),
                icon: const Icon(LucideIcons.link2, size: 18),
                label: const Text('Generate Token Telegram'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _formatTelegramLinkedAt(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Widget _menuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray100),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? AppColors.red500 : AppColors.gray600, size: 22),
        title: Text(title, style: TextStyle(color: isDestructive ? AppColors.red500 : AppColors.gray800, fontWeight: FontWeight.w500)),
        trailing: Icon(LucideIcons.chevronRight, size: 18, color: isDestructive ? AppColors.red500 : AppColors.gray400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showTelegramToken(BuildContext context, WidgetRef ref) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiEndpoints.telegramToken);
      final token = ((response.data['data'] as Map<String, dynamic>?)?['token'] as String?)?.trim();

      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token Telegram tidak tersedia')),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hubungkan Telegram'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Buka bot TrashBounty di Telegram'),
              const SizedBox(height: 6),
              const Text('2. Kirim perintah berikut:'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  '/link $token',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gray800),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: '/link $token'));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Perintah link Telegram disalin')),
                  );
                }
              },
              icon: const Icon(LucideIcons.copy, size: 16),
              label: const Text('Salin'),
            ),
          ],
        ),
      );
    } catch (error, stackTrace) {
      logAppError('Failed to generate Telegram token', error, stackTrace);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extractErrorMessage(
              error,
              fallbackMessage: 'Gagal membuat token Telegram',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _unlinkTelegram(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Putuskan Telegram'),
        content: const Text('Notifikasi Telegram akan berhenti sampai kamu menghubungkannya lagi. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dio = ref.read(dioProvider);
      await dio.delete(ApiEndpoints.telegramLink);

      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      ref.invalidate(profileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telegram berhasil diputuskan')),
      );
    } catch (error, stackTrace) {
      logAppError('Failed to unlink Telegram', error, stackTrace);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extractErrorMessage(
              error,
              fallbackMessage: 'Gagal memutuskan Telegram',
            ),
          ),
        ),
      );
    }
  }
}
