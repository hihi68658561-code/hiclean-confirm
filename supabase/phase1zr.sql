-- 1단계-zr: A/S·추가설치 입금 내역 (phase1zq.sql 다음에 실행)
-- A/S 한 건에 입금을 여러 번 나눠 적을 수 있습니다 (일부 입금 + 미수, 카드 + 현금 나눠 결제).
-- 납부 여부·청구방법·입금일·카드사(입금자)는 화면에서 이 내역으로 자동 계산해 A/S 건에 적습니다.

create table if not exists public.job_payments (
  id          uuid primary key default gen_random_uuid(),
  job_id      uuid not null references public.jobs(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete cascade,
  pay_date    date,
  method      text not null default '현금' check (method in ('카드','현금','계좌이체','승인취소')),
  payer       text not null default '',   -- 카드사 / 입금자명
  amount      bigint not null default 0,  -- 승인취소는 음수
  memo        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid default auth.uid()
);
create index if not exists job_payments_job_idx on public.job_payments(job_id);
create index if not exists job_payments_upd_idx on public.job_payments(updated_at);

-- 청구방법에 '카드+현금' 허용 (카드와 현금으로 나눠 받은 건)
alter table public.jobs drop constraint if exists jobs_pay_method_check;
alter table public.jobs add constraint jobs_pay_method_check check (pay_method in ('','카드','현금','입금','카드+현금'));

-- 권한: 그 A/S 건을 볼 수 있으면 조회, 고칠 수 있으면(사무실·관리자, 배정된 기사) 입력·수정·삭제
alter table public.job_payments enable row level security;
drop policy if exists jp_select on public.job_payments;
drop policy if exists jp_insert on public.job_payments;
drop policy if exists jp_update on public.job_payments;
drop policy if exists jp_delete on public.job_payments;
create policy jp_select on public.job_payments for select to authenticated
  using (exists (select 1 from public.jobs j where j.id = job_id));
create policy jp_insert on public.job_payments for insert to authenticated
  with check ((select public.is_office()) or exists (select 1 from public.jobs j where j.id = job_id and auth.uid() = any(j.techs)));
create policy jp_update on public.job_payments for update to authenticated
  using ((select public.is_office()) or exists (select 1 from public.jobs j where j.id = job_id and auth.uid() = any(j.techs)))
  with check ((select public.is_office()) or exists (select 1 from public.jobs j where j.id = job_id and auth.uid() = any(j.techs)));
create policy jp_delete on public.job_payments for delete to authenticated
  using ((select public.is_office()) or exists (select 1 from public.jobs j where j.id = job_id and auth.uid() = any(j.techs)));
revoke all on public.job_payments from anon;
grant select, insert, update, delete on public.job_payments to authenticated;

drop trigger if exists job_payments_touch on public.job_payments;
create trigger job_payments_touch before update on public.job_payments for each row execute function public.touch_updated();
