import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# 1. Update Home AppBar and Body
old_home_scaffold = """        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${store.students.length} طلبہ اندراج شدہ',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'سینٹر سیٹ اپ',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => CenterPage(store))),
              ),
              IconButton(
                tooltip: 'کردار تبدیل کریں',
                icon: const Icon(Icons.switch_account_rounded),
                onPressed: widget.onSwitch,
              ),
            ],
          ),
          body: SafeArea(child: pages[tab]),"""

new_home_scaffold = """        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${store.students.length} طلبہ اندراج شدہ',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6EE7B7))),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF3C7),
                    foregroundColor: const Color(0xFF92400E),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFFD97706)),
                  label: const Text('قرآن پاک', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuranReaderScreen()),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'سینٹر سیٹ اپ',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => CenterPage(store))),
              ),
              IconButton(
                tooltip: 'کردار تبدیل کریں',
                icon: const Icon(Icons.switch_account_rounded),
                onPressed: widget.onSwitch,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Teaching Mode Selector Bar
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildModePill(
                        label: 'تمام طلبہ (${store.students.length})',
                        icon: Icons.groups_rounded,
                        active: store.teachingMode == 'all',
                        color: const Color(0xFF0F766E),
                        onTap: () => store.setTeachingMode('all'),
                      ),
                      const SizedBox(width: 6),
                      _buildModePill(
                        label: 'فزیکل اکیڈمی (${store.students.where((x) => !x.isOnline).length})',
                        icon: Icons.apartment_rounded,
                        active: store.teachingMode == 'physical',
                        color: Colors.teal.shade800,
                        onTap: () => store.setTeachingMode('physical'),
                      ),
                      const SizedBox(width: 6),
                      _buildModePill(
                        label: 'آن لائن کلاس (${store.students.where((x) => x.isOnline).length})',
                        icon: Icons.videocam_rounded,
                        active: store.teachingMode == 'online',
                        color: Colors.indigo.shade700,
                        onTap: () => store.setTeachingMode('online'),
                      ),
                    ],
                  ),
                ),
                Expanded(child: pages[tab]),
              ],
            ),
          ),"""

c = c.replace(old_home_scaffold, new_home_scaffold)

# Add _buildModePill inside _HomeState
mode_pill_method = """  Widget _buildModePill({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            decoration: BoxDecoration(
              color: active ? color : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? color : color.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: active ? Colors.white : color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.bold : FontWeight.w600,
                      color: active ? Colors.white : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {"""

c = c.replace("  @override\n  Widget build(BuildContext context) {", mode_pill_method, 1)

# 2. Update StudentsPage filtering and add Quran Reader & mode banner
old_student_filter = """    final filtered = s.students.where((st) {
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        final match = st.name.toLowerCase().contains(q) ||
            st.phone.contains(q) ||
            st.code.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (filter == 'academy' && st.isOnline) return false;
      if (filter == 'online' && !st.isOnline) return false;
      if (filter == 'quran' && !st.isQuranStudent) return false;
      return true;
    }).toList();"""

new_student_filter = """    final filtered = s.students.where((st) {
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        final match = st.name.toLowerCase().contains(q) ||
            st.phone.contains(q) ||
            st.code.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (s.teachingMode == 'physical' && st.isOnline) return false;
      if (s.teachingMode == 'online' && !st.isOnline) return false;
      if (filter == 'academy' && st.isOnline) return false;
      if (filter == 'online' && !st.isOnline) return false;
      if (filter == 'quran' && !st.isQuranStudent) return false;
      return true;
    }).toList();"""

c = c.replace(old_student_filter, new_student_filter)

# In student cards, add "قرآن پڑھائیں" button to jump to reader
old_quran_diary_button = """                                   if (st.isQuranStudent) ...[
                                     FilledButton.icon(
                                       style: FilledButton.styleFrom(
                                           backgroundColor:
                                               const Color(0xFF0F7B5F)),
                                       icon: const Icon(Icons.menu_book_rounded,
                                           size: 16),
                                       label: const Text('قرآن ڈائری'),
                                       onPressed: () =>
                                           _openQuranDiarySheet(context, s, st),
                                     ),
                                     const SizedBox(width: 6),
                                   ],"""

new_quran_diary_button = """                                   if (st.isQuranStudent) ...[
                                     FilledButton.icon(
                                       style: FilledButton.styleFrom(
                                           backgroundColor:
                                               const Color(0xFF0F7B5F)),
                                       icon: const Icon(Icons.auto_stories_rounded,
                                           size: 16),
                                       label: const Text('قرآن پڑھائیں'),
                                       onPressed: () {
                                         final p = (st.quran?['para'] as num?)?.toInt() ?? 1;
                                         Navigator.push(
                                           context,
                                           MaterialPageRoute(
                                             builder: (_) => QuranReaderScreen(
                                               initialSurah: p == 1 ? 1 : ((p - 1) * 3 + 1).clamp(1, 114),
                                             ),
                                           ),
                                         );
                                       },
                                     ),
                                     const SizedBox(width: 6),
                                     FilledButton.tonalIcon(
                                       icon: const Icon(Icons.edit_note_rounded,
                                           size: 16),
                                       label: const Text('ڈائری'),
                                       onPressed: () =>
                                           _openQuranDiarySheet(context, s, st),
                                     ),
                                     const SizedBox(width: 6),
                                   ],"""

