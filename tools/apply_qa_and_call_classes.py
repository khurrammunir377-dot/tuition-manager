import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Replace loadQa and ask in _StudentPortalState
old_student_qa = """  Future<void> loadQa(String c) async {
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

new_student_qa = """  Future<void> loadQa(String c) async {
    final cleanCode = c.toLowerCase().trim();
    try {
      final r = await Supabase.instance.client
          .rpc('get_questions', params: {'p_code': cleanCode});
      if (mounted && r != null && (r as List).isNotEmpty) {
        setState(() => qa = List.from(r));
        return;
      }
    } catch (_) {}
    try {
      final r = await Supabase.instance.client
          .from('questions')
          .select('*')
          .eq('code', cleanCode)
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted && (r as List).isNotEmpty) {
        setState(() => qa = List.from(r));
        return;
      }
    } catch (_) {}
    // Robust snapshots table fallback
    try {
      final res = await Supabase.instance.client
          .from('snapshots')
          .select('data')
          .eq('code', cleanCode)
          .maybeSingle();
      if (res != null && res['data'] != null) {
        final d = Map<String, dynamic>.from(res['data'] as Map);
        final list = (d['qa'] as List?) ?? [];
        if (mounted) setState(() => qa = List.from(list));
      }
    } catch (_) {}
  }

  Future<void> ask() async {
    final c = code, q = qCtl.text.trim();
    if (c == null || q.isEmpty) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final cleanCode = c.toLowerCase().trim();
    bool sent = false;

    // 1. Try questions table / RPC
    try {
      await Supabase.instance.client
          .rpc('ask_question', params: {'p_code': cleanCode, 'p_q': q});
      sent = true;
    } catch (_) {
      try {
        await Supabase.instance.client.from('questions').insert({
          'code': cleanCode,
          'q': q,
          'created_at': nowIso,
        });
        sent = true;
      } catch (_) {}
    }

    // 2. Always persist into snapshots table as well
    try {
      final res = await Supabase.instance.client
          .from('snapshots')
          .select('data')
          .eq('code', cleanCode)
          .maybeSingle();

      Map<String, dynamic> snapData = {};
      if (res != null && res['data'] != null) {
        snapData = Map<String, dynamic>.from(res['data'] as Map);
      }
      List<dynamic> existingQa = List.from(snapData['qa'] ?? []);
      existingQa.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'code': cleanCode,
        'q': q,
        'a': null,
        'created_at': nowIso,
      });
      snapData['qa'] = existingQa;

      await Supabase.instance.client.from('snapshots').upsert({
        'code': cleanCode,
        'data': snapData,
        'updated_at': nowIso,
      });
      sent = true;
    } catch (_) {}

    if (sent) {
      qCtl.clear();
      await loadQa(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF0F7B5F),
          content: Text('آپ کا سوال استاد کو کامیابی سے بھیج دیا گیا ہے'),
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('خرابی: انٹرنیٹ کنکشن چیک کریں اور دوبارہ کوشش کریں'),
        ));
      }
    }
  }"""

if old_student_qa in text:
    text = text.replace(old_student_qa, new_student_qa)
    print("Replaced Student Portal QA")
else:
    print("WARNING: old_student_qa not found")

# 2. Replace loadQa and ask in _ParentPortalState
old_parent_qa = """  Future<void> loadQa(String c) async {
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

new_parent_qa = """  Future<void> loadQa(String c) async {
    final cleanCode = c.toLowerCase().trim();
    try {
      final r = await Supabase.instance.client
          .rpc('get_questions', params: {'p_code': cleanCode});
      if (mounted && code == c && r != null && (r as List).isNotEmpty) {
        setState(() => qa = List.from(r));
        return;
      }
    } catch (_) {}
    try {
      final r = await Supabase.instance.client
          .from('questions')
          .select('*')
          .eq('code', cleanCode)
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted && code == c && (r as List).isNotEmpty) {
        setState(() => qa = List.from(r));
        return;
      }
    } catch (_) {}
    // Robust snapshots table fallback
    try {
      final res = await Supabase.instance.client
          .from('snapshots')
          .select('data')
          .eq('code', cleanCode)
          .maybeSingle();
      if (res != null && res['data'] != null) {
        final d = Map<String, dynamic>.from(res['data'] as Map);
        final list = (d['qa'] as List?) ?? [];
        if (mounted && code == c) setState(() => qa = List.from(list));
      }
    } catch (_) {}
  }

  Future<void> ask() async {
    final c = code, q = qCtl.text.trim();
    if (c == null || q.isEmpty) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final cleanCode = c.toLowerCase().trim();
    bool sent = false;

    // 1. Try questions table / RPC
    try {
      await Supabase.instance.client
          .rpc('ask_question', params: {'p_code': cleanCode, 'p_q': q});
      sent = true;
    } catch (_) {
      try {
        await Supabase.instance.client.from('questions').insert({
          'code': cleanCode,
          'q': q,
          'created_at': nowIso,
        });
        sent = true;
      } catch (_) {}
    }

    // 2. Always persist into snapshots table as well
    try {
      final res = await Supabase.instance.client
          .from('snapshots')
          .select('data')
          .eq('code', cleanCode)
          .maybeSingle();

      Map<String, dynamic> snapData = {};
      if (res != null && res['data'] != null) {
        snapData = Map<String, dynamic>.from(res['data'] as Map);
      }
      List<dynamic> existingQa = List.from(snapData['qa'] ?? []);
      existingQa.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'code': cleanCode,
        'q': q,
        'a': null,
        'created_at': nowIso,
      });
      snapData['qa'] = existingQa;

      await Supabase.instance.client.from('snapshots').upsert({
        'code': cleanCode,
        'data': snapData,
        'updated_at': nowIso,
      });
      sent = true;
    } catch (_) {}

    if (sent) {
      qCtl.clear();
      await loadQa(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF0F7B5F),
          content: Text('آپ کا سوال استاد کو کامیابی سے بھیج دیا گیا ہے'),
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('خرابی: انٹرنیٹ کنکشن چیک کریں اور دوبارہ کوشش کریں'),
        ));
      }
    }
  }"""

if old_parent_qa in text:
    text = text.replace(old_parent_qa, new_parent_qa)
    print("Replaced Parent Portal QA")
else:
    print("WARNING: old_parent_qa not found")

# 3. Update Teacher QuestionsPage to load from both questions and snapshots
old_questions_load = """  Future<void> load() async {
    try {
      final r = await Supabase.instance.client
          .from('questions')
          .select('id,code,q,a,created_at')
          .order('created_at', ascending: false)
          .limit(50);
      setState(() {
        rows = List<Map<String, dynamic>>.from(r);
        msg = rows.isEmpty ? 'کوئی سوال نہیں' : '';
      });
    } catch (e) {
      setState(() => msg = 'خرابی: $e');
    }
  }"""

new_questions_load = """  Future<void> load() async {
    final Map<String, Map<String, dynamic>> map = {};
    try {
      final r = await Supabase.instance.client
          .from('questions')
          .select('id,code,q,a,created_at')
          .order('created_at', ascending: false)
          .limit(50);
      for (final item in r) {
        final m = Map<String, dynamic>.from(item);
        final k = '${m['code']}_${m['q']}';
        map[k] = m;
      }
    } catch (_) {}

    // Load from snapshots table
    try {
      final snapRows = await Supabase.instance.client
          .from('snapshots')
          .select('code,data');
      for (final row in snapRows) {
        final c = (row['code'] ?? '').toString();
        final d = Map<String, dynamic>.from(row['data'] as Map? ?? {});
        final qList = d['qa'] as List?;
        if (qList != null) {
          for (final qItem in qList) {
            final m = Map<String, dynamic>.from(qItem as Map);
            m['code'] = c;
            final k = '${c}_${m['q']}';
            if (!map.containsKey(k)) {
              map[k] = m;
            }
          }
        }
      }
    } catch (_) {}

    final list = map.values.toList();
    list.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    setState(() {
      rows = list;
      msg = rows.isEmpty ? 'کوئی نیا سوال یا پیغام موصول نہیں ہوا' : '';
    });
  }"""

if old_questions_load in text:
    text = text.replace(old_questions_load, new_questions_load)
    print("Updated QuestionsPage.load")
else:
    print("WARNING: old_questions_load not found")

# 4. Update answer in QuestionsPage to save to both
old_questions_answer = """    if (ok == true && c.text.trim().isNotEmpty) {
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
    }"""

new_questions_answer = """    if (ok == true && c.text.trim().isNotEmpty) {
      final answerText = c.text.trim();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      try {
        await Supabase.instance.client.from('questions').update({
          'a': answerText,
          'answered_at': nowIso,
        }).eq('id', r['id']);
      } catch (_) {}

      // Update snapshots table as well
      try {
        final cleanCode = (r['code'] ?? '').toString().toLowerCase().trim();
        final res = await Supabase.instance.client
            .from('snapshots')
            .select('data')
            .eq('code', cleanCode)
            .maybeSingle();
        if (res != null && res['data'] != null) {
          final snapData = Map<String, dynamic>.from(res['data'] as Map);
          final qList = (snapData['qa'] as List?) ?? [];
          for (final item in qList) {
            final m = item as Map;
            if (m['q'] == r['q']) {
              m['a'] = answerText;
              m['answered_at'] = nowIso;
            }
          }
          await Supabase.instance.client.from('snapshots').update({
            'data': snapData,
            'updated_at': nowIso,
          }).eq('code', cleanCode);
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Color(0xFF0F7B5F),
            content: Text('جواب کامیابی سے محفوظ اور بھیج دیا گیا ہے')));
      }
      load();
    }"""

if old_questions_answer in text:
    text = text.replace(old_questions_answer, new_questions_answer)
    print("Updated QuestionsPage.answer")
else:
    print("WARNING: old_questions_answer not found")

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Patch 2 complete")
