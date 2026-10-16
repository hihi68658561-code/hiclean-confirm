-- 1단계 보완: A/S 비용 납부 상태와 결제수단
-- Supabase 'SQL Editor'에 붙여넣고 'Run'. 여러 번 실행해도 안전합니다.
alter table public.jobs add column if not exists pay_status text not null default '';
alter table public.jobs add column if not exists pay_method text not null default '';
alter table public.jobs drop constraint if exists jobs_pay_status_check;
alter table public.jobs add constraint jobs_pay_status_check check (pay_status in ('','완료','미수'));
alter table public.jobs drop constraint if exists jobs_pay_method_check;
alter table public.jobs add constraint jobs_pay_method_check check (pay_method in ('','카드','현금','입금'));
