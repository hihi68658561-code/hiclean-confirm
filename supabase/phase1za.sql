-- 1단계-za: 미수·채권관리를 '미수채권현황' 엑셀 양식에 맞춤 (phase1z.sql 다음에 실행)
-- 담당자·진행단계(미수·추심·CMS-15일 등)·채권분류(정상·관리·불량·악성)·채권종류(매출채권·가불금·대여금)
-- 가불금·대여금처럼 계약이 없는 채권도 직접 등록 (ref_type = 'etc', 입금 내역은 ledger에)
alter table public.recv_cases drop constraint if exists recv_cases_ref_type_check;
alter table public.recv_cases add constraint recv_cases_ref_type_check check (ref_type in ('ctr','as','etc'));
alter table public.recv_cases alter column ref_id drop not null;
alter table public.recv_cases alter column customer_id drop not null;
alter table public.recv_cases add column if not exists kind       text   not null default '매출채권';  -- 매출채권·가불금·대여금
alter table public.recv_cases add column if not exists grade      text   not null default '';         -- 정상·관리·불량·악성
alter table public.recv_cases add column if not exists owner      uuid references public.staff(user_id) on delete set null;
alter table public.recv_cases add column if not exists owner_name text   not null default '';         -- 채권 담당자
alter table public.recv_cases add column if not exists progress   text   not null default '';         -- 진행단계 (미수·장기미수·추심·CMS-15일 …)
alter table public.recv_cases add column if not exists title      text   not null default '';         -- 직접 등록 채권의 대상(업체·사람)
alter table public.recv_cases add column if not exists amount     bigint not null default 0;          -- 직접 등록 채권 금액
alter table public.recv_cases add column if not exists issue_date date;                                -- 직접 등록 채권 발생일
alter table public.recv_cases add column if not exists ledger     jsonb  not null default '[]';       -- 직접 등록 채권 입금내역 [{d,t,add,pay}]
alter table public.recv_logs alter column customer_id drop not null;
