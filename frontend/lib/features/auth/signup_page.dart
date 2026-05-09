import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  String? _selectedRole;
  bool _showForm = false;
  bool _showPassword = false;
  bool _loading = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
            _selectedRole!,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        final message = _getErrorMessage(e);
        final isRoleConflict = message.contains('sudah terdaftar sebagai');
        ScaffoldMessenger.of(context).showSnackBar(_buildErrorSnackBar(message, isRoleConflict: isRoleConflict));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getErrorMessage(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.error is SocketException) {
        return 'Server tidak dapat dihubungi. Pastikan koneksi internet aktif dan coba lagi.';
      }

      final data = e.response?.data;
      if (data is Map && data['error'] is String) {
        final message = (data['error'] as String).trim();
        if (message.isNotEmpty) {
          return message;
        }
      }

      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Terjadi kesalahan';
  }

  SnackBar _buildErrorSnackBar(String message, {bool isRoleConflict = false}) {
    final backgroundColor = isRoleConflict ? const Color(0xFF9A3412) : AppColors.red600;
    final icon = isRoleConflict ? Icons.warning_amber_rounded : Icons.error_outline_rounded;

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('Pendaftaran gagal: $message')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(48),
                    bottomRight: Radius.circular(48),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 40,
                  bottom: 80,
                  left: 24,
                  right: 24,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 4,
                          ),
                        ),
                        child: const Icon(LucideIcons.leaf, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TrashBounty Lumi',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _showForm ? 'Daftar sebagai ${_selectedRole == 'reporter' ? 'Pelapor' : 'Eksekutor'}' : 'Buat Akun Baru',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _showForm ? _buildForm() : _buildRoleSelection(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Daftar Sebagai', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.gray800)),
              const SizedBox(height: 4),
              const Text('Pilih role Anda', style: TextStyle(fontSize: 14, color: AppColors.gray500)),
              const SizedBox(height: 24),
              _buildRoleCard(
                icon: LucideIcons.camera,
                title: 'Pelapor',
                subtitle: 'Laporkan sampah di sekitar Anda',
                colors: const [AppColors.green500, AppColors.emerald500],
                bgColor: AppColors.green50,
                role: 'reporter',
              ),
              const SizedBox(height: 12),
              _buildRoleCard(
                icon: LucideIcons.mapPin,
                title: 'Eksekutor',
                subtitle: 'Bersihkan sampah dan dapatkan poin',
                colors: const [AppColors.emerald500, AppColors.green500],
                bgColor: AppColors.emerald50,
                role: 'executor',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Sudah punya akun? ', style: TextStyle(color: AppColors.gray600)),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: const Text('Masuk', style: TextStyle(color: AppColors.green600, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required Color bgColor,
    required String role,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => setState(() {
          _selectedRole = role;
          _showForm = true;
        }),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.green200, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.gray600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _showForm = false),
              child: const Text('← Kembali', style: TextStyle(color: AppColors.green600, fontSize: 14)),
            ),
            const SizedBox(height: 16),
            const Center(child: Text('Daftar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.gray800))),
            const SizedBox(height: 24),
            const Text('Nama Lengkap', style: TextStyle(fontSize: 14, color: AppColors.gray700)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Masukkan nama lengkap',
                prefixIcon: Icon(LucideIcons.user, size: 20, color: AppColors.gray400),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            const Text('Email', style: TextStyle(fontSize: 14, color: AppColors.gray700)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'email@example.com',
                prefixIcon: Icon(LucideIcons.mail, size: 20, color: AppColors.gray400),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email wajib diisi';
                if (!v.contains('@')) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Kata Sandi', style: TextStyle(fontSize: 14, color: AppColors.gray700)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                hintText: 'Minimal 8 karakter',
                prefixIcon: const Icon(LucideIcons.lock, size: 20, color: AppColors.gray400),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 20, color: AppColors.gray400),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password wajib diisi';
                if (v.length < 8) return 'Minimal 8 karakter';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleSignup,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Daftar'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sudah punya akun? ', style: TextStyle(color: AppColors.gray600)),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text('Masuk', style: TextStyle(color: AppColors.green600, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
