# -*- coding: utf-8 -*-
with open('landing/index.html', 'r', encoding='utf-8') as f:
    c = f.read()

c = c.replace(
    "app1_btn: 'ڈاؤن لوڈ APK (210 MB)',",
    "app1_btn: 'ڈاؤن لوڈ APK (75 MB)',"
)

if "app3_badge: 'فکری پزل گیم'" not in c:
    c = c.replace(
        "app2_btn: 'ڈاؤن لوڈ APK (60 MB)',",
        "app2_btn: 'ڈاؤن لوڈ APK (60 MB)',\n        app3_badge: 'فکری پزل گیم',\n        app3_desc: 'ٹریفک اور رش سے گاڑی باہر نکالنے کی دلچسپ اور دماغی مشق والی پزل گیم۔ تمام عمر کے لیے پرلطف اور چیلنجنگ لیولز۔',\n        app3_btn: 'ڈاؤن لوڈ APK (14 MB)',"
    )

with open('landing/index.html', 'w', encoding='utf-8') as f:
    f.write(c)

print('Updated urdu dictionary successfully!')
