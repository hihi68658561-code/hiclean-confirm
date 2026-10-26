-- 1단계-zf: 싱크대 발주 ↔ 설치 작업 연동 (phase1ze.sql 다음에 실행)
-- 계약에 연결된 발주를 저장하면, 그 계약의 설치 작업 '싱크대 발주' 상태와 '싱크대 메모'(품명 및 규격)를 자동으로 맞춥니다.
alter table public.sink_orders add column if not exists spec_text text not null default '';   -- 품명 및 규격 (화면에서 만들어 저장)

create or replace function public.sink_sync_job() returns trigger
language plpgsql security definer set search_path = public as $$
declare st text;
begin
  if new.contract_id is null then return new; end if;
  st := case when new.status = '신규접수' then '발주대기'
             when new.status in ('주문완료','입고완료','출고완료') then '발주완료'
             else null end;
  update public.jobs j
     set sink_status = coalesce(case when coalesce(j.sink_status,'') in ('','해당없음','발주대기','발주완료') then st end, j.sink_status),
         sink_memo   = case when new.status = '취소' then j.sink_memo else new.spec_text end
   where j.contract_id = new.contract_id and j.kind = 'install' and j.status <> '취소';
  return new;
end $$;
drop trigger if exists sink_orders_sync on public.sink_orders;
create trigger sink_orders_sync after insert or update on public.sink_orders for each row execute function public.sink_sync_job();
