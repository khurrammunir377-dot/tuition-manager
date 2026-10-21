# -*- coding: utf-8 -*-
with open('lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = 0
for i, line in enumerate(lines):
    if skip > 0:
        skip -= 1
        continue
    if 'widget.s.sendWa(' in line:
        # replace the multi-line broken sendWa
        new_lines.append("                          widget.s.sendWhatsApp(st, 'وعلیکم السلام ' + st.name + '! آپ کے سوال کا جواب: ');\n")
        # see how many lines to skip until `});`
        for j in range(i + 1, min(i + 5, len(lines))):
            if '},' in lines[j] or '});' in lines[j]:
                skip = j - i - 1
                break
    else:
        new_lines.append(line)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Fixed sendWa successfully!")
