-- 1단계-t: 작업 구분에 '이전설치'(move) 추가
alter table public.jobs drop constraint if exists jobs_kind_check;
alter table public.jobs add constraint jobs_kind_check check (kind in ('install','as','remove','addon','move'));
