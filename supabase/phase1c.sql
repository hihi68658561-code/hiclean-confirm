-- 1단계 보완 2: A/S 결제 상세 (유상/무상, 입금일, 카드사·입금자명, 입금 메모, 매출마감)
-- Supabase 'SQL Editor'에 붙여넣고 'Run'. 여러 번 실행해도 안전합니다. (phase1b.sql 다음에 실행)
alter table public.jobs add column if not exists paid_type text not null default '';
alter table public.jobs add column if not exists pay_date  date;
alter table public.jobs add column if not exists pay_name  text not null default '';
alter table public.jobs add column if not exists pay_memo  text not null default '';
alter table public.jobs add column if not exists closed    boolean not null default false;
alter table public.jobs drop constraint if exists jobs_paid_type_check;
alter table public.jobs add constraint jobs_paid_type_check check (paid_type in ('','유상','무상'));
