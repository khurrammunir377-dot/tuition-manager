# ٹیوشن مینیجر (Tuition Manager) - Flutter + Supabase

## 1) Supabase سیٹ اپ (مفت، ایک بار)
1. supabase.com پر نیا پراجیکٹ بنائیں
2. SQL Editor میں `supabase_setup.sql` کا پورا مواد چلائیں
3. Authentication > Providers > Email میں "Confirm email" بند کر دیں (ورنہ نیا اکاؤنٹ بنتے ہی لاگ اِن نہیں ہوگا)
4. Project Settings > API سے URL اور anon key کاپی کر کے `lib/config.dart` میں ڈالیں

## 1الف) بیک اپ
`supabase_backup.sql` بھی چلائیں (خودکار سنک اس کے بغیر ناکام ہوگا)۔ ٹیچر کا سارا ڈیٹا ہر تبدیلی کے 3 سیکنڈ بعد خود بخود کلاؤڈ میں چلا جاتا ہے؛ نیا فون ہو تو لاگ اِن کر کے "کلاؤڈ بیک اپ سے بحال کریں" دبائیں۔

## 1ب) پرو پلان (10 طلبہ مفت)
- `supabase_pro.sql` بھی چلائیں
- `lib/config.dart` میں اپنا JazzCash/Easypaisa نمبر اور واٹس ایپ ڈالیں
- ٹیچر کی رسید آنے پر SQL فائل کے آخر والا کمانڈ (ای میل بدل کر) چلائیں: 30 دن کا پرو فعال ہو جاتا ہے
- نوٹ: Google Play پر رکھیں گے تو ایپ کے اندر سبسکرپشن کے لیے Play Billing لازمی ہے۔ شروع میں APK براہِ راست واٹس ایپ/ویب سے بانٹنا آسان ہے

## 1ج) پش نوٹیفکیشن (اختیاری، ایپ اس کے بغیر بھی چلتی ہے)
1. console.firebase.google.com پر پراجیکٹ بنائیں
2. Project settings > Service accounts > "Generate new private key": JSON فائل محفوظ رکھیں (کسی کو نہ دیں، گٹ ہب پر نہ ڈالیں)
3. Supabase: Integrations > Database Webhooks > Enable
4. Edge Function: `supabase/functions/notify/index.ts` ڈیپلوئی کریں:
   supabase functions deploy notify --no-verify-jwt
   supabase secrets set WEBHOOK_SECRET=کوئی_لمبا_خفیہ_لفظ FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
5. `supabase_push.sql` میں PROJECT_REF اور CHANGE_ME (وہی WEBHOOK_SECRET) بدل کر چلائیں
6. ایپ فولڈر میں: dart pub global activate flutterfire_cli ، پھر flutterfire configure
7. `flutter create ...` کے بعد ایک بار: sh tools/setup_android.sh (انٹرنیٹ اور نوٹیفکیشن کی اجازت ڈالتا ہے؛ INTERNET کے بغیر ریلیز APK میں سنک نہیں چلے گا)
8. اگر flutter pub get ورژن پر شکایت کرے: flutter pub upgrade --major-versions

کب نوٹیفکیشن جاتا ہے: حاضر/غیر حاضر، آج کا سبق، فیس وصول، نیا نوٹس بورڈ پیغام۔

## 1د) نئی SQL
`supabase_v2.sql` بھی چلائیں (ایک والد کے کئی بچوں کے نوٹیفکیشن کے لیے)۔ Edge Function دوبارہ ڈیپلوئی کریں۔

## 1ہ) ہوم ورک تصویر اور سوالات
`supabase_v3.sql` چلائیں (PROJECT_REF اور CHANGE_ME بدلنا نہ بھولیں) اور Edge Function دوبارہ ڈیپلوئی کریں۔ ہوم ورک کی تصویر کے لیے ٹیچر کا لاگ اِن ہونا ضروری ہے۔

## 2) ایپ چلانا
flutter create --org com.khurram --project-name tuition_manager .
flutter pub get
flutter run
APK: flutter build apk --release

## 3) استعمال
- ٹیچر: "میں ٹیچر ہوں" > بچے شامل کریں > "پیغامات" ٹیب میں لاگ اِن > "ابھی سنک کریں"
- ہر بچے کا 8 حرفی کوڈ واٹس ایپ میسج میں جاتا ہے
- والدین: ایپ کھول کر "میں والد/والدہ ہوں" > کوڈ ڈالیں > لائیو ریکارڈ، نیچے کھینچ کر تازہ کریں
- بلک: فلٹر (سب / فیس باقی / آج غیر حاضر) + میسج > "واٹس ایپ قطار" (ہر والد کے لیے ایک ٹیپ) یا "نوٹس بورڈ" (سب والدین کی ایپ میں خود نظر آتا ہے، سنک کے بعد)

## نوٹ
- ڈیٹا ٹیچر کے فون میں اصل ہے، سنک کرنے پر والدین کی کاپی اپڈیٹ ہوتی ہے
- واٹس ایپ خود بخود سب کو ایک ساتھ نہیں بھیجنے دیتا، اس کے لیے WhatsApp Business API (پیڈ) چاہیے
