-- 1단계-w: 영업·기사 계정 불러오기 시간 초과 해결
-- '내가 볼 수 있는 고객 목록'을 질의마다 한 번만 계산해서 권한 검사에 씁니다. (볼 수 있는 범위는 그대로)
-- phase1v.sql을 실행하지 않았어도 이 파일만 실행하면 됩니다.

-- 내가 담당·수금이거나, 내가 배정된 작업이 있는 고객
create or replace function public.my_customer_ids() returns setof uuid
language sql stable security definer set search_path = public as $$
  select x.id from public.customers x
   where (select public.is_staff()) and (x.owner = (select auth.uid()) or x.collector = (select auth.uid()))
  union
  select j.customer_id from public.jobs j
   where (select public.is_staff()) and (select auth.uid()) = any(j.techs)
$$;

drop policy if exists cust_select on public.customers;
create policy cust_select on public.customers for select to authenticated
  using ((select public.is_office()) or id in (select public.my_customer_ids()));

drop policy if exists ctr_select on public.contracts;
create policy ctr_select on public.contracts for select to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())));

drop policy if exists job_select on public.jobs;
create policy job_select on public.jobs for select to authenticated
  using ((select public.is_office()) or (select public.my_role()) = 'tech' or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())));

drop policy if exists pay_select on public.payments;
create policy pay_select on public.payments for select to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())));

drop policy if exists cf_select on public.customer_files;
create policy cf_select on public.customer_files for select to authenticated
  using (((select public.is_office()) or customer_id in (select public.my_customer_ids())) and ((select public.my_role()) <> 'tech' or kind <> '계약서'));

drop policy if exists cg_select on public.customer_grades;
create policy cg_select on public.customer_grades for select to authenticated
  using ((select public.my_role()) <> 'tech' and ((select public.is_office()) or customer_id in (select public.my_customer_ids())));

drop policy if exists sn_select on public.schedule_notes;
create policy sn_select on public.schedule_notes for select to authenticated using ((select public.is_staff()));

-- 색인
create index if not exists jobs_techs_gin on public.jobs using gin (techs);
create index if not exists contracts_customer_idx on public.contracts(customer_id);
create index if not exists payments_contract_idx on public.payments(contract_id);
create index if not exists payments_customer_idx on public.payments(customer_id);
create index if not exists customers_owner_idx on public.customers(owner);
create index if not exists customers_collector_idx on public.customers(collector);
create index if not exists jobs_contract_idx on public.jobs(contract_id);
create index if not exists jobs_updated_idx on public.jobs(updated_at);
create index if not exists contracts_updated_idx on public.contracts(updated_at);
create index if not exists customers_updated_idx on public.customers(updated_at);
