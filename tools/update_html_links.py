for fname in ['landing/index.html', 'index.html']:
    with open(fname, 'r', encoding='utf-8') as f:
        t = f.read()

    target = 'https://github.com/khurrammunir377-dot/tuition-manager/releases/tag/v1.1.0'
    if target in t:
        # replace the whole helper block with direct link
        t = t.replace('https://github.com/khurrammunir377-dot/tuition-manager/releases/download/v1.1.0/TuitionManager.apk', '/TuitionManager.apk')
        t = t.replace('<span>•</span>\n            <a href="https://github.com/khurrammunir377-dot/tuition-manager/releases/tag/v1.1.0" target="_blank" rel="noopener noreferrer" class="text-slate-600 hover:text-slate-900 underline">GitHub Releases</a>', '')
        t = t.replace('<span>•</span>\r\n            <a href="https://github.com/khurrammunir377-dot/tuition-manager/releases/tag/v1.1.0" target="_blank" rel="noopener noreferrer" class="text-slate-600 hover:text-slate-900 underline">GitHub Releases</a>', '')
        with open(fname, 'w', encoding='utf-8') as f:
            f.write(t)
        print(f"Updated {fname}")
    else:
        print(f"Target not found in {fname}")
