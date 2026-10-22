-- 1단계-x: 계약 '월마감' 체크 (OK면 당월리스트에서 빠지고 전체리스트로)
alter table public.contracts add column if not exists chk_month text not null default '';
create index if not exists contracts_chk_month_idx on public.contracts(chk_month);
