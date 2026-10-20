-- 1단계-n: 수금 담당자 이름 직접 입력
alter table public.customers add column if not exists collector_name text not null default '';
