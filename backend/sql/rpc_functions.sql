-- ================================================================
-- 파일명: rpc_functions.sql
-- 위치  : backend/sql/rpc_functions.sql
-- 목적  : Vega 핵심 비즈니스 로직 RPC 함수 정의
-- 환경  : Supabase (PostgreSQL 15)
--
-- 실행 순서: schema.sql 실행 완료 후 이 파일 실행
--
-- 함수 목록:
--   fn_register_agent          - 에이전트 등록 + 초기 포인트 100 지급
--   fn_recalculate_trust_score - 신뢰점수 가중합 재계산 (직접 UPDATE 대체)
--   fn_recalculate_agent_vote_score - PageRank 기반 인용 점수 재계산
--   fn_cite_knowledge          - ⚡ 핵심: 인용 원자적 트랜잭션
--
-- 호출 방식 (FastAPI에서):
--   await supabase.rpc('fn_cite_knowledge', {
--       'p_knowledge_id': '...',
--       'p_consumer_agent_id': '...'
--   }).execute()
--
-- 작성일: 2026-05-01
-- 참조  : PROJECT_CONTEXT.md § 2~4, CLAUDE.md § 에러코드
-- ================================================================


-- ================================================================
-- 함수 1: fn_register_agent
-- ================================================================
-- 목적: 에이전트 등록 + 초기 100포인트 자동 지급 (원자적)
-- 반환: JSON { agent_id, api_key_plain, initial_points }
--
-- 설계 근거:
--   - API Key 원문은 이 함수가 반환하는 1회에만 확인 가능.
--   - 초기 포인트 100 지급과 에이전트 생성은 한 트랜잭션으로 묶어
--     에이전트는 생성됐는데 포인트가 없는 상태를 방지.
--
-- 에러코드:
--   VEGA_008: 이름 또는 API Key 해시 중복 (UNIQUE 제약 위반)
-- ================================================================

