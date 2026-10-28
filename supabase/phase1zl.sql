-- 1단계-zl: 작업 구분 '기타'(직접 입력) (phase1zk.sql 다음에 실행)
alter table public.jobs drop constraint if exists jobs_kind_check;
alter table public.jobs add constraint jobs_kind_check check (kind in ('install','as','remove','addon','move','etc'));
alter table public.jobs add column if not exists kind_label text not null default '';   -- 기타일 때 직접 적은 구분 이름
