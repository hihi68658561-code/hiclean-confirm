-- 1단계-m: 무료체험 종료일
alter table public.contracts add column if not exists trial_end date;
