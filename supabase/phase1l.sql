-- 1단계-l: 고객정보(업체명·주소)를 바꾸면 그 고객의 설치·철거·A/S 접수건에도 자동 반영
create or replace function public.sync_job_customer() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.name is distinct from old.name or new.address is distinct from old.address then
    update public.jobs set customer_name = new.name, address = coalesce(nullif(new.address, ''), address)
     where customer_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists customers_sync_jobs on public.customers;
create trigger customers_sync_jobs after update on public.customers for each row execute function public.sync_job_customer();

-- 지금까지 어긋난 건 한 번에 맞추기
update public.jobs j set customer_name = c.name, address = coalesce(nullif(c.address, ''), j.address)
  from public.customers c where c.id = j.customer_id and (j.customer_name is distinct from c.name or (c.address <> '' and j.address is distinct from c.address));
