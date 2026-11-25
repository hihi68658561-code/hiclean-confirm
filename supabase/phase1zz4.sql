-- 1단계-zz4: 휴대폰(MacroDroid)에서 문자 원문을 그대로 보내도 되게 (phase1zz3.sql 다음에 실행)
-- 문자에 줄바꿈이 있어 JSON으로 보내면 깨질 수 있어서, 글자 그대로(text/plain) 받습니다.
--   POST https://<프로젝트>.supabase.co/rest/v1/rpc/ingest_sms
--   헤더 apikey: (공개 키), Content-Type: text/plain
--   본문 첫 줄: 입금 연결 키, 둘째 줄부터: 문자 내용
create or replace function public.ingest_sms(text) returns text
language plpgsql security definer set search_path = public, pg_temp as $$
declare first text := split_part(coalesce($1, ''), E'\n', 1);
begin
  return public.ingest_deposit(btrim(first, E' \r\t'), substr(coalesce($1, ''), length(first) + 2));
end $$;
revoke execute on function public.ingest_sms(text) from public;
grant execute on function public.ingest_sms(text) to anon, authenticated;
