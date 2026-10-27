-- 1단계-zi: 계약 구분에 '철거' 추가 (phase1zh.sql 다음에 실행)
alter table public.contracts drop constraint if exists contracts_contract_type_check;
alter table public.contracts add constraint contracts_contract_type_check check (contract_type in ('구매','무료체험','무상증정','무상임대','경품','양도','철거'));
