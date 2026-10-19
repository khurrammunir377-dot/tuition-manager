import json

juz_names = [
    'الم (آلٓمّٓ)',
    'سَیَقُولُ',
    'تِلْكَ الرُّسُلُ',
    'لَنْ تَنَالُوا',
    'وَالْمُحْصَنَاتُ',
    'لَا يُحِبُّ اللَّهُ',
    'وَإِذَا سَمِعُوا',
    'وَلَوْ أَنَّنَا',
    'قَالَ الْمَلَأُ',
    'وَاعْلَمُوا',
    'يَعْتَذِرُونَ',
    'وَمَا مِنْ دَابَّةٍ',
    'وَمَا أُبَرِّئُ',
    'رُبَمَا',
    'سُبْحَانَ الَّذِي',
    'قَالَ أَلَمْ',
    'اقْتَرَبَ لِلنَّاسِ',
    'قَدْ أَفْلَحَ',
    'وَقَالَ الَّذِينَ',
    'أَمَّنْ خَلَقَ',
    'اتْلُ مَا أُوحِيَ',
    'وَمَنْ يَقْنُتْ',
    'وَمَا لِيَ',
    'فَمَنْ أَظْلَمُ',
    'إِلَيْهِ يُرَدُّ',
    'حم (حٰمٓ)',
    'قَالَ فَمَا خَطْبُكُمْ',
    'قَدْ سَمِعَ اللَّهُ',
    'تَبَارَكَ الَّذِي',
    'عَمَّ'
]

with open('lib/quran_data.dart', 'r', encoding='utf-8') as f:
    text = f.read()

prefix = 'static const List<Map<String, dynamic>> juzs = ['
start = text.find(prefix)
end = text.find('];', start)

raw_juzs = text[start+len(prefix):end]
items = [x.strip() for x in raw_juzs.split('},') if x.strip()]

updated_juzs = []
for idx, name in enumerate(juz_names):
    item = items[idx].rstrip('}')
    updated_juzs.append(f'{item}, "name": "{name}"}}')

new_juz_decl = prefix + ', '.join(updated_juzs) + '];'

new_text = text[:start] + new_juz_decl + text[end+2:]
with open('lib/quran_data.dart', 'w', encoding='utf-8') as f:
    f.write(new_text)

print('Updated lib/quran_data.dart with Arabic Para names!')
