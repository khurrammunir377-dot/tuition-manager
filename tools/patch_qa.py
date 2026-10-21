# -*- coding: utf-8 -*-
with open('lib/main.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# 1. Update StudentPortal loadQa & ask
old_student_qa = """  Future<void> loadQa(String c) async {
    try {
      final r = await Supabase.instance.client
          .rpc('get_questions', params: {'p_code': c});
      if (mounted) setState(() => qa = List.from(r ?? []));
    } catch (_) {}
  }

  Future<void> ask() async {
    final c = code, q = qCtl.text.trim();
    if (c == null || q.isEmpty) return;
    try {
      await Supabase.instance.client
          .rpc('ask_question', params: {'p_code': c, 'p_q': q});
      qCtl.clear();
      await loadQa(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('آپ کا سوال استاد کو بھیج دیا گیا ہے')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'سوال نہیں بھیجا جا سکا۔ پچھلے جواب کا انتظار کریں۔')));
      }
    }
  }"""

new_student_qa = """  Future<void> loadQa(String c) async {
    try {
      final r = await Supabase.instance.client
          .rpc('get_questions', params: {'p_code': c});
      if (mounted && r != null && (r as List).isNotEmpty) {
        setState(() => qa = List.from(r));
        return;
      }
    } catch (_) {}
    try {
      final r = await Supabase.instance.client
          .from('questions')
          .select('*')
          .eq('code', c.toLowerCase().trim())
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) setState(() => qa = List.from(r));
    } catch (_) {}
  }

  Future<void> ask() async {
    final c = code, q = qCtl.text.trim();
    if (c == null || q.isEmpty) return;
    try {
      try {
        await Supabase.instance.client
            .rpc('ask_question', params: {'p_code': c, 'p_q': q});
      } catch (_) {
        await Supabase.instance.client.from('questions').insert({
          'code': c.toLowerCase().trim(),
          'q': q,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      qCtl.clear();
      await loadQa(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                backgroundColor: Color(0xFF0F7B5F),
                content: Text('آپ کا سوال استاد کو کامیابی سے بھیج دیا گیا ہے')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('سوال نہیں بھیجا جا سکا: $e')));
      }
    }
  }"""

if old_student_qa in c:
    c = c.replace(old_student_qa, new_student_qa)
    print("Replaced student loadQa & ask!")
else:
    print("Could not find old_student_qa (checking line endings)")
    # Normalize CRLF
    c_norm = c.replace('\r\n', '\n')
    old_norm = old_student_qa.replace('\r\n', '\n')
    if old_norm in c_norm:
        c_norm = c_norm.replace(old_norm, new_student_qa.replace('\r\n', '\n'))
        c = c_norm
        print("Replaced student loadQa & ask (with normalized newlines)!")

# 2. Update ParentPortal loadQa & ask
old_parent_qa = """  Future<void> loadQa(String c) async {
    try {
      final r = await Supabase.instance.client
          .rpc('get_questions', params: {'p_code': c});
      if (mounted && code == c) setState(() => qa = List.from(r ?? []));
    } catch (_) {}
  }

  Future<void> ask() async {
    final c = code, q = qCtl.text.trim();
    if (c == null || q.isEmpty) return;
    try {
      await Supabase.instance.client
          .rpc('ask_question', params: {'p_code': c, 'p_q': q});
      qCtl.clear();
      await loadQa(c);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'سوال نہیں بھیجا جا سکا، پہلے والے کے جواب کا انتظار کریں')));
      }
    }
  }"""

new_parent_qa = """  Future<void> loadQa(String c) async {
    try {
      final r = await Supabase.instance.client
          .rpc('get_questions', params: {'p_code': c});
      if (mounted && code == c && r != null && (r as List).isNotEmpty) {
        setState(() => qa = List.from(r));
        return;
      }
    } catch (_) {}
    try {
      final r = await Supabase.instance.client
          .from('questions')
          .select('*')
          .eq('code', c.toLowerCase().trim())
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted && code == c) setState(() => qa = List.from(r));
    } catch (_) {}
  }

  Future<void> ask() async {
    final c = code, q = qCtl.text.trim();
    if (c == null || q.isEmpty) return;
    try {
      try {
        await Supabase.instance.client
            .rpc('ask_question', params: {'p_code': c, 'p_q': q});
      } catch (_) {
        await Supabase.instance.client.from('questions').insert({
          'code': c.toLowerCase().trim(),
          'q': q,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      qCtl.clear();
      await loadQa(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Color(0xFF0F7B5F),
            content: Text('آپ کا سوال استاد کو بھیج دیا گیا ہے')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('سوال نہیں بھیجا جا سکا: $e')));
      }
    }
  }"""

if old_parent_qa in c:
    c = c.replace(old_parent_qa, new_parent_qa)
    print("Replaced parent loadQa & ask!")
else:
    c_norm = c.replace('\r\n', '\n')
    old_norm = old_parent_qa.replace('\r\n', '\n')
    if old_norm in c_norm:
        c_norm = c_norm.replace(old_norm, new_parent_qa.replace('\r\n', '\n'))
        c = c_norm
        print("Replaced parent loadQa & ask (with normalized newlines)!")

# 3. Update QuestionsPage for teacher
old_qp = """  String who(String code) {
    for (final st in widget.s.students) {
      if (st.code == code) return st.name;
    }
    return code;
  }

  Future<void> answer(Map<String, dynamic> r) async {
    final c = TextEditingController(text: (r['a'] as String?) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${who(r['code'])}: ${r['q']}'),
        content: TextField(controller: c, maxLines: 3, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('منسوخ')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('جواب بھیجیں')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      try {
        await Supabase.instance.client.from('questions').update({
          'a': c.text.trim(),
          'answered_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', r['id']);
      } catch (_) {}
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return subPage('والدین و طلبہ کے سوالات', [
      Row(children: [
        Expanded(child: Text(msg)),
        TextButton(onPressed: load, child: const Text('تازہ کریں')),
      ]),
      ...rows.map((r) => Card(
            child: ListTile(
              title: Text('${who(r['code'])}: ${r['q']}'),
              subtitle:
                  Text(r['a'] == null ? 'جواب باقی ہے' : 'جواب: ${r['a']}'),
              trailing: Icon(r['a'] == null ? Icons.reply : Icons.check_circle,
                  color: r['a'] == null ? null : Colors.green),
              onTap: () => answer(r),
            ),
          )),
    ]);
  }"""

new_qp = """  Student? findStudent(String code) {
    for (final st in widget.s.students) {
      if (st.code == code) return st;
    }
    return null;
  }

  String who(String code) {
    final st = findStudent(code);
    return st != null ? st.name : code;
  }

  Future<void> answer(Map<String, dynamic> r) async {
    final c = TextEditingController(text: (r['a'] as String?) ?? '');
    final st = findStudent(r['code'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${who(r['code'])}: ${r['q']}'),
        content: TextField(
          controller: c,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'طالب علم کو اپنا جواب لکھیں...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('منسوخ')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('جواب بھیجیں')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      try {
        await Supabase.instance.client.from('questions').update({
          'a': c.text.trim(),
          'answered_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', r['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: Color(0xFF0F7B5F),
              content: Text('جواب کامیابی سے محفوظ اور بھیج دیا گیا ہے')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خرابی: $e')));
        }
      }
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return subPage('والدین و طلبہ کے سوالات', [
      Row(children: [
        Expanded(child: Text(msg)),
        FilledButton.tonalIcon(
          onPressed: load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('تازہ کریں'),
        ),
      ]),
      const SizedBox(height: 8),
      ...rows.map((r) {
        final st = findStudent(r['code'] ?? '');
        final hasAnswer = r['a'] != null && r['a'].toString().isNotEmpty;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: hasAnswer ? Colors.green.shade100 : Colors.amber.shade100,
                      foregroundColor: hasAnswer ? Colors.green.shade800 : Colors.amber.shade900,
                      child: Icon(hasAnswer ? Icons.check : Icons.question_mark, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        who(r['code'] ?? ''),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (r['created_at'] != null)
                      Text(
                        r['created_at'].toString().substring(0, 10),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'سوال: ${r['q']}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasAnswer ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hasAnswer ? Colors.green.shade200 : Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(hasAnswer ? Icons.reply_all_rounded : Icons.pending_rounded,
                          size: 16,
                          color: hasAnswer ? Colors.green.shade700 : Colors.amber.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasAnswer ? 'استاد کا جواب: ${r['a']}' : 'جواب باقی ہے (جواب دینے کے لیے نیچے بٹن دبائیں)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hasAnswer ? FontWeight.w600 : FontWeight.normal,
                            color: hasAnswer ? Colors.green.shade900 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (st != null && st.phone.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('واٹس ایپ جواب', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          widget.s.sendWa(st, text: 'وعلیکم السلام ${st.name}!\nآپ کے سوال: "${r['q']}" کے جواب میں:\n');
                        },
                      ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7B5F),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      icon: Icon(hasAnswer ? Icons.edit_rounded : Icons.reply_rounded, size: 16),
                      label: Text(hasAnswer ? 'جواب بدلیں' : 'جواب لکھیں', style: const TextStyle(fontSize: 12)),
                      onPressed: () => answer(r),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    ]);
  }"""

if old_qp in c:
    c = c.replace(old_qp, new_qp)
    print("Replaced QuestionsPage!")
else:
    c_norm = c.replace('\r\n', '\n')
    old_norm = old_qp.replace('\r\n', '\n')
    if old_norm in c_norm:
        c_norm = c_norm.replace(old_norm, new_qp.replace('\r\n', '\n'))
        c = c_norm
        print("Replaced QuestionsPage (with normalized newlines)!")

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(c)

print("Finished patching lib/main.dart!")
