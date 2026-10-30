-- 1단계-zo: 싱크대 발주 → 설치·추가설치 작업 연동을 발주일 기준으로 (phase1zn.sql 다음에 실행)
-- 계약 1건에 나중에 싱크대를 추가로 설치하는 경우, 그 발주는 원래 설치 작업이 아니라
-- 발주일 이후 가장 먼저 하는 '추가설치' 작업의 싱크대 메모·발주 상태로 들어갑니다.
create or replace function public.sink_sync_job() returns trigger
language plpgsql security definer set search_path = public as $$
declare st text; cid uuid; jid uuid;
begin
  cid := new.customer_id;
  if cid is null and new.contract_id is not null then select customer_id into cid from public.contracts where id = new.contract_id; end if;
  if cid is null then return new; end if;
  st := case when new.status = '신규접수' then '발주대기'
             when new.status in ('주문완료','입고완료','출고완료') then '발주완료'
             else null end;
  select j.id into jid from public.jobs j
   where j.customer_id = cid and j.kind in ('install','addon') and j.status <> '취소'
     and (coalesce(j.done_date, j.visit_date) is null or new.order_date is null or coalesce(j.done_date, j.visit_date) >= new.order_date)
   order by coalesce(j.done_date, j.visit_date) nulls last, j.created_at
   limit 1;
  if jid is null then return new; end if;
  update public.jobs j
     set sink_status = coalesce(case when coalesce(j.sink_status,'') in ('','해당없음','발주대기','발주완료') then st end, j.sink_status),
         sink_memo   = case when new.status = '취소' then j.sink_memo else new.spec_text end
   where j.id = jid;
  return new;
end $$;
