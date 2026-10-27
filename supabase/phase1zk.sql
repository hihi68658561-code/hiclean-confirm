-- 1단계-zk: A/S 세제 구매 수량·금액 (phase1zj.sql 다음에 실행)
alter table public.jobs add column if not exists det_qty integer not null default 0;   -- 세제 수량(통)
alter table public.jobs add column if not exists det_fee integer not null default 0;   -- 세제 금액
