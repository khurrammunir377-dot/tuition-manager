import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'quran_screen.dart';

bool pushReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Cfg.ready) {
    await Supabase.initialize(url: Cfg.url, anonKey: Cfg.anonKey);
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      pushReady = true;
    } catch (_) {}
  }
  runApp(const TuitionApp());
}

String newCode() {
  const c = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(8, (_) => c[r.nextInt(c.length)]).join();
}

class Student {
  final String id, name, phone, code;
  final String? batchId;
  final int fee;
  final String currency; // 'PKR', 'USD', 'GBP', 'AED', 'SAR', 'EUR'
  final bool isOnline;
  final String meetingLink;
  final String courseType; // 'school', 'quran_qaida', 'quran_nazra', 'quran_hifz', 'quran_tarjuma', 'general_online'
  final Map<String, dynamic>? quran;
  final String timing; // e.g. '4:00 PM - 6:00 PM'

  Student(
    this.id,
    this.name,
    this.phone,
    this.fee,
    this.code, {
    this.batchId,
    this.currency = 'PKR',
    this.isOnline = false,
    this.meetingLink = '',
    this.courseType = 'school',
    this.quran,
    this.timing = '',
  });

  String get currencySymbol {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'EUR':
        return '€';
      case 'AED':
        return 'AED';
      case 'SAR':
        return 'SAR';
      default:
        return 'روپے';
    }
  }

  String get courseLabel {
    switch (courseType) {
      case 'quran_qaida':
        return 'نورانی قاعدہ';
      case 'quran_nazra':
        return 'ناظرہ قرآن';
      case 'quran_hifz':
        return 'حفظ القرآن';
      case 'quran_tarjuma':
        return 'ترجمہ و تفسیر';
      case 'general_online':
        return 'آن لائن ٹیوشن';
      default:
        return 'اکیڈمی / سکول';
    }
  }

  bool get isQuranStudent => courseType.startsWith('quran_');

  Student copyWith({
    String? name,
    String? phone,
    int? fee,
    String? batchId,
    String? currency,
    bool? isOnline,
    String? meetingLink,
    String? courseType,
    Map<String, dynamic>? quran,
    String? timing,
  }) =>
      Student(
        id,
        name ?? this.name,
        phone ?? this.phone,
        fee ?? this.fee,
        code,
        batchId: batchId ?? this.batchId,
        currency: currency ?? this.currency,
        isOnline: isOnline ?? this.isOnline,
        meetingLink: meetingLink ?? this.meetingLink,
        courseType: courseType ?? this.courseType,
        quran: quran ?? this.quran,
        timing: timing ?? this.timing,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'fee': fee,
        'code': code,
        'batchId': batchId,
        'currency': currency,
        'isOnline': isOnline,
        'meetingLink': meetingLink,
        'courseType': courseType,
        'quran': quran,
        'timing': timing,
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        j['id'],
        j['name'],
        j['phone'],
        j['fee'],
        j['code'] ?? newCode(),
        batchId: j['batchId'],
        currency: j['currency'] ?? 'PKR',
        isOnline: j['isOnline'] ?? false,
        meetingLink: j['meetingLink'] ?? '',
        courseType: j['courseType'] ?? 'school',
        quran: j['quran'] != null ? Map<String, dynamic>.from(j['quran']) : null,
        timing: j['timing'] ?? '',
      );
}

class Store extends ChangeNotifier {
  String center = 'میرا ٹیوشن و قرآن سینٹر';
  String teachingMode = 'all'; // 'all', 'physical', 'online'

  void setTeachingMode(String m) {
    teachingMode = m;
    notifyListeners();
  }

  List<Student> get filteredStudents {
    if (teachingMode == 'physical') return students.where((s) => !s.isOnline).toList();
    if (teachingMode == 'online') return students.where((s) => s.isOnline).toList();
    return students;
  }

  final List<Student> students = [];
  final Map<String, Map<String, bool>> att = {};
  final Map<String, Map<String, bool>> paid = {};
  final Map<String, Map<String, int>> pays = {};
  final Map<String, String> notes = {};
  final List<Map<String, String>> notices = [];
  final List<Map<String, dynamic>> batches = [];
  final List<Map<String, dynamic>> tests = [];
  final List<Map<String, dynamic>> ledger = [];
  final List<Map<String, dynamic>> homework = [];
  final Map<String, String> profile = {};
  SharedPreferences? _p;

  String get today => DateTime.now().toIso8601String().substring(0, 10);
  String get month => today.substring(0, 7);

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p!.getString('tuition_v1');
    if (raw == null) return;
    _apply(jsonDecode(raw) as Map<String, dynamic>);
    _save();
  }

  void _apply(Map<String, dynamic> j) {
    center = j['center'] ?? center;
    students
      ..clear()
      ..addAll((j['students'] as List)
          .map((e) => Student.fromJson(Map<String, dynamic>.from(e))));
    att.clear();
    (j['att'] as Map).forEach((d, m) => att[d] = Map<String, bool>.from(m));
    paid.clear();
    (j['paid'] as Map).forEach((d, m) => paid[d] = Map<String, bool>.from(m));
    notes
      ..clear()
      ..addAll(Map<String, String>.from(j['notes']));
    notices
      ..clear()
      ..addAll(((j['notices'] ?? []) as List)
          .map((e) => Map<String, String>.from(e)));
    List<Map<String, dynamic>> list(String k) => ((j[k] ?? []) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    batches
      ..clear()
      ..addAll(list('batches'));
    tests
      ..clear()
      ..addAll(list('tests'));
    ledger
      ..clear()
      ..addAll(list('ledger'));
    homework
      ..clear()
      ..addAll(list('homework'));
    profile
      ..clear()
      ..addAll(Map<String, String>.from(j['profile'] ?? {}));
    pays.clear();
    ((j['pays'] ?? {}) as Map).forEach((m, v) {
      pays[m] = Map<String, int>.from(v);
    });
  }

  void _save() {
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
  }

  Map<String, dynamic> toMap() => {
        'center': center,
        'students': students.map((s) => s.toJson()).toList(),
        'att': att,
        'paid': paid,
        'notes': notes,
        'notices': notices,
        'batches': batches,
        'tests': tests,
        'ledger': ledger,
        'homework': homework,
        'profile': profile,
        'pays': pays,
      };

  Timer? _timer;
  String syncStatus = '';
  bool get _loggedIn =>
      Cfg.ready && Supabase.instance.client.auth.currentUser != null;

  Future<void> publishSnapshots() async {
    if (!Cfg.ready || students.isEmpty) return;
    try {
      final c = Supabase.instance.client;
      await c.from('snapshots').upsert(
        students.map((s) => {
          'code': s.code.toLowerCase().trim(),
          'student_id': s.id,
          'center': center,
          'data': snapshot(s),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).toList(),
        onConflict: 'code',
      );
    } catch (_) {
      try {
        final c = Supabase.instance.client;
        await c.from('snapshots').upsert(
          students.map((s) => {
            'code': s.code.toLowerCase().trim(),
            'data': snapshot(s),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).toList(),
          onConflict: 'code',
        );
      } catch (_) {}
    }
  }

  void _autoSync() {
    publishSnapshots();
    if (!_loggedIn) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () async {
      syncStatus = await sync();
      notifyListeners();
    });
  }

  Future<String> restore() async {
    if (!_loggedIn) return 'پہلے لاگ اِن کریں';
    try {
      final r = await Supabase.instance.client
          .from('backups')
          .select('data')
          .maybeSingle();
      if (r == null) return 'کوئی بیک اپ نہیں ملا';
      _apply(Map<String, dynamic>.from(r['data']));
      _save();
      return 'بحال ہو گیا: ${students.length} طلبہ';
    } catch (e) {
      return 'بحالی ناکام: $e';
    }
  }

  void addStudent(
    String name,
    String phone,
    int fee, {
    String? batchId,
    String currency = 'PKR',
    bool isOnline = false,
    String meetingLink = '',
    String courseType = 'school',
    Map<String, dynamic>? quran,
    String timing = '',
  }) {
    students.add(Student(
      's${DateTime.now().microsecondsSinceEpoch}',
      name,
      phone,
      fee,
      newCode(),
      batchId: batchId,
      currency: currency,
      isOnline: isOnline,
      meetingLink: meetingLink,
      courseType: courseType,
      quran: quran,
      timing: timing,
    ));
    _save();
  }

  void updateStudent(Student updated) {
    final i = students.indexWhere((s) => s.id == updated.id);
    if (i != -1) {
      students[i] = updated;
      _save();
    }
  }

  void updateQuranProgress(
    String studentId, {
    required int para,
    required String surah,
    required String sabaq,
    required String sabaqi,
    required String manzil,
    required String grade,
  }) {
    final i = students.indexWhere((s) => s.id == studentId);
    if (i != -1) {
      final st = students[i];
      students[i] = st.copyWith(
        quran: {
          'para': para,
          'surah': surah,
          'sabaq': sabaq,
          'sabaqi': sabaqi,
          'manzil': manzil,
          'grade': grade,
          'updated_at': today,
        },
      );
      _save();
    }
  }

  void delStudent(String id) {
    final st = students.firstWhere((s) => s.id == id);
    students.removeWhere((s) => s.id == id);
    if (Cfg.ready && Supabase.instance.client.auth.currentUser != null) {
      Supabase.instance.client
          .from('snapshots')
          .delete()
          .eq('code', st.code)
          .then((_) {}, onError: (_) {});
    }
    _save();
  }

  void setAtt(String id, bool v) {
    att.putIfAbsent(today, () => {})[id] = v;
    _save();
  }

  void markAllAtt(bool v) {
    final m = att.putIfAbsent(today, () => {});
    for (final s in students) {
      m[s.id] = v;
    }
    _save();
  }

  bool? attToday(String id) => att[today]?[id];
  bool isPaid(String id) => paid[month]?[id] ?? false;

  int dueOf(String id) {
    final i = students.indexWhere((x) => x.id == id);
    if (i < 0) return 0;
    final st = students[i];
    var d = st.fee;
    final pct = int.tryParse(profile['sibling'] ?? '') ?? 0;
    if (pct > 0 && st.phone.trim().isNotEmpty) {
      final dup =
          students.sublist(0, i).any((x) => x.phone.trim() == st.phone.trim());
      if (dup) d = (d * (100 - pct) / 100).round();
    }
    return d;
  }

  int remaining(String id) =>
      isPaid(id) ? 0 : max(0, dueOf(id) - (pays[month]?[id] ?? 0));

  int receivedTotal() => students.fold<int>(
      0, (a, x) => a + (isPaid(x.id) ? dueOf(x.id) : (pays[month]?[x.id] ?? 0)));

  void togglePaid(String id) {
    final m = paid.putIfAbsent(month, () => {});
    final now = !(m[id] ?? false);
    m[id] = now;
    if (now) {
      pays.putIfAbsent(month, () => {})[id] = dueOf(id);
    } else {
      pays[month]?.remove(id);
    }
    _save();
  }

  void addPayment(String id, int amount) {
    final m = pays.putIfAbsent(month, () => {});
    m[id] = (m[id] ?? 0) + amount;
    if (m[id]! >= dueOf(id)) paid.putIfAbsent(month, () => {})[id] = true;
    _save();
  }

  String feeReminder(Student s) =>
      'السلام علیکم! ${s.name} کی $month کی فیس ${remaining(s.id)} ${s.currencySymbol} باقی ہے۔ براہِ کرم ادا فرما دیں۔ شکریہ\n$center';

  void setNote(String t) {
    notes[today] = t;
    _save();
  }

  void setCenter(String t) {
    center = t;
    _save();
  }

  int presentDays(String id) => att.entries
      .where((e) => e.key.startsWith(month) && e.value[id] == true)
      .length;
  int markedDays(String id) => att.entries
      .where((e) => e.key.startsWith(month) && e.value.containsKey(id))
      .length;

  String message(Student s) {
    final a = attToday(s.id);
    final status = a == true
        ? 'حاضر ✅'
        : a == false
            ? 'غیر حاضر ❌'
            : 'غیر معین';
    final note = notes[today];
    final fee = isPaid(s.id)
        ? 'مکمل ادا شدہ ✅'
        : 'باقی: ${remaining(s.id)} ${s.currencySymbol}';
    
    var t = 'السلام علیکم ورحمۃ اللہ!\n';
    t += '🏫 *$center*\n\n';
    t += 'محترم والدین، طالب علم *${s.name}* کی روزانہ تعلیمی رپورٹ:\n';
    t += '📅 تاریخ: $today\n';
    t += 'حاضری: $status\n';
    if (s.timing.isNotEmpty) {
      t += '⏰ کلاس کا وقت: ${s.timing}\n';
    }
    if (s.isOnline && s.meetingLink.isNotEmpty) {
      t += '💻 آن لائن کلاس لنک: ${s.meetingLink}\n';
    }
    if (s.quran != null) {
      final q = s.quran!;
      t += '📖 قرآن سبق: پارہ ${q['para'] ?? 1}، ${q['surah'] ?? ''} (${q['sabaq'] ?? ''})\n';
      if ((q['sabaqi'] ?? '').toString().isNotEmpty) {
        t += '🔁 سبقی: ${q['sabaqi']}\n';
      }
      if ((q['manzil'] ?? '').toString().isNotEmpty) {
        t += '🕋 منزل: ${q['manzil']}\n';
      }
      if ((q['grade'] ?? '').toString().isNotEmpty) {
        t += '⭐ کارکردگی: ${q['grade']}\n';
      }
    } else if (note != null && note.isNotEmpty) {
      t += '📝 آج کا سبق: $note\n';
    }
    t += '💰 فیس ($month): $fee\n\n';
    t += '📲 *والدین و طلبہ پورٹل:*\n';
    t += 'روزانہ لائیو حاضری، سبق اور مکمل ریکارڈ دیکھنے کے لیے ایپ ڈاؤن لوڈ کریں:\n';
    t += '👉 https://kmb-teacher.vercel.app\n\n';
    t += '🔑 *طالب علم لاگ اِن کوڈ (Student Code):*\n';
    t += '━━━━━━━━━━━━━━━━━━━━\n';
    t += '```${s.code}```\n';
    t += '━━━━━━━━━━━━━━━━━━━━\n';
    t += '👆 _کوڈ کو کاپی کرنے کے لیے اوپر دیے گئے کوڈ پر ٹیپ کریں_\n';
    t += '(ایپ میں "میں والد/والدہ ہوں" یا "میں طالب علم ہوں" منتخب کر کے یہ کوڈ درج کریں)';
    return t;
  }

  void addHomework(String url, String path, String batch) {
    homework
        .add({'id': _id(), 'd': today, 'url': url, 'path': path, 'batch': batch});
    if (homework.length > 10) homework.removeAt(0);
    _save();
  }

  void delHomework(String id) {
    final h = homework.firstWhere((x) => x['id'] == id);
    homework.removeWhere((x) => x['id'] == id);
    if (_loggedIn) {
      Supabase.instance.client.storage
          .from('homework')
          .remove(['${h['path']}']).then((_) {}, onError: (_) {});
    }
    _save();
  }

  List<Map<String, dynamic>> hwFor(Student s) => homework.reversed
      .where((h) => (h['batch'] ?? '') == '' || h['batch'] == s.batchId)
      .take(3)
      .map((h) => {'url': h['url'], 'd': h['d']})
      .toList();

  List<int> weekStats(String id) {
    final cs = DateTime.now()
        .subtract(const Duration(days: 6))
        .toIso8601String()
        .substring(0, 10);
    var m = 0, pr = 0;
    att.forEach((d, mp) {
      if (d.compareTo(cs) >= 0 && mp.containsKey(id)) {
        m++;
        if (mp[id] == true) pr++;
      }
    });
    return [m, pr];
  }

  String weeklyMessage(Student s) {
    final w = weekStats(s.id);
    final ts = testsFor(s)
        .take(3)
        .map((x) => '${x['name']} ${x['got']}/${x['total']}')
        .join('، ');
    final fee = isPaid(s.id) ? 'ادا ✅' : 'باقی ${remaining(s.id)} ${s.currencySymbol}';
    final tl = ts.isEmpty ? '' : 'ٹیسٹ: $ts\n';
    return 'السلام علیکم! ${s.name} کا ہفتہ وار خلاصہ:\nحاضری: ${w[0]} میں سے ${w[1]} دن\n${tl}فیس: $fee\n\n'
        '📲 مکمل ریکارڈ دیکھنے کے لیے ایپ لنک:\nhttps://kmb-teacher.vercel.app\n\n'
        '🔑 طالب علم لاگ اِن کوڈ:\n━━━━━━━━━━━━━━━━━━━━\n```${s.code}```\n━━━━━━━━━━━━━━━━━━━━\n$center';
  }

  Map<String, dynamic>? batchOf(Student s) {
    for (final b in batches) {
      if (b['id'] == s.batchId) return b;
    }
    return null;
  }

  List<Map<String, dynamic>> testsFor(Student s) {
    final out = <Map<String, dynamic>>[];
    for (final t in tests.reversed) {
      final b = t['batch'] ?? '';
      if (b != '' && b != s.batchId) continue;
      final m = (t['marks'] as Map)[s.id];
      if (m != null) {
        out.add({'name': t['name'], 'd': t['date'], 'total': t['total'], 'got': m});
      }
      if (out.length >= 5) break;
    }
    return out;
  }

  String _id() => 'x${DateTime.now().microsecondsSinceEpoch}';

  void setProfile(String k, String v) {
    profile[k] = v;
    _save();
  }

  void addBatch(String name, String subject, String time, int fee) {
    batches.add({
      'id': _id(),
      'name': name,
      'subject': subject,
      'time': time,
      'fee': fee
    });
    _save();
  }

  void delBatch(String id) {
    batches.removeWhere((b) => b['id'] == id);
    for (var i = 0; i < students.length; i++) {
      final x = students[i];
      if (x.batchId == id) {
        students[i] = Student(
          x.id,
          x.name,
          x.phone,
          x.fee,
          x.code,
          currency: x.currency,
          isOnline: x.isOnline,
          meetingLink: x.meetingLink,
          courseType: x.courseType,
          quran: x.quran,
        );
      }
    }
    _save();
  }

  void addTest(String name, int total, String batch) {
    tests.add({
      'id': _id(),
      'name': name,
      'date': today,
      'total': total,
      'batch': batch,
      'marks': <String, dynamic>{}
    });
    _save();
  }

  void delTest(String id) {
    tests.removeWhere((x) => x['id'] == id);
    _save();
  }

  void setMark(String tid, String sid, num? v) {
    final m = tests.firstWhere((x) => x['id'] == tid)['marks'] as Map;
    if (v == null) {
      m.remove(sid);
    } else {
      m[sid] = v;
    }
    _save();
  }

  void addLedger(String type, String title, int amount) {
    ledger.add({
      'id': _id(),
      'd': today,
      'type': type,
      'title': title,
      'amount': amount
    });
    _save();
  }

  void delLedger(String id) {
    ledger.removeWhere((x) => x['id'] == id);
    _save();
  }

  void addNotice(String t) {
    notices.insert(0, {'d': today, 't': t});
    if (notices.length > 5) notices.removeLast();
    _save();
  }

  Map<String, dynamic> snapshot(Student s) => {
        'name': s.name,
        'today': today,
        'att': attToday(s.id),
        'present': presentDays(s.id),
        'marked': markedDays(s.id),
        'note': notes[today] ?? '',
        'paid': isPaid(s.id),
        'fee': dueOf(s.id),
        'rem': remaining(s.id),
        'currency': s.currency,
        'currencySymbol': s.currencySymbol,
        'isOnline': s.isOnline,
        'meetingLink': s.meetingLink,
        'courseType': s.courseType,
        'courseLabel': s.courseLabel,
        'quran': s.quran,
        'month': month,
        'notices': notices,
        'batch': batchOf(s)?['name'] ?? '',
        'time': s.timing.isNotEmpty ? s.timing : (batchOf(s)?['time'] ?? ''),
        'tests': testsFor(s),
        'hw': hwFor(s),
        'week': weekStats(s.id),
        'teacherName': profile['teacher'] ?? '',
        'centerPhone': profile['phone'] ?? '',
      };

  Future<String> sync() async {
    if (!Cfg.ready) return "پہلے config.dart میں Supabase کی کیز ڈالیں";
    final c = Supabase.instance.client;
    if (c.auth.currentUser != null) {
      try {
        await c.from("backups").upsert({
          "owner": c.auth.currentUser!.id,
          "data": toMap(),
          "updated_at": DateTime.now().toUtc().toIso8601String(),
        }, onConflict: "owner");
      } catch (_) {}
    }
    if (students.isEmpty) return "سنک مکمل (کوئی طالب علم نہیں)";
    try {
      await c.from("snapshots").upsert(
          students
              .map((s) => {
                    "code": s.code.toLowerCase().trim(),
                    "student_id": s.id,
                    "center": center,
                    "data": snapshot(s),
                    "updated_at": DateTime.now().toUtc().toIso8601String(),
                  })
              .toList(),
          onConflict: "code");
      return "تمام طلبہ کا پورٹل ڈیٹا کامیابی سے سنک ہو گیا";
    } catch (_) {
      try {
        await c.from("snapshots").upsert(
            students
                .map((s) => {
                      "code": s.code.toLowerCase().trim(),
                      "data": snapshot(s),
                      "updated_at": DateTime.now().toUtc().toIso8601String(),
                    })
                .toList(),
            onConflict: "code");
        return "طالب علم پورٹل اپ ڈیٹ ہو گیا";
      } catch (e) {
        return "سنک میں خرابی: $e";
      }
    }
  }

  Future<void> sendWhatsApp(Student s, [String? text]) async {
    var p = s.phone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) p = '92${p.substring(1)}';
    final uri = Uri.parse(
        'https://wa.me/$p?text=${Uri.encodeComponent(text ?? message(s))}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class TuitionApp extends StatelessWidget {
  const TuitionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ٹیوشن و قرآن مینیجر',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            primary: const Color(0xFF0F766E),
            secondary: const Color(0xFFD97706),
            surface: const Color(0xFFF8FAFC),
          ),
          useMaterial3: true,
          fontFamily: 'JameelNooriNastaleeq',
          scaffoldBackgroundColor: const Color(0xFFF1F5F9),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF064E3B),
            foregroundColor: Colors.white,
            elevation: 1,
            centerTitle: false,
            iconTheme: IconThemeData(color: Colors.white),
            actionsIconTheme: IconThemeData(color: Colors.white),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            brightness: Brightness.dark,
            primary: const Color(0xFF14B8A6),
            secondary: const Color(0xFFF59E0B),
            surface: const Color(0xFF0F172A),
          ),
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0B0F19),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF022C22),
            foregroundColor: Colors.white,
            elevation: 1,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        builder: (c, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const SplashScreen(),
      );
}

