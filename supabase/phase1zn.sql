-- 1단계-zn: 당월리스트·전체리스트 '소계' (당월마감·익월마감·취소,보류·전기마감) (phase1zm.sql 다음에 실행)
alter table public.contracts add column if not exists settle_tag text not null default '';
