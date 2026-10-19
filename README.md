# 하이클린 업무관리

고객·계약·설치/A/S를 관리하고, 설치확인서와 A/S 확인서를 고객정보가 채워진 상태로 인쇄하는 웹 프로그램입니다.

- 접속: https://hihi68658561-code.github.io/hiclean-confirm/
- 데이터: Supabase(서울). 등록된 직원만 로그인할 수 있고, 역할(관리자·사무실·영업·설치/A/S 기사)에 따라 볼 수 있는 고객이 데이터베이스에서 제한됩니다.
- 설정 순서: `supabase/setup.sql` → `supabase/first_admin.sql` → `supabase/phase1.sql` → `supabase/phase1b.sql` → `supabase/phase1c.sql` → `supabase/phase1d → phase1e.sql`
- 이 저장소에는 고객 정보가 들어 있지 않습니다. 페이지의 Supabase 공개용 키(publishable)는 로그인과 행 단위 권한 규칙으로 보호됩니다.
