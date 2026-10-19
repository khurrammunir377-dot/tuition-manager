// Supabase dashboard > Project Settings > API سے یہ دو قدریں یہاں ڈالیں
class Cfg {
  static const url = 'https://gxlwsrrdcbecqcaiwufm.supabase.co';
  static const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bHdzcnJkY2JlY3FjYWl3dWZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NzA0MzQsImV4cCI6MjA5ODU0NjQzNH0.ABH9WyW3OAC0cynj4qMy1iAEb2qJJFZGzNlTED6zG2A';
  static bool get ready => !url.startsWith('YOUR_');

  // پرو پلان
  static const freeLimit = 10; // supabase_pro.sql میں بھی یہی عدد رکھیں
  static const proPrice = 500; // روپے ماہانہ
  static const payInfo = 'JazzCash/Easypaisa: 03XX-XXXXXXX (نام)';
  static const adminWhatsapp = '92300XXXXXXXX'; // آپ کا واٹس ایپ، بغیر +
}
