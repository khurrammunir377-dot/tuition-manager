import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Update version constant in _GateState
text = text.replace("static const currentVersion = '1.1.0';", "static const currentVersion = '1.2.0';")

# 2. Add checkForAppUpdate call in _GateState.initState
old_gate_init = """      setState(() {
        role = p.getString('role');
        loaded = true;
        showUpgradeNotice = upgraded;
      });
    });
  }"""

new_gate_init = """      setState(() {
        role = p.getString('role');
        loaded = true;
        showUpgradeNotice = upgraded;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => checkForAppUpdate(context));
    });
  }"""

if old_gate_init in text:
    text = text.replace(old_gate_init, new_gate_init)
    print("Added checkForAppUpdate to _GateState.initState")
else:
    print("WARNING: old_gate_init not found")

# 3. Add Voice & Video Call buttons to Student Card in Teacher Portal
old_student_card_buttons = """                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.send_rounded,
                                        size: 16),
                                    label: const Text('واٹس ایپ'),
                                    onPressed: () => s.sendWhatsApp(st),
                                  ),
                                  const SizedBox(width: 6),"""

new_student_card_buttons = """                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.send_rounded,
                                        size: 16),
                                    label: const Text('واٹس ایپ'),
                                    onPressed: () => s.sendWhatsApp(st),
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                                    label: const Text('وائس کال'),
                                    onPressed: () => CallSessionManager.instance.startCall(context, st, video: false),
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF128C7E),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.videocam_rounded, size: 16),
                                    label: const Text('ویڈیو کال'),
                                    onPressed: () => CallSessionManager.instance.startCall(context, st, video: true),
                                  ),
                                  const SizedBox(width: 6),"""

if old_student_card_buttons in text:
    text = text.replace(old_student_card_buttons, new_student_card_buttons)
    print("Added Call buttons to student card in teacher portal")
else:
    print("WARNING: old_student_card_buttons not found")

# 4. Add Voice & Video Call buttons to Student Portal
old_student_portal_whatsapp = """                                if ((snap?['centerPhone'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
                                    label: const Text('واٹس ایپ'),
                                    onPressed: () {
                                      final p = snap!['centerPhone'].toString().replaceAll(RegExp(r'\\D'), '');
                                      final name = snap!['name'] ?? '';
                                      final qText = qCtl.text.trim();
                                      final txt = Uri.encodeComponent('السلام علیکم سر! میں $name بات کر رہا ہوں۔ میرا سوال یہ ہے:\\n$qText');
                                      launchUrl(Uri.parse('https://wa.me/$p?text=$txt'), mode: LaunchMode.externalApplication);
                                    },
                                  ),
                                ],"""

new_student_portal_whatsapp = """                                if ((snap?['centerPhone'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                                    label: const Text('وائس کال'),
                                    onPressed: () {
                                      final p = snap!['centerPhone'].toString().replaceAll(RegExp(r'\\D'), '');
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
                                      final p = snap!['centerPhone'].toString().replaceAll(RegExp(r'\\D'), '');
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
                                      final p = snap!['centerPhone'].toString().replaceAll(RegExp(r'\\D'), '');
                                      final name = snap!['name'] ?? '';
                                      final qText = qCtl.text.trim();
                                      final txt = Uri.encodeComponent('السلام علیکم سر! میں $name بات کر رہا ہوں۔ میرا سوال یہ ہے:\\n$qText');
                                      launchUrl(Uri.parse('https://wa.me/$p?text=$txt'), mode: LaunchMode.externalApplication);
                                    },
                                  ),
                                ],"""

if old_student_portal_whatsapp in text:
    text = text.replace(old_student_portal_whatsapp, new_student_portal_whatsapp)
    print("Added Call buttons to Student Portal")
else:
    print("WARNING: old_student_portal_whatsapp not found")

# 5. Add Voice & Video Call buttons to Parent Portal
old_parent_portal_whatsapp = """                                  if (code != null && (snaps[code]?['centerPhone'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green.shade700,
                                      ),
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
                                      label: const Text('واٹس ایپ'),
                                      onPressed: () {
                                        final p = snaps[code]!['centerPhone'].toString().replaceAll(RegExp(r'\\D'), '');
                                        final name = snaps[code]!['name'] ?? '';
                                        final qText = qCtl.text.trim();
                                        final txt = Uri.encodeComponent('السلام علیکم سر! میں $name کے والدین میں سے بات کر رہا ہوں۔ میرا سوال یہ ہے:\\n$qText');
                                        launchUrl(Uri.parse('https://wa.me/$p?text=$txt'), mode: LaunchMode.externalApplication);
                                      },
                                    ),
                                  ],"""

new_parent_portal_whatsapp = """                                  if (code != null && (snaps[code]?['centerPhone'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                                      icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                                      label: const Text('وائس کال'),
                                      onPressed: () {
                                        final p = snaps[code]!['centerPhone'].toString().replaceAll(RegExp(r'\\D'), '');
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
                                        final p = snaps[code]!['centerPhone'].toString().replaceAll(RegExp(r'\\D'), '');
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
                                        final p = snaps[code]!['centerPhone'].toString().replaceAll(RegExp(r'\\D'), '');
                                        final name = snaps[code]!['name'] ?? '';
                                        final qText = qCtl.text.trim();
                                        final txt = Uri.encodeComponent('السلام علیکم سر! میں $name کے والدین میں سے بات کر رہا ہوں۔ میرا سوال یہ ہے:\\n$qText');
                                        launchUrl(Uri.parse('https://wa.me/$p?text=$txt'), mode: LaunchMode.externalApplication);
                                      },
                                    ),
                                  ],"""

if old_parent_portal_whatsapp in text:
    text = text.replace(old_parent_portal_whatsapp, new_parent_portal_whatsapp)
    print("Added Call buttons to Parent Portal")
else:
    print("WARNING: old_parent_portal_whatsapp not found")

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Patch 1 complete")
