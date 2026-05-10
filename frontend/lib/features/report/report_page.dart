import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import 'package:dio/dio.dart' as dio_pkg;

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

enum _Stage { upload, analyzing, result }

const _agencyRecipient = 'dinaslh@jakarta.go.id';
const _analyzedReportStatuses = {'approved', 'bounty_created', 'completed', 'rejected'};

class _ReportPageState extends ConsumerState<ReportPage> {
  _Stage _stage = _Stage.upload;
  File? _imageFile;
  String _locationText = 'Lokasi belum ditambahkan';
  String _description = '';
  Map<String, dynamic>? _reportResult; // full report from GET /reports/{id}
  bool _approved = false;
  double? _latitude;
  double? _longitude;
  String? _analyzeStatus; // current poll status text
  double? _analyzeProgress;
  bool _isDetectingLocation = false;
  bool _showLocationValidationError = false;
  String _analysisErrorMessage = 'Coba lagi nanti';
  bool _isEscalatingAgency = false;
  bool _pollRequestInFlight = false;
  int _pollGeneration = 0;
  Timer? _pollTimer;

  @override
  void dispose() {
    _cancelPolling();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchReportDetail(String reportId) async {
    final client = ref.read(dioProvider);
    final response = await client.get(ApiEndpoints.reportDetail(reportId));
    return response.data['data'] as Map<String, dynamic>?;
  }

  Future<void> _detectLocation() async {
    if (_isDetectingLocation) return;

    setState(() {
      _isDetectingLocation = true;
      _showLocationValidationError = false;
      _locationText = 'Mendeteksi lokasi...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _latitude = null;
          _longitude = null;
          _locationText = 'Layanan lokasi belum aktif';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _latitude = null;
          _longitude = null;
          _locationText = 'Izin lokasi ditolak';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationText = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      });
    } catch (error, stackTrace) {
      logAppError('Failed to detect report location', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _latitude = null;
        _longitude = null;
        _locationText = 'Gagal mendeteksi lokasi';
      });
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (xFile != null) {
      setState(() => _imageFile = File(xFile.path));
    }
  }

  Future<void> _submit() async {
    if (_imageFile == null) return;
    if (_latitude == null || _longitude == null) {
      setState(() => _showLocationValidationError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi wajib diisi sebelum laporan dikirim.')),
      );
      return;
    }

    final note = await _showLocationConfirmationDialog();
    if (note == null || !mounted) return;

    _description = note;
    setState(() {
      _stage = _Stage.analyzing;
      _analyzeStatus = 'Mengirim laporan...';
      _analyzeProgress = 0;
      _analysisErrorMessage = 'Coba lagi nanti';
    });

    try {
      final client = ref.read(dioProvider);
      final formData = dio_pkg.FormData.fromMap({
        'image': await dio_pkg.MultipartFile.fromFile(_imageFile!.path),
        'location_text': _locationText,
        'description': _description,
        'latitude': _latitude.toString(),
        'longitude': _longitude.toString(),
      });
      final response = await client.post(ApiEndpoints.reports, data: formData);
      final data = response.data['data'] as Map<String, dynamic>?;
      final reportId = data?['report_id'] as String?;

      if (reportId == null) {
        _setError('Laporan diterima tapi ID laporan tidak ditemukan.');
        return;
      }

      setState(() {
        _analyzeStatus = 'Laporan diterima. Menunggu antrean analisis...';
        _analyzeProgress = 0;
      });
      _startPolling(reportId);
    } catch (error, stackTrace) {
      logAppError('Failed to submit report', error, stackTrace);
      _setError(
        extractErrorMessage(
          error,
          fallbackMessage: 'Gagal mengirim laporan. Coba lagi.',
        ),
      );
    }
  }

