import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

final privacySettingsProvider = FutureProvider.autoDispose<PrivacySettings>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.privacy);
  return PrivacySettings.fromJson(response.data['data']);
});

class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({super.key});

  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  bool? _publicProfile;
  bool? _locationSharing;
  bool? _twoFactor;
  LocationPermission? _locationPermission;
  permission_handler.PermissionStatus? _cameraPermission;
  bool _checkingPermissions = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatuses();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(privacySettingsProvider);

    return SingleChildScrollView(
      child: Column(
        children: [
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
                        'Privasi & Keamanan',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Kelola pengaturan privasi, keamanan, dan izin Android Anda', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: settingsAsync.when(
              data: (settings) {
                _publicProfile ??= settings.publicProfile;
                _locationSharing ??= settings.locationSharing;
                _twoFactor ??= settings.twoFactorEnabled;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      title: 'Privasi',
                      subtitle: 'Atur apa yang terlihat oleh pengguna lain di profil Anda.',
                    ),
                    _sectionCard(
                      children: [
                        _toggleCard(
                          icon: LucideIcons.eye,
                          title: 'Profil Publik',
                          subtitle: 'Izinkan orang lain melihat profil Anda di leaderboard dan profil publik.',
                          value: _publicProfile!,
                          onChanged: (value) => setState(() => _publicProfile = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionHeader(
                      title: 'Keamanan',
                      subtitle: 'Lindungi akun Anda dengan kontrol keamanan tambahan.',
                    ),
                    _sectionCard(
                      children: [
                        _toggleCard(
                          icon: LucideIcons.shield,
                          title: 'Autentikasi Dua Faktor',
                          subtitle: 'Tambahkan lapisan keamanan ekstra saat masuk ke akun.',
                          value: _twoFactor!,
                          onChanged: (value) => setState(() => _twoFactor = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionHeader(
                      title: 'Izin Aplikasi',
                      subtitle: 'Pastikan Android memberi akses yang dibutuhkan saat Anda membuka fitur aplikasi.',
                    ),
                    _sectionCard(
                      children: [
                        _permissionInfoBanner(),
                        const SizedBox(height: 16),
                        _toggleCard(
                          icon: Icons.my_location_rounded,
                          title: 'Gunakan Lokasi Saat Membuka Fitur',
                          subtitle: 'Aktifkan agar TrashBounty dapat meminta lokasi saat Anda membuka laporan atau bounty.',
                          value: _locationSharing!,
                          onChanged: _handleLocationSharingChanged,
                        ),
                        const SizedBox(height: 12),
                        _permissionTile(
                          icon: LucideIcons.mapPin,
                          title: 'Izin Lokasi Android',
                          subtitle: _locationPermissionDescription(),
                          status: _locationPermissionLabel(),
                          statusColor: _locationPermissionColor(),
                          actionLabel: _locationPermissionActionLabel(),
                          onPressed: _handleLocationPermissionAction,
                          loading: _checkingPermissions,
                        ),
                        const SizedBox(height: 12),
                        _permissionTile(
                          icon: LucideIcons.camera,
                          title: 'Izin Kamera Android',
                          subtitle: _cameraPermissionDescription(),
                          status: _cameraPermissionLabel(),
                          statusColor: _cameraPermissionColor(),
                          actionLabel: _cameraPermissionActionLabel(),
                          onPressed: _handleCameraPermissionAction,
                          loading: _checkingPermissions,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Simpan Perubahan'),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (error, stackTrace) => const Center(child: Text('Gagal memuat pengaturan')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.gray800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.gray500, height: 1.4)),
        ],
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _toggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.green600, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.gray500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.green600,
          ),
        ],
      ),
    );
  }

  Widget _permissionInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green100),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.green700, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Saat Android menampilkan izin lokasi, pilih "Allow while using the app" agar fitur laporan dan bounty dapat mendeteksi lokasi Anda saat aplikasi dibuka.',
              style: TextStyle(fontSize: 12.5, color: AppColors.green700, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required String actionLabel,
    required VoidCallback onPressed,
    required bool loading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.green600, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray800)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.gray500, height: 1.4)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: loading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.green700,
              side: const BorderSide(color: AppColors.green300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshPermissionStatuses() async {
    final locationPermission = await Geolocator.checkPermission();
    final cameraPermission = await permission_handler.Permission.camera.status;
    if (!mounted) {
      return;
    }

    setState(() {
      _locationPermission = locationPermission;
      _cameraPermission = cameraPermission;
      _checkingPermissions = false;
    });
  }

  bool _isLocationGranted(LocationPermission? permission) {
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  String _locationPermissionLabel() {
    final permission = _locationPermission;
    if (permission == null) {
      return 'Memeriksa izin';
    }
    if (_isLocationGranted(permission)) {
      return 'Diizinkan';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Perlu buka pengaturan';
    }
    return 'Belum diizinkan';
  }

  Color _locationPermissionColor() {
    final permission = _locationPermission;
    if (_isLocationGranted(permission)) {
      return AppColors.green700;
    }
    if (permission == LocationPermission.deniedForever) {
      return AppColors.red600;
    }
    return AppColors.amber600;
  }

  String _locationPermissionDescription() {
    if (_locationPermission == null) {
      return 'Sedang memeriksa status izin lokasi Android Anda.';
    }
    if (_isLocationGranted(_locationPermission)) {
      return 'Android sudah mengizinkan akses lokasi. TrashBounty bisa membaca lokasi saat Anda membuka fitur terkait.';
    }
    if (_locationPermission == LocationPermission.deniedForever) {
      return 'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengaktifkannya kembali.';
    }
    return 'Android belum mengizinkan akses lokasi. Tekan tombol di samping untuk meminta izin.';
  }

  String _locationPermissionActionLabel() {
    if (_locationPermission == LocationPermission.deniedForever || _isLocationGranted(_locationPermission)) {
      return 'Buka Pengaturan';
    }
    return 'Izinkan';
  }

  String _cameraPermissionLabel() {
    final permission = _cameraPermission;
    if (permission == null) {
      return 'Memeriksa izin';
    }
    if (permission.isGranted) {
      return 'Diizinkan';
    }
    if (permission.isPermanentlyDenied) {
      return 'Perlu buka pengaturan';
    }
    return 'Belum diizinkan';
  }

  Color _cameraPermissionColor() {
    final permission = _cameraPermission;
    if (permission?.isGranted == true) {
      return AppColors.green700;
    }
    if (permission?.isPermanentlyDenied == true) {
      return AppColors.red600;
    }
    return AppColors.amber600;
  }

  String _cameraPermissionDescription() {
    final permission = _cameraPermission;
    if (permission == null) {
      return 'Sedang memeriksa status izin kamera Android Anda.';
    }
    if (permission.isGranted) {
      return 'Kamera sudah diizinkan untuk mengambil foto laporan atau bukti penyelesaian bounty.';
    }
    if (permission.isPermanentlyDenied) {
      return 'Izin kamera ditolak permanen. Buka pengaturan aplikasi untuk mengaktifkannya kembali.';
    }
    return 'Aktifkan izin kamera agar Anda bisa mengambil foto langsung dari aplikasi.';
  }

  String _cameraPermissionActionLabel() {
    if (_cameraPermission?.isGranted == true || _cameraPermission?.isPermanentlyDenied == true) {
      return 'Buka Pengaturan';
    }
    return 'Izinkan';
  }

  Future<void> _handleLocationSharingChanged(bool value) async {
    if (!value) {
      setState(() => _locationSharing = false);
      return;
    }

    if (_isLocationGranted(_locationPermission)) {
      setState(() => _locationSharing = true);
      return;
    }

    final granted = await _requestLocationPermission();
    if (!mounted) {
      return;
    }

    setState(() => _locationSharing = granted);

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin lokasi Android perlu diaktifkan lebih dulu.')),
      );
    }
  }

  Future<void> _handleLocationPermissionAction() async {
    if (_locationPermission == LocationPermission.deniedForever || _isLocationGranted(_locationPermission)) {
      await permission_handler.openAppSettings();
      await _refreshPermissionStatuses();
      return;
    }

    final granted = await _requestLocationPermission();
    if (!mounted) {
      return;
    }

    if (granted && (_locationSharing ?? false) == false) {
      setState(() => _locationSharing = true);
    }
  }

  Future<void> _handleCameraPermissionAction() async {
    final permission = _cameraPermission;
    if (permission?.isGranted == true || permission?.isPermanentlyDenied == true) {
      await permission_handler.openAppSettings();
      await _refreshPermissionStatuses();
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Izinkan Kamera'),
        content: const Text('TrashBounty memerlukan akses kamera agar Anda bisa mengambil foto laporan sampah dan bukti penyelesaian bounty langsung dari aplikasi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nanti Saja'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (approved != true) {
      return;
    }

    final status = await permission_handler.Permission.camera.request();
    if (status.isPermanentlyDenied) {
      await permission_handler.openAppSettings();
    }
    await _refreshPermissionStatuses();
  }

  Future<bool> _requestLocationPermission() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Izinkan Lokasi'),
        content: const Text('TrashBounty memerlukan akses lokasi untuk melaporkan sampah dan menemukan bounty terdekat. Saat Android menampilkan izin, pilih "Allow while using the app".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nanti Saja'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (approved != true) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await permission_handler.openAppSettings();
    }

    if (!mounted) {
      return false;
    }

    setState(() {
      _locationPermission = permission;
      _checkingPermissions = false;
    });

    return _isLocationGranted(permission);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put(ApiEndpoints.privacy, data: PrivacySettings(
        publicProfile: _publicProfile ?? false,
        locationSharing: _locationSharing ?? false,
        twoFactorEnabled: _twoFactor ?? false,
      ).toJson());
      ref.invalidate(privacySettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan berhasil disimpan')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan pengaturan')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