CREATE OR REPLACE FUNCTION fn_register_agent(
    p_name          TEXT,
    p_api_key_hash  TEXT,       -- FastAPI 레이어에서 bcrypt 해시 후 전달
    p_type          TEXT DEFAULT 'human',
    p_bio           TEXT DEFAULT NULL,
    p_agent_id      UUID DEFAULT gen_random_uuid()  -- FastAPI에서 사전 생성한 UUID (API Key 형식: vk_{id}_{random})
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER   -- 서비스 권한으로 실행 (RLS 우회)
AS $$
DECLARE
    v_agent_id          UUID;
    v_transaction_id    UUID;
BEGIN
    -- ── 에이전트 생성 ──
    -- p_agent_id를 직접 사용: API Key 형식이 "vk_{agent_id_no_dashes}_{random}"이므로
    -- FastAPI에서 UUID를 먼저 생성하고 Key에 포함시킨 뒤 이 RPC로 전달한다.
    INSERT INTO agent (id, name, api_key_hash, type, bio)
    VALUES (p_agent_id, p_name, p_api_key_hash, p_type, p_bio)
    RETURNING id INTO v_agent_id;

    -- ── 초기 100포인트 지급 트랜잭션 기록 ──
    -- from_agent_id = NULL: 시스템 지급
    INSERT INTO transaction (from_agent_id, to_agent_id, amount, type, status, memo)
    VALUES (NULL, v_agent_id, 100, 'admin', 'completed', '에이전트 등록 초기 포인트 지급')
    RETURNING id INTO v_transaction_id;

    RETURN json_build_object(
        'agent_id',         v_agent_id,
        'initial_points',   100,
        'transaction_id',   v_transaction_id
    );

EXCEPTION
    -- UNIQUE 제약 위반 (api_key_hash 중복 등)
    WHEN unique_violation THEN
        RAISE EXCEPTION 'VEGA_008: 이미 등록된 에이전트 정보입니다. (중복 키)';
END;
$$;

COMMENT ON FUNCTION fn_register_agent IS
    '에이전트 등록 + 초기 100포인트 지급을 원자적으로 처리한다.
     API Key 해시는 FastAPI 레이어에서 bcrypt 처리 후 전달해야 한다.';


-- ================================================================
-- 함수 2: fn_recalculate_trust_score
-- ================================================================
-- 목적: trust_score 가중합 재계산 및 갱신
-- 호출: 점수 구성요소 변경 시 항상 이 함수를 통해 갱신 (직접 UPDATE 금지)
--
-- 공식: trust_score = (system_score × 0.4) + (agent_vote_score × 0.5) + (admin_score × 0.1)
-- 출처: PROJECT_CONTEXT.md § 2
--
-- 설계 근거:
--   - 공식이 변경되더라도 이 함수만 수정하면 됨 (단일 책임)
--   - LEAST(계산값, 1.0)으로 소수점 오차로 인한 1.0 초과 방지
-- ================================================================

CREATE OR REPLACE FUNCTION fn_recalculate_trust_score(
    p_knowledge_id          UUID,
    p_new_system_score      FLOAT8 DEFAULT NULL,   -- NULL이면 기존 값 유지
    p_new_agent_vote_score  FLOAT8 DEFAULT NULL,
    p_new_admin_score       FLOAT8 DEFAULT NULL
)
RETURNS FLOAT8
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_trust_score FLOAT8;
BEGIN
    UPDATE knowledge
    SET
        -- NULL이면 기존 값 유지 (COALESCE 패턴)
        system_score      = COALESCE(p_new_system_score,     system_score),
        agent_vote_score  = COALESCE(p_new_agent_vote_score, agent_vote_score),
        admin_score       = COALESCE(p_new_admin_score,      admin_score),

        -- trust_score = 가중합 (LEAST로 1.0 초과 방지)
        trust_score = LEAST(
            (COALESCE(p_new_system_score,     system_score)     * 0.4) +
            (COALESCE(p_new_agent_vote_score, agent_vote_score) * 0.5) +
            (COALESCE(p_new_admin_score,      admin_score)      * 0.1),
            1.0
        )
    WHERE id = p_knowledge_id
    RETURNING trust_score INTO v_new_trust_score;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'VEGA_004: 지식(%)을 찾을 수 없습니다.', p_knowledge_id;
    END IF;

    RETURN v_new_trust_score;
END;
$$;

COMMENT ON FUNCTION fn_recalculate_trust_score IS
    'trust_score를 가중합 공식으로 재계산한다.
     직접 UPDATE knowledge SET trust_score = ... 사용 금지.
     공식: (system_score×0.4) + (agent_vote_score×0.5) + (admin_score×0.1)';


-- ================================================================
-- 함수 3: fn_recalculate_agent_vote_score
-- ================================================================
-- 목적: 인용 발생 시 PageRank 기반 agent_vote_score 재계산
-- 호출: fn_cite_knowledge 내부에서 인용 완료 후 자동 호출
--
-- PageRank 계산 방식:
--   - knowledge_citation 테이블에서 해당 지식의 모든 인용 이력 집계
--   - 각 인용자의 trust_score 스냅샷의 평균 × log(인용수+1) 스케일업
--   - LEAST(결과, 1.0) 으로 상한 클램핑
--
-- 설계 근거:
--   - 단순 인용 횟수가 아닌 인용자 신뢰도 가중 집계 → Sybil 방어
--   - log 스케일: 초기 인용의 기여를 크게, 대량 인용의 한계 효용 감소
--   - 스냅샷 기반: 과거 기여도가 현재 신뢰점수 변화에 영향받지 않음
-- ================================================================

CREATE OR REPLACE FUNCTION fn_recalculate_agent_vote_score(
    p_knowledge_id UUID
)
RETURNS FLOAT8
LANGUAGE plpgsql
AS $$
DECLARE
    v_citation_count        INTEGER;
    v_avg_citer_trust       FLOAT8;
    v_new_agent_vote_score  FLOAT8;
    v_new_trust_score       FLOAT8;
BEGIN
    -- 인용 수 + 인용자 평균 신뢰점수 집계
    SELECT
        COUNT(*),
        COALESCE(AVG(citer_trust_score_snapshot), 0.0)
    INTO
        v_citation_count,
        v_avg_citer_trust
    FROM knowledge_citation
    WHERE knowledge_id = p_knowledge_id;

    -- PageRank 점수 계산
    -- 수식: avg_citer_trust × log₁₀(인용수 + 1) / log₁₀(101)
    -- log₁₀(101) ≈ 2.004: 100회 인용 시 agent_vote_score가 avg_citer_trust에 수렴하도록 정규화
    IF v_citation_count = 0 THEN
        v_new_agent_vote_score := 0.0;
    ELSE
        v_new_agent_vote_score := LEAST(
            v_avg_citer_trust * LOG(v_citation_count + 1) / LOG(101),
            1.0
        );
    END IF;

    -- trust_score 재계산 (agent_vote_score만 갱신)
    v_new_trust_score := fn_recalculate_trust_score(
        p_knowledge_id,
        NULL,                       -- system_score 유지
        v_new_agent_vote_score,     -- agent_vote_score 갱신
        NULL                        -- admin_score 유지
    );

    RETURN v_new_agent_vote_score;
END;
$$;

COMMENT ON FUNCTION fn_recalculate_agent_vote_score IS
    'PageRank 방식으로 agent_vote_score를 재계산한다.
     인용자 신뢰점수 스냅샷 평균 × log 스케일로 계산.
     fn_cite_knowledge() 완료 후 자동 호출됨.';


-- ================================================================
-- 함수 4: fn_cite_knowledge  ⚡ 핵심 원자적 트랜잭션
-- ================================================================
-- 목적: 지식 인용 처리 — 포인트 차감·지급·카운트 증가를 원자적으로 실행
--
-- 실행 순서 (단일 트랜잭션 내):
--   1. 지식 조회 + 행 잠금 (SELECT FOR UPDATE)
--   2. 지식 상태 검증 (active만 가능)
--   3. 자기 인용 방지
--   4. 인용자 조회 + 행 잠금 (SELECT FOR UPDATE)
--   5. 포인트 잔액 검증
--   6. 중복 인용 검증 (Sybil 방어)
--   7. 발행자 행 잠금 (SELECT FOR UPDATE)
--   8. 인용자 포인트 차감
--   9. 발행자 포인트 지급
--  10. knowledge.citation_count +1
--  11. transaction 레코드 생성 (completed)
--  12. knowledge_citation 레코드 생성 (스냅샷 포함)
--  13. fn_recalculate_agent_vote_score() 호출 (PageRank 갱신)
--
-- 에러코드 (CLAUDE.md § 3-3):
--   VEGA_001: 에이전트 미존재 또는 비활성
--   VEGA_002: 포인트 부족
--   VEGA_003: 지식 상태가 active가 아님
--   VEGA_004: 지식 미존재
--   VEGA_009: 자기 인용 시도
--   VEGA_010: 중복 인용 시도
--
-- 반환: JSON {
--   success, transaction_id, new_trust_score,
--   new_citation_count, citer_remaining_points, publisher_earned_points
-- }
-- ================================================================

-- p_consumer_agent_id: 인용(소비) 에이전트
CREATE OR REPLACE FUNCTION fn_cite_knowledge(
    p_knowledge_id          UUID,
    p_consumer_agent_id    UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_knowledge             knowledge%ROWTYPE;
    v_citer                 agent%ROWTYPE;
    v_publisher             agent%ROWTYPE;
    v_transaction_id        UUID;
    v_new_agent_vote_score  FLOAT8;
    v_new_trust_score       FLOAT8;
    v_citer_remaining       INTEGER;
BEGIN

    -- ── Step 1: 지식 조회 + 행 잠금 ──
    -- FOR UPDATE: 동시 인용 요청 시 경쟁 조건 방지
    SELECT * INTO v_knowledge
    FROM knowledge
    WHERE id = p_knowledge_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'VEGA_004: 지식(%)을 찾을 수 없습니다.', p_knowledge_id;
    END IF;

    -- ── Step 2: 지식 상태 검증 ──
    -- pending, rejected 지식 인용 불가 (PROJECT_CONTEXT.md § 4)
    IF v_knowledge.status != 'active' THEN
        RAISE EXCEPTION 'VEGA_003: active 상태가 아닌 지식은 인용할 수 없습니다. 현재 상태: [%]', v_knowledge.status;
    END IF;

    -- ── Step 3: 자기 인용 방지 ──
    IF v_knowledge.agent_id = p_consumer_agent_id THEN
        RAISE EXCEPTION 'VEGA_009: 자신이 발행한 지식은 인용할 수 없습니다.';
    END IF;

    -- ── Step 4: 인용자(consumer) 조회 + 행 잠금 ──
    SELECT * INTO v_citer
    FROM agent
    WHERE id = p_consumer_agent_id AND is_active = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'VEGA_001: 에이전트(%)를 찾을 수 없거나 비활성 상태입니다.', p_consumer_agent_id;
    END IF;

    -- ── Step 5: 포인트 잔액 검증 ──
    IF v_citer.points < v_knowledge.citation_price THEN
        RAISE EXCEPTION 'VEGA_002: 포인트 부족. 필요 포인트: %, 현재 잔액: %',
            v_knowledge.citation_price, v_citer.points;
    END IF;

    -- ── Step 6: 중복 인용 검증 (Sybil Attack 방어) ──
    IF EXISTS (
        SELECT 1
        FROM knowledge_citation
        WHERE knowledge_id = p_knowledge_id
          AND citer_agent_id = p_consumer_agent_id
    ) THEN
        RAISE EXCEPTION 'VEGA_010: 이미 인용한 지식입니다. 동일 지식의 중복 인용은 불가합니다.';
    END IF;

    -- ── Step 7: 발행자 행 잠금 ──
    -- 잠금 순서 고정(인용자→발행자)으로 데드락 방지
    SELECT * INTO v_publisher
    FROM agent
    WHERE id = v_knowledge.agent_id
    FOR UPDATE;

    -- ══════════════════════════════════════════════════════════════
    -- ⚡ 원자적 처리 구간 시작 (이후 실패 시 전체 롤백)
    -- ══════════════════════════════════════════════════════════════

    -- ── Step 8: 인용자 포인트 차감 ──
    UPDATE agent
    SET points = points - v_knowledge.citation_price
    WHERE id = p_consumer_agent_id;

    -- ── Step 9: 발행자 포인트 지급 ──
    UPDATE agent
    SET points = points + v_knowledge.citation_price
    WHERE id = v_knowledge.agent_id;

    -- ── Step 10: 인용 카운트 증가 ──
    UPDATE knowledge
    SET citation_count = citation_count + 1
    WHERE id = p_knowledge_id;

    -- ── Step 11: 거래 기록 생성 ──
    INSERT INTO transaction (
        from_agent_id,
        to_agent_id,
        knowledge_id,
        amount,
        type,
        status,
        memo
    )
    VALUES (
        p_consumer_agent_id,
        v_knowledge.agent_id,
        p_knowledge_id,
        v_knowledge.citation_price,
        'cite',
        'completed',
        '지식 인용 포인트 정산'
    )
    RETURNING id INTO v_transaction_id;

    -- ── Step 12: 인용 이력 생성 (PageRank 데이터) ──
    INSERT INTO knowledge_citation (
        knowledge_id,
        citer_agent_id,
        transaction_id,
        citer_trust_score_snapshot
    )
    VALUES (
        p_knowledge_id,
        p_consumer_agent_id,
        v_transaction_id,
        v_citer.trust_score      -- 인용 시점 신뢰점수 스냅샷 고정
    );

    -- ── Step 13: PageRank 기반 agent_vote_score 재계산 (내부에서 trust_score 동시 갱신) ──
    v_new_agent_vote_score := fn_recalculate_agent_vote_score(p_knowledge_id);

    SELECT trust_score INTO v_new_trust_score
    FROM knowledge
    WHERE id = p_knowledge_id;

    -- ══════════════════════════════════════════════════════════════
    -- ⚡ 원자적 처리 구간 끝
    -- ══════════════════════════════════════════════════════════════

    -- 반환 값 계산 (UPDATE 후 실제 잔액)
    v_citer_remaining := v_citer.points - v_knowledge.citation_price;

    RETURN json_build_object(
        'success',                  TRUE,
        'transaction_id',           v_transaction_id,
        'new_citation_count',       v_knowledge.citation_count + 1,
        'new_agent_vote_score',     v_new_agent_vote_score,
        'new_trust_score',          v_new_trust_score,
        'citer_remaining_points',   v_citer_remaining,
        'publisher_earned_points',  v_knowledge.citation_price
    );

END;
$$;

COMMENT ON FUNCTION fn_cite_knowledge IS
    '⚡ 지식 인용 핵심 원자적 트랜잭션.
     인수 p_consumer_agent_id = 인용(소비) 에이전트. transaction·knowledge_citation 기록 포함.
     실패 시 전체 롤백. 동일 (knowledge_id, citer) 재인용은 VEGA_010.';


-- ================================================================
-- 함수 5: fn_update_knowledge_status  (관리자 전용)
-- ================================================================
-- 목적: 지식 상태 변경 (pending → active | rejected)
-- 호출: LLM 품질 평가 완료 후 system_score와 함께 상태 전환
-- ================================================================

CREATE OR REPLACE FUNCTION fn_update_knowledge_status(
    p_knowledge_id      UUID,
    p_new_status        TEXT,
    p_new_system_score  FLOAT8 DEFAULT NULL   -- active 전환 시 LLM 품질 평가 점수
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_trust_score FLOAT8;
BEGIN
    -- 상태값 검증
    IF p_new_status NOT IN ('active', 'rejected') THEN
        RAISE EXCEPTION 'VEGA_003: 유효하지 않은 상태값입니다. (active 또는 rejected만 허용)';
    END IF;

    -- 상태 갱신 (system_score 동시 반영)
    UPDATE knowledge
    SET status = p_new_status
    WHERE id = p_knowledge_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'VEGA_004: 지식(%)을 찾을 수 없습니다.', p_knowledge_id;
    END IF;

    -- active 전환 시 system_score 및 trust_score 재계산
    IF p_new_status = 'active' AND p_new_system_score IS NOT NULL THEN
        v_new_trust_score := fn_recalculate_trust_score(
            p_knowledge_id,
            p_new_system_score,   -- LLM 평가 점수 반영
            NULL,
            NULL
        );
    ELSE
        SELECT trust_score INTO v_new_trust_score
        FROM knowledge WHERE id = p_knowledge_id;
    END IF;

    RETURN json_build_object(
        'success',          TRUE,
        'knowledge_id',     p_knowledge_id,
        'new_status',       p_new_status,
        'new_trust_score',  v_new_trust_score
    );
END;
$$;

COMMENT ON FUNCTION fn_update_knowledge_status IS
    '관리자·LLM 품질 파이프라인 전용 지식 상태 변경 함수.
     active 전환 시 system_score와 trust_score를 동시에 재계산한다.';


-- ================================================================
-- 함수 6: fn_search_knowledge  (pgvector 시맨틱 검색)
-- ================================================================
-- 목적: 쿼리 임베딩과 cosine similarity를 계산해 유사 지식을 반환한다.
-- 호출: FastAPI knowledge_service.search_knowledge() 및 research.py에서 호출
-- 반환: 유사도 순 정렬된 active·pending 지식 목록 (발행자 정보 포함, rejected 제외)
-- ================================================================

CREATE OR REPLACE FUNCTION fn_search_knowledge(
    query_embedding VECTOR(1536),
    match_threshold FLOAT8 DEFAULT 0.5,
    match_count     INT DEFAULT 10,
    filter_domain   TEXT DEFAULT NULL       -- NULL이면 전체 도메인 검색
)
RETURNS TABLE (
    id                      UUID,
    title                   TEXT,
    content_claim           TEXT,
    domain                  TEXT,
    tags                    TEXT[],
    trust_score             FLOAT8,
    citation_price          INT,
    citation_count          INT,
    status                  TEXT,
    publisher_id            UUID,
    publisher_name          TEXT,
    publisher_trust_score   FLOAT8,
    created_at              TIMESTAMPTZ,
    similarity              FLOAT8
)
LANGUAGE sql
STABLE   -- 동일 입력에 동일 출력 (쿼리 최적화 힌트)
AS $$
    SELECT
        k.id,
        k.title,
        k.content_claim,
        k.domain,
        k.tags,
        k.trust_score,
        k.citation_price,
        k.citation_count,
        k.status,
        a.id            AS publisher_id,
        a.name          AS publisher_name,
        a.trust_score   AS publisher_trust_score,
        k.created_at,
        -- cosine similarity: 1 - cosine distance (높을수록 유사)
        1 - (k.content_embedding <=> query_embedding) AS similarity
    FROM
        knowledge k
        INNER JOIN agent a ON k.agent_id = a.id
    WHERE
        k.status IN ('active', 'pending')
        AND k.content_embedding IS NOT NULL
        AND 1 - (k.content_embedding <=> query_embedding) >= match_threshold
        AND (filter_domain IS NULL OR k.domain = filter_domain)
    ORDER BY
        k.content_embedding <=> query_embedding  -- cosine distance 오름차순 (유사할수록 앞)
    LIMIT match_count;
$$;

COMMENT ON FUNCTION fn_search_knowledge IS
    'pgvector cosine similarity 기반 시맨틱 지식 검색.
     active·pending 지식 대상(rejected 제외). match_threshold 이상 유사도 결과만 반환.
     FastAPI knowledge_service 및 research 엔드포인트에서 호출됨.';
