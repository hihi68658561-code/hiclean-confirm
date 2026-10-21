-- 1단계-s: 고객 '검색창내용' (예전 상호·양도 전 업체명·별칭 등, 고객 검색에 함께 걸림)
alter table public.customers add column if not exists search_text text not null default '';
