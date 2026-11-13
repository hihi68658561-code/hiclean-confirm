-- 1단계-zx: 작업을 '취소'로 바꾼 날짜(취소일) 자동 기록 (phase1zw.sql 다음에 실행)
-- 당월 설치·A/S 표에서 '지난달 접수 → 이번 달 취소' 건을 이월접수·취소로 세는 데 씁니다.
-- 이 SQL을 실행하기 전에 이미 취소돼 있던 건은 취소일이 비어 있고, 예전 취소 건으로 봅니다.
alter table public.jobs add column if not exists cancel_date date;

create or replace function public.jobs_set_cancel_date() returns trigger language plpgsql as $$
begin
  if new.status = '취소' then
    if tg_op = 'INSERT' or old.status is distinct from '취소' then
      new.cancel_date := coalesce(new.cancel_date, (now() at time zone 'Asia/Seoul')::date);
    end if;
  else
    new.cancel_date := null;
  end if;
  return new;
end $$;
drop trigger if exists jobs_cancel_date on public.jobs;
create trigger jobs_cancel_date before insert or update on public.jobs
  for each row execute function public.jobs_set_cancel_date();
