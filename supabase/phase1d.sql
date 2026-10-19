-- 1단계 보완 3: 설치·A/S 상태에 '보류' 추가
-- Supabase 'SQL Editor'에 붙여넣고 'Run'. 여러 번 실행해도 안전합니다.
alter table public.jobs drop constraint if exists jobs_status_check;
alter table public.jobs add constraint jobs_status_check check (status in ('접수','배정','보류','완료','취소'));