c = c.replace(old_quran_diary_button, new_quran_diary_button)

# 3. In AttendancePage, use filteredStudents
old_att_calc = """    final marked =
        s.students.where((x) => s.attToday(x.id) != null).length;
    final pr =
        s.students.where((x) => s.attToday(x.id) == true).length;
    final ab =
        s.students.where((x) => s.attToday(x.id) == false).length;"""

new_att_calc = """    final list = s.filteredStudents;
    final marked =
        list.where((x) => s.attToday(x.id) != null).length;
    final pr =
        list.where((x) => s.attToday(x.id) == true).length;
    final ab =
        list.where((x) => s.attToday(x.id) == false).length;"""

c = c.replace(old_att_calc, new_att_calc)
c = c.replace("        ...s.students.map((st) {", "        ...list.map((st) {")

# 4. In Gate, add colorful Quran Reader card
gate_role_cards = """                _roleCard(
                  icon: Icons.school_rounded,
                  title: 'میں طالب علم ہوں (Student)',
                  subtitle:
                      'اپنا سبق، ہوم ورک، آن لائن کلاس لنک اور ٹیسٹ رزلٹ دیکھیں',
                  color: Colors.teal.shade700,
                  onTap: () => pick('student'),
                ),"""

gate_role_cards_with_quran = """                _roleCard(
                  icon: Icons.school_rounded,
                  title: 'میں طالب علم ہوں (Student)',
                  subtitle:
                      'اپنا سبق، ہوم ورک، آن لائن کلاس لنک اور ٹیسٹ رزلٹ دیکھیں',
                  color: Colors.teal.shade700,
                  onTap: () => pick('student'),
                ),
                const SizedBox(height: 14),
                _roleCard(
                  icon: Icons.menu_book_rounded,
                  title: '📖 مکمل رنگین قرآن پاک (Quran Reader)',
                  subtitle:
                      '114 سورتیں، 30 پارے، نورانی قاعدہ اور 3 مختلف رسم الخط (مفت بلا لاگ اِن)',
                  color: const Color(0xFFD97706),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const QuranReaderScreen()),
                  ),
                ),"""

c = c.replace(gate_role_cards, gate_role_cards_with_quran)

# 5. In StudentHome, add Quran Reader button in AppBar and inside Quran diary card
old_student_appbar = """      appBar: AppBar(
        title: Text(snap?['center'] ?? 'طالب علم پورٹل'),
        actions: [
          if (code != null)"""

new_student_appbar = """      appBar: AppBar(
        title: Text(snap?['center'] ?? 'طالب علم پورٹل'),
        actions: [
          IconButton(
            tooltip: 'قرآن پاک تلاوت',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuranReaderScreen()),
            ),
          ),
          if (code != null)"""

c = c.replace(old_student_appbar, new_student_appbar)

# Add read Quran button inside Student Quran Diary card
old_student_quran_card_end = """                              if ((d['quran']['manzil'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _kv('منزل', '${d['quran']['manzil']}'),
                              ],
                            ],
                          ),
                        ),"""

new_student_quran_card_end = """                              if ((d['quran']['manzil'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _kv('منزل', '${d['quran']['manzil']}'),
                              ],
                              const Divider(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F7B5F),
                                  ),
                                  icon: const Icon(Icons.menu_book_rounded),
                                  label: const Text('📖 رنگین قرآن پاک کھولیں (سبق پڑھیں)'),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const QuranReaderScreen(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),"""

c = c.replace(old_student_quran_card_end, new_student_quran_card_end)

# 6. In ParentHome, add Quran button in AppBar and inside Quran diary card
old_parent_appbar = """      appBar: AppBar(
        title: Text(snap?['center'] ?? 'والدین پورٹل'),
        actions: [
          if (code != null)"""

new_parent_appbar = """      appBar: AppBar(
        title: Text(snap?['center'] ?? 'والدین پورٹل'),
        actions: [
          IconButton(
            tooltip: 'قرآن پاک تلاوت',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuranReaderScreen()),
            ),
          ),
          if (code != null)"""

c = c.replace(old_parent_appbar, new_parent_appbar)

# 7. In MorePage, add a card to open QuranReaderScreen
more_page_top = """    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('والدین اور طلبہ کے لیے کلاؤڈ سنک',"""

more_page_with_quran_card = """    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFF0FDF4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF86EFAC)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF0F7B5F),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.menu_book_rounded, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مکمل رنگین قرآن پاک ریڈر',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F7B5F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '114 سورتیں، 30 پارے، اردو ترجمہ اور 3 خوبصورت رسم الخط',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F7B5F)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuranReaderScreen()),
                  ),
                  child: const Text('کھولیں'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('والدین اور طلبہ کے لیے کلاؤڈ سنک',"""

c = c.replace(more_page_top, more_page_with_quran_card)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(c)

print("Phase 2 updates applied successfully!")
