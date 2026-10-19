-- نئی تبدیلیاں (اگر supabase_push.sql پہلے چلا چکے ہیں تو یہ بھی چلائیں)
-- ایک والد کے کئی بچے: کسی ایک بچے کا نوٹیفکیشن بند کرنے کے لیے
create or replace function unregister_token(p_token text, p_code text)
returns void language sql security definer set search_path = public as $$
  delete from push_tokens where token = p_token and code = p_code
$$;
grant execute on function unregister_token(text, text) to anon, authenticated;
