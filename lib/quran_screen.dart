import 'package:flutter/gestures.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_data.dart';

class QuranReaderScreen extends StatefulWidget {
  final int initialSurah;
  final int? initialAyah;
  const QuranReaderScreen({super.key, this.initialSurah = 1, this.initialAyah});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  int _selectedSurah = 1;
  int _selectedJuz = 1;
  double _fontSize = 28.0;
  String _fontStyle = 'IndoPak'; // 'IndoPak' (standard South Asian), 'Amiri', 'Uthmani'
  String _colorTheme = 'emerald'; // 'emerald', 'amber', 'cream', 'night'
  bool _tajweedColors = true; // Authentic tajweed word/character coloring
  bool _showUrdu = false; // Pure authentic Arabic by default!
  bool _showEnglish = false;
  bool _isLoading = true;
  Map<String, dynamic> _allAyahs = {};

  // Continuous Page View mode vs Ayah Cards mode
  bool _continuousView = true;

  // Noorani Qaida PDF Mode vs List Mode
  bool _showQaidaPdf = true;

  // Auto-scroll features
  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 25.0; // pixels per second
  Timer? _autoScrollTimer;

  // Bookmarks: list of Map {'surah': int, 'ayah': int, 'surahName': String, 'time': String}
  List<Map<String, dynamic>> _bookmarks = [];
  Map<String, dynamic>? _lastRead;
  int? _targetAyah;

  // Search filter
  String _surahSearch = '';

  @override
  void initState() {
    super.initState();
    _selectedSurah = widget.initialSurah;
    _tabController = TabController(length: 4, vsync: this);
    // If opened from a specific surah, jump to reading tab
    if (widget.initialSurah > 1) {
      _tabController.index = 2; // Read Surah tab
    }
    _loadQuranText();
    _loadBookmarks();
  }