// ---------------- دلکش ویلکم / سپلیش اسکرین (Splash Screen) ----------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();

    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const Gate(),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF042F2E), // Dark Emerald
              Color(0xFF0F766E), // Emerald Green
              Color(0xFF042F2E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: FadeTransition(
                  opacity: _fade,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icons/kmb_logo.png',
                      height: 85,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.menu_book_rounded,
                        size: 68,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    const Text(
                      'ٹیوشن اکیڈمی و آن لائن قرآن پورٹل',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'JameelNooriNastaleeq',
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                      ),
                      child: const Text(
                        'KMB Education Suite · v1.2',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFFFDE68A),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'اساتذہ، اکیڈمیز، آن لائن تدریس، طلبہ اور والدین کا باوقار ڈیجیٹل ساتھی',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'JameelNooriNastaleeq',
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.95),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFDE68A)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ورژن 1.2.0',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final VoidCallback onSwitch;
  const Home({super.key, required this.onSwitch});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final store = Store();
  bool ready = false;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    store.load().then((_) {
      setState(() => ready = true);
    });
  }

  Widget _buildModePill({
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
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pages = [
          StudentsPage(store),
          AttendancePage(store),
          FeesPage(store),
          NotePage(store),
          MorePage(store),
        ];
        return Scaffold(
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
                icon: const Icon(Icons.mark_chat_unread_rounded),
                tooltip: 'طلبہ کے سوالات و پیغامات',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => QuestionsPage(store)),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'مزید اختیارات',
                onSelected: (val) {
                  if (val == 'quran') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuranReaderScreen()),
                    );
                  } else if (val == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CenterPage(store)),
                    );
                  } else if (val == 'switch') {
                    widget.onSwitch();
                  } else if (val == 'about') {
                    showAboutDialog(
                      context: context,
                      applicationName: 'ٹیوشن و قرآن مینیجر',
                      applicationVersion: 'v1.1.0 (PRO)',
                      applicationIcon: const Icon(Icons.menu_book_rounded, size: 48, color: Color(0xFF0F766E)),
                      children: const [
                        Text('اکیڈمیز، آن لائن ٹیوشن، حفظ و ناظرہ قرآن اور سکول اساتذہ کے لیے ہمہ گیر انتظامی ایپ۔\n\n© 2026 Tuition Manager'),
                      ],
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'quran',
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: Color(0xFF0F766E), size: 20),
                        SizedBox(width: 10),
                        Text('📖 قرآن پاک و قاعدہ'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, color: Color(0xFF0F766E), size: 20),
                        SizedBox(width: 10),
                        Text('⚙️ سینٹر سیٹنگز و بیک اپ'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'switch',
                    child: Row(
                      children: [
                        Icon(Icons.switch_account_rounded, color: Color(0xFF0F766E), size: 20),
                        SizedBox(width: 10),
                        Text('🔄 کردار تبدیل کریں'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'about',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                        SizedBox(width: 10),
                        Text('ℹ️ ایپ کے بارے میں'),
                      ],
                    ),
                  ),
                ],
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
          ),
          floatingActionButton: (tab == 0 && store.students.isNotEmpty)
              ? FloatingActionButton.extended(
                  onPressed: () => _openAddStudentSheet(context, store),
                  backgroundColor: const Color(0xFF0F7B5F),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('طالب علم شامل کریں',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.groups_rounded), label: 'طلبہ'),
              NavigationDestination(
                  icon: Icon(Icons.how_to_reg_rounded), label: 'حاضری'),
              NavigationDestination(
                  icon: Icon(Icons.payments_rounded), label: 'فیس'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_rounded), label: 'سبق'),
              NavigationDestination(
                  icon: Icon(Icons.campaign_rounded), label: 'پیغامات'),
            ],
          ),
        );
      },
    );
  }
}

Widget field(TextEditingController c, String hint,
        {TextInputType? type, String? helper}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: hint,
          helperText: helper,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );


