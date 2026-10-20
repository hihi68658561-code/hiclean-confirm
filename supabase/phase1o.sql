-- 1단계-o: 고객 관리등급 (레드=주의, 블랙=거래 중지)
-- 기사 계정에는 보이지 않도록 고객 표와 따로 둡니다. 지정·해제는 사무실·관리자만.
-- grade: 레드 / 블랙 / 정상(미수 60일 자동 레드를 붙이지 않음). 행이 없으면 '자동'.
create table if not exists public.customer_grades (
  customer_id uuid primary key references public.customers(id) on delete cascade,
  grade       text not null check (grade in ('레드','블랙','정상')),
  reason      text not null default '',
  set_at      timestamptz not null default now(),
  set_by      uuid default auth.uid()
);
alter table public.customer_grades enable row level security;
drop policy if exists cg_select on public.customer_grades;
drop policy if exists cg_write on public.customer_grades;
create policy cg_select on public.customer_grades for select to authenticated
  using (public.my_role() <> 'tech' and public.can_see_customer(customer_id));
create policy cg_write on public.customer_grades for all to authenticated
  using (public.is_office()) with check (public.is_office());
revoke all on public.customer_grades from anon;
grant select, insert, update, delete on public.customer_grades to authenticated;
