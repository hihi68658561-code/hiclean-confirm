-- 1단계-k: 설치·철거·A/S 접수건별 사진 (phase1j.sql 먼저 실행)
alter table public.customer_files add column if not exists job_id uuid references public.jobs(id) on delete set null;
create index if not exists customer_files_job_idx on public.customer_files(job_id);
alter table public.customer_files drop constraint if exists customer_files_kind_check;
alter table public.customer_files add constraint customer_files_kind_check
  check (kind in ('계약서','설치사진','철거사진','A/S사진','사업자등록증','기타'));