  Future<void> _loadQuranText() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/quran_full.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _allAyahs = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    try {
      final p = await SharedPreferences.getInstance();
      final bmStr = p.getString('quran_bookmarks');
      if (bmStr != null) {
        final List list = jsonDecode(bmStr);
        _bookmarks = list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final lrStr = p.getString('quran_last_read');
      if (lrStr != null) {
        _lastRead = Map<String, dynamic>.from(jsonDecode(lrStr));
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveBookmarks() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('quran_bookmarks', jsonEncode(_bookmarks));
      if (_lastRead != null) {
        await p.setString('quran_last_read', jsonEncode(_lastRead));
      }
    } catch (_) {}
  }

  void _toggleBookmark(int surahNum, int ayahNum, String surahName) {
    final idx = _bookmarks.indexWhere((b) => b['surah'] == surahNum && b['ayah'] == ayahNum);
    setState(() {
      if (idx >= 0) {
        _bookmarks.removeAt(idx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('سورۃ $surahName (آیت $ayahNum) بک مارک سے ہٹا دی گئی'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        _bookmarks.add({
          'surah': surahNum,
          'ayah': ayahNum,
          'surahName': surahName,
          'time': DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' '),
        });
        _lastRead = {
          'surah': surahNum,
          'ayah': ayahNum,
          'surahName': surahName,
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            content: Text('سورۃ $surahName (آیت $ayahNum) کامیابی سے بک مارک ہو گئی ⭐'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
    _saveBookmarks();
  }

  bool _isBookmarked(int surahNum, int ayahNum) {
    return _bookmarks.any((b) => b['surah'] == surahNum && b['ayah'] == ayahNum);
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });

    _autoScrollTimer?.cancel();
    if (_isAutoScrolling) {
      // 50ms interval => 20 ticks per second
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!_scrollController.hasClients) return;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final current = _scrollController.offset;
        final step = _autoScrollSpeed * 0.05; // distance per 50ms

        if (current >= maxScroll) {
          _autoScrollTimer?.cancel();
          setState(() => _isAutoScrolling = false);
        } else {
          _scrollController.jumpTo(current + step);
        }
      });
    }
  }

  void _showBookmarksDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark_rounded, color: Color(0xFFD97706), size: 26),
                  const SizedBox(width: 8),
                  const Text(
                    'محفوظ شدہ بک مارکس (Bookmarks)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'JameelNooriNastaleeq'),
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 18),
              if (_bookmarks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.bookmark_border_rounded, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'ابھی تک کوئی آیت بک مارک نہیں کی گئی۔\nتلاوت کے دوران کسی بھی آیت کے بک مارک آئیکن پر کلک کریں!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _bookmarks.length,
                    itemBuilder: (c, idx) {
                      final bm = _bookmarks[idx];
                      final sNum = bm['surah'] as int;
                      final aNum = bm['ayah'] as int;
                      final sName = bm['surahName'] ?? 'سورۃ $sNum';
                      final time = bm['time'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _primaryAccent.withValues(alpha: 0.15),
                            foregroundColor: _primaryAccent,
                            child: const Icon(Icons.bookmark_added_rounded),
                          ),
                          title: Text(
                            'سورۃ $sName · آیت نمبر $aNum',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text('تاریخ: $time', style: TextStyle(fontSize: 11, color: _subtextColor)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: () {
                              _toggleBookmark(sNum, aNum, sName);
                              setM(() {});
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedSurah = sNum;
                              _targetAyah = aNum;
                              _continuousView = false; // Card view lets us jump to the exact verse card!
                              _tabController.animateTo(2);
                            });
                            Future.delayed(const Duration(milliseconds: 350), () {
                              if (_scrollController.hasClients) {
                                final targetOffset = ((aNum - 1) * 160.0).clamp(0.0, _scrollController.position.maxScrollExtent);
                                _scrollController.animateTo(
                                  targetOffset,
                                  duration: const Duration(milliseconds: 550),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _bgSurface {
    switch (_colorTheme) {
      case 'amber':
        return const Color(0xFFFFFBEB);
      case 'cream':
        return const Color(0xFFFBF8EE);
      case 'night':
        return const Color(0xFF0F172A);
      default:
        return const Color(0xFFF0FDF4); // emerald light
    }
  }

  Color get _cardBg {
    switch (_colorTheme) {
      case 'amber':
        return Colors.white;
      case 'cream':
        return const Color(0xFFFFFDF9);
      case 'night':
        return const Color(0xFF1E293B);
      default:
        return Colors.white;
    }
  }

  Color get _primaryAccent {
    switch (_colorTheme) {
      case 'amber':
        return const Color(0xFFD97706);
      case 'cream':
        return const Color(0xFFB45309);
      case 'night':
        return const Color(0xFF38BDF8);
      default:
        return const Color(0xFF0F7B5F);
    }
  }

  Color get _textColor {
    switch (_colorTheme) {
      case 'night':
        return const Color(0xFFF8FAFC);
      default:
        return const Color(0xFF1E293B);
    }
  }

  Color get _subtextColor {
    switch (_colorTheme) {
      case 'night':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF475569);
    }
  }

  String get _quranFontFamily {
    switch (_fontStyle) {
      case 'IndoPak':
        return 'PdmsSaleemQuran';
      case 'Amiri':
        return 'Amiri';
      default:
        return 'sans-serif';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      appBar: AppBar(
        backgroundColor: _primaryAccent,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('قرآن مجید و نورانی قاعدہ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'JameelNooriNastaleeq')),
            Text('مع اردو (جمیل نوری نستعلیق) و انگریزی ترجمہ',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'محفوظ شدہ بک مارکس',
            icon: const Icon(Icons.bookmark_rounded),
            onPressed: _showBookmarksDialog,
          ),
          IconButton(
            tooltip: _tajweedColors ? 'تجویدی رنگ بند کریں' : 'تجویدی رنگ آن کریں',
            icon: Icon(_tajweedColors ? Icons.color_lens_rounded : Icons.color_lens_outlined),
            onPressed: () => setState(() => _tajweedColors = !_tajweedColors),
          ),
          IconButton(
            tooltip: 'فانٹ اور زبان سیٹنگز',
            icon: const Icon(Icons.format_size_rounded),
            onPressed: _showSettingsDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.amber.shade300,
            indicatorWeight: 4.0,
            labelColor: Colors.amber.shade200,
            unselectedLabelColor: Colors.white70,
            isScrollable: false,
            labelPadding: EdgeInsets.zero,
            labelStyle: const TextStyle(
              fontFamily: 'JameelNooriNastaleeq',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'JameelNooriNastaleeq',
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.list_alt_rounded, size: 22), text: 'سورتیں', iconMargin: EdgeInsets.only(bottom: 2)),
              Tab(icon: Icon(Icons.menu_book_rounded, size: 22), text: 'پارے', iconMargin: EdgeInsets.only(bottom: 2)),
              Tab(icon: Icon(Icons.auto_stories_rounded, size: 22), text: 'تلاوت', iconMargin: EdgeInsets.only(bottom: 2)),
              Tab(icon: Icon(Icons.school_rounded, size: 22), text: 'قاعدہ', iconMargin: EdgeInsets.only(bottom: 2)),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryAccent),
                  const SizedBox(height: 16),
                  Text('قرآن پاک لوڈ ہو رہا ہے...',
                      style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontFamily: 'JameelNooriNastaleeq')),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSurahListPage(),
                _buildJuzListPage(),
                _buildReadingView(),
                _buildQaidaTabView(),
              ],
            ),
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_rounded, color: _primaryAccent),
                  const SizedBox(width: 8),
                  const Text('ریڈر سیٹنگز (قراءت و تھیم)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'JameelNooriNastaleeq')),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 16),
              // Font size slider
              Row(
                children: [
                  const Text('عربی خط کا سائز: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${_fontSize.round()} px',
                      style: TextStyle(color: _primaryAccent, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 20.0,
                      max: 44.0,
                      divisions: 12,
                      activeColor: _primaryAccent,
                      onChanged: (v) {
                        setM(() => _fontSize = v);
                        setState(() => _fontSize = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Font style selector
              const Text('رسم الخط (Standard Writing Style):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _styleChip('انڈو پاک معیاری (سلیم خط)', 'IndoPak', setM),
                  _styleChip('عامری / مدینہ منورہ', 'Amiri', setM),
                  _styleChip('عثمانی رسم الخط', 'Uthmani', setM),
                ],
              ),
              const SizedBox(height: 12),
              // Translations toggle
              const Text('تراجم کا انتخاب:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  FilterChip(
                    label: const Text('اردو ترجمہ (جمیل نوری نستعلیق)', style: TextStyle(fontFamily: 'JameelNooriNastaleeq')),
                    selected: _showUrdu,
                    onSelected: (v) {
                      setM(() => _showUrdu = v);
                      setState(() => _showUrdu = v);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('English (Sahih Intl)'),
                    selected: _showEnglish,
                    onSelected: (v) {
                      setM(() => _showEnglish = v);
                      setState(() => _showEnglish = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tajweed color toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تجویدی حروف (Tajweed Letters)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('لفظ اللہ (سرخ)، مدات (نیلا)، اخفاء و غنہ (سبز)', style: TextStyle(fontSize: 12)),
                value: _tajweedColors,
                onChanged: (v) {
                  setM(() => _tajweedColors = v);
                  setState(() => _tajweedColors = v);
                },
              ),
              const SizedBox(height: 8),
              // Theme colors
              const Text('رنگوں کی تھیم (Color Theme):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _themeCard('زمردی سبز', const Color(0xFF0F7B5F), 'emerald', setM),
                  const SizedBox(width: 8),
                  _themeCard('سنہری و زعفرانی', const Color(0xFFD97706), 'amber', setM),
                  const SizedBox(width: 8),
                  _themeCard('قدیم مصحف', const Color(0xFFB45309), 'cream', setM),
                  const SizedBox(width: 8),
                  _themeCard('نائٹ موڈ', const Color(0xFF1E293B), 'night', setM),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styleChip(String label, String value, StateSetter setM) {
    final selected = _fontStyle == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: _primaryAccent.withValues(alpha: 0.2),
      onSelected: (_) {
        setM(() => _fontStyle = value);
        setState(() => _fontStyle = value);
      },
    );
  }

  Widget _themeCard(String label, Color color, String value, StateSetter setM) {
    final isSelected = _colorTheme == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setM(() => _colorTheme = value);
          setState(() => _colorTheme = value);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2.2,
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(radius: 12, backgroundColor: color),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. Dedicated Surah Selection Page (Full Grid & Search) ---
  Widget _buildSurahListPage() {
    final list = QuranData.surahs.where((s) {
      if (_surahSearch.isEmpty) return true;
      final q = _surahSearch.toLowerCase();
      return s['name'].toString().contains(q) ||
          s['englishName'].toString().toLowerCase().contains(q) ||
          s['number'].toString().contains(q);
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: _cardBg,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'سورۃ کا نام یا نمبر تلاش کریں (مثلاً یٰسٓ، البقرۃ، 36)...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _surahSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _surahSearch = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (v) => setState(() => _surahSearch = v.trim()),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemCount: list.length,
            itemBuilder: (ctx, idx) {
              final s = list[idx];
              final isCurrent = s['number'] == _selectedSurah;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedSurah = s['number'] as int;
                    _tabController.animateTo(2); // Jump to reading tab
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? _primaryAccent : _primaryAccent.withValues(alpha: 0.2),
                      width: isCurrent ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: isCurrent ? _primaryAccent : _primaryAccent.withValues(alpha: 0.12),
                            foregroundColor: isCurrent ? Colors.white : _primaryAccent,
                            child: Text('${s['number']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _primaryAccent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  s['revelationType'] == 'Meccan' ? 'مکی' : 'مدنی',
                                  style: TextStyle(fontSize: 10, color: _primaryAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _toggleBookmark(s['number'], 1, s['name']),
                                child: Icon(
                                  _isBookmarked(s['number'], 1) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  size: 18,
                                  color: _isBookmarked(s['number'], 1) ? const Color(0xFFD97706) : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Center(
                        child: Text(
                          '${s['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PdmsSaleemQuran',
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${s['englishName']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: _subtextColor),
                            ),
                          ),
                          Text(
                            '${s['numberOfAyahs']} آیات',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primaryAccent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 2. Dedicated Juz (Para) Selection Page ---
  Widget _buildJuzListPage() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemCount: 30,
      itemBuilder: (ctx, i) {
        final juzNum = i + 1;
        final ref = QuranData.juzs[i];
        final paraName = ref['name'] ?? 'پارہ $juzNum';
        final sMeta = QuranData.surahs.firstWhere(
          (s) => s['number'] == ref['surah'],
          orElse: () => QuranData.surahs.first,
        );
        final isCurrent = _selectedJuz == juzNum;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedJuz = juzNum;
              _selectedSurah = ref['surah'] as int;
              _tabController.animateTo(2); // Jump to reading tab
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrent ? _primaryAccent : _primaryAccent.withValues(alpha: 0.2),
                width: isCurrent ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: isCurrent ? _primaryAccent : _primaryAccent.withValues(alpha: 0.12),
                      foregroundColor: isCurrent ? Colors.white : _primaryAccent,
                      child: Text('$juzNum',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      'پارہ نمبر $juzNum',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _primaryAccent),
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    '$paraName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PdmsSaleemQuran',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'شروع: ${sMeta['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: _primaryAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      'آیت: ${ref['ayah']}',
                      style: TextStyle(fontSize: 11, color: _subtextColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 3. Reading View (With Continuous Mushaf Page View, Auto-Scroll, & Bookmarks) ---
  Widget _buildReadingView() {
    final curSurahMeta = QuranData.surahs.firstWhere(
      (s) => s['number'] == _selectedSurah,
      orElse: () => QuranData.surahs.first,
    );
    final ayahs = (_allAyahs['$_selectedSurah'] as List?) ?? [];

    return Column(
      children: [
        // Compact Top Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _cardBg,
            border: Border(bottom: BorderSide(color: _primaryAccent.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'پچھلی سورۃ',
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: _selectedSurah > 1 ? () => setState(() => _selectedSurah--) : null,
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(0), // Jump to Surah selection tab
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${curSurahMeta['number']}. ${curSurahMeta['name']}',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${curSurahMeta['numberOfAyahs']} آیات)',
                          style: TextStyle(color: _subtextColor, fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: _primaryAccent, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'اگلی سورۃ',
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: _selectedSurah < 114 ? () => setState(() => _selectedSurah++) : null,
              ),
            ],
          ),
        ),

        // Quick Controls Bar: Mode Switcher (Continuous vs Cards) & Auto-Scroll
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: _primaryAccent.withValues(alpha: 0.05),
          child: Row(
            children: [
              // Continuous Page Mode vs Card Mode Pill
              InkWell(
                onTap: () => setState(() => _continuousView = !_continuousView),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _continuousView ? _primaryAccent : _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primaryAccent),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _continuousView ? Icons.menu_book_rounded : Icons.view_agenda_rounded,
                        size: 14,
                        color: _continuousView ? Colors.white : _primaryAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _continuousView ? 'مسلسل قراءت (صفحہ)' : 'آیات کارڈز',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _continuousView ? Colors.white : _primaryAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Quick Bookmark Toggle for Current Surah
              InkWell(
                onTap: () => _toggleBookmark(_selectedSurah, _targetAyah ?? 1, curSurahMeta['name']),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isBookmarked(_selectedSurah, _targetAyah ?? 1) ? const Color(0xFFD97706) : _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD97706)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isBookmarked(_selectedSurah, _targetAyah ?? 1) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 14,
                        color: _isBookmarked(_selectedSurah, _targetAyah ?? 1) ? Colors.white : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isBookmarked(_selectedSurah, _targetAyah ?? 1) ? 'بک مارک شدہ' : 'بک مارک کریں',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isBookmarked(_selectedSurah, _targetAyah ?? 1) ? Colors.white : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Auto-Scroll Toggle Button
              InkWell(
                onTap: _toggleAutoScroll,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAutoScrolling ? Colors.amber.shade700 : _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _isAutoScrolling ? Colors.amber.shade800 : Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAutoScrolling ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                        size: 15,
                        color: _isAutoScrolling ? Colors.white : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isAutoScrolling ? 'روکیں (آٹو سکرول)' : 'خودکار سکرول',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isAutoScrolling ? Colors.white : _textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isAutoScrolling) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_autoScrollSpeed > 15) _autoScrollSpeed -= 10;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: Color(0xFFD97706)),
                  ),
                ),
                Text(
                  '${(_autoScrollSpeed / 25).toStringAsFixed(1)}x',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_autoScrollSpeed < 80) _autoScrollSpeed += 15;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFFD97706)),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Reading Content: Wrapped with Interactive Scrollbar and Quick Jump Float Buttons
        Expanded(
          child: Stack(
            children: [
              Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                thickness: 8,
                radius: const Radius.circular(6),
                child: ayahs.isEmpty
                    ? Center(child: Text('آیات لوڈ ہو رہی ہیں...', style: TextStyle(color: _textColor, fontFamily: 'JameelNooriNastaleeq')))
                    : _continuousView
                        ? _buildContinuousMushafView(ayahs, curSurahMeta)
                        : _buildCardListView(ayahs),
              ),
              // Floating Up & Down Quick Navigation Buttons (تلاوت کے دوران فوری اوپر نیچے جانے کے لیے)
              Positioned(
                bottom: 16,
                right: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'quran_scroll_top_btn',
                      backgroundColor: _cardBg.withValues(alpha: 0.92),
                      foregroundColor: _primaryAccent,
                      elevation: 4,
                      tooltip: 'اوپر جائیں (Scroll to Top)',
                      onPressed: () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'quran_scroll_bottom_btn',
                      backgroundColor: _cardBg.withValues(alpha: 0.92),
                      foregroundColor: _primaryAccent,
                      elevation: 4,
                      tooltip: 'نیچے جائیں (Scroll to Bottom)',
                      onPressed: () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Continuous Quran Page View (اصل مصحف کی طرح تسلسل کے ساتھ قراءت) ---
  Widget _buildContinuousMushafView(List ayahs, Map<String, dynamic> curSurahMeta) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryAccent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Decorative Surah Header Frame
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryAccent.withValues(alpha: 0.15),
                    _primaryAccent.withValues(alpha: 0.05),
                    _primaryAccent.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primaryAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'سُورَةُ ${curSurahMeta['name']}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PdmsSaleemQuran',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${curSurahMeta['revelationType'] == 'Meccan' ? "مكية" : "مدنية"} · آیاتها ${curSurahMeta['numberOfAyahs']}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _subtextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Bismillah Banner (except Surah Taubah)
            if (_selectedSurah != 9)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _primaryAccent,
                    fontSize: _fontSize * 0.9,
                    fontFamily: _quranFontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Flowing Continuous Arabic Verses with Ayah Stop Circles
            Directionality(
              textDirection: TextDirection.rtl,
              child: _buildContinuousArabicRichText(ayahs, curSurahMeta['name']),
            ),

            // Inline Translations Block below if enabled
            if (_showUrdu || _showEnglish) ...[
              const SizedBox(height: 24),
              const Divider(thickness: 1.2),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.translate_rounded, size: 18, color: _primaryAccent),
                    const SizedBox(width: 8),
                    Text(
                      'اردو و انگریزی ترجمہ (آیات وار)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _primaryAccent,
                        fontFamily: 'JameelNooriNastaleeq',
                      ),
                    ),
                  ],
                ),
              ),
              ...ayahs.map((aItem) {
                final a = Map<String, dynamic>.from(aItem);
                final aNum = a['n'] ?? 1;
                final urdu = a['u'] ?? '';
                final eng = a['e'] ?? '';
                final isBm = _isBookmarked(_selectedSurah, aNum);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryAccent.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryAccent.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _primaryAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'آیت $aNum',
                              style: TextStyle(
                                color: _primaryAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              isBm ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 18,
                              color: isBm ? const Color(0xFFD97706) : _subtextColor,
                            ),
                            tooltip: 'بک مارک لگائیں',
                            onPressed: () => _toggleBookmark(_selectedSurah, aNum, curSurahMeta['name']),
                          ),
                        ],
                      ),
                      if (_showUrdu && urdu.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$urdu',
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: _subtextColor,
                            fontFamily: 'JameelNooriNastaleeq',
                            fontSize: 22.0,
                            height: 1.9,
                          ),
                        ),
                      ],
                      if (_showEnglish && eng.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$eng',
                          textAlign: TextAlign.left,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: Colors.blueGrey.shade800,
                            fontSize: 16.0,
                            height: 1.55,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // Continuous Arabic text builder with Ayah end stops: ۝١, ۝٢ ...
  Widget _buildContinuousArabicRichText(List ayahs, String surahName) {
    final spans = <InlineSpan>[];

    for (int idx = 0; idx < ayahs.length; idx++) {
      final a = Map<String, dynamic>.from(ayahs[idx]);
      final ayahNum = a['n'] ?? (idx + 1);
      final rawText = (_fontStyle == 'IndoPak' && (a['ip'] != null))
          ? '${a['ip']}'
          : '${a['t'] ?? ""}';

      // Words with tajweed coloring
      final words = rawText.trim().split(' ');
      for (int wIdx = 0; wIdx < words.length; wIdx++) {
        final w = words[wIdx];
        Color wColor = _textColor;

        if (_tajweedColors) {
          if (w.contains('اللَّه') || w.contains('اللّٰه') || w.contains('لِلَّه') || w.contains('لِلّٰه') || w.contains('ٱللَّه')) {
            wColor = const Color(0xFFDC2626);
          } else if (w.contains('ٓ') || w.contains('ۤ') || w.contains('ٰ')) {
            wColor = const Color(0xFF2563EB);
          } else if (w.contains('نّ') || w.contains('مّ') || w.contains('نَّ') || w.contains('مَّ')) {
            wColor = const Color(0xFF16A34A);
          } else if (w.contains('ۘ') || w.contains('ۚ') || w.contains('ۖ') || w.contains('ۗ')) {
            wColor = const Color(0xFFD97706);
          }
        }

        spans.add(TextSpan(
          text: '$w ',
          style: TextStyle(
            color: wColor,
            fontSize: _fontSize,
            fontFamily: _quranFontFamily,
            height: 2.3,
            fontWeight: wColor != _textColor ? FontWeight.w600 : FontWeight.normal,
          ),
        ));
      }

      // Ultra-fast lightweight Quranic Ayah Stop marker (﴿ayahNum﴾) - no heavy WidgetSpan layout overhead!
      final isBm = _isBookmarked(_selectedSurah, ayahNum);
      spans.add(TextSpan(
        text: ' ﴿$ayahNum﴾ ',
        recognizer: TapGestureRecognizer()
          ..onTap = () => _toggleBookmark(_selectedSurah, ayahNum, surahName),
        style: TextStyle(
          color: isBm ? const Color(0xFFD97706) : _primaryAccent,
          fontSize: _fontSize * 0.85,
          fontWeight: FontWeight.bold,
          fontFamily: _quranFontFamily,
          backgroundColor: isBm ? const Color(0xFFFDE68A).withValues(alpha: 0.35) : null,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
    );
  }

  // --- Card List View Mode ---
  Widget _buildCardListView(List ayahs) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      itemCount: ayahs.length,
      itemBuilder: (ctx, idx) {
        final a = Map<String, dynamic>.from(ayahs[idx]);
        return _buildAyahCard(a);
      },
    );
  }

  Widget _buildAyahCard(Map<String, dynamic> a) {
    final ayahNum = a['n'] ?? 1;
    final curSurahMeta = QuranData.surahs.firstWhere(
      (s) => s['number'] == _selectedSurah,
      orElse: () => QuranData.surahs.first,
    );
    final isBm = _isBookmarked(_selectedSurah, ayahNum);

    // Choose authentic Indo-Pak script when IndoPak is selected, or Uthmani
    final rawText = (_fontStyle == 'IndoPak' && (a['ip'] != null))
        ? '${a['ip']}'
        : '${a['t'] ?? ""}';
    final urdu = a['u'] ?? '';
    final english = a['e'] ?? '';

    final isTarget = _targetAyah == ayahNum;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTarget ? const Color(0xFFFEF3C7) : _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTarget ? const Color(0xFFD97706) : (isBm ? const Color(0xFFD97706) : _primaryAccent.withValues(alpha: 0.15)),
          width: isTarget ? 2.5 : (isBm ? 1.5 : 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: isTarget ? const Color(0xFFD97706).withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.02),
            blurRadius: isTarget ? 10 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Ayah number, Bookmark toggle & copy button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isTarget
                      ? const Color(0xFFB45309)
                      : (isBm ? const Color(0xFFD97706) : _primaryAccent.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isTarget ? '📌 آیت $ayahNum (بک مارک)' : 'آیت $ayahNum',
                  style: TextStyle(
                    color: (isTarget || isBm) ? Colors.white : _primaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: isBm ? 'بک مارک سے ہٹائیں' : 'بک مارک محفوظ کریں',
                icon: Icon(
                  isBm ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isBm ? const Color(0xFFD97706) : _subtextColor,
                ),
                onPressed: () => _toggleBookmark(_selectedSurah, ayahNum, curSurahMeta['name']),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: _subtextColor,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '$rawText\n$urdu\n$english'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('آیت مبارکہ مع ترجمہ کاپی ہو گئی')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Colored Arabic Verse Text
          Directionality(
            textDirection: TextDirection.rtl,
            child: _tajweedColors
                ? _buildColoredArabicText(rawText)
                : Text(
                    rawText,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _fontSize,
                      fontFamily: _quranFontFamily,
                      height: 2.1,
                    ),
                  ),
          ),

          // Urdu Translation in Jameel Noori Nastaleeq
          if (_showUrdu && urdu.toString().isNotEmpty) ...[
            const Divider(height: 18),
            Text(
              '$urdu',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: _subtextColor,
                fontFamily: 'JameelNooriNastaleeq',
                fontSize: 22.0,
                height: 1.9,
              ),
            ),
          ],

          // English Translation (Sahih International)
          if (_showEnglish && english.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '$english',
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: Colors.blueGrey.shade800,
                fontSize: 16.0,
                height: 1.55,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Tajweed word/character colorizer (Allah in red, Madd in blue, etc.)
  Widget _buildColoredArabicText(String text) {
    final words = text.split(' ');
    final spans = <TextSpan>[];

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      Color wColor = _textColor;

      // Rule 1: The Word 'Allah' or 'Lillah' in majestic Crimson Red (Color Tajweed)
      if (w.contains('اللَّه') || w.contains('اللّٰه') || w.contains('لِلَّه') || w.contains('لِلّٰه') || w.contains('ٱللَّه')) {
        wColor = const Color(0xFFDC2626); // Bright Crimson Red
      }
      // Rule 2: Words with elongation Madd sign (ٓ or ~) in Sapphire Blue
      else if (w.contains('ٓ') || w.contains('ۤ') || w.contains('ٰ')) {
        wColor = const Color(0xFF2563EB); // Royal Blue
      }
      // Rule 3: Words with Meem / Noon Shaddah or Ghunnah in Forest Green
      else if (w.contains('نّ') || w.contains('مّ') || w.contains('نَّ') || w.contains('مَّ')) {
        wColor = const Color(0xFF16A34A); // Tajweed Green
      }
      // Rule 4: Qalqalah or ending Waqf signs in Gold / Orange
      else if (w.contains('ۘ') || w.contains('ۚ') || w.contains('ۖ') || w.contains('ۗ')) {
        wColor = const Color(0xFFD97706); // Amber Gold
      }

      spans.add(TextSpan(
        text: w + (i < words.length - 1 ? ' ' : ''),
        style: TextStyle(
          color: wColor,
          fontSize: _fontSize,
          fontFamily: _quranFontFamily,
          height: 2.1,
          fontWeight: wColor != _textColor ? FontWeight.w600 : FontWeight.normal,
        ),
      ));
    }

    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(children: spans),
    );
  }

  // --- 4. Noorani Qaida Tab View ---
  Widget _buildQaidaTabView() {
    return Column(
      children: [
        // Mode Selector Bar (PDF Book vs Lesson List)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _cardBg,
            border: Border(bottom: BorderSide(color: _primaryAccent.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: Text('مکمل اصل کتاب (PDF)', style: TextStyle(fontFamily: 'JameelNooriNastaleeq', fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.format_list_bulleted_rounded, size: 18),
                      label: Text('اسباق کی فہرست', style: TextStyle(fontFamily: 'JameelNooriNastaleeq', fontSize: 13)),
                    ),
                  ],
                  selected: {_showQaidaPdf},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() => _showQaidaPdf = newSelection.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return _primaryAccent;
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return _textColor;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content Area
        Expanded(
          child: _showQaidaPdf
              ? PdfPreview(
                  build: (format) async {
                    final data = await rootBundle.load('assets/noorani_qaida.pdf');
                    return data.buffer.asUint8List();
                  },
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  maxPageWidth: 720,
                  pdfFileName: 'Noorani_Qaida.pdf',
                  scrollViewDecoration: BoxDecoration(color: _bgSurface),
                  loadingWidget: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: _primaryAccent),
                        const SizedBox(height: 14),
                        Text(
                          'نورانی قاعدہ لوڈ ہو رہا ہے...',
                          style: TextStyle(
                            fontFamily: 'JameelNooriNastaleeq',
                            fontSize: 16,
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: QuranData.qaidaLessons.length,
                  itemBuilder: (ctx, idx) {
                    final lesson = QuranData.qaidaLessons[idx];
                    final letters = (lesson['letters'] as List<dynamic>?) ?? [];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: _cardBg,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: _primaryAccent.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _primaryAccent,
                                  foregroundColor: Colors.white,
                                  child: Text('${lesson['lesson']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${lesson['title']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textColor,
                                          fontFamily: 'JameelNooriNastaleeq',
                                        ),
                                      ),
                                      Text(
                                        '${lesson['desc']}',
                                        style: TextStyle(fontSize: 13, color: _subtextColor, fontFamily: 'JameelNooriNastaleeq'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: letters.map((l) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _primaryAccent.withValues(alpha: 0.07),
                                        _primaryAccent.withValues(alpha: 0.18),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _primaryAccent.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    '$l',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor,
                                      fontFamily: 'PdmsSaleemQuran',
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
