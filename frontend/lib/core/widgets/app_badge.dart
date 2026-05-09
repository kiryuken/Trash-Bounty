import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;

  const AppBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
  });

  factory AppBadge.severity(int severity) {
    Color bg;
    Color text;
    if (severity >= 8) {
      bg = AppColors.red100;
      text = AppColors.red600;
    } else if (severity >= 5) {
      bg = AppColors.amber100;
      text = AppColors.amber600;
    } else {
      bg = AppColors.green100;
      text = AppColors.green700;
    }
    return AppBadge(label: 'Severity $severity', backgroundColor: bg, textColor: text);
  }

  static String normalizeStatus(String status) {
    return status.trim().toLowerCase().replaceAll('-', '_');
  }

  static String statusLabel(String status) {
    switch (normalizeStatus(status)) {
      case 'completed':
        return 'Selesai';
      case 'approved':
        return 'Disetujui';
      case 'bounty_created':
        return 'Bounty Dibuat';
      case 'in_progress':
        return 'Dalam Proses';
      case 'taken':
        return 'Diambil';
      case 'ai_analyzing':
        return 'Sedang Dianalisis';
      case 'rejected':
        return 'Ditolak';
      case 'disputed':
        return 'Dispute';
      case 'cancelled':
        return 'Dibatalkan';
      case 'open':
        return 'Terbuka';
      case 'pending':
        return 'Menunggu';
      default:
        return status;
    }
  }

  factory AppBadge.status(String status) {
    final normalizedStatus = normalizeStatus(status);
    Color bg;
    Color text;
    switch (normalizedStatus) {
      case 'completed' || 'approved' || 'bounty_created':
        bg = AppColors.green100;
        text = AppColors.green700;
      case 'in_progress' || 'taken' || 'ai_analyzing':
        bg = AppColors.amber100;
        text = AppColors.amber600;
      case 'rejected' || 'disputed' || 'cancelled':
        bg = AppColors.red100;
        text = AppColors.red600;
      case 'open' || 'pending':
        bg = AppColors.blue100;
        text = AppColors.blue600;
      default:
        bg = AppColors.gray100;
        text = AppColors.gray600;
    }
    return AppBadge(label: statusLabel(status), backgroundColor: bg, textColor: text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.green100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppColors.green700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
