-- 1단계-e: 작업 구분에 철거·추가설치 추가
-- install(설치), as(A/S), remove(철거), addon(추가설치)
alter table public.jobs drop constraint if exists jobs_kind_check;
alter table public.jobs add constraint jobs_kind_check check (kind in ('install','as','remove','addon'));
