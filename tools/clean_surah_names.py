import json

with open('lib/quran_data.dart', 'r', encoding='utf-8') as f:
    text = f.read()

prefix = 'static const List<Map<String, dynamic>> surahs = '
start = text.find(prefix)
end = text.find(';', start)

surahs_json = text[start+len(prefix):end].strip()
surahs = json.loads(surahs_json)

for s in surahs:
    name = s['name']
    for p in ['سُورَةُ ٱلْ', 'سُورَةُ ال', 'سُورَةُ ', 'سُورَةِ ']:
        if name.startswith(p):
            name = name[len(p):]
            break
    s['name'] = name.strip()

# Let's write clean names
new_surahs_json = json.dumps(surahs, ensure_ascii=False)
new_text = text[:start+len(prefix)] + new_surahs_json + text[end:]

with open('lib/quran_data.dart', 'w', encoding='utf-8') as f:
    f.write(new_text)

print('Cleaned surah names in lib/quran_data.dart successfully!')
