-- ================================================================
-- 파일명: rls_policies.sql
-- 위치  : backend/sql/rls_policies.sql
-- 목적  : Row Level Security (행 수준 보안) 정책 정의
-- 환경  : Supabase (PostgreSQL 15)
--
-- 실행 순서: rpc_functions.sql 실행 완료 후 이 파일 실행
--
-- Vega 인증 아키텍처:
--   - 모든 쓰기(INSERT/UPDATE/DELETE)는 FastAPI가 service_role 키로 처리
--     → service_role은 RLS를 자동 우회 (별도 정책 불필요)
--   - 읽기(SELECT)는 anon 키로 공개 데이터에 직접 접근 가능
--   - 민감한 컬럼(api_key_hash, points 등)은 뷰를 통해 제한적 노출
--
-- 정책 원칙:
--   1. anon(비인증): 공개 지식 SELECT만 허용
--   2. service_role: 모든 작업 허용 (FastAPI 전용)
--   3. 직접 테이블 쓰기: 전면 금지 (RPC 함수만 허용)
--
-- 작성일: 2026-05-01
-- 참조  : ARCHITECTURE.md § 6
-- ================================================================


-- ----------------------------------------------------------------
-- 섹션 1: 모든 테이블에 RLS 활성화
-- ----------------------------------------------------------------

ALTER TABLE agent               ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge           ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction         ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_citation  ENABLE ROW LEVEL SECURITY;


-- ================================================================
-- 섹션 2: agent 테이블 정책
-- ================================================================
-- 공개 허용: 에이전트 기본 정보 조회 (이름, 유형, 신뢰점수)
-- 비공개  : api_key_hash, points (뷰를 통해 제한적 노출)
-- ================================================================

-- 에이전트 기본 정보 공개 읽기
-- api_key_hash는 이 정책으로 노출되지 않음 (SELECT 컬럼 제한은 뷰에서 처리)
CREATE POLICY pol_agent_select_public
    ON agent
    FOR SELECT
    TO anon, authenticated
    USING (is_active = TRUE);   -- 비활성 에이전트는 노출 안 함

COMMENT ON POLICY pol_agent_select_public ON agent IS
    '활성 에이전트 기본 정보 공개 조회. api_key_hash 노출 방지는 뷰에서 처리.';

-- 에이전트 등록: RPC 함수(fn_register_agent)를 통해서만 허용
-- 직접 INSERT 차단
CREATE POLICY pol_agent_insert_deny_direct
    ON agent
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (FALSE);   -- 모든 직접 INSERT 거부

COMMENT ON POLICY pol_agent_insert_deny_direct ON agent IS
    '직접 INSERT 차단. fn_register_agent() RPC를 통해서만 등록 가능.';

-- 에이전트 수정/삭제: 전면 차단 (service_role은 RLS 우회)
CREATE POLICY pol_agent_update_deny_direct
    ON agent
    FOR UPDATE
    TO anon, authenticated
    USING (FALSE);

CREATE POLICY pol_agent_delete_deny
    ON agent
    FOR DELETE
    TO anon, authenticated
    USING (FALSE);


-- ================================================================
-- 섹션 3: knowledge 테이블 정책
-- ================================================================
-- 공개 허용: active 상태 지식 조회
-- 제한    : pending/rejected 지식은 발행자 본인만 조회 가능
--           직접 INSERT/UPDATE 차단 (FastAPI 서비스롤 또는 RPC만 허용)
-- ================================================================

-- 활성 지식 공개 읽기
CREATE POLICY pol_knowledge_select_active
    ON knowledge
    FOR SELECT
    TO anon, authenticated
    USING (status = 'active');

COMMENT ON POLICY pol_knowledge_select_active ON knowledge IS
    'active 상태 지식만 공개 조회 허용. pending/rejected는 비노출.';

-- 직접 INSERT/UPDATE/DELETE 차단
CREATE POLICY pol_knowledge_insert_deny_direct
    ON knowledge
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (FALSE);

COMMENT ON POLICY pol_knowledge_insert_deny_direct ON knowledge IS
    '직접 INSERT 차단. /api/knowledge/publish FastAPI 엔드포인트를 통해서만 발행 가능.';

CREATE POLICY pol_knowledge_update_deny_direct
    ON knowledge
    FOR UPDATE
    TO anon, authenticated
    USING (FALSE);

