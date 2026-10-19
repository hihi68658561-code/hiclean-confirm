-- 1단계-f: 계약 진행단계에 무료체험·무상임대·경품·철거·무상증정 추가
alter table public.contracts drop constraint if exists contracts_stage_check;
alter table public.contracts add constraint contracts_stage_check check (stage in ('미정','보류','확정','미수','완료','취소','무료체험','무상임대','경품','철거','무상증정'));
