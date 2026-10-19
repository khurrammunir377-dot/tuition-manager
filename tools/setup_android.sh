#!/bin/sh
# flutter create کے بعد ایک بار چلائیں: انٹرنیٹ (ریلیز APK کے لیے ضروری) اور نوٹیفکیشن کی اجازت
M=android/app/src/main/AndroidManifest.xml
[ -f "$M" ] || { echo "پہلے flutter create چلائیں"; exit 1; }
grep -q 'android.permission.INTERNET' "$M" || \
  sed -i '0,/<application/s#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$M"
grep -q 'POST_NOTIFICATIONS' "$M" || \
  sed -i '0,/<application/s#<application#<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application#' "$M"
echo "ہو گیا"
