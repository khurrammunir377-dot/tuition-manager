with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

marker = '// ============================================================================\n// 1. WhatsApp Voice & Video Call Session Manager with Live Duration & Quran Mode'
pos = text.find(marker)
if pos != -1:
    text = text[:pos]

clean_code = """// ============================================================================
// 1. WhatsApp Voice & Video Call Session Manager with Live Duration & Quran Mode
// ============================================================================
class CallSessionManager {
  static final CallSessionManager instance = CallSessionManager._();
  CallSessionManager._();

  Student? activeStudent;
  DateTime? callStartTime;
  Timer? _timer;
  int elapsedSeconds = 0;
  final ValueNotifier<int> durationNotifier = ValueNotifier<int>(0);
  bool isVideoCall = false;

  void startCall(BuildContext context, Student student, {bool video = false}) async {
    activeStudent = student;
    isVideoCall = video;
    callStartTime = DateTime.now();
    elapsedSeconds = 0;
    durationNotifier.value = 0;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      elapsedSeconds++;
      durationNotifier.value = elapsedSeconds;
    });

    // Launch WhatsApp
    var p = student.phone.replaceAll(RegExp(r'\\D'), '');
    if (p.startsWith('0')) p = '92${p.substring(1)}';
    final callType = video ? 'ویڈیو کال (Video Call)' : 'وائس کال (Voice Call)';
    final msg = 'السلام علیکم ورحمۃ اللہ!\\nآن لائن کلاس / قرآن پاک تلاوت: استاد $callType شروع کر رہے ہیں، برائے مہربانی کال اٹھائیں۔';
    final uri = Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(msg)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);

    // Show floating Active Call bottom banner / dialog with Quran & End buttons
    _showActiveCallOverlay(context);
  }

  void _showActiveCallOverlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ActiveCallSheet(
        student: activeStudent!,
        isVideo: isVideoCall,
        durationNotifier: durationNotifier,
        onEndCall: () => endCall(context),
      ),
    );
  }

  void endCall(BuildContext context) {
    _timer?.cancel();
    final duration = elapsedSeconds;
    final st = activeStudent;
    activeStudent = null;
    elapsedSeconds = 0;

    if (st == null) return;

    final mins = duration ~/ 60;
    final secs = duration % 60;
    final durationStr = mins > 0 ? '$mins منٹ $secs سیکنڈ' : '$secs سیکنڈ';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (d) => _CallSummaryDialog(
        student: st,
        durationStr: durationStr,
        isVideo: isVideoCall,
      ),
    );
  }
}

class _ActiveCallSheet extends StatelessWidget {
  final Student student;
  final bool isVideo;
  final ValueNotifier<int> durationNotifier;
  final VoidCallback onEndCall;

  const _ActiveCallSheet({
    required this.student,
    required this.isVideo,
    required this.durationNotifier,
    required this.onEndCall,
  });

  String _formatDuration(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isVideo ? Colors.tealAccent.shade700 : const Color(0xFF25D366),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'کال جاری ہے: ${student.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: durationNotifier,
                      builder: (_, secs, __) => Text(
                        'دورانیہ: ${_formatDuration(secs)}',
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: 'چھپائیں (کال پس منظر میں جاری رہے گی)',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFDE68A),
                    foregroundColor: const Color(0xFF042F2E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text(
                    '📖 قرآن پاک کھولیں (سبق سنیں)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuranReaderScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                icon: const Icon(Icons.call_end_rounded, size: 18),
                label: const Text(
                  'کال ختم کریں',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onEndCall();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallSummaryDialog extends StatelessWidget {
  final Student student;
  final String durationStr;
  final bool isVideo;

  const _CallSummaryDialog({
    required this.student,
    required this.durationStr,
    required this.isVideo,
  });

  void _sendDurationWhatsApp(BuildContext context) {
    var p = student.phone.replaceAll(RegExp(r'\\D'), '');
    if (p.startsWith('0')) p = '92${p.substring(1)}';
    final now = DateTime.now();
    final callType = isVideo ? 'آن لائن ویڈیو کلاس' : 'آن لائن وائس کلاس / تلاوت';
    final msg = '''السلام علیکم ورحمۃ اللہ!
محترم والدین / طالب علم ${student.name}!
آج بتاریخ ${now.day}/${now.month}/${now.year} $callType کامیابی سے مکمل ہوئی۔
⏱️ کال دورانیہ: $durationStr

بارک اللہ فیکم و جزاکم اللہ خيراً۔
— ٹیوشن و قرآن اکیڈمی''';

    final uri = Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(msg)}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.check_circle_rounded, color: Color(0xFF0F7B5F), size: 28),
          SizedBox(width: 10),
          Text('کال کامیابی سے مکمل ہوئی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFF0F766E), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('طالب علم: ${student.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('کل دورانیہ: $durationStr', style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'کیا آپ والدین اور طالب علم کو کال کے دورانیے کا خودکار واٹس ایپ میسج بھیجنا چاہتے ہیں؟',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('چھوڑ دیں (Skip)'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('واٹس ایپ میسج بھیجیں'),
          onPressed: () {
            _sendDurationWhatsApp(context);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ============================================================================
// 2. Auto App Update Check from Vercel version.json
// ============================================================================
Future<void> checkForAppUpdate(BuildContext context) async {
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    final req = await client.getUrl(Uri.parse('https://kmb-teacher.vercel.app/version.json'));
    final res = await req.close();
    if (res.statusCode == 200) {
      final text = await res.transform(utf8.decoder).join();
      final data = jsonDecode(text) as Map<String, dynamic>;
      final remoteVersion = data['version'] as String? ?? '1.0.0';
      const localVersion = '1.1.0';

      if (_isVersionGreater(remoteVersion, localVersion) && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (d) => _AppUpdateDialog(updateData: data),
        );
      }
    }
  } catch (_) {}
}

bool _isVersionGreater(String remote, String local) {
  final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (int i = 0; i < max(r.length, l.length); i++) {
    final rv = i < r.length ? r[i] : 0;
    final lv = i < l.length ? l[i] : 0;
    if (rv > lv) return true;
    if (rv < lv) return false;
  }
  return false;
}

class _AppUpdateDialog extends StatelessWidget {
  final Map<String, dynamic> updateData;
  const _AppUpdateDialog({required this.updateData});

  @override
  Widget build(BuildContext context) {
    final ver = updateData['version'] ?? '1.2.0';
    final notes = updateData['notes_ur'] ?? 'نئی خصوصیات اور اصلاحات شامل کی گئی ہیں۔';
    final downloadUrl = updateData['apk_url'] ?? 'https://kmb-teacher.vercel.app/TuitionManager.apk';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.system_update_rounded, color: Color(0xFF0F766E), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نیا ورژن دستیاب ہے!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                Text('ورژن: $ver', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تازہ ترین تبدیلیاں:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'بہترین کارکردگی کے لیے نیا ورژن ابھی ڈاؤن لوڈ کر کے انسٹال کریں۔',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بعد میں'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('ابھی اپڈیٹ کریں (ڈاؤن لوڈ APK)'),
          onPressed: () {
            launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
"""

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text + clean_code)

print("Applied clean classes to lib/main.dart")
