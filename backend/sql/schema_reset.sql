-- ================================================================
-- 파일명: schema_reset.sql
-- 목적  : Vega 테이블/뷰를 제거한 뒤 schema.sql을 처음부터 적용할 때 사용
--
-- ⚠️  모든 Vega 데이터가 삭제됩니다. 개발/빈 DB에서만 실행하세요.
--
-- 사용 순서:
--   1) 이 파일 전체 실행
--   2) schema.sql 실행
--   3) rpc_functions.sql 실행
--   4) rls_policies.sql 실행
-- ================================================================

-- 뷰(테이블에 의존)
DROP VIEW IF EXISTS v_knowledge_citation_stats CASCADE;
DROP VIEW IF EXISTS v_agent_stats CASCADE;
DROP VIEW IF EXISTS v_active_knowledge CASCADE;

-- 테이블(의존성 역순)
DROP TABLE IF EXISTS knowledge_citation CASCADE;
DROP TABLE IF EXISTS transaction CASCADE;
DROP TABLE IF EXISTS knowledge CASCADE;
DROP TABLE IF EXISTS agent CASCADE;

-- 공통 트리거 함수 (테이블 삭제 후에도 남을 수 있음)
DROP FUNCTION IF EXISTS fn_set_updated_at() CASCADE;

-- pgvector 익스텐션은 유지 (schema.sql에서 IF NOT EXISTS로 재확인)
