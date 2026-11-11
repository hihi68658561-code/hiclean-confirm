-- 1단계-zu: 기사 화면·확인서에 계약의 제품·시리얼·신청일자가 나오게 (phase1zt.sql 다음에 실행)
-- 기사 계정은 계약을 볼 수 없어서, 설치·철거 작업에 그 계약의 제품·규격·옵션·시리얼·계약일자·수압식 여부를 복사해 둡니다.
-- 계약을 고치면 연결된 설치·철거 작업에도 자동으로 반영됩니다.
create or replace function public.ctr_job_product(k public.contracts) returns jsonb language sql immutable as $$
  select jsonb_build_object('product', coalesce(k.product,''), 'size', coalesce(k.size,''), 'options', coalesce(k.options,''),
                            'serial', coalesce(k.serial,''), 'cdate', k.contract_date, 'wash', coalesce(k.wash_added,false),
                            'ctype', coalesce(k.contract_type,''))
$$;

-- 계약이 바뀌면 → 연결된 설치·철거 작업의 제품 정보 갱신
create or replace function public.ctr_sync_job_product() returns trigger language plpgsql security definer set search_path = public as $$
declare v jsonb := public.ctr_job_product(new);
begin
  update public.jobs j set product = coalesce(j.product,'{}'::jsonb) || v
   where j.contract_id = new.id and j.kind in ('install','remove')
     and (coalesce(j.product,'{}'::jsonb) || v) is distinct from j.product;
  return new;
end $$;
drop trigger if exists contracts_sync_job_product on public.contracts;
create trigger contracts_sync_job_product after insert or update of product, size, options, serial, contract_date, wash_added, contract_type
  on public.contracts for each row execute function public.ctr_sync_job_product();

-- 설치·철거 작업을 만들거나 다른 계약에 연결하면 → 그 계약의 제품 정보 채우기
create or replace function public.job_fill_ctr_product() returns trigger language plpgsql security definer set search_path = public as $$
declare k public.contracts;
begin
  if new.kind in ('install','remove') and new.contract_id is not null then
    select * into k from public.contracts where id = new.contract_id;
    if found then new.product := coalesce(new.product,'{}'::jsonb) || public.ctr_job_product(k); end if;
  end if;
  return new;
end $$;
drop trigger if exists jobs_fill_ctr_product on public.jobs;
create trigger jobs_fill_ctr_product before insert or update of contract_id, kind on public.jobs
  for each row execute function public.job_fill_ctr_product();

-- 지금 있는 설치·철거 작업에 한 번 채워 넣기
update public.jobs j set product = coalesce(j.product,'{}'::jsonb) || public.ctr_job_product(k)
  from public.contracts k
 where k.id = j.contract_id and j.kind in ('install','remove')
   and (coalesce(j.product,'{}'::jsonb) || public.ctr_job_product(k)) is distinct from j.product;
