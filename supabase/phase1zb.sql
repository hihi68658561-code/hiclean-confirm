-- 1단계-zb: 채권관리단계 조정 (phase1za.sql 다음에 실행)
-- 0 당월매출(자동) · 1 정상 · 2 관리 · 3 불량 · 4 법적조치 · 5 추심이관  (+ 회수완료·대손처리)
alter table public.recv_cases drop constraint if exists recv_cases_stage_check;
update public.recv_cases set stage = case when grade in ('관리','불량') then grade when grade = '악성' then '불량' else '정상' end
  where stage in ('정상관리','독촉중','분할약정');
update public.recv_cases set stage = '법적조치' where stage = '내용증명';
alter table public.recv_cases add constraint recv_cases_stage_check
  check (stage in ('정상','관리','불량','법적조치','추심이관','회수완료','대손처리'));
alter table public.recv_cases alter column stage set default '정상';
