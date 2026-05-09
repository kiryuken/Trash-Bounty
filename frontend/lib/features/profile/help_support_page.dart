import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';

class HelpSupportPage extends ConsumerStatefulWidget {
  const HelpSupportPage({super.key});

  @override
  ConsumerState<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends ConsumerState<HelpSupportPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_SupportMessage> _messages = [
    const _SupportMessage(
      role: _SupportRole.assistant,
      content: 'Halo, aku Lumi. Aku siap bantu menjelaskan fitur TrashBounty, reward, bounty, laporan, dan akun kamu dengan senang hati.',
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    FocusScope.of(context).unfocus();
    _controller.clear();
    setState(() {
      _messages.add(_SupportMessage(role: _SupportRole.user, content: text));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        ApiEndpoints.supportChat,
        data: {
          'messages': _messages
              .map((message) => {
                    'role': message.role == _SupportRole.user ? 'user' : 'assistant',
                    'content': message.content,
                  })
              .toList(),
        },
      );

      final reply = ((response.data['data'] as Map<String, dynamic>?)?['reply'] as String?)?.trim();
      setState(() {
        _messages.add(
          _SupportMessage(
            role: _SupportRole.assistant,
            content: reply?.isNotEmpty == true ? reply! : 'Maaf, Lumi belum bisa menjawab saat ini.',
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.add(
          const _SupportMessage(
            role: _SupportRole.assistant,
            content: 'Koneksi ke Lumi sedang terganggu. Coba lagi beberapa saat lagi.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      child: Text('Bantuan', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Pusat bantuan, FAQ, dan chat bersama Lumi', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeading(
                  title: 'FAQ Cepat',
                  subtitle: 'Jawaban singkat untuk pertanyaan yang paling sering muncul.',
                ),
                _FaqItem(
                  question: 'Bagaimana cara melaporkan sampah?',
                  answer: 'Buka tab "Lapor", ambil foto sampah, dan kirimkan. Lumi akan menganalisis gambar lalu menghitung poin dan estimasi rupiah dengan rasio 10 poin = Rp 1.',
                ),
                _FaqItem(
                  question: 'Bagaimana sistem bounty bekerja?',
                  answer: 'Setelah laporan divalidasi, bounty akan dibuat. Eksekutor mendapat 80% reward bounty saat tugas selesai, sedangkan pelapor mendapat bonus 20%.',
                ),
                _FaqItem(
                  question: 'Berapa lama proses verifikasi Lumi?',
                  answer: 'Proses analisis Lumi biasanya memakan waktu 10-30 detik. Hasilnya akan langsung ditampilkan setelah selesai.',
                ),
                _FaqItem(
                  question: 'Berapa nilai poin dan batas reward?',
                  answer: 'Sekarang 10 poin setara Rp 1. Untuk kasus moderat, total reward bounty dibatasi sampai 100.000 poin atau Rp 10.000.',
                ),
                _FaqItem(
                  question: 'Bagaimana cara mencairkan poin?',
                  answer: 'Poin dapat dicairkan melalui menu Profil > Dompet. Minimal pencairan adalah 50.000 poin, setara Rp 5.000 dengan rasio sekarang.',
                ),
                _FaqItem(
                  question: 'Saya menemukan bug, bagaimana melaporkan?',
                  answer: 'Silakan kirim email ke support@trashbounty.id dengan detail masalah yang Anda temukan.',
                ),
                const SizedBox(height: 16),
                const _SectionHeading(
                  title: 'Chat dengan Lumi',
                  subtitle: 'Gunakan chat ini untuk bertanya soal reward, bounty, laporan, atau akun Anda.',
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.green100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.messagesSquare, size: 18, color: Colors.white),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Lumi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                                  SizedBox(height: 2),
                                  Text('Asisten ceria TrashBounty yang siap membantu', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_messages.length == 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Container(
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
                                Icon(LucideIcons.sparkles, size: 16, color: AppColors.green700),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tanya apapun tentang TrashBounty. Lumi akan membantu menjelaskan alur laporan, bounty, dan reward Anda dengan jelas.',
                                    style: TextStyle(color: AppColors.green700, fontSize: 12.5, height: 1.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 320,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) => _ChatBubble(message: _messages[index]),
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemCount: _messages.length,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 4,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: InputDecoration(
                                  hintText: 'Tanya Lumi...',
                                  filled: true,
                                  fillColor: AppColors.gray50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 48,
                              width: 48,
                              child: ElevatedButton(
                                onPressed: _sending ? null : _sendMessage,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: _sending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(LucideIcons.send, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionHeading(
                  title: 'Hubungi Tim',
                  subtitle: 'Jika membutuhkan bantuan manual, kirim detail masalah langsung ke tim support.',
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.green50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.green200),
                  ),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.headphones, size: 40, color: AppColors.green600),
                      const SizedBox(height: 12),
                      const Text('Butuh bantuan lain?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.gray800)),
                      const SizedBox(height: 4),
                      const Text('Hubungi tim support kami', style: TextStyle(color: AppColors.gray500, fontSize: 14)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(LucideIcons.mail, size: 16),
                          label: const Text('support@trashbounty.id'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.green600,
                            side: const BorderSide(color: AppColors.green300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SupportRole { user, assistant }

class _SupportMessage {
  final _SupportRole role;
  final String content;

  const _SupportMessage({required this.role, required this.content});
}

class _ChatBubble extends StatelessWidget {
  final _SupportMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _SupportRole.user;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isUser) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.bot, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? AppColors.green600 : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 16),
              ),
              border: isUser ? null : Border.all(color: AppColors.gray100),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.gray700,
                height: 1.4,
              ),
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.green100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, size: 16, color: AppColors.green700),
          ),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
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
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray800, fontSize: 14),
                      ),
                    ),
                    Icon(
                      _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 18,
                      color: AppColors.gray400,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  Text(widget.answer, style: const TextStyle(color: AppColors.gray600, fontSize: 14, height: 1.5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