// ---------------- کال موڈل شیٹ (Call Options Modal) ----------------
void _openCallSheet(BuildContext context, Student st) {
  final cleanPhone = st.phone.replaceAll(RegExp(r'\D'), '');
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF0F766E)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${st.name} سے رابطہ',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      st.phone.isNotEmpty ? st.phone : 'کوئی فون نمبر درج نہیں',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.call_rounded, color: Colors.blue.shade700),
            ),
            title: const Text('براہ راست فون کال (SIM Direct Call)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('موبائل سم سے فوری کال ملائیں (کوئی انٹرنیٹ ضروری نہیں)'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.pop(ctx);
              if (cleanPhone.isNotEmpty) {
                launchUrl(Uri.parse('tel:$cleanPhone'), mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('طالب علم کا فون نمبر درج نہیں ہے')));
              }
            },
          ),
          const Divider(height: 12),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF166534)),
            ),
            title: const Text('واٹس ایپ وائس کال (WhatsApp Voice)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('واٹس ایپ کال + دورانِ کال قرآن و حاضری سیشن ٹائمر'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.pop(ctx);
              CallSessionManager.instance.startCall(context, st, video: false);
            },
          ),
          const Divider(height: 12),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.videocam_rounded, color: Color(0xFF0F766E)),
            ),
            title: const Text('واٹس ایپ ویڈیو کال (WhatsApp Video)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('آن لائن تلاوت و سبق کے لیے ویڈیو کال'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.pop(ctx);
              CallSessionManager.instance.startCall(context, st, video: true);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

// ---------------- طالب علم فارم (Add / Edit Student Sheet) ----------------
void _openAddStudentSheet(BuildContext context, Store s, [Student? edit]) {
  final nameCtl = TextEditingController(text: edit?.name ?? '');
  final phoneCtl = TextEditingController(text: edit?.phone ?? '');
  final feeCtl = TextEditingController(text: edit != null ? '${edit.fee}' : '');
  final meetCtl = TextEditingController(text: edit?.meetingLink ?? '');
  final timeCtl = TextEditingController(text: edit?.timing ?? '');
  String? batch = edit?.batchId;
  String currency = edit?.currency ?? 'PKR';
  bool isOnline = edit?.isOnline ?? false;
  String courseType = edit?.courseType ?? 'school';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setM) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Icon(edit == null ? Icons.person_add_rounded : Icons.edit_note,
                    color: const Color(0xFF0F7B5F), size: 28),
                const SizedBox(width: 10),
                Text(
                  edit == null
                      ? 'نیا طالب علم شامل کریں'
                      : 'طالب علم کی تفصیل بدلیں',
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 20),
            field(nameCtl, 'طالب علم کا پورا نام'),
            field(phoneCtl, 'والدین کا واٹس ایپ نمبر (+ کے ساتھ، مثلاً +92... یا +1...)',
                type: TextInputType.phone,
                helper: 'بین الاقوامی نمبر + کوڈ کے ساتھ درج کریں'),
            field(timeCtl, 'کلاس / پڑھائی کے اوقات (مثلاً: 4:00 PM تا 6:00 PM)',
                helper: 'روزانہ ٹیوشن یا قرآن کلاس کا وقت'),
            const Text('کورس کی نوعیت',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: courseType,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'school', child: Text('📚 اکیڈمی / سکول و کالج ٹیوشن')),
                DropdownMenuItem(
                    value: 'quran_qaida', child: Text('📖 نورانی قاعدہ')),
                DropdownMenuItem(
                    value: 'quran_nazra', child: Text('📖 ناظرہ قرآن مجید')),
                DropdownMenuItem(
                    value: 'quran_hifz', child: Text('🕌 حفظ القرآن الکریم')),
                DropdownMenuItem(
                    value: 'quran_tarjuma', child: Text('🕋 ترجمہ و تفسیر قرآن')),
                DropdownMenuItem(
                    value: 'general_online', child: Text('🌐 عمومی آن لائن کلاس')),
              ],
              onChanged: (v) => setM(() => courseType = v ?? 'school'),
            ),
            const SizedBox(height: 12),
            Card(
              color: isOnline ? Colors.teal.shade50 : null,
              child: SwitchListTile(
                title: const Text('آن لائن کلاس ہے؟',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isOnline
                    ? 'آن لائن زوم / گوگل میٹ کے ذریعے'
                    : 'فزیکل / اکیڈمی میں'),
                value: isOnline,
                onChanged: (v) => setM(() => isOnline = v),
              ),
            ),
            if (isOnline) ...[
              const SizedBox(height: 6),
              field(meetCtl, 'زوم / گوگل میٹ لنک (Zoom / Meet URL)',
                  type: TextInputType.url,
                  helper: 'طالب علم ایپ سے ایک کلک پر کلاس میں شامل ہو سکے گا'),
            ],
            if (s.batches.isNotEmpty) ...[
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                value: batch,
                decoration: const InputDecoration(
                    labelText: 'بیچ / کلاس (اختیاری)',
                    border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('کوئی بیچ نہیں')),
                  ...s.batches.map((b) => DropdownMenuItem(
                      value: b['id'] as String, child: Text('${b['name']}'))),
                ],
                onChanged: (v) => setM(() => batch = v),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: field(feeCtl, 'ماہانہ فیس کی رقم',
                      type: TextInputType.number),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: currency,
                    decoration:
                        const InputDecoration(labelText: 'کرنسی', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'PKR', child: Text('PKR (روپے)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                      DropdownMenuItem(value: 'AED', child: Text('AED')),
                      DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                    ],
                    onChanged: (v) => setM(() => currency = v ?? 'PKR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7B5F)),
                icon: Icon(edit == null ? Icons.add_circle : Icons.check_circle),
                label: Text(
                  edit == null ? 'طالب علم محفوظ کریں' : 'تبدیلیاں محفوظ کریں',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final name = nameCtl.text.trim();
                  if (name.isEmpty) return;
                  final fee = int.tryParse(feeCtl.text.trim()) ?? 0;
                  if (edit == null) {
                    s.addStudent(
                      name,
                      phoneCtl.text.trim(),
                      fee,
                      batchId: batch,
                      currency: currency,
                      isOnline: isOnline,
                      meetingLink: meetCtl.text.trim(),
                      courseType: courseType,
                      timing: timeCtl.text.trim(),
                    );
                  } else {
                    s.updateStudent(edit.copyWith(
                      name: name,
                      phone: phoneCtl.text.trim(),
                      fee: fee,
                      batchId: batch,
                      currency: currency,
                      isOnline: isOnline,
                      meetingLink: meetCtl.text.trim(),
                      courseType: courseType,
                      timing: timeCtl.text.trim(),
                    ));
                  }
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------- قرآن پاک ڈائری لاگر (Quran Progress Logger) ----------------
void _openQuranDiarySheet(BuildContext context, Store s, Student st) {
  final curQ = st.quran ?? {};
  int para = (curQ['para'] as num?)?.toInt() ?? 1;
  final surahCtl = TextEditingController(text: '${curQ['surah'] ?? ""}');
  final sabaqCtl = TextEditingController(text: '${curQ['sabaq'] ?? ""}');
  final sabaqiCtl = TextEditingController(text: '${curQ['sabaqi'] ?? ""}');
  final manzilCtl = TextEditingController(text: '${curQ['manzil'] ?? ""}');
  String grade = '${curQ['grade'] ?? "ممتاز"}';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setM) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    color: Color(0xFF0F7B5F), size: 28),
                const SizedBox(width: 10),
                Text(
                  '${st.name} - یومیہ قرآن ڈائری',
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: para,
                    decoration: const InputDecoration(
                        labelText: 'پارہ نمبر', border: OutlineInputBorder()),
                    items: List.generate(
                      30,
                      (i) => DropdownMenuItem(
                          value: i + 1, child: Text('پارہ ${i + 1}')),
                    ),
                    onChanged: (v) => setM(() => para = v ?? 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: field(surahCtl, 'سورۃ کا نام (مثلاً البقرۃ)'),
                ),
              ],
            ),
            field(sabaqCtl, 'آج کا سبق (مثلاً آیات 1 تا 25، یا صفحہ 10)'),
            field(sabaqiCtl, 'سبقی (مثلاً پچھلا نصف پارہ / 5 صفحات)'),
            field(manzilCtl, 'منزل (مثلاً پارہ 1 تا 3 کی دہرائی)'),
            const Text('کارکردگی / گریڈ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['ممتاز ⭐⭐⭐', 'بہت اچھا ⭐⭐', 'مناسب ⭐', 'دہرائی درکار ⚠️']
                  .map((g) => ChoiceChip(
                        label: Text(g),
                        selected: grade == g,
                        onSelected: (_) => setM(() => grade = g),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      s.updateQuranProgress(
                        st.id,
                        para: para,
                        surah: surahCtl.text.trim(),
                        sabaq: sabaqCtl.text.trim(),
                        sabaqi: sabaqiCtl.text.trim(),
                        manzil: manzilCtl.text.trim(),
                        grade: grade,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('قرآن ڈائری محفوظ ہو گئی')));
                    },
                    child: const Text('صرف محفوظ کریں'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7B5F)),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('محفوظ و واٹس ایپ'),
                    onPressed: () async {
                      s.updateQuranProgress(
                        st.id,
                        para: para,
                        surah: surahCtl.text.trim(),
                        sabaq: sabaqCtl.text.trim(),
                        sabaqi: sabaqiCtl.text.trim(),
                        manzil: manzilCtl.text.trim(),
                        grade: grade,
                      );
                      Navigator.pop(ctx);
                      final updatedSt = s.students.firstWhere((x) => x.id == st.id);
                      await s.sendWhatsApp(updatedSt);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------- طلبہ کا صفحہ (StudentsPage) ----------------
class StudentsPage extends StatefulWidget {
  final Store s;
  const StudentsPage(this.s, {super.key});
  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String search = '';
  String filter = 'all'; // all, academy, online, quran

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final filtered = s.students.where((st) {
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
    }).toList();

    return Column(
      children: [
        // Top search & filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'طالب علم کا نام، فون یا کوڈ تلاش کریں...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => search = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => search = v.trim()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('سب (${s.students.length})'),
                      selected: filter == 'all',
                      onSelected: (_) => setState(() => filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                          '🏫 اکیڈمی (${s.students.where((x) => !x.isOnline).length})'),
                      selected: filter == 'academy',
                      onSelected: (_) => setState(() => filter = 'academy'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                          '💻 آن لائن (${s.students.where((x) => x.isOnline).length})'),
                      selected: filter == 'online',
                      onSelected: (_) => setState(() => filter = 'online'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                          '📖 قرآن پاک (${s.students.where((x) => x.isQuranStudent).length})'),
                      selected: filter == 'quran',
                      onSelected: (_) => setState(() => filter = 'quran'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Student List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          s.students.isEmpty
                              ? 'ابھی تک کوئی طالب علم شامل نہیں کیا گیا'
                              : 'کوئی طالب علم نہیں ملا',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.students.isEmpty
                              ? 'نیچے دیے گئے بٹن سے اکیڈمی یا آن لائن قرآن کلاس کا طالب علم شامل کریں۔'
                              : 'تلاش یا فلٹر بدل کر دیکھیں۔',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _openAddStudentSheet(context, s),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('طالب علم شامل کریں'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final st = filtered[i];
                    final b = s.batchOf(st);
                    final isPd = s.isPaid(st.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: st.isQuranStudent
                                      ? const Color(0xFF0F7B5F)
                                      : (st.isOnline
                                          ? Colors.indigo
                                          : Colors.teal.shade700),
                                  foregroundColor: Colors.white,
                                  child: Icon(st.isQuranStudent
                                      ? Icons.menu_book_rounded
                                      : (st.isOnline
                                          ? Icons.videocam_rounded
                                          : Icons.person_rounded)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(st.name,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                        '${st.phone.isEmpty ? "بغیر فون" : st.phone} · فیس: ${st.fee} ${st.currencySymbol}${st.timing.isNotEmpty ? " · ⏰ ${st.timing}" : ""}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                                // Code pill
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: st.code));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'کوڈ کاپی ہو گیا: ${st.code}')));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('کوڈ: ${st.code}',
                                        style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                      st.isOnline
                                          ? Icons.wifi_rounded
                                          : Icons.apartment_rounded,
                                      size: 14),
                                  label: Text(
                                      st.isOnline ? 'آن لائن' : 'فزیکل اکیڈمی',
                                      style: const TextStyle(fontSize: 11)),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(st.courseLabel,
                                      style: const TextStyle(fontSize: 11)),
                                ),
                                if (b != null)
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text('${b['name']}',
                                        style: const TextStyle(fontSize: 11)),
                                  ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: isPd
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  label: Text(
                                      isPd
                                          ? 'فیس ادا ✅'
                                          : 'فیس باقی: ${s.remaining(st.id)} ${st.currencySymbol}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isPd
                                              ? Colors.green.shade800
                                              : Colors.red.shade800)),
                                ),
                              ],
                            ),
                            if (st.isQuranStudent && st.quran != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFBBF7D0)),
                                ),
                                child: Text(
                                  '📖 پارہ ${st.quran!['para'] ?? 1} | ${st.quran!['surah'] ?? ""} | سبق: ${st.quran!['sabaq'] ?? "-"} | گریڈ: ${st.quran!['grade'] ?? "-"}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF166534)),
                                ),
                              ),
                            ],
                            const Divider(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.call_rounded, size: 18),
                                    label: const Text('کال کریں', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    onPressed: () => _openCallSheet(context, st),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFDCFCE7),
                                      foregroundColor: const Color(0xFF166534),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.send_rounded, size: 18),
                                    label: const Text('رپورٹ / واٹس ایپ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: () => s.sendWhatsApp(st),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (st.isQuranStudent) ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0F7B5F),
                                        side: const BorderSide(color: Color(0xFF0F7B5F)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.menu_book_rounded, size: 16),
                                      label: const Text('قرآن ڈائری', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _openQuranDiarySheet(context, s, st),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (st.isOnline && st.meetingLink.isNotEmpty) ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.indigo,
                                        side: const BorderSide(color: Colors.indigo),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.videocam_rounded, size: 16),
                                      label: const Text('کلاس لنک', style: TextStyle(fontSize: 12)),
                                      onPressed: () => launchUrl(Uri.parse(st.meetingLink), mode: LaunchMode.externalApplication),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade800,
                                    side: BorderSide(color: Colors.grey.shade400),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.description_outlined, size: 16),
                                  label: const Text('رسید', style: TextStyle(fontSize: 12)),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocPage(s, st))),
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  tooltip: 'مزید اختیارات',
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      _openAddStudentSheet(context, s, st);
                                    } else if (val == 'receipt') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => DocPage(s, st)));
                                    } else if (val == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: Text('${st.name} کو حذف کریں؟'),
                                          content: const Text('کیا آپ واقعی اس طالب علم کا تمام ریکارڈ حذف کرنا چاہتے ہیں؟'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('نہیں')),
                                            FilledButton(
                                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('حذف کریں'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) s.delStudent(st.id);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('طالب علم میں ترمیم'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'receipt',
                                      child: Row(
                                        children: [
                                          Icon(Icons.receipt_long_rounded, size: 18, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text('مکمل فیس رسید و ریکارڈ'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('حذف کریں', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
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
}

// ---------------- حاضری (AttendancePage) ----------------
class AttendancePage extends StatelessWidget {
  final Store s;
  const AttendancePage(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    if (s.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.how_to_reg_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('پہلے طلبہ شامل کریں',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _openAddStudentSheet(context, s),
                child: const Text('طالب علم شامل کریں'),
              ),
            ],
          ),
        ),
      );
    }

    final list = s.filteredStudents;
    final marked =
        list.where((x) => s.attToday(x.id) != null).length;
    final pr =
        list.where((x) => s.attToday(x.id) == true).length;
    final ab =
        list.where((x) => s.attToday(x.id) == false).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('آج کی تاریخ: ${s.today}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('حاضر: $pr | غیر حاضر: $ab | حاضری لگی: $marked / ${s.students.length}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => s.markAllAtt(true),
                  child: const Text('سب کو حاضر کریں'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...list.map((st) {
          final a = s.attToday(st.id);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: a == true
                        ? Colors.green.shade100
                        : (a == false ? Colors.red.shade100 : Colors.grey.shade200),
                    foregroundColor: a == true
                        ? Colors.green.shade900
                        : (a == false ? Colors.red.shade900 : Colors.grey.shade800),
                    child: Icon(
                      a == true
                          ? Icons.check_rounded
                          : (a == false ? Icons.close_rounded : Icons.help_outline_rounded),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${st.courseLabel}${st.timing.isNotEmpty ? " · ⏰ ${st.timing}" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => s.setAtt(st.id, true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: a == true ? Colors.green.shade700 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: a == true ? Colors.green.shade700 : Colors.green.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: a == true ? Colors.white : Colors.green.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'حاضر',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: a == true ? Colors.white : Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () async {
                      if (a == true) {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (d) => AlertDialog(
                            title: const Text('غیر حاضر کی تصدیق'),
                            content: Text(
                                'کیا آپ واقعی "${st.name}" کو "غیر حاضر" مارک کرنا چاہتے ہیں؟'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(d, false),
                                child: const Text('نہیں'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade700),
                                onPressed: () => Navigator.pop(d, true),
                                child: const Text('غیر حاضر کریں'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) s.setAtt(st.id, false);
                      } else {
                        s.setAtt(st.id, false);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: a == false ? Colors.red.shade700 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: a == false ? Colors.red.shade700 : Colors.red.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cancel_rounded,
                            size: 14,
                            color: a == false ? Colors.white : Colors.red.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'غائب',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: a == false ? Colors.white : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ---------------- فیس (FeesPage) ----------------
class FeesPage extends StatelessWidget {
  final Store s;
  const FeesPage(this.s, {super.key});

  Future<void> askInstallment(BuildContext context, Student st) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${st.name}: قسط درج کریں'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'رقم (${st.currencySymbol})',
            helperText: 'باقی فیس: ${s.remaining(st.id)} ${st.currencySymbol}',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('منسوخ')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('درج کریں')),
        ],
      ),
    );
    final a = int.tryParse(c.text);
    if (ok == true && a != null && a > 0) s.addPayment(st.id, a);
  }

  @override
  Widget build(BuildContext context) {
    if (s.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payments_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('کوئی طالب علم موجود نہیں'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _openAddStudentSheet(context, s),
                child: const Text('طالب علم شامل کریں'),
              ),
            ],
          ),
        ),
      );
    }

    final list = s.filteredStudents;
    var total = 0;
    for (final st in list) {
      total += s.dueOf(st.id);
    }
    final got = list.fold<int>(
        0, (a, x) => a + (s.isPaid(x.id) ? s.dueOf(x.id) : (s.pays[s.month]?[x.id] ?? 0)));
    final pending = list.where((x) => s.remaining(x.id) > 0).length;

    Widget box(String t, int v, Color c) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(t, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('$v',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: c)),
                ],
              ),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            box('کل وصول شدہ', got, Colors.green.shade700),
            box('کل باقی رقم', total - got, Colors.red.shade700),
          ],
        ),
        if (pending > 0)
          Card(
            color: Colors.amber.shade50,
            child: ListTile(
              leading: const Icon(Icons.notifications_active, color: Colors.orange),
              title: Text('$pending طلبہ کی فیس ابھی باقی ہے',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: FilledButton.tonal(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => FeeRemindPage(s))),
                child: const Text('یاد دہانی بھیجیں'),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text('مہینہ: ${s.month}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...list.map((st) {
          final p = s.isPaid(st.id);
          final due = s.dueOf(st.id);
          final rem = s.remaining(st.id);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(st.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Chip(
                        backgroundColor:
                            p ? Colors.green.shade50 : Colors.red.shade50,
                        label: Text(
                          p ? 'مکمل ادا ✅' : 'باقی $rem ${st.currencySymbol}',
                          style: TextStyle(
                              color: p
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'واجب $due ${st.currencySymbol} · وصول ${due - rem} ${st.currencySymbol}',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: () => s.togglePaid(st.id),
                        child: Text(p ? 'ادائیگی منسوخ' : 'پوری وصول'),
                      ),
                      const SizedBox(width: 8),
                      if (!p) ...[
                        OutlinedButton(
                          onPressed: () => askInstallment(context, st),
                          child: const Text('قسط وصول'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        tooltip: 'فیس کی رسید (PDF)',
                        icon: const Icon(Icons.receipt_long_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocPage(s, st, receipt: true),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'یاد دہانی واٹس ایپ',
                        icon: const Icon(Icons.send_rounded),
                        onPressed: () =>
                            s.sendWhatsApp(st, s.feeReminder(st)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class FeeRemindPage extends StatefulWidget {
  final Store s;
  const FeeRemindPage(this.s, {super.key});
  @override
  State<FeeRemindPage> createState() => _FeeRemindPageState();
}

class _FeeRemindPageState extends State<FeeRemindPage> {
  late final List<Student> q = widget.s.students
      .where((x) => widget.s.remaining(x.id) > 0 && x.phone.trim().isNotEmpty)
      .toList();
  int i = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return subPage('فیس کی یاد دہانی', [
      if (q.isEmpty)
        const Card(child: ListTile(title: Text('کوئی باقی فیس نہیں ✅')))
      else if (i >= q.length)
        const Card(child: ListTile(title: Text('سب کو بھیج دیا گیا ✅')))
      else
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اگلا: ${q[i].name}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    '${i + 1} / ${q.length} · باقی ${s.remaining(q[i].id)} ${q[i].currencySymbol}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () async {
                        final st = q[i];
                        await s.sendWhatsApp(st, s.feeReminder(st));
                        setState(() => i++);
                      },
                      label: const Text('واٹس ایپ بھیجیں'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                        onPressed: () => setState(() => i++),
                        child: const Text('چھوڑیں')),
                  ],
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}

// ---------------- سبق اور ہوم ورک (NotePage) ----------------
class NotePage extends StatefulWidget {
  final Store s;
  const NotePage(this.s, {super.key});
  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late final center = TextEditingController(text: widget.s.center);
  late final note = TextEditingController(text: widget.s.notes[widget.s.today]);
  bool up = false;
  String hwBatch = '';

  void snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> pick(ImageSource src) async {
    final x = await ImagePicker()
        .pickImage(source: src, maxWidth: 1280, imageQuality: 70);
    if (x == null) return;
    setState(() => up = true);
    try {
      final c = Supabase.instance.client;
      if (Cfg.ready && c.auth.currentUser != null) {
        final path =
            '${c.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await c.storage.from('homework').upload(path, File(x.path),
            fileOptions: const FileOptions(contentType: 'image/jpeg'));
        widget.s.addHomework(
            c.storage.from('homework').getPublicUrl(path), path, hwBatch);
        snack('ہوم ورک آن لائن لگ گیا');
      } else {
        widget.s.addHomework(x.path, x.path, hwBatch);
        snack('ہوم ورک محفوظ ہو گیا');
      }
    } catch (_) {
      widget.s.addHomework(x.path, x.path, hwBatch);
      snack('ہوم ورک مقامی طور پر محفوظ ہو گیا');
    }
    if (mounted) setState(() => up = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('یومیہ سبق ڈائری (Academy / Tuition Lesson)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'آج کیا پڑھایا / ہوم ورک کی تفصیل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    onPressed: () {
                      s.setNote(note.text);
                      snack('سبق محفوظ ہو گیا');
                    },
                    label: const Text('محفوظ کریں'),
                  ),
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
                const Text('ہوم ورک کی تصویر (Camera / Gallery)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'والدین اور طالب علم ایپ کے اندر ہوم ورک کی تصویر دیکھ سکیں گے',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                if (s.batches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: hwBatch,
                    decoration: const InputDecoration(
                        labelText: 'بیچ منتخب کریں',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('تمام طلبہ')),
                      ...s.batches.map((b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text('${b['name']}'))),
                    ],
                    onChanged: (v) => setState(() => hwBatch = v ?? ''),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: const Text('کیمرہ'),
                        onPressed: up ? null : () => pick(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('گیلری'),
                        onPressed: up ? null : () => pick(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                if (up) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 10),
                ...s.homework.reversed.take(3).map((h) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network('${h['url']}',
                            width: 50, height: 50, fit: BoxFit.cover),
                      ),
                      title: Text('تاریخ: ${h['d']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => s.delHomework('${h['id']}'),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- شروع: انتخاب کردار (Gate) ----------------
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  String? role;
  bool loaded = false;

  bool showUpgradeNotice = false;
  String appLang = 'ur';
  static const currentVersion = '1.2.0';

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
        appLang = p.getString('app_lang') ?? 'ur';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => checkForAppUpdate(context));
    });
  }

  Future<void> pick(String? r) async {
    final p = await SharedPreferences.getInstance();
    if (r == null) {
      await p.remove('role');
    } else {
      await p.setString('role', r);
    }
    setState(() => role = r);
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (role == 'teacher') return Home(onSwitch: () => pick(null));
    if (role == 'parent') return ParentHome(onSwitch: () => pick(null));
    if (role == 'student') return StudentHome(onSwitch: () => pick(null));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Startup Language Picker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, size: 16, color: Color(0xFF0F7B5F)),
                      const SizedBox(width: 6),
                      Text(appLang == 'ur' ? 'زبان منتخب کریں:' : 'Language:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() => appLang = 'ur');
                          SharedPreferences.getInstance().then((p) => p.setString('app_lang', 'ur'));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: appLang == 'ur' ? const Color(0xFF0F7B5F) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'اردو',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: appLang == 'ur' ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          setState(() => appLang = 'en');
                          SharedPreferences.getInstance().then((p) => p.setString('app_lang', 'en'));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: appLang == 'en' ? const Color(0xFF0F7B5F) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'English',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: appLang == 'en' ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F7B5F).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      size: 64, color: Color(0xFF0F7B5F)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ٹیوشن و قرآن مینیجر',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'اکیڈمیز، ہوم ٹیوٹرز، آن لائن اساتذہ، طلبہ اور والدین کے لیے مکمل حل',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (showUpgradeNotice) ...[
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
                                'نئے فونٹس (جمیل نوری نستعلیق)، تجویدی قرآن، انگریزی ترجمہ اور مستقل کنیکٹیویٹی شامل کر دی گئی ہے۔',
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
                _roleCard(
                  icon: Icons.person_outline_rounded,
                  title: 'میں ٹیچر / اکیڈمی ایڈمن ہوں',
                  subtitle:
                      'طلبہ کا اندراج، حاضری، فیس، ٹیسٹ اور آن لائن قرآن ٹریکر',
                  color: const Color(0xFF0F7B5F),
                  onTap: () => pick('teacher'),
                ),
                const SizedBox(height: 14),
                _roleCard(
                  icon: Icons.family_restroom_rounded,
                  title: 'میں والد / والدہ ہوں (Parent)',
                  subtitle:
                      'بچے کی حاضری، ہوم ورک، فیس اور لائیو کارکردگی دیکھیں',
                  color: Colors.indigo,
                  onTap: () => pick('parent'),
                ),
                const SizedBox(height: 14),
                _roleCard(
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
                  title: '📖 مکمل قرآن پاک (Quran Reader)',
                  subtitle:
                      '114 سورتیں، 30 پارے، نورانی قاعدہ اور 3 مختلف رسم الخط (مفت بلا لاگ اِن)',
                  color: const Color(0xFFD97706),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const QuranReaderScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withOpacity(0.3))),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(0.15),
                  foregroundColor: color,
                  child: Icon(icon, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: color),
              ],
            ),
          ),
        ),
      );
}


// ---------------- استاد سے رابطہ کارڈ (Teacher Contact Card Helper) ----------------
Widget _buildTeacherContactCard(BuildContext context, {
  required String teacherName,
  required String centerPhone,
  required String studentName,
  required String studentCode,
  required bool isParent,
}) {
  final cleanPhone = centerPhone.replaceAll(RegExp(r'\D'), '');
  final displayName = teacherName.isNotEmpty ? teacherName : 'محترم استاد';

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF86EFAC)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F766E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'استاد سے رابطہ: $displayName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF14532D)),
                  ),
                  Text(
                    cleanPhone.isNotEmpty ? 'فون نمبر: $centerPhone' : 'براہ راست کال اور واٹس ایپ رابطہ',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.call_rounded, size: 16),
                label: const Text('براہ راست فون کال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  if (cleanPhone.isNotEmpty) {
                    launchUrl(Uri.parse('tel:$cleanPhone'), mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('استاد کا رابطہ نمبر ابھی درج نہیں ہوا')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: const Text('واٹس ایپ رابطہ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  if (cleanPhone.isNotEmpty) {
                    var p = cleanPhone;
                    if (p.startsWith('0')) p = '92' + p.substring(1);
                    final intro = isParent
                        ? 'السلام علیکم استاد محترم! میں $studentName کے والدین میں سے رابطہ کر رہا ہوں۔'
                        : 'السلام علیکم استاد محترم! میں آپ کا طالب علم ($studentName) رابطہ کر رہا ہوں۔';
                    launchUrl(
                      Uri.parse('https://wa.me/$p?text=' + Uri.encodeComponent(intro)),
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('استاد کا رابطہ نمبر ابھی درج نہیں ہوا')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ---------------- طالب علم پورٹل (StudentHome) ----------------
class StudentHome extends StatefulWidget {
  final VoidCallback onSwitch;
  const StudentHome({super.key, required this.onSwitch});
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final codeCtl = TextEditingController();
  final qCtl = TextEditingController();
  String? code;
  Map<String, dynamic>? snap;
  String err = '';
  bool loading = false;
  List qa = [];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      code = p.getString('student_code');
      final cSnap = p.getString('student_snap');
      if (cSnap != null) {
        snap = Map<String, dynamic>.from(jsonDecode(cSnap));
      }
      if (code != null) fetch(code!);
      setState(() {});
    });
  }

  Future<void> fetch(String raw) async {
    final c = raw.trim().toLowerCase();
    setState(() {
      loading = true;
      err = '';
    });
    final p = await SharedPreferences.getInstance();
    try {
      Map<String, dynamic>? m;
      if (Cfg.ready) {
        try {
          final r = await Supabase.instance.client
              .rpc('get_snapshot', params: {'p_code': c});
          if (r != null) {
            final resMap = Map<String, dynamic>.from(r);
            if (resMap.containsKey('data') && resMap['data'] is Map) {
              m = resMap;
            } else {
              m = {'code': c, 'center': 'ٹیوشن اکیڈمی', 'data': resMap};
            }
          }
        } catch (_) {}
        // Fallback: direct table select if RPC function not found or failed
        if (m == null) {
          try {
            final direct = await Supabase.instance.client
                .from('snapshots')
                .select('*')
                .or('code.ilike.$c,code.eq.$c')
                .maybeSingle();
            if (direct != null) {
              final rawData = direct['data'];
              m = {
                'code': direct['code'] ?? c,
                'student_id': direct['student_id'] ?? '',
                'center': direct['center'] ?? 'ٹیوشن اکیڈمی',
                'data': rawData is Map ? Map<String, dynamic>.from(rawData) : {},
                'updated_at': direct['updated_at'],
              };
            }
          } catch (_) {}
        }
      }
      // Check local storage fallback if server returned null or offline
      if (m == null) {
        final localStr = p.getString('snap_$c');
        if (localStr != null) {
          m = Map<String, dynamic>.from(jsonDecode(localStr));
        } else {
          // Check tuition_v1 store for this student code
          final t1 = p.getString('tuition_v1');
          if (t1 != null) {
            final tData = jsonDecode(t1) as Map<String, dynamic>;
            final stList = (tData['students'] as List?) ?? [];
            for (final st in stList) {
              if ((st['code'] ?? '').toString().trim().toLowerCase() == c) {
                m = {
                  'code': c,
                  'student_id': st['id'],
                  'center': tData['center'] ?? 'ٹیوشن سینٹر',
                  'data': {
                    'name': st['name'],
                    'today': DateTime.now().toIso8601String().substring(0, 10),
                    'att': null,
                    'present': 0,
                    'marked': 0,
                    'note': '',
                    'paid': false,
                    'fee': st['fee'] ?? 0,
                    'rem': st['fee'] ?? 0,
                    'currency': st['currency'] ?? 'PKR',
                    'currencySymbol': 'روپے',
                    'isOnline': st['isOnline'] ?? false,
                    'meetingLink': st['meetingLink'] ?? '',
                    'courseType': st['courseType'] ?? 'school',
                    'courseLabel': 'کورس',
                    'quran': st['quran'],
                    'month': DateTime.now().toIso8601String().substring(0, 7),
                    'notices': tData['notices'] ?? [],
                    'batch': '',
                    'time': '',
                    'tests': [],
                    'hw': [],
                    'week': [0, 0],
                  }
                };
                break;
              }
            }
          }
        }
      }

      if (m == null) {
        err = 'طالب علم کا کوڈ درست نہیں ملا۔ برائے مہربانی استاد سے تصدیق کریں۔';
      } else {
        code = c;
        snap = m;
        await p.setString('student_code', c);
        await p.setString('student_snap', jsonEncode(m));
        if (Cfg.ready) loadQa(c);
      }
    } catch (e) {
      final localStr = p.getString('snap_$c');
      if (localStr != null) {
        final m = Map<String, dynamic>.from(jsonDecode(localStr));
        code = c;
        snap = m;
        await p.setString('student_code', c);
        await p.setString('student_snap', jsonEncode(m));
      } else {
        err = 'ریکارڈ نہیں ملا۔ برائے مہربانی کوڈ چیک کریں: $e';
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadQa(String c) async {
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
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('student_code');
    await p.remove('student_snap');
    setState(() {
      code = null;
      snap = null;
      codeCtl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = snap == null ? null : (snap!['data'] is Map ? Map<String, dynamic>.from(snap!['data']) : Map<String, dynamic>.from(snap!));
    return Scaffold(
      appBar: AppBar(
        title: Text(snap?['center'] ?? 'طالب علم پورٹل'),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'مزید اختیارات',
            onSelected: (val) {
              if (val == 'quran') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranReaderScreen()),
                );
              } else if (val == 'logout') {
                logout();
              } else if (val == 'switch') {
                widget.onSwitch();
              } else if (val == 'about') {
                showAboutDialog(
                  context: context,
                  applicationName: 'طالب علم پورٹل',
                  applicationVersion: 'v1.1.0',
                  applicationIcon: const Icon(Icons.school_rounded, size: 48, color: Color(0xFF0F766E)),
                  children: const [
                    Text('روزانہ حاضری، فیس سٹیٹس، ہوم ورک اور قرآن پاک کا سبق دیکھنے کے لیے۔'),
                  ],
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'quran',
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: Color(0xFF0F766E), size: 20),
                    SizedBox(width: 10),
                    Text('📖 قرآن پاک و قاعدہ'),
                  ],
                ),
              ),
              if (code != null)
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text('🚪 کوڈ تبدیل کریں'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.switch_account_rounded, color: Color(0xFF0F766E), size: 20),
                    SizedBox(width: 10),
                    Text('🔄 کردار تبدیل کریں'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                    SizedBox(width: 10),
                    Text('ℹ️ ایپ کے بارے میں'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: d == null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.school_rounded,
                      size: 64, color: Color(0xFF0F7B5F)),
                  const SizedBox(height: 16),
                  const Text(
                    'طالب علم لاگ اِن (Student Login)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اپنے استاد کے دیے گئے 8 حرفی طالب علم کوڈ سے لاگ اِن کریں',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  field(codeCtl, '8 حرفی کوڈ (مثلاً x8j2k49p)'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7B5F)),
                      onPressed: loading ? null : () => fetch(codeCtl.text),
                      child: Text(
                        loading ? 'لوڈ ہو رہا ہے...' : 'لاگ اِن کریں',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (err.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(err,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              )
            : RefreshIndicator(
                onRefresh: () => fetch(code!),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Welcome header
                    Card(
                      color: const Color(0xFF0F7B5F),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              child: Icon(Icons.person, size: 30),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'خوش آمدید، ${d['name']}! 🌟',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${d['courseLabel'] ?? "کلاس"} · تازہ ترین: ${d['today']}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Contact Teacher Card
                    _buildTeacherContactCard(
                      context,
                      teacherName: (d['teacherName'] ?? '').toString(),
                      centerPhone: (d['centerPhone'] ?? '').toString(),
                      studentName: (d['name'] ?? '').toString(),
                      studentCode: code ?? '',
                      isParent: false,
                    ),

                    // Online Live Class Banner
                    if (d['isOnline'] == true &&
                        (d['meetingLink'] ?? '').toString().isNotEmpty) ...[
                      Card(
                        color: Colors.indigo.shade50,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.indigo.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                child: const Icon(Icons.videocam_rounded),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('لائیو آن لائن کلاس',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    Text(
                                        'زوم / گوگل میٹ کے ذریعے کلاس میں شامل ہوں',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700)),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade700),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('شامل ہوں'),
                                onPressed: () => launchUrl(
                                    Uri.parse('${d['meetingLink']}'),
                                    mode: LaunchMode.externalApplication),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Quran Daily Diary Card (if student is learning Quran)
                    if (d['quran'] != null) ...[
                      Card(
                        color: const Color(0xFFF0FDF4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFF86EFAC))),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.menu_book_rounded,
                                      color: Color(0xFF0F7B5F)),
                                  const SizedBox(width: 8),
                                  const Text('قرآن پاک یومیہ ڈائری',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F7B5F))),
                                  const Spacer(),
                                  if ((d['quran']['grade'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F7B5F),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${d['quran']['grade']}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                      child: _kv('پارہ نمبر',
                                          '${d['quran']['para'] ?? 1}')),
                                  Expanded(
                                      child: _kv('سورۃ',
                                          '${d['quran']['surah'] ?? "-"}')),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _kv('آج کا سبق',
                                  '${d['quran']['sabaq'] ?? "ابھی نہیں لکھا گیا"}'),
                              if ((d['quran']['sabaqi'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _kv('سبقی', '${d['quran']['sabaqi']}'),
                              ],
                              if ((d['quran']['manzil'] ?? '')
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
                                  label: const Text('📖 قرآن پاک کھولیں (سبق پڑھیں)'),
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
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Attendance & Monthly metrics
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  const Text('آج کی حاضری',
                                      style: TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    d['att'] == true
                                        ? 'حاضر ✅'
                                        : (d['att'] == false
                                            ? 'غیر حاضر ❌'
                                            : '-'),
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  const Text('اس ماہ حاضری',
                                      style: TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${d['present']}/${d['marked']} دن',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Lesson Note
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.edit_calendar_rounded),
                        title: const Text('آج کا سبق / ڈائری'),
                        subtitle: Text(
                          (d['note'] ?? '').toString().isEmpty
                              ? 'کوئی نیا سبق درج نہیں کیا گیا'
                              : '${d['note']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),

                    // Homework photos
                    if ((d['hw'] ?? []).isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('ہوم ورک کی تصاویر',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: (d['hw'] as List)
                              .map((h) => Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: GestureDetector(
                                      onTap: () => showDialog(
                                        context: context,
                                        builder: (_) => Dialog(
                                          child: InteractiveViewer(
                                            child: Image.network('${h['url']}'),
                                          ),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          '${h['url']}',
                                          height: 120,
                                          width: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],

                    // Tests
                    if ((d['tests'] ?? []).isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('ٹیسٹ کے نتائج',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ...(d['tests'] as List).map((x) => Card(
                            child: ListTile(
                              title: Text('${x['name']}'),
                              subtitle: Text('تاریخ: ${x['d']}'),
                              trailing: Text('${x['got']} / ${x['total']}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                          )),
                    ],

                    // Q&A with teacher
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('استاد سے سوال پوچھیں',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: qCtl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText:
                                    'سبق، ہوم ورک یا وقت کے متعلق سوال لکھیں...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F7B5F)),
                                    icon: const Icon(Icons.send_rounded),
                                    onPressed: ask,
                                    label: const Text('سوال بھیجیں'),
                                  ),
                                ),
                                if ((snap?['centerPhone'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                                    label: const Text('وائس کال'),
                                    onPressed: () {
                                      final p = snap!['centerPhone'].toString().replaceAll(RegExp(r'\D'), '');
                                      final name = snap!['name'] ?? '';
                                      final fakeStudent = Student('s_temp', name, p, 0, code ?? '');
                                      CallSessionManager.instance.startCall(context, fakeStudent, video: false);
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF128C7E), foregroundColor: Colors.white),
                                    icon: const Icon(Icons.videocam_rounded, size: 16),
                                    label: const Text('ویڈیو کال'),
                                    onPressed: () {
                                      final p = snap!['centerPhone'].toString().replaceAll(RegExp(r'\D'), '');
                                      final name = snap!['name'] ?? '';
                                      final fakeStudent = Student('s_temp', name, p, 0, code ?? '');
                                      CallSessionManager.instance.startCall(context, fakeStudent, video: true);
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 16),
                                    label: const Text('واٹس ایپ'),
                                    onPressed: () {
                                      final p = snap!['centerPhone'].toString().replaceAll(RegExp(r'\D'), '');
                                      final name = snap!['name'] ?? '';
                                      final qText = qCtl.text.trim();
                                      final txt = Uri.encodeComponent('السلام علیکم سر! میں $name بات کر رہا ہوں۔ میرا سوال یہ ہے:\n$qText');
                                      launchUrl(Uri.parse('https://wa.me/$p?text=$txt'), mode: LaunchMode.externalApplication);
                                    },
                                  ),
                                ],
                              ],
                            ),
                            if (qa.isNotEmpty) ...[
                              const Divider(height: 20),
                              Row(
                                children: [
                                  const Text('پوچھے گئے سوالات و جوابات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const Spacer(),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('تازہ کریں', style: TextStyle(fontSize: 12)),
                                    onPressed: () => code != null ? loadQa(code!) : null,
                                  ),
                                ],
                              ),
                              ...qa.map((x) {
                                final hasAns = x['a'] != null && x['a'].toString().isNotEmpty;
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: hasAns ? Colors.green.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: hasAns ? Colors.green.shade200 : Colors.amber.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('سوال: ${x['q']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(hasAns ? Icons.reply_all_rounded : Icons.pending_rounded,
                                              size: 14,
                                              color: hasAns ? Colors.green.shade700 : Colors.amber.shade800),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              hasAns ? 'استاد کا جواب: ${x['a']}' : 'استاد کے جواب کا انتظار ہے...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: hasAns ? FontWeight.bold : FontWeight.normal,
                                                color: hasAns ? Colors.green.shade900 : Colors.amber.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('تازہ ترین ریکارڈ دیکھنے کے لیے نیچے کھینچیں',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$k: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87)),
          Expanded(child: Text(v)),
        ],
      );
}

// ---------------- پیغامات اور سنک (MorePage) ----------------
class MorePage extends StatefulWidget {
  final Store s;
  const MorePage(this.s, {super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  final email = TextEditingController(), pass = TextEditingController();
  final msg = TextEditingController(text: 'السلام علیکم! {name} کے والدین، ');
  String filter = 'all', status = '';
  List<Student> queue = [];
  int qi = 0;
  String plan = '';
  bool weekly = false;
  int qCount = 0;

  @override
  void initState() {
    super.initState();
    loadPlan();
  }

  bool get proActive {
    final d = DateTime.tryParse(plan);
    return d != null &&
        !d.isBefore(DateTime.now().subtract(const Duration(days: 1)));
  }

  Future<void> loadPlan() async {
    if (!loggedIn) return;
    try {
      final r = await Supabase.instance.client
          .from('plans')
          .select('paid_until')
          .maybeSingle();
      if (mounted) setState(() => plan = r == null ? '' : '${r['paid_until']}');
      final q = await Supabase.instance.client
          .from('questions')
          .select('a')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(
            () => qCount = (q as List).where((x) => x['a'] == null).length);
      }
    } catch (_) {}
  }

  bool get loggedIn =>
      Cfg.ready && Supabase.instance.client.auth.currentUser != null;

  List<Student> targets() => widget.s.students.where((x) {
        if (x.phone.trim().isEmpty) return false;
        if (filter == 'unpaid') return !widget.s.isPaid(x.id);
        if (filter == 'absent') return widget.s.attToday(x.id) == false;
        return true;
      }).toList();

  Future<void> auth(bool signup) async {
    if (!Cfg.ready) {
      setState(() => status = 'پہلے config.dart میں Supabase کی کیز ڈالیں');
      return;
    }
    final a = Supabase.instance.client.auth;
    try {
      if (signup) {
        await a.signUp(email: email.text.trim(), password: pass.text);
      } else {
        await a.signInWithPassword(
            email: email.text.trim(), password: pass.text);
      }
      setState(() => status = 'لاگ اِن ہو گیا');
      loadPlan();
    } catch (e) {
      setState(() => status = 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final t = targets();
    return ListView(
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
                        'مکمل قرآن پاک ریڈر',
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
                  const Text('والدین اور طلبہ کے لیے کلاؤڈ سنک',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (!loggedIn) ...[
                    field(email, 'ای میل', type: TextInputType.emailAddress),
                    TextField(
                        controller: pass,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'پاس ورڈ', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: FilledButton(
                              onPressed: () => auth(false),
                              child: const Text('لاگ اِن'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: FilledButton.tonal(
                              onPressed: () => auth(true),
                              child: const Text('نیا اکاؤنٹ'))),
                    ]),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('ابھی سنک کریں'),
                        onPressed: () async {
                          final r = await s.sync();
                          setState(() => status = r);
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title:
                                const Text('موجودہ ڈیٹا کلاؤڈ بیک اپ سے بدل دیں؟'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('نہیں')),
                              TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('ہاں')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          final r = await s.restore();
                          setState(() => status = r);
                        }
                      },
                      child: const Text('کلاؤڈ بیک اپ سے بحال کریں'),
                    ),
                  ],
                  if (status.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(status)),
                  if (s.syncStatus.isNotEmpty)
                    Text('خودکار: ${s.syncStatus}',
                        style: const TextStyle(fontSize: 12)),
                ]),
          ),
        ),
        if (loggedIn)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        proActive
                            ? 'پرو پلان فعال: $plan تک'
                            : 'مفت پلان: ${Cfg.freeLimit} طلبہ تک لائیو سنک',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (!proActive) ...[
                      const SizedBox(height: 6),
                      Text(
                          'پرو: ${Cfg.proPrice} روپے ماہانہ، لامحدود طلبہ۔\n${Cfg.payInfo}'),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          final m = 'پرو پلان کی ادائیگی کر دی ہے۔ اکاؤنٹ: '
                              '${Supabase.instance.client.auth.currentUser?.email}';
                          launchUrl(
                              Uri.parse(
                                  'https://wa.me/${Cfg.adminWhatsapp}?text=${Uri.encodeComponent(m)}'),
                              mode: LaunchMode.externalApplication);
                        },
                        child: const Text('ادائیگی کی رسید واٹس ایپ پر بھیجیں'),
                      ),
                    ],
                    TextButton(
                        onPressed: loadPlan, child: const Text('پلان تازہ کریں')),
                  ]),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بلک پیغام (واٹس ایپ قطار)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: filter,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('تمام والدین')),
                      DropdownMenuItem(
                          value: 'unpaid', child: Text('جن کی فیس باقی ہے')),
                      DropdownMenuItem(
                          value: 'absent', child: Text('جو آج غیر حاضر ہیں')),
                    ],
                    onChanged: (v) => setState(() {
                      filter = v!;
                      queue = [];
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: msg,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        helperText: '{name} کی جگہ بچے کا نام آئے گا',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Text('${t.length} والدین چنے گئے'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: FilledButton(
                            onPressed: t.isEmpty
                                ? null
                                : () => setState(() {
                                      queue = t;
                                      qi = 0;
                                      weekly = false;
                                    }),
                            child: const Text('واٹس ایپ قطار'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: FilledButton.tonal(
                            onPressed: () {
                              final x =
                                  msg.text.replaceAll('{name}', 'طلبہ').trim();
                              if (x.isEmpty) return;
                              s.addNotice(x);
                              setState(() => status =
                                  'نوٹس بورڈ پر لگ گیا، سنک کریں');
                            },
                            child: const Text('نوٹس بورڈ'))),
                  ]),
                ]),
          ),
        ),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.question_answer_rounded, color: Color(0xFF0F7B5F)),
              title: Text(
                  'والدین و طلبہ کے سوالات و پیغامات${qCount > 0 ? " ($qCount بغیر جواب)" : ""}'),
              subtitle: const Text('طالب علم اور والدین کے موصولہ پیغامات دیکھیں اور جواب دیں'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => QuestionsPage(s)));
                loadPlan();
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize_rounded),
              title: const Text('ہفتہ وار خلاصہ (واٹس ایپ)'),
              subtitle:
                  const Text('حاضری، ٹیسٹ اور فیس، ہر والد کو ایک ٹیپ میں'),
              onTap: () => setState(() {
                queue =
                    s.students.where((x) => x.phone.trim().isNotEmpty).toList();
                qi = 0;
                weekly = true;
              }),
            ),
          ]),
        ),
        if (queue.isNotEmpty && qi < queue.length)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              title: Text('اگلا: ${queue[qi].name}'),
              subtitle: Text('${qi + 1} / ${queue.length}'),
              trailing: FilledButton(
                onPressed: () async {
                  final st = queue[qi];
                  await s.sendWhatsApp(
                      st,
                      weekly
                          ? s.weeklyMessage(st)
                          : msg.text.replaceAll('{name}', st.name));
                  setState(() => qi++);
                },
                child: const Text('کھولیں'),
              ),
            ),
          ),
        if (queue.isNotEmpty && qi >= queue.length)
          const Card(child: ListTile(title: Text('سب کو بھیج دیا گیا ✅'))),
      ],
    );
  }
}

// ---------------- والدین کی ایپ (ParentHome) ----------------
class ParentHome extends StatefulWidget {
  final VoidCallback onSwitch;
  const ParentHome({super.key, required this.onSwitch});
  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  final codeCtl = TextEditingController();
  List<String> codes = [];
  Map<String, Map<String, dynamic>> snaps = {};
  StreamSubscription? _sub;
  bool _reg = false;
  List qa = [];
  final qCtl = TextEditingController();
  String? code;
  Map<String, dynamic>? snap;
  String err = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (pushReady) {
      _sub = FirebaseMessaging.onMessage.listen((m) {
        if (code != null) fetch(code!);
        final b = m.notification?.body;
        if (b != null && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(b)));
        }
      });
    }
    SharedPreferences.getInstance().then((p) {
      code = p.getString('parent_code');
      final cached = p.getString('parent_snap');
      if (cached != null) snap = Map<String, dynamic>.from(jsonDecode(cached));
      codes = p.getStringList('parent_codes') ?? (code != null ? [code!] : []);
      final sj = p.getString('parent_snaps');
      if (sj != null) {
        (jsonDecode(sj) as Map).forEach((k, v) {
          snaps[k] = Map<String, dynamic>.from(v);
        });
      }
      if (snap == null && code != null) snap = snaps[code];
      if (code != null) fetch(code!);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> registerPush(String c) async {
    if (!pushReady) return;
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      final tok = await m.getToken();
      if (tok != null) {
        await Supabase.instance.client
            .rpc('register_token', params: {'p_code': c, 'p_token': tok});
      }
      if (!_reg) {
        _reg = true;
        m.onTokenRefresh.listen((t) {
          if (code != null) {
            Supabase.instance.client
                .rpc('register_token', params: {'p_code': code, 'p_token': t})
                .then((_) {}, onError: (_) {});
          }
        });
      }
    } catch (_) {}
  }

  Future<void> unregisterPush(String c) async {
    if (!pushReady) return;
    try {
      final tok = await FirebaseMessaging.instance.getToken();
      if (tok != null) {
        await Supabase.instance.client
            .rpc('unregister_token', params: {'p_token': tok, 'p_code': c});
      }
    } catch (_) {}
  }

  Future<void> loadQa(String c) async {
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
  }

  Future<void> persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('parent_codes', codes);
    await p.setString('parent_snaps', jsonEncode(snaps));
    if (code != null) {
      await p.setString('parent_code', code!);
      await p.setString('parent_snap', jsonEncode(snaps[code]));
    } else {
      await p.remove('parent_code');
      await p.remove('parent_snap');
    }
  }

  Future<void> fetch(String raw) async {
    final c = raw.trim().toLowerCase();
    setState(() {
      loading = true;
      err = '';
    });
    final p = await SharedPreferences.getInstance();
    try {
      Map<String, dynamic>? m;
      if (Cfg.ready) {
        try {
          final r = await Supabase.instance.client
              .rpc('get_snapshot', params: {'p_code': c});
          if (r != null) {
            final resMap = Map<String, dynamic>.from(r);
            if (resMap.containsKey('data') && resMap['data'] is Map) {
              m = resMap;
            } else {
              m = {'code': c, 'center': 'ٹیوشن اکیڈمی', 'data': resMap};
            }
          }
        } catch (_) {}
        // Fallback: direct table select if RPC function not found
        if (m == null) {
          try {
            final direct = await Supabase.instance.client
                .from('snapshots')
                .select('*')
                .or('code.ilike.$c,code.eq.$c')
                .maybeSingle();
            if (direct != null) {
              final rawData = direct['data'];
              m = {
                'code': direct['code'] ?? c,
                'student_id': direct['student_id'] ?? '',
                'center': direct['center'] ?? 'ٹیوشن اکیڈمی',
                'data': rawData is Map ? Map<String, dynamic>.from(rawData) : {},
                'updated_at': direct['updated_at'],
              };
            }
          } catch (_) {}
        }
      }
      // Check local storage fallback
      if (m == null) {
        final localStr = p.getString('snap_$c');
        if (localStr != null) {
          m = Map<String, dynamic>.from(jsonDecode(localStr));
        } else {
          // Check tuition_v1 store for this student code
          final t1 = p.getString('tuition_v1');
          if (t1 != null) {
            final tData = jsonDecode(t1) as Map<String, dynamic>;
            final stList = (tData['students'] as List?) ?? [];
            for (final st in stList) {
              if ((st['code'] ?? '').toString().trim().toLowerCase() == c) {
                m = {
                  'code': c,
                  'student_id': st['id'],
                  'center': tData['center'] ?? 'ٹیوشن سینٹر',
                  'data': {
                    'name': st['name'],
                    'today': DateTime.now().toIso8601String().substring(0, 10),
                    'att': null,
                    'present': 0,
                    'marked': 0,
                    'note': '',
                    'paid': false,
                    'fee': st['fee'] ?? 0,
                    'rem': st['fee'] ?? 0,
                    'currency': st['currency'] ?? 'PKR',
                    'currencySymbol': 'روپے',
                    'isOnline': st['isOnline'] ?? false,
                    'meetingLink': st['meetingLink'] ?? '',
                    'courseType': st['courseType'] ?? 'school',
                    'courseLabel': 'کورس',
                    'quran': st['quran'],
                    'month': DateTime.now().toIso8601String().substring(0, 7),
                    'notices': tData['notices'] ?? [],
                    'batch': '',
                    'time': '',
                    'tests': [],
                    'hw': [],
                    'week': [0, 0],
                  }
                };
                break;
              }
            }
          }
        }
      }

      if (m == null) {
        err = 'کوڈ درست نہیں ملا۔ برائے مہربانی استاد سے دوبارہ تصدیق کریں۔';
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
        err = 'ریکارڈ نہیں ملا۔ برائے مہربانی کوڈ چیک کریں: $e';
      }
    }
    if (mounted) setState(() => loading = false);
  }

  void select(String c) {
    setState(() {
      code = c;
      snap = snaps[c];
    });
    persist();
    fetch(c);
  }

  Future<void> addChild() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('دوسرے بچے کا کوڈ'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('منسوخ')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('شامل کریں')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) await fetch(c.text);
  }

  Future<void> clear() async {
    final c = code;
    if (c == null) return;
    await unregisterPush(c);
    codes.remove(c);
    snaps.remove(c);
    code = codes.isNotEmpty ? codes.first : null;
    snap = code == null ? null : snaps[code];
    await persist();
    if (mounted) setState(() => codeCtl.clear());
  }

  @override
  Widget build(BuildContext context) {
    final d = snap == null ? null : (snap!['data'] is Map ? Map<String, dynamic>.from(snap!['data']) : Map<String, dynamic>.from(snap!));
    return Scaffold(
      appBar: AppBar(
        title: Text(snap?['center'] ?? 'والدین پورٹل'),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'مزید اختیارات',
            onSelected: (val) {
              if (val == 'quran') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranReaderScreen()),
                );
              } else if (val == 'add_child') {
                addChild();
              } else if (val == 'remove_child') {
                clear();
              } else if (val == 'switch') {
                widget.onSwitch();
              } else if (val == 'about') {
                showAboutDialog(
                  context: context,
                  applicationName: 'والدین پورٹل',
                  applicationVersion: 'v1.1.0',
                  applicationIcon: const Icon(Icons.family_restroom_rounded, size: 48, color: Color(0xFF0F766E)),
                  children: const [
                    Text('بچوں کی تعلیمی کارکردگی، حاضری، ماہانہ فیس اور قرآن مجید کے روزانہ اسباق دیکھنے کے لیے۔'),
                  ],
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'quran',
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: Color(0xFF0F766E), size: 20),
                    SizedBox(width: 10),
                    Text('📖 قرآن پاک و قاعدہ'),
                  ],
                ),
              ),
              if (code != null)
                const PopupMenuItem(
                  value: 'add_child',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1, color: Color(0xFF0F766E), size: 20),
                      SizedBox(width: 10),
                      Text('➕ دوسرا بچہ شامل کریں'),
                    ],
                  ),
                ),
              if (code != null)
                const PopupMenuItem(
                  value: 'remove_child',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text('➖ یہ بچہ ہٹائیں'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.switch_account_rounded, color: Color(0xFF0F766E), size: 20),
                    SizedBox(width: 10),
                    Text('🔄 کردار تبدیل کریں'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                    SizedBox(width: 10),
                    Text('ℹ️ ایپ کے بارے میں'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: d == null
            ? ListView(padding: const EdgeInsets.all(24), children: [
                const Icon(Icons.family_restroom_rounded,
                    size: 64, color: Color(0xFF0F7B5F)),
                const SizedBox(height: 16),
                const Text(
                  'والدین لاگ اِن (Parent Portal)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'استاد کے بھیجے ہوئے میسج سے 8 حرفی کوڈ یہاں درج کریں',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                field(codeCtl, 'بچے کا 8 حرفی کوڈ'),
                const SizedBox(height: 8),
                FilledButton(
                    onPressed: loading ? null : () => fetch(codeCtl.text),
                    child: Text(loading ? 'لوڈ ہو رہا ہے...' : 'ریکارڈ دیکھیں')),
                if (err.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(err,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red))),
              ])
            : RefreshIndicator(
                onRefresh: () => fetch(code!),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (codes.length > 1)
                      Wrap(
                        spacing: 8,
                        children: codes
                            .map((c) => ChoiceChip(
                                  label: Text(
                                      '${snaps[c]?['data']?['name'] ?? c}'),
                                  selected: c == code,
                                  onSelected: (_) => select(c),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 8),
                    // Contact Teacher Card
                    _buildTeacherContactCard(
                      context,
                      teacherName: (d['teacherName'] ?? '').toString(),
                      centerPhone: (d['centerPhone'] ?? '').toString(),
                      studentName: (d['name'] ?? '').toString(),
                      studentCode: code ?? '',
                      isParent: true,
                    ),
                    // Online Live Class
                    if (d['isOnline'] == true &&
                        (d['meetingLink'] ?? '').toString().isNotEmpty) ...[
                      Card(
                        color: Colors.indigo.shade50,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.indigo.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                child: const Icon(Icons.videocam_rounded),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('آن لائن لائیو کلاس',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    Text('زوم / گوگل میٹ کے ذریعے کلاس',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700)),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade700),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('شامل ہوں'),
                                onPressed: () => launchUrl(
                                    Uri.parse('${d['meetingLink']}'),
                                    mode: LaunchMode.externalApplication),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Quran Diary
                    if (d['quran'] != null) ...[
                      Card(
                        color: const Color(0xFFF0FDF4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF86EFAC))),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.menu_book_rounded,
                                      color: Color(0xFF0F7B5F)),
                                  const SizedBox(width: 8),
                                  const Text('قرآن پاک یومیہ ڈائری',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F7B5F))),
                                  const Spacer(),
                                  if ((d['quran']['grade'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F7B5F),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${d['quran']['grade']}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                      child: Text(
                                          'پارہ نمبر: ${d['quran']['para'] ?? 1}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  Expanded(
                                      child: Text(
                                          'سورۃ: ${d['quran']['surah'] ?? "-"}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('آج کا سبق: ${d['quran']['sabaq'] ?? "-"}'),
                              if ((d['quran']['sabaqi'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text('سبقی: ${d['quran']['sabaqi']}'),
                              if ((d['quran']['manzil'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text('منزل: ${d['quran']['manzil']}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Card(
                        child: ListTile(
                            title: Text('${d['name']}'),
                            subtitle: Text('تازہ ترین: ${d['today']}'))),
                    Row(children: [
                      Expanded(
                          child: Card(
                              child: ListTile(
                                  title: const Text('آج کی حاضری'),
                                  subtitle: Text(
                                      d['att'] == true
                                          ? 'حاضر ✅'
                                          : (d['att'] == false
                                              ? 'غیر حاضر ❌'
                                              : '-'),
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold))))),
                      Expanded(
                          child: Card(
                              child: ListTile(
                                  title: const Text('اس ماہ'),
                                  subtitle: Text(
                                      '${d['present']}/${d['marked']} دن',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold))))),
                    ]),
                    Card(
                        child: ListTile(
                            title: const Text('آج کا سبق'),
                            subtitle: Text((d['note'] ?? '').toString().isEmpty
                                ? 'ابھی نہیں لکھا گیا'
                                : '${d['note']}'))),
                    Card(
                        child: ListTile(
                            title: Text('فیس ${d['month']}'),
                            subtitle: Text(
                                '${d['fee']} ${d['currencySymbol'] ?? "روپے"}'),
                            trailing: Chip(
                                label: Text(d['paid'] == true
                                    ? 'مکمل ادا ✅'
                                    : 'باقی ${d['rem'] ?? d['fee']} ${d['currencySymbol'] ?? "روپے"}')))),
                    if ((d['notices'] as List).isNotEmpty) ...[
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('نوٹس بورڈ')),
                      ...(d['notices'] as List).map((n) => Card(
                          child: ListTile(
                              title: Text('${n['t']}'),
                              subtitle: Text('${n['d']}')))),
                    ],
                    if ((d['hw'] ?? []).isNotEmpty) ...[
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('ہوم ورک کی تصاویر')),
                      SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: (d['hw'] as List)
                              .map((h) => Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: GestureDetector(
                                      onTap: () => showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                              child: InteractiveViewer(
                                                  child: Image.network(
                                                      '${h['url']}')))),
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network('${h['url']}',
                                              height: 110,
                                              width: 110,
                                              fit: BoxFit.cover)),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                    if ((d['tests'] ?? []).isNotEmpty) ...[
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('ٹیسٹ کے نتائج')),
                      ...(d['tests'] as List).map((x) => Card(
                          child: ListTile(
                              title: Text('${x['name']}'),
                              subtitle: Text('${x['d']}'),
                              trailing: Text('${x['got']}/${x['total']}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold))))),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('استاد سے سوال',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextField(
                                  controller: qCtl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                      hintText: 'اپنا سوال لکھیں',
                                      border: OutlineInputBorder())),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F7B5F)),
                                      icon: const Icon(Icons.send_rounded),
                                      onPressed: ask,
                                      label: const Text('سوال بھیجیں'),
                                    ),
                                  ),
                                  if (code != null && (snaps[code]?['centerPhone'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                                      icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                                      label: const Text('وائس کال'),
                                      onPressed: () {
                                        final p = snaps[code]!['centerPhone'].toString().replaceAll(RegExp(r'\D'), '');
                                        final name = snaps[code]!['name'] ?? '';
                                        final fakeStudent = Student('s_temp', name, p, 0, code ?? '');
                                        CallSessionManager.instance.startCall(context, fakeStudent, video: false);
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF128C7E), foregroundColor: Colors.white),
                                      icon: const Icon(Icons.videocam_rounded, size: 16),
                                      label: const Text('ویڈیو کال'),
                                      onPressed: () {
                                        final p = snaps[code]!['centerPhone'].toString().replaceAll(RegExp(r'\D'), '');
                                        final name = snaps[code]!['name'] ?? '';
                                        final fakeStudent = Student('s_temp', name, p, 0, code ?? '');
                                        CallSessionManager.instance.startCall(context, fakeStudent, video: true);
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green.shade700,
                                      ),
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 16),
                                      label: const Text('واٹس ایپ'),
                                      onPressed: () {
                                        final p = snaps[code]!['centerPhone'].toString().replaceAll(RegExp(r'\D'), '');
                                        final name = snaps[code]!['name'] ?? '';
                                        final qText = qCtl.text.trim();
                                        final txt = Uri.encodeComponent('السلام علیکم سر! میں $name کے والدین میں سے بات کر رہا ہوں۔ میرا سوال یہ ہے:\n$qText');
                                        launchUrl(Uri.parse('https://wa.me/$p?text=$txt'), mode: LaunchMode.externalApplication);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              if (qa.isNotEmpty) ...[
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    const Text('پوچھے گئے سوالات و جوابات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Spacer(),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                      icon: const Icon(Icons.refresh, size: 14),
                                      label: const Text('تازہ کریں', style: TextStyle(fontSize: 12)),
                                      onPressed: () => code != null ? loadQa(code!) : null,
                                    ),
                                  ],
                                ),
                                ...qa.map((x) {
                                  final hasAns = x['a'] != null && x['a'].toString().isNotEmpty;
                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: hasAns ? Colors.green.shade50 : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: hasAns ? Colors.green.shade200 : Colors.amber.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('سوال: ${x['q']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(hasAns ? Icons.reply_all_rounded : Icons.pending_rounded,
                                                size: 14,
                                                color: hasAns ? Colors.green.shade700 : Colors.amber.shade800),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                hasAns ? 'استاد کا جواب: ${x['a']}' : 'استاد کے جواب کا انتظار ہے...',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: hasAns ? FontWeight.bold : FontWeight.normal,
                                                  color: hasAns ? Colors.green.shade900 : Colors.amber.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ]),
                      ),
                    ),
                    const Center(
                        child: Text('نیچے کھینچ کر تازہ کریں',
                            style: TextStyle(fontSize: 12))),
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------- سینٹر سیٹ اپ ----------------
Widget subPage(String title, List<Widget> children) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.all(16), children: children)),
    );

class CenterPage extends StatelessWidget {
  final Store s;
  const CenterPage(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        void go(Widget w) =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => w));

        Widget item(IconData i, String t, String sub, Widget w) => Card(
            child: ListTile(
                leading: Icon(i, color: const Color(0xFF0F7B5F)),
                title: Text(t,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => go(w)));

        return subPage('سینٹر سیٹ اپ', [
          item(Icons.badge_rounded, 'سینٹر پروفائل',
              'سینٹر کا نام، رابطہ، شہر اور بھائی بہن رعایت %', ProfilePage(s)),
          item(Icons.schedule_rounded, 'بیچ / کلاسیں اور اوقات',
              'کلاسوں کے نام، مضامین اور اوقات بنائیں', BatchesPage(s)),
          item(Icons.person_add_rounded, 'طالب علم شامل کریں',
              'فوری نیا بچہ شامل کریں', Builder(builder: (ctx) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(ctx);
              _openAddStudentSheet(context, s);
            });
            return const SizedBox();
          })),
          item(Icons.quiz_rounded, 'ٹیسٹ اور نمبر',
              'ہفتہ وار یا ماہانہ ٹیسٹ اور مارکس شیٹ', TestsPage(s)),
          item(Icons.account_balance_wallet_rounded, 'حساب: آمدن اور خرچ',
              'اکیڈمی کے اخراجات (کرایہ، بلز) اور منافع', LedgerPage(s)),
        ]);
      },
    );
  }
}

class ProfilePage extends StatefulWidget {
  final Store s;
  const ProfilePage(this.s, {super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final c = TextEditingController(text: widget.s.center);
  late final t = TextEditingController(text: widget.s.profile['teacher']);
  late final ph = TextEditingController(text: widget.s.profile['phone']);
  late final ci = TextEditingController(text: widget.s.profile['city']);
  late final sb = TextEditingController(text: widget.s.profile['sibling']);

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return subPage('سینٹر پروفائل', [
      field(c, 'سینٹر / اکیڈمی کا نام'),
      field(t, 'ٹیچر کا نام'),
      field(ph, 'رابطہ نمبر', type: TextInputType.phone),
      field(ci, 'شہر / علاقہ'),
      field(sb, 'بھائی بہن کی رعایت % (ایک فون نمبر کے دوسرے بچوں پر)',
          type: TextInputType.number),
      FilledButton(
        onPressed: () {
          s.setCenter(c.text.trim());
          s.setProfile('teacher', t.text.trim());
          s.setProfile('phone', ph.text.trim());
          s.setProfile('city', ci.text.trim());
          s.setProfile('sibling', sb.text.trim());
          Navigator.pop(context);
        },
        child: const Text('محفوظ کریں'),
      ),
    ]);
  }
}

class BatchesPage extends StatefulWidget {
  final Store s;
  const BatchesPage(this.s, {super.key});
  @override
  State<BatchesPage> createState() => _BatchesPageState();
}

class _BatchesPageState extends State<BatchesPage> {
  final n = TextEditingController(),
      sub = TextEditingController(),
      tm = TextEditingController(),
      f = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => subPage('بیچ / کلاسیں', [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              field(n, 'بیچ کا نام (مثلاً نویں - صبح، یا ناظرہ گروپ)'),
              field(sub, 'مضمون / کورس'),
              field(tm, 'وقت (مثلاً 4 سے 5 بجے، پیر تا جمعہ)'),
              field(f, 'ماہانہ فیس', type: TextInputType.number),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('بیچ بنائیں'),
                  onPressed: () {
                    if (n.text.trim().isEmpty) return;
                    s.addBatch(n.text.trim(), sub.text.trim(), tm.text.trim(),
                        int.tryParse(f.text) ?? 0);
                    n.clear();
                    sub.clear();
                    tm.clear();
                    f.clear();
                  },
                ),
              ),
            ]),
          ),
        ),
        ...s.batches.map((b) => Card(
              child: ListTile(
                isThreeLine: true,
                title: Text('${b['name']}'),
                subtitle: Text(
                    '${b['subject']} · ${b['time']} · ${b['fee']} روپے\n${s.students.where((x) => x.batchId == b['id']).length} طلبہ'),
                trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => s.delBatch(b['id'])),
              ),
            )),
      ]),
    );
  }
}

