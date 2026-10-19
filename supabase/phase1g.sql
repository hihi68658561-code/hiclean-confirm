-- 1단계-g: 계약을 '구분'과 '진행단계' 두 가지로 나눔
-- 구분: 구매, 무료체험, 무상증정, 무상임대, 경품
-- 진행단계: 미정, 보류, 확정, 철거, 취소, 완료, 미수
alter table public.contracts add column if not exists contract_type text not null default '구매';
alter table public.contracts drop constraint if exists contracts_stage_check;
alter table public.contracts drop constraint if exists contracts_contract_type_check;
-- 예전에 진행단계로 넣었던 무료체험·무상임대·경품·무상증정은 구분으로 옮기고 진행단계는 '확정'으로
update public.contracts set contract_type = stage, stage = '확정' where stage in ('무료체험','무상임대','경품','무상증정');
alter table public.contracts add constraint contracts_contract_type_check check (contract_type in ('구매','무료체험','무상증정','무상임대','경품'));
alter table public.contracts add constraint contracts_stage_check check (stage in ('미정','보류','확정','철거','취소','완료','미수'));
