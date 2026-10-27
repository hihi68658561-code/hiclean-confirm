-- 1단계-zj: 진행단계에 '철거예정'·'철거완료' 추가, 구분 '철거'는 진행단계 '철거완료'로 (phase1zi.sql 다음, 두 번 실행해도 괜찮음)
alter table public.contracts drop constraint if exists contracts_stage_check;
alter table public.contracts add constraint contracts_stage_check check (stage in ('미정','보류','확정','철거','철거예정','철거완료','취소','완료','미수'));
update public.contracts set contract_type = '구매', stage = '철거완료' where contract_type = '철거';
update public.contracts set stage = '철거완료' where stage = '철거';