class TestsPage extends StatefulWidget {
  final Store s;
  const TestsPage(this.s, {super.key});
  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  final n = TextEditingController(), tot = TextEditingController();
  String batch = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => subPage('ٹیسٹ اور نمبر', [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              field(n, 'ٹیسٹ کا نام (مثلاً ریاضی - ہفتہ وار)'),
              field(tot, 'کل نمبر', type: TextInputType.number),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: batch,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('تمام طلبہ')),
                  ...s.batches.map((b) => DropdownMenuItem(
                      value: b['id'] as String, child: Text('${b['name']}'))),
                ],
                onChanged: (v) => setState(() => batch = v ?? ''),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('ٹیسٹ بنائیں'),
                  onPressed: () {
                    if (n.text.trim().isEmpty) return;
                    s.addTest(n.text.trim(), int.tryParse(tot.text) ?? 100, batch);
                    n.clear();
                    tot.clear();
                  },
                ),
              ),
            ]),
          ),
        ),
        ...s.tests.reversed.map((x) => Card(
              child: ListTile(
                title: Text('${x['name']}'),
                subtitle: Text(
                    '${x['date']} · کل ${x['total']} · ${(x['marks'] as Map).length} کے نمبر لگے'),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MarksPage(s, x['id'] as String))),
                trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => s.delTest(x['id'])),
              ),
            )),
      ]),
    );
  }
}

