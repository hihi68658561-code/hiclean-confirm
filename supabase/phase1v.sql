-- 1단계-v: 불러오기 속도 (권한 검사를 줄마다가 아니라 한 번만)
-- 권한 규칙의 내용은 그대로이고, is_office()·my_role() 같은 확인을 (select ...)로 감싸 질의마다 한 번만 계산합니다.

drop policy if exists cust_select on public.customers;
create policy cust_select on public.customers for select to authenticated
  using ((select public.is_office()) or public.can_see_customer(id));

drop policy if exists ctr_select on public.contracts;
create policy ctr_select on public.contracts for select to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and public.can_see_customer(customer_id)));

drop policy if exists job_select on public.jobs;
create policy job_select on public.jobs for select to authenticated
  using ((select public.is_office()) or (select public.my_role()) = 'tech' or ((select public.my_role()) = 'sales' and public.can_see_customer(customer_id)));

drop policy if exists pay_select on public.payments;
create policy pay_select on public.payments for select to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and public.can_see_customer(customer_id)));

drop policy if exists cf_select on public.customer_files;
create policy cf_select on public.customer_files for select to authenticated
  using (((select public.is_office()) or public.can_see_customer(customer_id)) and ((select public.my_role()) <> 'tech' or kind <> '계약서'));

drop policy if exists cg_select on public.customer_grades;
create policy cg_select on public.customer_grades for select to authenticated
  using ((select public.my_role()) <> 'tech' and ((select public.is_office()) or public.can_see_customer(customer_id)));

drop policy if exists sn_select on public.schedule_notes;
create policy sn_select on public.schedule_notes for select to authenticated using ((select public.is_staff()));

-- 자주 찾는 칸에 색인
create index if not exists contracts_customer_idx on public.contracts(customer_id);
create index if not exists payments_contract_idx on public.payments(contract_id);
create index if not exists payments_customer_idx on public.payments(customer_id);
create index if not exists customers_owner_idx on public.customers(owner);
create index if not exists customers_collector_idx on public.customers(collector);
create index if not exists jobs_contract_idx on public.jobs(contract_id);
create index if not exists jobs_updated_idx on public.jobs(updated_at);
create index if not exists contracts_updated_idx on public.contracts(updated_at);
create index if not exists customers_updated_idx on public.customers(updated_at);
