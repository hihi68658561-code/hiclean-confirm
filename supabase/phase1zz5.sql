-- 1단계-zz5: A/S 항목(분석용 분류) 칸 (phase1zz4.sql 다음에 실행)
alter table public.jobs add column if not exists as_item text not null default '';