class MarksPage extends StatelessWidget {
  final Store s;
  final String tid;
  const MarksPage(this.s, this.tid, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = s.tests.firstWhere((x) => x['id'] == tid);
    final list = s.students
        .where((x) => (t['batch'] ?? '') == '' || t['batch'] == x.batchId)
        .toList();
    return subPage('${t['name']} (کل ${t['total']})', [
      if (list.isEmpty)
        const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('کوئی طالب علم نہیں'))),
      ...list.map((st) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              key: ValueKey('${tid}_${st.id}'),
              initialValue: ((t['marks'] as Map)[st.id] ?? '').toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: st.name, border: const OutlineInputBorder()),
              onChanged: (v) => s.setMark(tid, st.id, num.tryParse(v)),
            ),
          )),
    ]);
  }
}

class LedgerPage extends StatefulWidget {
  final Store s;
  const LedgerPage(this.s, {super.key});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final title = TextEditingController(), amt = TextEditingController();
  String type = 'out';

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final feeIn = s.receivedTotal();
        final rows =
            s.ledger.where((e) => '${e['d']}'.startsWith(s.month)).toList();
        int sum(String ty) => rows
            .where((e) => e['type'] == ty)
            .fold<int>(0, (a, e) => a + (e['amount'] as num).toInt());
        final oin = sum('in'), out = sum('out'), net = feeIn + oin - out;
        Widget box(String t, int v, Color c) => Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(children: [
                    Text(t, style: const TextStyle(fontSize: 12)),
                    Text('$v',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: c)),
                  ]),
                ),
              ),
            );
        return subPage('حساب (${s.month})', [
          Row(children: [
            box('فیس وصول', feeIn, Colors.green.shade700),
            box('دیگر آمدن', oin, Colors.green.shade700),
          ]),
          Row(children: [
            box('خرچ', out, Colors.red.shade700),
            box('بچت', net, net >= 0 ? Colors.green.shade700 : Colors.red.shade700),
          ]),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: type,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'out', child: Text('خرچ (کرایہ، بل، کتابیں...)')),
                    DropdownMenuItem(
                        value: 'in', child: Text('دیگر آمدن (داخلہ فیس...)')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'out'),
                ),
                const SizedBox(height: 8),
                field(title, 'تفصیل'),
                field(amt, 'رقم', type: TextInputType.number),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('درج کریں'),
                    onPressed: () {
                      final a = int.tryParse(amt.text);
                      if (a == null || title.text.trim().isEmpty) return;
                      s.addLedger(type, title.text.trim(), a);
                      title.clear();
                      amt.clear();
                    },
                  ),
                ),
              ]),
            ),
          ),
          ...rows.reversed.map((e) => Card(
                child: ListTile(
                  title: Text('${e['title']}'),
                  subtitle:
                      Text('${e['d']} · ${e['type'] == 'in' ? 'آمدن' : 'خرچ'}'),
                  leading: Text('${e['amount']}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: e['type'] == 'in'
                              ? Colors.green.shade700
                              : Colors.red.shade700)),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => s.delLedger(e['id'])),
                ),
              )),
        ]);
      },
    );
  }
}

