-- 1단계-zs: 추가설치 건도 월마감 (phase1zr.sql 다음에 실행)
-- 추가설치(작업)에 고객등록·전표마감·매출마감·월마감 칸을 만들고,
-- 이미 월마감된 계약에 딸린 추가설치는 월마감 OK로 맞춰 둡니다 (지금 화면과 똑같이 보이도록).
alter table public.jobs add column if not exists chk_cust  text not null default '';
alter table public.jobs add column if not exists chk_slip  text not null default '';
alter table public.jobs add column if not exists chk_sales text not null default '';
alter table public.jobs add column if not exists chk_month text not null default '';

update public.jobs j set chk_month = 'OK'
 where j.kind = 'addon' and j.chk_month = ''
   and exists (select 1 from public.contracts k where k.id = j.contract_id and k.chk_month = 'OK');
