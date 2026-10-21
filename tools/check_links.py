import re

for filename in ['landing/index.html', 'index.html']:
    print(f"=== {filename} ===")
    with open(filename, 'r', encoding='utf-8') as f:
        text = f.read()

    hrefs = re.findall(r'href=["\']([^"\']+)["\']', text)
    for h in sorted(set(hrefs)):
        if not h.startswith('#') and not h.startswith('mailto') and not h.startswith('https://fonts') and not h.startswith('https://cdn') and not h.startswith('https://unpkg'):
            print(f"  {h}")