class QuestionsPage extends StatefulWidget {
  final Store s;
  const QuestionsPage(this.s, {super.key});
  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  List<Map<String, dynamic>> rows = [];
  String msg = 'لوڈ ہو رہا ہے...';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
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
  }

  Student? findStudent(String code) {
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
    // final st = findStudent(r['code'] ?? '');
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
                          widget.s.sendWhatsApp(st, 'وعلیکم السلام ' + st.name + '! آپ کے سوال کا جواب: ');
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
  }
}

// ---------------- رپورٹ کارڈ اور فیس کی رسید (PDF) ----------------
class DocPage extends StatefulWidget {
  final Store s;
  final Student st;
  final bool receipt;
  const DocPage(this.s, this.st, {this.receipt = false, super.key});
  @override
  State<DocPage> createState() => _DocPageState();
}

class _DocPageState extends State<DocPage> {
  final key = GlobalKey();
  final remarks = TextEditingController();
  bool busy = false;

  Future<Uint8List> png() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 3);
    final d = await img.toByteData(format: ui.ImageByteFormat.png);
    return d!.buffer.asUint8List();
  }

  Future<void> share() async {
    setState(() => busy = true);
    try {
      final im = pw.MemoryImage(await png());
      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (c) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(im, fit: pw.BoxFit.fitWidth)),
      ));
      await Printing.sharePdf(
          bytes: await doc.save(),
          filename:
              '${widget.receipt ? "receipt" : "report"}_${widget.st.code}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF نہیں بن سکا: $e')));
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Widget kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k)),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  Widget card() {
    final s = widget.s, st = widget.st;
    final b = s.batchOf(st);
    final due = s.dueOf(st.id), rem = s.remaining(st.id);
    final teacher = s.profile['teacher'] ?? '';
    final phone = s.profile['phone'] ?? '';
    final city = s.profile['city'] ?? '';
    final info = [teacher, phone, city].where((x) => x.isNotEmpty).join(' · ');
    final tests = s.testsFor(st);
    var got = 0.0, tot = 0.0;
    for (final x in tests) {
      got += (x['got'] as num).toDouble();
      tot += (x['total'] as num).toDouble();
    }
    final marked = s.markedDays(st.id), present = s.presentDays(st.id);
    final no =
        'R-${s.today.replaceAll("-", "")}-${st.code.substring(0, 4).toUpperCase()}';

    final rows = <Widget>[
      Text(s.center,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F7B5F))),
      if (info.isNotEmpty)
        Text(info,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
      const Divider(height: 24),
      Text(widget.receipt ? 'فیس کی رسید' : 'رپورٹ کارڈ',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      kv('نام طالب علم', st.name, bold: true),
      kv('کورس / کلاس',
          '${st.courseLabel}${st.isOnline ? " (آن لائن)" : ""}${b != null ? " - ${b['name']}" : ""}'),
      kv('مہینہ', s.month),
    ];
    if (widget.receipt) {
      rows.addAll([
        kv('رسید نمبر', no),
        const Divider(height: 24),
        kv('واجب فیس', '$due ${st.currencySymbol}'),
        kv('وصول شدہ', '${due - rem} ${st.currencySymbol}', bold: true),
        kv('باقی فیس', '$rem ${st.currencySymbol}'),
        const SizedBox(height: 6),
        Text(rem == 0 ? 'فیس مکمل ادا ✅' : 'فیس جزوی ادا',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      ]);
    } else {
      if (st.isQuranStudent && st.quran != null) {
        rows.addAll([
          const Divider(height: 24),
          const Text('قرآن مجید یومیہ ریکارڈ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          kv('پارہ نمبر', 'پارہ ${st.quran!['para'] ?? 1}'),
          kv('سورۃ', '${st.quran!['surah'] ?? "-"}'),
          kv('سبق', '${st.quran!['sabaq'] ?? "-"}'),
          if ((st.quran!['sabaqi'] ?? '').toString().isNotEmpty)
            kv('سبقی', '${st.quran!['sabaqi']}'),
          if ((st.quran!['manzil'] ?? '').toString().isNotEmpty)
            kv('منزل', '${st.quran!['manzil']}'),
          if ((st.quran!['grade'] ?? '').toString().isNotEmpty)
            kv('کارکردگی / گریڈ', '${st.quran!['grade']}', bold: true),
        ]);
      }
      rows.addAll([
        const Divider(height: 24),
        kv('حاضری',
            marked == 0
                ? '-'
                : '$present / $marked دن (${(present * 100 / marked).round()}%)'),
        if (tests.isNotEmpty) ...[
          const Divider(height: 24),
          const Text('ٹیسٹ کے نتائج',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...tests.map((x) {
            final tt = (x['total'] as num).toDouble();
            final pc = tt == 0 ? 0 : ((x['got'] as num) * 100 / tt).round();
            return kv('${x['name']}', '${x['got']} / ${x['total']}  ($pc%)');
          }),
          if (tot > 0)
            kv('اوسط', '${(got * 100 / tot).round()}%', bold: true),
        ],
        const Divider(height: 24),
        kv('فیس سٹیٹس', rem == 0 ? 'مکمل ادا ✅' : 'باقی $rem ${st.currencySymbol}'),
        if (remarks.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('استاد کے ریمارکس',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(remarks.text.trim()),
        ],
      ]);
    }
    rows.addAll([
      const Divider(height: 28),
      kv('تاریخ اجراء', s.today),
      const SizedBox(height: 28),
      const Text('دستخط استاد / ایڈمن: ______________'),
    ]);

    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: Container(
        width: 595,
        color: Colors.white,
        padding: const EdgeInsets.all(28),
        child: DefaultTextStyle(
          style: const TextStyle(
              color: Colors.black, fontSize: 17, height: 1.8),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receipt ? 'فیس کی رسید' : 'رپورٹ کارڈ')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (!widget.receipt)
            TextField(
              controller: remarks,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'استاد کے ریمارکس (اختیاری)',
                  border: OutlineInputBorder()),
            ),
          const SizedBox(height: 12),
          FittedBox(
              fit: BoxFit.fitWidth,
              child: RepaintBoundary(key: key, child: card())),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: Text(busy ? '...' : 'PDF شیئر کریں (واٹس ایپ)'),
            onPressed: busy ? null : share,
          ),
        ]),
      ),
    );
  }
}


// ============================================================================
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
    var p = student.phone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) p = '92${p.substring(1)}';
    final callType = video ? 'ویڈیو کال (Video Call)' : 'وائس کال (Voice Call)';
    final msg = 'السلام علیکم ورحمۃ اللہ!\nآن لائن کلاس / قرآن پاک تلاوت: استاد $callType شروع کر رہے ہیں، برائے مہربانی کال اٹھائیں۔';
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
    var p = student.phone.replaceAll(RegExp(r'\D'), '');
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
