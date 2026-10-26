-- 1단계-zc: 문자 보내기 (솔라피) — 발송 기록과 자주 쓰는 문구 (phase1zb.sql 다음에 실행)
create table if not exists public.sms_logs (
  id          uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers(id) on delete set null,
  ref_type    text not null default '',      -- job / ctr / recv
  ref_id      uuid,
  to_phone    text not null,
  from_phone  text not null default '',
  content     text not null default '',
  msg_type    text not null default '',      -- SMS / LMS
  status      text not null default '접수',  -- 접수 / 실패
  error       text not null default '',
  group_id    text not null default '',
  by_name     text not null default '',
  created_by  uuid,
  created_at  timestamptz not null default now()
);
create index if not exists sms_logs_customer_idx on public.sms_logs(customer_id, created_at desc);
alter table public.sms_logs enable row level security;
drop policy if exists sms_select on public.sms_logs;
create policy sms_select on public.sms_logs for select to authenticated
  using ((select public.is_office()) or created_by = (select auth.uid()) or customer_id in (select public.my_customer_ids()));
-- 기록은 문자 보내기 기능(서버)만 남깁니다. 화면에서 직접 쓰거나 지울 수 없음
revoke all on public.sms_logs from anon;
grant select on public.sms_logs to authenticated;

create table if not exists public.sms_templates (
  id         uuid primary key default gen_random_uuid(),
  title      text not null default '',
  content    text not null default '',
  sort       int  not null default 0,
  created_at timestamptz not null default now()
);
alter table public.sms_templates enable row level security;
drop policy if exists smt_select on public.sms_templates;
drop policy if exists smt_write on public.sms_templates;
create policy smt_select on public.sms_templates for select to authenticated using ((select public.is_staff()));
create policy smt_write on public.sms_templates for all to authenticated using ((select public.is_office())) with check ((select public.is_office()));
revoke all on public.sms_templates from anon;
grant select, insert, update, delete on public.sms_templates to authenticated;

insert into public.sms_templates (title, content, sort)
select * from (values
  ('방문 안내', '[하이클린] {업체명} 고객님, {방문일} {시간}에 방문 예정입니다. 감사합니다.', 1),
  ('A/S 접수', '[하이클린] {업체명} 고객님, A/S 접수되었습니다. 일정 확인 후 연락드리겠습니다.', 2),
  ('설치 완료', '[하이클린] {업체명} 고객님, 초음파 식기세척기 설치가 완료되었습니다. 이용해 주셔서 감사합니다.', 3),
  ('미수 안내', '[하이클린] {업체명} 고객님, 미납 금액 {미수금}원 입금 부탁드립니다. {계좌}', 4)
) v(title, content, sort)
where not exists (select 1 from public.sms_templates);
