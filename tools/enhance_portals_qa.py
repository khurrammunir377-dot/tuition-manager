# -*- coding: utf-8 -*-
with open('lib/main.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# 1. Enhance StudentPortal Q&A
old_student_ui = """                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F7B5F)),
                                icon: const Icon(Icons.send_rounded),
                                onPressed: ask,
                                label: const Text('سوال بھیجیں'),
                              ),
                            ),
                            ...qa.map((x) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('سوال: ${x['q']}'),
                                  subtitle: Text(x['a'] == null
                                      ? 'جواب کا انتظار...'
                                      : 'استاد کا جواب: ${x['a']}'),
                                )),"""

new_student_ui = """                            Row(
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
                            ],"""

# 2. Enhance ParentPortal Q&A
old_parent_ui = """                              FilledButton(
                                  onPressed: ask, child: const Text('بھیجیں')),
                              ...qa.map((x) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${x['q']}'),
                                    subtitle: Text(x['a'] == null
                                        ? 'جواب کا انتظار...'
                                        : 'جواب: ${x['a']}'),
                                  )),"""

new_parent_ui = """                              Row(
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
                              ],"""

c_norm = c.replace('\r\n', '\n')
if old_student_ui.replace('\r\n', '\n') in c_norm:
    c_norm = c_norm.replace(old_student_ui.replace('\r\n', '\n'), new_student_ui.replace('\r\n', '\n'))
    print("Replaced student UI!")
else:
    print("Could not find old_student_ui")

if old_parent_ui.replace('\r\n', '\n') in c_norm:
    c_norm = c_norm.replace(old_parent_ui.replace('\r\n', '\n'), new_parent_ui.replace('\r\n', '\n'))
    print("Replaced parent UI!")
else:
    print("Could not find old_parent_ui")

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(c_norm)

print("Saved portals QA updates!")
