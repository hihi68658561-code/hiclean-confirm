-- 1단계-zw: 철거가 접수되면 계약을 바로 '철거예정'으로 (phase1zv.sql 다음에 실행)
-- 기사가 휴대폰에서 완료 처리해도 계약 진행단계가 바뀌도록 서버에서 맞춥니다.
--  · 설치: 접수→미정, 배정→확정, 보류→보류, 취소→취소 (계약이 미정·확정·보류·취소일 때만)
--  · 설치 완료: 합계금액을 다 받았으면 '완료', 아니면 '미수' (무료체험처럼 아직 금액이 없거나 덜 받은 건은 미수)
--  · 철거 접수·배정·보류: 계약을 '철거예정'으로
--  · 철거 완료: 계약을 '철거완료'로
create or replace function public.job_sync_ctr_stage() returns trigger language plpgsql security definer set search_path = public as $$
declare k public.contracts; ns text; paid numeric;
begin
  if new.contract_id is null or new.kind not in ('install','remove') then return new; end if;
  if tg_op = 'UPDATE' and old.status is not distinct from new.status and old.contract_id is not distinct from new.contract_id then return new; end if;
  select * into k from public.contracts where id = new.contract_id;
  if not found then return new; end if;
  if new.kind = 'remove' then
    if new.status = '완료' and k.stage not in ('철거완료','취소') then update public.contracts set stage = '철거완료' where id = k.id; end if;
    if new.status in ('접수','배정','보류') and k.stage not in ('철거예정','철거완료','철거','취소') then update public.contracts set stage = '철거예정' where id = k.id; end if;
    return new;
  end if;
  if new.status = '완료' then
    if k.stage in ('미정','확정','보류') then
      select coalesce(sum(amount),0) into paid from public.payments where contract_id = k.id;
      ns := case when coalesce(k.amount,0) > 0 and paid >= k.amount then '완료' else '미수' end;
      update public.contracts set stage = ns where id = k.id;
    end if;
  else
    ns := case new.status when '접수' then '미정' when '배정' then '확정' when '보류' then '보류' when '취소' then '취소' end;
    if ns is not null and k.stage in ('미정','확정','보류','취소') and k.stage <> ns then update public.contracts set stage = ns where id = k.id; end if;
  end if;
  return new;
end $$;
drop trigger if exists jobs_sync_ctr_stage on public.jobs;
create trigger jobs_sync_ctr_stage after insert or update of status, contract_id on public.jobs
  for each row execute function public.job_sync_ctr_stage();

-- 이미 접수되어 있는 철거 건도 한 번 맞춤
update public.contracts k set stage = '철거예정'
 where k.stage not in ('철거예정','철거완료','철거','취소')
   and exists (select 1 from public.jobs j where j.contract_id = k.id and j.kind = 'remove' and j.status in ('접수','배정','보류'));
