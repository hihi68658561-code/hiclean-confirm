-- 1단계-zz3: 은행 입금 문자 자동 등록 · 입금 확인 (phase1zz2.sql 다음에 실행)
-- 회사 휴대폰(MacroDroid)이 기업은행 입금 문자를 아래 주소로 보내면 '입금 확인' 메뉴에 쌓입니다.
--   POST https://<프로젝트>.supabase.co/rest/v1/rpc/ingest_deposit
--   헤더 apikey: (공개 키)   본문 {"p_token":"(설정 화면의 입금 연결 키)","p_text":"(문자 내용)"}
-- 입금 연결 키는 관리자만 프로그램 설정 화면에서 볼 수 있습니다.

create table if not exists public.bank_deposits (
  id          uuid primary key default gen_random_uuid(),
  dep_at      timestamptz,                 -- 입금일시
  bank        text not null default '',
  account     text not null default '',    -- 계좌(가려진 번호 그대로)
  depositor   text not null default '',    -- 입금자명(적요)
  amount      bigint not null default 0,
  raw         text not null default '',    -- 받은 문자 원문
  status      text not null default '미확인' check (status in ('미확인','확인','제외')),
  match_type  text not null default '',    -- ctr(계약) / as(작업)
  match_id    uuid,
  customer_id uuid references public.customers(id) on delete set null,
  pay_id      uuid,                        -- 만들어진 입금 기록(payments / job_payments)
  memo        text not null default '',
  handled_by  text not null default '',
  handled_at  timestamptz,
  dedup_key   text unique,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists bank_deposits_at_idx on public.bank_deposits(dep_at desc);
create index if not exists bank_deposits_upd_idx on public.bank_deposits(updated_at);

alter table public.bank_deposits enable row level security;
drop policy if exists bd_select on public.bank_deposits;
drop policy if exists bd_update on public.bank_deposits;
drop policy if exists bd_delete on public.bank_deposits;
create policy bd_select on public.bank_deposits for select to authenticated using ((select public.is_office()));
create policy bd_update on public.bank_deposits for update to authenticated using ((select public.is_office())) with check ((select public.is_office()));
create policy bd_delete on public.bank_deposits for delete to authenticated using ((select public.is_admin()));
revoke all on public.bank_deposits from anon;
grant select, update, delete on public.bank_deposits to authenticated;
drop trigger if exists bank_deposits_touch on public.bank_deposits;
create trigger bank_deposits_touch before update on public.bank_deposits for each row execute function public.touch_updated();

-- 입금 연결 키 (아무도 직접 읽을 수 없고, 관리자만 아래 함수로 확인)
create table if not exists public.deposit_cfg (id int primary key default 1 check (id = 1), token text not null);
alter table public.deposit_cfg enable row level security;
revoke all on public.deposit_cfg from anon, authenticated;
insert into public.deposit_cfg(id, token) values (1, replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')) on conflict (id) do nothing;

create or replace function public.deposit_token(p_reset boolean default false) returns text
language plpgsql security definer set search_path = public, pg_temp as $$
declare t text;
begin
  if not public.is_admin() then raise exception '관리자만 볼 수 있습니다'; end if;
  if p_reset then update public.deposit_cfg set token = replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '') where id = 1; end if;
  select token into t from public.deposit_cfg where id = 1;
  return t;
end $$;
revoke execute on function public.deposit_token(boolean) from public, anon;
grant execute on function public.deposit_token(boolean) to authenticated;

-- 문자 읽어서 저장 (휴대폰에서 호출). 입금 문자가 아니면 'skip'
create or replace function public.ingest_deposit(p_token text, p_text text) returns text
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  t text; ln text; lines text[]; m text[];
  v_at timestamptz; v_amt bigint; v_acct text := ''; v_bank text := ''; v_name text := '';
  y int; kst timestamp := (now() at time zone 'Asia/Seoul');
begin
  if p_token is null or p_token <> (select token from public.deposit_cfg where id = 1) then raise exception 'bad token'; end if;
  t := left(coalesce(p_text, ''), 2000);
  if t !~ '입금' then return 'skip'; end if;
  m := regexp_match(t, '입금\s*([0-9][0-9,]*)\s*원?');
  if m is null then return 'skip'; end if;
  v_amt := replace(m[1], ',', '')::bigint;
  m := regexp_match(t, '(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})\s+(\d{1,2}):(\d{2})');
  if m is not null then
    v_at := make_timestamp(m[1]::int, m[2]::int, m[3]::int, m[4]::int, m[5]::int, 0) at time zone 'Asia/Seoul';
  else
    m := regexp_match(t, '(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2})');
    if m is not null then
      y := extract(year from kst)::int;
      if m[1]::int > extract(month from kst)::int then y := y - 1; end if;
      v_at := make_timestamp(y, m[1]::int, m[2]::int, m[3]::int, m[4]::int, 0) at time zone 'Asia/Seoul';
    else v_at := now(); end if;
  end if;
  lines := regexp_split_to_array(t, '\s*\n\s*');
  foreach ln in array lines loop
    ln := btrim(ln);
    continue when ln = '' or ln ~ '^\[.*\]$' or ln ~ '\d{1,4}[/.-]\d{1,2}.*\d{1,2}:\d{2}' or ln ~ '입금' or ln ~ '잔액';
    if ln ~ '^[0-9*\-]{6,}$' then v_acct := ln; continue; end if;
    if ln ~ '^(기업|IBK|국민|신한|우리|하나|농협|NH|SC|씨티|카카오|토스|케이)' and length(ln) <= 6 then v_bank := ln; continue; end if;
    if v_name = '' then v_name := left(ln, 40); end if;
  end loop;
  if v_bank = '' and t ~ '(기업|IBK)' then v_bank := '기업'; end if;
  insert into public.bank_deposits(dep_at, bank, account, depositor, amount, raw, dedup_key)
  values (v_at, v_bank, v_acct, v_name, v_amt, t, md5(coalesce(v_at::text,'') || '|' || v_amt || '|' || v_name || '|' || v_acct))
  on conflict (dedup_key) do nothing;
  return 'ok';
end $$;
revoke execute on function public.ingest_deposit(text, text) from public;
grant execute on function public.ingest_deposit(text, text) to anon, authenticated;
