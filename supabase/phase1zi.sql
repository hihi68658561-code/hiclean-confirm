-- 1단계-zi: 계약 '철거'를 진행단계에서 구분으로 옮김 (phase1zh.sql 다음에 실행, 두 번 실행해도 괜찮음)
alter table public.contracts drop constraint if exists contracts_contract_type_check;
alter table public.contracts add constraint contracts_contract_type_check check (contract_type in ('구매','무료체험','무상증정','무상임대','경품','양도','철거'));
-- 진행단계가 '철거'였던 계약 → 구분 '철거', 진행단계 '완료'
update public.contracts set contract_type = '철거', stage = '완료' where stage = '철거';