  Future<String?> _showLocationConfirmationDialog() async {
    final noteController = TextEditingController(text: _description);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Lokasi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Apa lokasi sudah sesuai? Jika belum, tambahkan note untuk penyesuaian.'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.green200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.mapPin, size: 18, color: AppColors.green600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationText,
                        style: const TextStyle(
                          color: AppColors.gray700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note lokasi (opsional)',
                  hintText: 'Contoh: titik sampah agak geser ke samping gerbang atau dekat selokan',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cek Lagi'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(noteController.text.trim()),
              child: const Text('Lokasi Sudah Sesuai'),
            ),
          ],
        );
      },
    );

    noteController.dispose();
    return result;
  }

  void _cancelPolling() {
    _pollGeneration++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollRequestInFlight = false;
  }

  void _stopPollingTimer(Timer timer) {
    timer.cancel();
    if (identical(_pollTimer, timer)) {
      _pollTimer = null;
    }
  }

  String _backendAnalyzeStatus(String? status, double? progress) {
    switch (status) {
      case 'pending':
        return 'Laporan menunggu antrean analisis...';
      case 'ai_analyzing':
        if (progress != null) {
          return 'Lumi sedang menganalisis gambar (${progress.round()}%)...';
        }
        return 'Lumi sedang menganalisis gambar...';
      case 'approved':
      case 'bounty_created':
      case 'completed':
        return 'Analisis selesai. Mengambil hasil laporan...';
      case 'rejected':
        return 'Analisis selesai. Menyiapkan hasil penolakan...';
      default:
        return 'Lumi sedang memproses laporan...';
    }
  }

  void _startPolling(String reportId) {
    const maxAttempts = 60; // 60 × 3s = 3 minutes max
    int attempts = 0;
    _cancelPolling();
    final pollGeneration = _pollGeneration;

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
	  if (_pollRequestInFlight) {
		  return;
	  }

      attempts++;
      if (attempts > maxAttempts) {
        _setError('Analisis Lumi melebihi batas waktu. Coba lagi nanti.');
        return;
      }

    _pollRequestInFlight = true;

      try {
        final client = ref.read(dioProvider);
        final statusResp = await client.get(ApiEndpoints.reportStatus(reportId));
        final statusData = statusResp.data['data'] as Map<String, dynamic>?;
        final status = statusData?['status'] as String?;
        final progress = (statusData?['progress'] as num?)?.toDouble();
          final clampedProgress = progress?.clamp(0, 100).toDouble();

        if (!mounted || pollGeneration != _pollGeneration) {
          _stopPollingTimer(timer);
          return;
        }

        if (status == 'ai_analyzing' || status == 'pending') {
          setState(() {
            _analyzeStatus = _backendAnalyzeStatus(status, clampedProgress);
            _analyzeProgress = clampedProgress;
          });
          return;
        }

        _stopPollingTimer(timer);
        final report = await _fetchReportDetail(reportId);

        if (!mounted || pollGeneration != _pollGeneration) {
          return;
        }

        setState(() {
          _reportResult = report;
          _analyzeStatus = _backendAnalyzeStatus(status, clampedProgress ?? 100);
          _analyzeProgress = 100;
          _approved = report?['status'] == 'approved' ||
              report?['status'] == 'bounty_created' ||
              report?['status'] == 'completed';
          _stage = _Stage.result;
        });
      } catch (error, stackTrace) {
        logAppError('Report polling failed', error, stackTrace);
        if (attempts >= maxAttempts) {
          _setError(
            extractErrorMessage(
              error,
              fallbackMessage: 'Gagal memeriksa status laporan.',
            ),
          );
        }
      } finally {
        _pollRequestInFlight = false;
      }
    });
  }

  void _setError([String message = 'Coba lagi nanti']) {
    _cancelPolling();
    if (!mounted) return;
    setState(() {
      _reportResult = null;
      _approved = false;
      _analyzeProgress = null;
      _analysisErrorMessage = message;
      _stage = _Stage.result;
    });
  }

  bool _canEscalateToAgency(Map<String, dynamic>? report) {
    final status = report?['status'] as String?;
    return status != null && _analyzedReportStatuses.contains(status);
  }

  Future<String?> _showAgencyEscalationDialog() async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? validationError;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Lapor ke Dinas'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email laporan akan dikirim ke $_agencyRecipient beserta foto report. Jelaskan alasan urgensinya agar dinas bisa menilai prioritas penanganan.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Alasan urgensi',
                      hintText: 'Contoh: sampah menutup saluran air dan berisiko memicu banjir lokal.',
                      border: const OutlineInputBorder(),
                      errorText: validationError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final trimmed = reasonController.text.trim();
                    if (trimmed.isEmpty) {
                      setDialogState(() => validationError = 'Alasan urgensi wajib diisi.');
                      return;
                    }
                    Navigator.of(dialogContext).pop(trimmed);
                  },
                  child: const Text('Kirim ke Dinas'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
    return result;
  }

  Future<void> _submitAgencyEscalation() async {
    final reportId = _reportResult?['id'] as String?;
    if (reportId == null || _isEscalatingAgency) return;

    final urgencyReason = await _showAgencyEscalationDialog();
    if (urgencyReason == null || !mounted) return;

    final previousReport = _reportResult == null ? null : Map<String, dynamic>.from(_reportResult!);
    setState(() {
      _isEscalatingAgency = true;
      _reportResult = {
        ...?_reportResult,
        'agency_escalation_status': 'pending',
        'agency_escalation_reason': urgencyReason,
        'agency_escalation_requested_at': DateTime.now().toUtc().toIso8601String(),
        'agency_escalation_sent_at': null,
        'agency_escalation_failed_at': null,
        'agency_escalation_last_error': null,
      };
    });

    try {
      final client = ref.read(dioProvider);
      await client.post(
        ApiEndpoints.reportEscalate(reportId),
        data: {'urgency_reason': urgencyReason},
      );

      final refreshed = await _fetchReportDetail(reportId);
      if (!mounted) return;
      setState(() {
        _reportResult = refreshed ?? _reportResult;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan sedang diteruskan ke dinas lingkungan hidup.')),
      );
    } catch (error, stackTrace) {
      logAppError('Failed to escalate report to agency', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _reportResult = previousReport;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extractErrorMessage(
              error,
              fallbackMessage: 'Gagal meneruskan laporan ke dinas. Coba lagi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isEscalatingAgency = false);
      }
    }
  }

  Widget _buildAgencyEscalationCard() {
    if (!_canEscalateToAgency(_reportResult)) {
      return const SizedBox.shrink();
    }

    final escalationStatus = _reportResult?['agency_escalation_status'] as String?;
    final escalationReason = (_reportResult?['agency_escalation_reason'] as String?)?.trim();
    final lastError = (_reportResult?['agency_escalation_last_error'] as String?)?.trim();

    Color backgroundColor;
    Color borderColor;
    Color accentColor;
    IconData icon;
    String title;
    String description;
    String? actionLabel;

    switch (escalationStatus) {
      case 'pending':
        backgroundColor = AppColors.amber50;
        borderColor = AppColors.amber100;
        accentColor = AppColors.amber600;
        icon = LucideIcons.clock3;
        title = 'Sedang diteruskan ke dinas';
        description = 'Email laporan sedang diproses untuk dikirim ke $_agencyRecipient.';
        actionLabel = null;
      case 'sent':
        backgroundColor = AppColors.green50;
        borderColor = AppColors.green100;
        accentColor = AppColors.green700;
        icon = LucideIcons.mailCheck;
        title = 'Laporan sudah diteruskan';
        description = 'Email laporan dan foto sudah diteruskan ke $_agencyRecipient.';
        actionLabel = null;
      case 'failed':
        backgroundColor = AppColors.red50;
        borderColor = AppColors.red200;
        accentColor = AppColors.red600;
        icon = LucideIcons.mailWarning;
        title = 'Pengiriman ke dinas gagal';
        description = lastError?.isNotEmpty == true
            ? lastError!
            : 'Coba kirim lagi ketika koneksi backend atau email service sudah normal.';
        actionLabel = 'Coba Kirim Lagi';
      default:
        backgroundColor = AppColors.blue50;
        borderColor = AppColors.blue100;
        accentColor = AppColors.blue600;
        icon = LucideIcons.mail;
        title = 'Butuh penanganan dinas?';
        description = 'Jika kasus ini memang perlu tindak lanjut resmi, Anda bisa meneruskan laporan beserta foto ke $_agencyRecipient.';
        actionLabel = 'Lapor ke Dinas';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(color: AppColors.gray700, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (escalationReason != null && escalationReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alasan urgensi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    escalationReason,
                    style: const TextStyle(color: AppColors.gray700, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isEscalatingAgency ? null : _submitAgencyEscalation,
                icon: _isEscalatingAgency
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(actionLabel == 'Coba Kirim Lagi' ? LucideIcons.refreshCw : LucideIcons.send, size: 18),
                label: Text(_isEscalatingAgency ? 'Mengirim...' : actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _reset() {
    _cancelPolling();
    setState(() {
      _stage = _Stage.upload;
      _imageFile = null;
      _locationText = 'Lokasi belum ditambahkan';
      _description = '';
      _reportResult = null;
      _analyzeStatus = null;
      _analyzeProgress = null;
      _latitude = null;
      _longitude = null;
      _isDetectingLocation = false;
      _showLocationValidationError = false;
      _analysisErrorMessage = 'Coba lagi nanti';
      _isEscalatingAgency = false;
    });
  }

  List<String> _reasoningSections(String reasoning) {
    final normalized = reasoning
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\s*\|\s*'), '\n');

    final sections = normalized
        .split(RegExp(r'\n+'))
        .map((part) => part.trim())
        .map((part) => part.replaceFirst(RegExp(r'^[-*•]\s*'), ''))
        .where((part) => part.isNotEmpty)
        .toList();

    if (sections.length == 1 && sections.first.length > 140) {
      return sections.first
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }

    return sections;
  }

  Widget _buildAiReasoningPanel({
    required String title,
    required String reasoning,
    required Color accentColor,
    required Color backgroundColor,
    required Color borderColor,
    required IconData icon,
  }) {
    final sections = _reasoningSections(reasoning);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < sections.length; index++) ...[
            _buildAiReasoningItem(
              text: sections[index],
              accentColor: accentColor,
            ),
            if (index != sections.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildAiReasoningItem({
    required String text,
    required Color accentColor,
  }) {
    final separatorIndex = text.indexOf(':');
    final hasLabel = separatorIndex > 0 && separatorIndex <= 18;
    final label = hasLabel ? text.substring(0, separatorIndex).trim() : null;
    final content = hasLabel ? text.substring(separatorIndex + 1).trim() : text;
    final displayText = content.isEmpty ? text : content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null && label.isNotEmpty) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            displayText,
            style: const TextStyle(
              color: AppColors.gray600,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                      child: Text('Lapor Sampah', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Bantu jaga kebersihan lingkungan', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_stage) {
      case _Stage.upload:
        return _buildUploadForm();
      case _Stage.analyzing:
        return _buildAnalyzing();
      case _Stage.result:
        return _buildResult();
    }
  }

  Widget _buildUploadForm() {
    return Column(
      children: [
        // Image upload
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray100),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload Foto', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray700)),
              const SizedBox(height: 12),
              if (_imageFile != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, height: 256, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _imageFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: AppColors.red500, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.xCircle, size: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                GestureDetector(
                  onTap: () => _showImageSourceDialog(),
                  child: Container(
                    height: 256,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray300, width: 2, strokeAlign: BorderSide.strokeAlignInside),
                      color: AppColors.gray50,
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.camera, size: 48, color: AppColors.gray400),
                          SizedBox(height: 12),
                          Text('Ambil Foto', style: TextStyle(color: AppColors.gray600)),
                          SizedBox(height: 4),
                          Text('atau pilih dari galeri', style: TextStyle(color: AppColors.gray400, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Location
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _showLocationValidationError ? AppColors.red200 : AppColors.gray100,
              width: _showLocationValidationError ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, color: AppColors.green600, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lokasi', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray700)),
                        const SizedBox(height: 4),
                        Text(
                          _locationText,
                          style: TextStyle(
                            color: _latitude != null && _longitude != null ? AppColors.gray700 : AppColors.gray500,
                            fontSize: 13,
                            fontWeight: _latitude != null && _longitude != null ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isDetectingLocation ? null : _detectLocation,
                  icon: _isDetectingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_latitude == null ? LucideIcons.mapPin : LucideIcons.refreshCw, size: 18),
                  label: Text(_latitude == null ? 'Tambah Lokasi' : 'Perbarui Lokasi'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _showLocationValidationError
                    ? 'Lokasi wajib diisi sebelum laporan dikirim.'
                    : 'Izin lokasi hanya akan diminta saat Anda menambahkan lokasi.',
                style: TextStyle(
                  color: _showLocationValidationError ? AppColors.red500 : AppColors.gray500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Description
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray100),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray700)),
                  SizedBox(width: 4),
                  Text('(Opsional)', style: TextStyle(color: AppColors.gray400, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                onChanged: (v) => _description = v,
                decoration: const InputDecoration(
                  hintText: 'Tambahkan detail lokasi sampah...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Submit
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _imageFile != null ? _submit : null,
            icon: const Icon(LucideIcons.upload, size: 20),
            label: const Text('Kirim untuk Analisis Lumi'),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzing() {
    final progress = _analyzeProgress == null
        ? null
        : (_analyzeProgress!.clamp(0, 100) / 100).toDouble();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.green600,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Menganalisis Gambar...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.gray800)),
          const SizedBox(height: 8),
          Text(
            _analyzeStatus ?? 'Lumi sedang memproses...',
            style: const TextStyle(color: AppColors.gray500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: AppColors.green600,
              backgroundColor: AppColors.green100,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress == null
                ? 'Menunggu status terbaru dari server...'
                : '${_analyzeProgress!.round()}% berdasarkan status backend',
            style: const TextStyle(color: AppColors.gray500, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gray100),
            ),
            child: const Text(
              'Status analisis diambil langsung dari backend. Jika server sedang sibuk, progres dapat tertahan di status yang sama sampai ada update baru.',
              style: TextStyle(color: AppColors.gray600, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_reportResult == null && !_approved) {
      return _buildError();
    }

    final severity = (_reportResult?['severity'] as num?)?.toInt() ?? 0;
    final wasteType = _reportResult?['waste_type'] as String?;
    final pointsEarned = (_reportResult?['points_earned'] as num?)?.toInt() ?? 0;
    final rewardIdr = (_reportResult?['reward_idr'] as num?)?.toDouble() ?? 0;
    final aiConfidence = (_reportResult?['ai_confidence'] as num?)?.toDouble() ?? 0;
    final aiReasoning = _reportResult?['ai_reasoning'] as String?;
    final estimatedWeightKg = (_reportResult?['estimated_weight_kg'] as num?)?.toDouble();
    final impactScore = severity * (estimatedWeightKg ?? 1);
    final impactLabel = impactScore >= 40
        ? 'Tinggi'
        : impactScore >= 18
            ? 'Sedang'
            : 'Rendah';
    final impactColor = impactLabel == 'Tinggi'
        ? AppColors.red500
        : impactLabel == 'Sedang'
            ? AppColors.amber600
            : AppColors.green600;

    return Column(
      children: [
        // Status banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _approved ? AppColors.green50 : AppColors.red50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _approved ? AppColors.green200 : AppColors.red200, width: 2),
          ),
          child: Column(
            children: [
              Icon(
                _approved ? LucideIcons.checkCircle : LucideIcons.xCircle,
                size: 64,
                color: _approved ? AppColors.green500 : AppColors.red500,
              ),
              const SizedBox(height: 12),
              Text(
                _approved ? 'Laporan Disetujui!' : 'Laporan Ditolak',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _approved ? AppColors.green800 : AppColors.red600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _approved ? 'Laporan Anda telah divalidasi oleh Lumi' : 'Lumi belum dapat memvalidasi laporan ini',
                style: TextStyle(color: _approved ? AppColors.green600 : AppColors.red500),
              ),
            ],
          ),
        ),

        if (_approved && _reportResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hasil Analisis Lumi', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray700)),
                const SizedBox(height: 12),

                // Waste type
                if (wasteType != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jenis Sampah', style: TextStyle(color: AppColors.gray600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          wasteType.toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Severity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Skor Keparahan', style: TextStyle(color: AppColors.gray600)),
                    Text(
                      '$severity/10',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.red600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: severity / 10,
                    minHeight: 8,
                    backgroundColor: AppColors.gray200,
                    valueColor: const AlwaysStoppedAnimation(AppColors.amber500),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.green50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.green100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimasi Dampak',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray700),
                      ),
                      const SizedBox(height: 8),
                      if (estimatedWeightKg != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Berat sampah', style: TextStyle(color: AppColors.gray600)),
                            Text(
                              '${estimatedWeightKg.toStringAsFixed(1)} kg',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green700),
                            ),
                          ],
                        ),
                      if (estimatedWeightKg != null) const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Level dampak', style: TextStyle(color: AppColors.gray600)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: impactColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              impactLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: impactColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        estimatedWeightKg != null
                            ? 'Perkiraan ini membantu memprioritaskan bounty berdasarkan keparahan dan volume sampah.'
                            : 'Level dampak dihitung dari tingkat keparahan laporan untuk membantu prioritas penanganan.',
                        style: const TextStyle(color: AppColors.gray600, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // AI Confidence
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Akurasi Lumi', style: TextStyle(color: AppColors.gray600)),
                    Text(
                      '${(aiConfidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Reward
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reward Poin', style: TextStyle(color: AppColors.gray600)),
                    Text(
                      '$pointsEarned Poin',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.amber600),
                    ),
                  ],
                ),
                if (rewardIdr > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reward IDR', style: TextStyle(color: AppColors.gray600)),
                      Text(
                        'Rp ${rewardIdr.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Konversi reward: 10 poin = Rp 1. Reward moderat dibatasi sampai Rp 10.000.',
                    style: TextStyle(color: AppColors.gray500, fontSize: 12, height: 1.4),
                  ),
                ],

                // AI Reasoning
                if (aiReasoning != null && aiReasoning.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildAiReasoningPanel(
                    title: 'Catatan Lumi',
                    reasoning: aiReasoning,
                    accentColor: AppColors.green700,
                    backgroundColor: AppColors.green50,
                    borderColor: AppColors.green100,
                    icon: LucideIcons.fileText,
                  ),
                ],
              ],
            ),
          ),
        ],

        if (!_approved && _reportResult != null && aiReasoning != null && aiReasoning.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildAiReasoningPanel(
            title: 'Penjelasan Lumi',
            reasoning: aiReasoning,
            accentColor: AppColors.red600,
            backgroundColor: AppColors.red50,
            borderColor: AppColors.red200,
            icon: LucideIcons.alertCircle,
          ),
        ],

        if (_reportResult != null) ...[
          const SizedBox(height: 12),
          _buildAgencyEscalationCard(),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _reset,
            child: const Text('Buat Laporan Baru'),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.red50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red200, width: 2),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.xCircle, size: 64, color: AppColors.red500),
          const SizedBox(height: 12),
          const Text('Gagal Menganalisis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.red600)),
          const SizedBox(height: 4),
          Text(_analysisErrorMessage, style: const TextStyle(color: AppColors.gray500), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _reset, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.camera, color: AppColors.green600),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.image, color: AppColors.green600),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
