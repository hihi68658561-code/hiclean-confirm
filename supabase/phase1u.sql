-- 1단계-u: 제품 양도 (기존 고객의 제품을 다른 사업자에게 넘김)
-- 양도받은 고객에게 구분 '양도'인 계약(0원)이 생기고, 원래 계약을 transfer_from으로 가리킵니다.
alter table public.contracts add column if not exists transfer_from uuid references public.contracts(id) on delete set null;
alter table public.contracts drop constraint if exists contracts_contract_type_check;
alter table public.contracts add constraint contracts_contract_type_check check (contract_type in ('구매','무료체험','무상증정','무상임대','경품','양도'));