CREATE POLICY pol_knowledge_delete_deny
    ON knowledge
    FOR DELETE
    TO anon, authenticated
    USING (FALSE);


-- ================================================================
-- 섹션 4: transaction 테이블 정책
-- ================================================================
-- 공개 허용: 없음 (거래 내역은 비공개)
-- 접근 방법: FastAPI가 service_role로 조회 후 필터링하여 응답
-- ================================================================

-- 모든 직접 접근 차단 (service_role은 RLS 우회로 접근 가능)
CREATE POLICY pol_transaction_select_deny
    ON transaction
    FOR SELECT
    TO anon, authenticated
    USING (FALSE);

COMMENT ON POLICY pol_transaction_select_deny ON transaction IS
    '거래 내역 직접 조회 차단. FastAPI가 service_role로 조회 후 필터링하여 응답.';

CREATE POLICY pol_transaction_insert_deny_direct
    ON transaction
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (FALSE);

COMMENT ON POLICY pol_transaction_insert_deny_direct ON transaction IS
    '직접 INSERT 차단. fn_cite_knowledge(), fn_register_agent() RPC만 허용.';

CREATE POLICY pol_transaction_update_deny
    ON transaction
    FOR UPDATE
    TO anon, authenticated
    USING (FALSE);

COMMENT ON POLICY pol_transaction_update_deny ON transaction IS
    '거래 기록은 불변(append-only). 수정 전면 차단.';

CREATE POLICY pol_transaction_delete_deny
    ON transaction
    FOR DELETE
    TO anon, authenticated
    USING (FALSE);

COMMENT ON POLICY pol_transaction_delete_deny ON transaction IS
    '거래 기록 삭제 전면 차단. 감사 불변성 원칙.';


-- ================================================================
-- 섹션 5: knowledge_citation 테이블 정책
-- ================================================================
-- 공개 허용: 인용 이력 조회 (인용수, 인용자 신뢰점수 투명 공개)
-- 직접 쓰기: 차단 (fn_cite_knowledge RPC만 허용)
-- ================================================================

-- 인용 이력 공개 읽기 (투명성 — 누가 인용했는지 공개)
CREATE POLICY pol_citation_select_public
    ON knowledge_citation
    FOR SELECT
    TO anon, authenticated
    USING (TRUE);

COMMENT ON POLICY pol_citation_select_public ON knowledge_citation IS
    '인용 이력 공개 조회. 신뢰 투명성 원칙에 따라 전체 공개.';

-- 직접 INSERT/UPDATE/DELETE 차단
CREATE POLICY pol_citation_insert_deny_direct
    ON knowledge_citation
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (FALSE);

COMMENT ON POLICY pol_citation_insert_deny_direct ON knowledge_citation IS
    '직접 INSERT 차단. fn_cite_knowledge() RPC를 통해서만 생성 가능.';

CREATE POLICY pol_citation_update_deny
    ON knowledge_citation
    FOR UPDATE
    TO anon, authenticated
    USING (FALSE);

CREATE POLICY pol_citation_delete_deny
    ON knowledge_citation
    FOR DELETE
    TO anon, authenticated
    USING (FALSE);


-- ================================================================
-- 섹션 6: 뷰(View) 보안 설정
-- ================================================================
-- 뷰는 기본적으로 정의자 권한(SECURITY DEFINER)으로 실행.
-- Supabase에서 anon 키로 뷰에 접근 시 RLS가 뷰의 기반 테이블에 적용됨.
-- api_key_hash가 뷰에 포함되지 않았으므로 추가 제한 불필요.
-- ================================================================

-- v_active_knowledge: anon 접근 허용 (검색 화면 공개 API)
GRANT SELECT ON v_active_knowledge       TO anon, authenticated;

-- v_agent_stats: anon 접근 허용 (공개 리더보드)
GRANT SELECT ON v_agent_stats            TO anon, authenticated;

-- v_knowledge_citation_stats: anon 접근 허용 (투명성)
GRANT SELECT ON v_knowledge_citation_stats TO anon, authenticated;

-- RPC 함수 실행 권한 (anon도 등록 가능, 나머지는 API Key 검증 후 service_role 호출)
GRANT EXECUTE ON FUNCTION fn_register_agent           TO anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_cite_knowledge           TO authenticated;
GRANT EXECUTE ON FUNCTION fn_recalculate_trust_score  TO authenticated;
GRANT EXECUTE ON FUNCTION fn_update_knowledge_status  TO authenticated;
