-- 1단계-r: 일정표 (설치팀 업무일정표)
-- 작업 종료 시간, 그리고 날짜별 메모(연차·반차·차량 배정 후 출발·대체공휴일 등)
alter table public.jobs add column if not exists end_time text not null default '';

create table if not exists public.schedule_notes (
  id         uuid primary key default gen_random_uuid(),
  day        date not null,
  user_id    uuid references public.staff(user_id) on delete cascade,  -- 비어 있으면 그날 전체 '참조' 메모
  time_text  text not null default '',
  note       text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid()
);
create index if not exists schedule_notes_day_idx on public.schedule_notes(day);
alter table public.schedule_notes enable row level security;
drop policy if exists sn_select on public.schedule_notes;
drop policy if exists sn_write on public.schedule_notes;
create policy sn_select on public.schedule_notes for select to authenticated using (public.is_staff());
create policy sn_write on public.schedule_notes for all to authenticated using (public.is_office()) with check (public.is_office());
revoke all on public.schedule_notes from anon;
grant select, insert, update, delete on public.schedule_notes to authenticated;
