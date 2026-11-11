-- 1단계-zt: 전자 확인서 (phase1zs.sql 다음에 실행)
-- 사진·서류 종류에 '확인서'를 추가합니다. 기사 화면에서 작성·서명한 설치확인서 / A/S 확인서 이미지가 이 종류로 저장됩니다.
alter table public.customer_files drop constraint if exists customer_files_kind_check;
alter table public.customer_files add constraint customer_files_kind_check
  check (kind in ('계약서','확인서','설치사진','철거사진','A/S사진','사업자등록증','채권','기타'));
