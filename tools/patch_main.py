import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update ThemeData fontFamily to JameelNooriNastaleeq
code = code.replace("fontFamily: 'sans-serif',", "fontFamily: 'JameelNooriNastaleeq',")

# 2. Add local storage fallback snapshot when teacher saves students or updates
# In Store._save():
save_old = """  void _save() {
    _p?.setString('tuition_v1', jsonEncode(toMap()));
    notifyListeners();
    _autoSync();
  }"""

save_new = """  void _save() {
    _p?.setString('tuition_v1', jsonEncode(toMap()));
    // Save local student snapshots for instant offline access by code
    for (final s in students) {
      final snapData = {
        'code': s.code,
        'student_id': s.id,
        'center': center,
        'data': snapshot(s),
      };
      _p?.setString('snap_${s.code.trim().toLowerCase()}', jsonEncode(snapData));
    }
    notifyListeners();
    _autoSync();
  }"""

code = code.replace(save_old, save_new)

# 3. In StudentHome.fetch: add local fallback when offline or Supabase rpc fails
student_fetch_old = """    try {
      final r = await Supabase.instance.client
          .rpc('get_snapshot', params: {'p_code': c});
      if (r == null) {
        err = 'یہ طالب علم کوڈ غلط ہے۔ استاد سے دوبارہ معلوم کریں۔';
      } else {
        final m = Map<String, dynamic>.from(r);
        code = c;
        snap = m;
        final p = await SharedPreferences.getInstance();
        await p.setString('student_code', c);
        await p.setString('student_snap', jsonEncode(m));
        loadQa(c);
      }
    } catch (e) {
      err = 'رابطہ نہ ہو سکا: $e';
    }"""

student_fetch_new = """    final p = await SharedPreferences.getInstance();
    try {
      Map<String, dynamic>? m;
      if (Cfg.ready) {
        final r = await Supabase.instance.client
            .rpc('get_snapshot', params: {'p_code': c});
        if (r != null) m = Map<String, dynamic>.from(r);
      }
      // Check local storage fallback if server returned null or offline
      if (m == null) {
        final localStr = p.getString('snap_$c');
        if (localStr != null) {
          m = Map<String, dynamic>.from(jsonDecode(localStr));
        }
      }

      if (m == null) {
        err = 'یہ طالب علم کوڈ درست نہیں ہے۔ استاد سے دوبارہ تصدیق کریں۔';
      } else {
        code = c;
        snap = m;
        await p.setString('student_code', c);
        await p.setString('student_snap', jsonEncode(m));
        if (Cfg.ready) loadQa(c);
      }
    } catch (e) {
      // Offline fallback
      final localStr = p.getString('snap_$c');
      if (localStr != null) {
        final m = Map<String, dynamic>.from(jsonDecode(localStr));
        code = c;
        snap = m;
        await p.setString('student_code', c);
        await p.setString('student_snap', jsonEncode(m));
      } else {
        err = 'رابطہ نہ ہو سکا۔ برائے مہربانی کوڈ چیک کریں: $e';
      }
    }"""

code = code.replace(student_fetch_old, student_fetch_new)

# 4. In ParentHome.fetch: add local fallback when offline or Supabase rpc fails
parent_fetch_old = """    try {
      final r = await Supabase.instance.client
          .rpc('get_snapshot', params: {'p_code': c});
      if (r == null) {
        err = 'کوڈ غلط ہے';
        codes.remove(c);
        snaps.remove(c);
        if (code == c) {
          code = codes.isNotEmpty ? codes.first : null;
          snap = code == null ? null : snaps[code];
        }
      } else {
        final m = Map<String, dynamic>.from(r);
        snaps[c] = m;
        if (!codes.contains(c)) codes.add(c);
        code = c;
        snap = m;
        registerPush(c);
        loadQa(c);
      }
      await persist();
    } catch (e) {
      err = 'انٹرنیٹ یا سرور کا مسئلہ: $e';
    }"""

parent_fetch_new = """    final p = await SharedPreferences.getInstance();
    try {
      Map<String, dynamic>? m;
      if (Cfg.ready) {
        final r = await Supabase.instance.client
            .rpc('get_snapshot', params: {'p_code': c});
        if (r != null) m = Map<String, dynamic>.from(r);
      }
      // Check local storage fallback
      if (m == null) {
        final localStr = p.getString('snap_$c');
        if (localStr != null) {
          m = Map<String, dynamic>.from(jsonDecode(localStr));
        }
      }

      if (m == null) {
        err = 'کوڈ درست نہیں ہے۔ استاد سے دوبارہ معلوم کریں۔';
        codes.remove(c);
        snaps.remove(c);
        if (code == c) {
          code = codes.isNotEmpty ? codes.first : null;
          snap = code == null ? null : snaps[code];
        }
      } else {
        snaps[c] = m;
        if (!codes.contains(c)) codes.add(c);
        code = c;
        snap = m;
        if (Cfg.ready) {
          registerPush(c);
          loadQa(c);
        }
      }
      await persist();
    } catch (e) {
      final localStr = p.getString('snap_$c');
      if (localStr != null) {
        final m = Map<String, dynamic>.from(jsonDecode(localStr));
        snaps[c] = m;
        if (!codes.contains(c)) codes.add(c);
        code = c;
        snap = m;
        await persist();
      } else {
        err = 'انٹرنیٹ یا سرور کا مسئلہ: $e';
      }
    }"""

code = code.replace(parent_fetch_old, parent_fetch_new)

# 5. In Gate (main screen): check version and show upgrade notification card
gate_check_old = """  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() {
        role = p.getString('role');
        loaded = true;
      });
    });
  }"""

gate_check_new = """  bool showUpgradeNotice = false;
  static const currentVersion = '1.1.0';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final lastVer = p.getString('installed_version');
      bool upgraded = false;
      if (lastVer != null && lastVer != currentVersion) {
        upgraded = true;
      }
      p.setString('installed_version', currentVersion);

      setState(() {
        role = p.getString('role');
        loaded = true;
        showUpgradeNotice = upgraded;
      });
    });
  }"""

code = code.replace(gate_check_old, gate_check_new)

# Insert upgrade banner in Gate build Column
gate_column_old = """                const SizedBox(height: 32),
                _roleCard("""

gate_column_new = """                if (showUpgradeNotice) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ایپ کامیابی سے اپ گریڈ ہو گئی! (v1.1.0)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'نئے فونٹس (جمیل نوری نستعلیق)، رنگین تجویدی قرآن، انگریزی ترجمہ اور مستقل کنیکٹیویٹی شامل کر دی گئی ہے۔',
                                style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: const Color(0xFF92400E),
                          onPressed: () => setState(() => showUpgradeNotice = false),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _roleCard("""

code = code.replace(gate_column_old, gate_column_new)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print('Updated lib/main.dart with font, connectivity, and upgrade notice!')
