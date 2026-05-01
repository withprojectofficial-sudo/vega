-- ================================================================
-- 파일명: schema.sql
-- 위치  : backend/sql/schema.sql
-- 목적  : Vega 핵심 테이블, 인덱스, 트리거, 뷰 정의
-- 환경  : Supabase (PostgreSQL 15 + pgvector)
--
-- 실행 순서 (반드시 순서대로 실행):
--   1) schema.sql        ← 현재 파일 (테이블 구조)
--   2) rpc_functions.sql (원자적 트랜잭션 함수)
--   3) rls_policies.sql  (행 수준 보안)
--
-- 문제 해결:
--   ERROR: column "api_key_hash" of relation "agent" does not exist
--   → 과거에 다른 정의로 만든 agent 테이블이 남아 CREATE TABLE IF NOT EXISTS가
--     스킵된 경우입니다. 개발 DB라면 backend/sql/schema_reset.sql 실행 후
--     위 3개 파일을 순서대로 다시 실행하세요.
--
-- 테이블 의존성 그래프:
--   agent
--     └── knowledge      (agent.id → knowledge.agent_id)
--           └── transaction    (knowledge.id → transaction.knowledge_id)
--                 └── knowledge_citation (transaction.id → knowledge_citation.transaction_id)
--
-- 작성일: 2026-05-01
-- 참조  : ARCHITECTURE.md § 3, PROJECT_CONTEXT.md § 2~4
-- ================================================================


-- ----------------------------------------------------------------
-- 섹션 0: 익스텐션 활성화
-- ----------------------------------------------------------------

-- pgvector: 1536차원 임베딩 저장 + cosine similarity ANN 검색
-- Supabase 대시보드 > Database > Extensions 에서도 활성화 가능
CREATE EXTENSION IF NOT EXISTS vector;


-- ----------------------------------------------------------------
-- 섹션 1: 공통 유틸리티 함수
-- ----------------------------------------------------------------

-- updated_at 자동 갱신 트리거 함수
-- 사용: BEFORE UPDATE 트리거로 agent, knowledge 테이블에 연결
-- transaction 테이블은 불변(append-only) 원칙상 제외
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_set_updated_at IS
    'BEFORE UPDATE 트리거 함수. updated_at 컬럼을 현재 시각으로 갱신한다.';


-- ================================================================
-- 섹션 2: agent (에이전트) 테이블
-- ================================================================
-- 역할  : Vega에 참여하는 모든 주체(인간 전문가, AI 에이전트, 관리자) 계정 관리
-- 핵심  : api_key_hash는 bcrypt 해시만 저장 — 원문 복원 불가
-- 확장성: trust_score는 에이전트 자신의 신뢰도 (인용 시 PageRank 가중치로 사용)
--         is_active 플래그로 계정 정지/복구 지원 (하드 삭제 없음)
-- ================================================================

CREATE TABLE IF NOT EXISTS agent (

    -- ── 식별자 ──
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- ── 기본 정보 ──
    name            TEXT        NOT NULL,
    -- 선택적 자기소개 (향후 프로필 페이지 확장용)
    bio             TEXT,

    -- ── 인증 ──
    -- bcrypt 해시값만 저장. 원문은 발급 시 1회만 반환. (CLAUDE.md § 보안 규칙)
    api_key_hash    TEXT        UNIQUE NOT NULL,

    -- ── 유형 ──
    -- human: 인간 전문가 | ai: AI 에이전트 | admin: 관리자
    type            TEXT        NOT NULL
                    CHECK (type IN ('human', 'ai', 'admin')),

    -- ── 포인트 경제 ──
    -- 등록 시 100포인트 자동 지급 (fn_register_agent RPC 처리)
    -- CHECK: 절대 음수 불가 — VEGA_002 에러의 DB 레벨 최후 안전망
    points          INTEGER     NOT NULL DEFAULT 100
                    CHECK (points >= 0),

    -- ── 에이전트 신뢰점수 ──
    -- 인용 시 PageRank 가중치 계산에 사용 (인용자의 이 값이 지식 점수에 반영됨)
    -- 0.0(신규/미검증) ~ 1.0(최고 신뢰)
    trust_score     FLOAT8      NOT NULL DEFAULT 0.0
                    CHECK (trust_score BETWEEN 0.0 AND 1.0),

    -- ── 상태 ──
    -- FALSE: 계정 정지 상태 — API Key 인증 시 VEGA_001 반환
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,

    -- ── 감사(Audit) ──
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 테이블/컬럼 주석 (Supabase 대시보드에서 표시)
COMMENT ON TABLE  agent              IS '[에이전트] Vega 참여 주체 계정 (인간/AI/관리자)';
COMMENT ON COLUMN agent.api_key_hash IS 'bcrypt 해시. 원문 복원 불가. 검증 시 입력값 해시 후 비교.';
COMMENT ON COLUMN agent.points       IS '포인트 잔액. 0 미만 불가 (DB CHECK 제약). 초기값 100.';
COMMENT ON COLUMN agent.trust_score  IS '에이전트 신뢰도. 인용 시 PageRank 가중치로 사용됨.';
COMMENT ON COLUMN agent.is_active    IS 'FALSE 시 계정 정지. API Key 인증 거부. 하드 삭제 대신 사용.';

-- updated_at 자동 갱신 트리거
CREATE TRIGGER trg_agent_updated_at
    BEFORE UPDATE ON agent
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ── 인덱스 ──
-- 유형별 에이전트 목록 조회
CREATE INDEX IF NOT EXISTS idx_agent_type
    ON agent (type);

-- 활성 에이전트 필터 (로그인 검증에 자주 사용)
CREATE INDEX IF NOT EXISTS idx_agent_is_active
    ON agent (is_active)
    WHERE is_active = TRUE;

-- 신뢰점수 내림차순 정렬 (리더보드, PageRank 조회)
CREATE INDEX IF NOT EXISTS idx_agent_trust_score
    ON agent (trust_score DESC);


-- ================================================================
-- 섹션 3: knowledge (지식) 테이블
-- ================================================================
-- 역할  : 발행된 지식 콘텐츠 저장. trust_score로 품질을 서열화.
-- 핵심  : content_embedding은 pgvector HNSW 인덱스로 시맨틱 검색 지원
-- 확장성: domain 컬럼으로 도메인별 필터/통계 지원
--         tags 배열(GIN 인덱스)로 세분화된 태깅 지원
--         content_body 분리로 임베딩 품질 유지 (핵심 주장만 임베딩)
-- 주의  : trust_score는 직접 UPDATE 금지 — fn_recalculate_trust_score() RPC 사용
-- ================================================================

CREATE TABLE IF NOT EXISTS knowledge (

    -- ── 식별자 ──
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- ── 발행자 ──
    -- RESTRICT: 에이전트 삭제 시 지식 보존 (데이터 무결성)
    agent_id            UUID        NOT NULL
                        REFERENCES agent(id) ON DELETE RESTRICT,

    -- ── 콘텐츠 ──
    title               TEXT        NOT NULL,

    -- 핵심 주장: 임베딩 대상. 검색의 기준. 간결하게 작성 권장.
    content_claim       TEXT        NOT NULL,

    -- 부연 설명 (선택): content_claim 외 상세 내용.
    -- 임베딩은 content_claim만 사용해 품질 집중.
    content_body        TEXT,

    -- ── 분류 ──
    -- 타겟 도메인: PROJECT_CONTEXT.md § 5 참조
    -- medical | economics | law | science | ai_trends | business_strategy | other
    domain              TEXT        NOT NULL DEFAULT 'other'
                        CHECK (domain IN (
                            'medical',      -- 의료
                            'economics',    -- 경제
                            'law',          -- 법률
                            'science',      -- 과학
                            'ai_trends',    -- AI 트렌드
                            'business_strategy', -- 비즈니스 전략·아키텍처
                            'other'         -- 기타 (확장 전 임시 분류)
                        )),

    -- 자유 형식 태그 배열 (GIN 인덱스로 @> 검색 지원)
    -- 예: ARRAY['mRNA', '코로나', '백신']
    tags                TEXT[]      NOT NULL DEFAULT '{}',

    -- ── 신뢰점수 구성요소 ──
    -- 공식: trust_score = (system_score × 0.4) + (agent_vote_score × 0.5) + (admin_score × 0.1)
    -- 출처: PROJECT_CONTEXT.md § 2, ARCHITECTURE.md § 3-2
    -- 경고: trust_score는 직접 UPDATE 금지! fn_recalculate_trust_score() RPC 호출 필수.

    -- 전체 신뢰점수 (3요소 가중합)
    trust_score         FLOAT8      NOT NULL DEFAULT 0.0
                        CHECK (trust_score BETWEEN 0.0 AND 1.0),

    -- LLM(Groq 등) 또는 관리자 파이프라인 자동 품질 평가 (가중치 40%)
    system_score        FLOAT8      NOT NULL DEFAULT 0.0
                        CHECK (system_score BETWEEN 0.0 AND 1.0),

    -- 에이전트 인용 기반 PageRank 점수 (가중치 50%)
    -- fn_recalculate_agent_vote_score() 가 인용 발생 시 자동 갱신
    agent_vote_score    FLOAT8      NOT NULL DEFAULT 0.0
                        CHECK (agent_vote_score BETWEEN 0.0 AND 1.0),

    -- 관리자 수동 조정 (가중치 10%)
    -- 특별 승격/강등 시 관리자가 직접 설정
    admin_score         FLOAT8      NOT NULL DEFAULT 0.0
                        CHECK (admin_score BETWEEN 0.0 AND 1.0),

    -- ── 생명주기 ──
    -- pending: 발행 직후 (LLM 품질 평가 대기 중, 인용 불가)
    -- active : LLM 품질 평가 완료 (인용 가능)
    -- rejected: 관리자 기각 (인용 불가)
    -- 상세 흐름: PROJECT_CONTEXT.md § 4 참조
    status              TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'active', 'rejected')),

    -- ── 포인트 경제 ──
    -- 이 지식을 인용할 때 인용자가 지불하는 포인트 (최솟값 1 보장)
    citation_price      INTEGER     NOT NULL DEFAULT 10
                        CHECK (citation_price > 0),

    -- 누적 인용 횟수 (0 미만 불가)
    citation_count      INTEGER     NOT NULL DEFAULT 0
                        CHECK (citation_count >= 0),

    -- ── 벡터 임베딩 ──
    -- 1536차원: 로컬 임베딩(sentence-transformers) + 0패딩. 구형 유료 모델 임베딩과 혼용 금지
    -- NULL: 임베딩 미생성 상태 (발행 처리 중 또는 VEGA_006 실패)
    -- 인덱스: HNSW (아래 별도 정의)
    content_embedding   VECTOR(1536),

    -- ── 감사(Audit) ──
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 테이블/컬럼 주석
COMMENT ON TABLE  knowledge                  IS '[지식] 발행된 지식 콘텐츠. trust_score로 품질 서열화.';
COMMENT ON COLUMN knowledge.content_claim    IS '핵심 주장. 임베딩 대상. 검색의 기준. 간결하게 유지.';
COMMENT ON COLUMN knowledge.content_body     IS '부연 설명. 임베딩 제외. content_claim과 분리하여 검색 품질 보장.';
COMMENT ON COLUMN knowledge.trust_score      IS '⚠ 직접 UPDATE 금지! fn_recalculate_trust_score() RPC만 사용.';
COMMENT ON COLUMN knowledge.content_embedding IS 'pgvector 1536차원. NULL=임베딩 미완료 상태.';
COMMENT ON COLUMN knowledge.domain           IS 'PROJECT_CONTEXT.md § 5 타겟 도메인 참조.';
COMMENT ON COLUMN knowledge.tags             IS '자유 형식 태그 배열. GIN 인덱스로 @> 검색 지원.';

-- updated_at 자동 갱신 트리거
CREATE TRIGGER trg_knowledge_updated_at
    BEFORE UPDATE ON knowledge
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ── 벡터 검색 인덱스 ──
-- HNSW (Hierarchical Navigable Small World): 대규모 데이터 ANN 검색 최적화
-- vector_cosine_ops: cosine similarity (의미 유사도 검색에 최적)
-- m=16, ef_construction=64: 정확도/속도/메모리 균형 기본값
--   → Week 2 벤치마크 결과에 따라 m, ef_construction 조정 예정
CREATE INDEX IF NOT EXISTS idx_knowledge_embedding_hnsw
    ON knowledge
    USING hnsw (content_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- ── 일반 조회 인덱스 ──
-- 발행자별 지식 목록
CREATE INDEX IF NOT EXISTS idx_knowledge_agent_id
    ON knowledge (agent_id);

-- 상태 필터 (가장 빈번한 WHERE 조건)
CREATE INDEX IF NOT EXISTS idx_knowledge_status
    ON knowledge (status);

-- 도메인별 필터
CREATE INDEX IF NOT EXISTS idx_knowledge_domain
    ON knowledge (domain);

-- 신뢰점수 내림차순 (지식 리스트 기본 정렬)
CREATE INDEX IF NOT EXISTS idx_knowledge_trust_score
    ON knowledge (trust_score DESC);

-- 최신순 정렬
CREATE INDEX IF NOT EXISTS idx_knowledge_created_at
    ON knowledge (created_at DESC);

-- tags 배열 GIN 인덱스
-- WHERE tags @> ARRAY['mRNA'] 스타일 조회 지원
CREATE INDEX IF NOT EXISTS idx_knowledge_tags
    ON knowledge USING gin (tags);

-- ── 복합 인덱스 ──
-- "활성 지식 신뢰점수 순 목록" — 가장 빈번한 쿼리 패턴 최적화
-- Partial index로 active 레코드만 포함 (저장 공간 효율)
CREATE INDEX IF NOT EXISTS idx_knowledge_active_by_trust
    ON knowledge (trust_score DESC, created_at DESC)
    WHERE status = 'active';

-- 도메인 + 신뢰점수 복합 (도메인 필터 후 정렬)
CREATE INDEX IF NOT EXISTS idx_knowledge_domain_trust
    ON knowledge (domain, trust_score DESC)
    WHERE status = 'active';


-- ================================================================
-- 섹션 4: transaction (포인트 거래) 테이블
-- ================================================================
-- 역할  : 모든 포인트 이동 이력을 불변(append-only)으로 기록.
--         인용·보상·환불·관리자 지급 등 모든 거래의 감사 로그.
-- 핵심  : updated_at 없음 — 거래 기록은 절대 수정하지 않음 (감사 불변성)
--         status='failed' 레코드도 삭제 금지 (실패 이력 보존)
--         amount는 항상 양수 — 방향은 from_agent_id → to_agent_id로 결정
-- ================================================================

CREATE TABLE IF NOT EXISTS transaction (

    -- ── 식별자 ──
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- ── 포인트 이동 방향 ──
    -- NULL: 시스템 지급 (초기 100포인트, 관리자 보상 등)
    from_agent_id   UUID        REFERENCES agent(id) ON DELETE RESTRICT,

    -- 수신 에이전트 (필수)
    to_agent_id     UUID        NOT NULL
                    REFERENCES agent(id) ON DELETE RESTRICT,

    -- ── 연관 지식 ──
    -- cite 타입에서 필수. admin/reward/refund는 NULL 허용.
    knowledge_id    UUID        REFERENCES knowledge(id) ON DELETE RESTRICT,

    -- ── 금액 ──
    -- 항상 양수. 포인트 이동 방향은 from → to 로만 결정.
    amount          INTEGER     NOT NULL
                    CHECK (amount > 0),

    -- ── 유형 ──
    -- cite  : 인용 (인용자 차감, 발행자 지급)
    -- reward: 시스템 보상 지급
    -- refund: 환불 처리
    -- admin : 관리자 수동 지급 (초기 100포인트 포함)
    type            TEXT        NOT NULL
                    CHECK (type IN ('cite', 'reward', 'refund', 'admin')),

    -- ── 처리 상태 ──
    -- pending  : 처리 중 (RPC 실행 중간 상태)
    -- completed: 정상 완료
    -- failed   : 실패/롤백 (삭제 금지 — 감사 불변성 원칙)
    status          TEXT        NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'completed', 'failed')),

    -- ── 비고 ──
    -- 선택적 거래 사유. 관리자 메모, 환불 이유 등.
    memo            TEXT,

    -- ── 감사(Audit) ──
    -- ⚠ updated_at 없음: 거래 기록은 불변(append-only). 수정 금지.
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 테이블/컬럼 주석
COMMENT ON TABLE  transaction               IS '[거래] 포인트 이동 이력. 불변(append-only) 감사 로그.';
COMMENT ON COLUMN transaction.from_agent_id IS 'NULL = 시스템 지급 (초기 포인트, 관리자 보상).';
COMMENT ON COLUMN transaction.amount        IS '항상 양수. 방향은 from_agent_id → to_agent_id.';
COMMENT ON COLUMN transaction.status        IS '⚠ failed 레코드 삭제 금지. 감사 불변성 원칙.';

-- ── 조회 인덱스 ──
-- 에이전트별 송금 내역
CREATE INDEX IF NOT EXISTS idx_transaction_from_agent
    ON transaction (from_agent_id);

-- 에이전트별 수신 내역
CREATE INDEX IF NOT EXISTS idx_transaction_to_agent
    ON transaction (to_agent_id);

-- 지식별 인용 거래 내역
CREATE INDEX IF NOT EXISTS idx_transaction_knowledge_id
    ON transaction (knowledge_id);

-- 유형별 필터
CREATE INDEX IF NOT EXISTS idx_transaction_type
    ON transaction (type);

-- 상태별 필터
CREATE INDEX IF NOT EXISTS idx_transaction_status
    ON transaction (status);

-- 최신 거래 내역 조회 (기본 정렬)
CREATE INDEX IF NOT EXISTS idx_transaction_created_at
    ON transaction (created_at DESC);

-- ── 복합 인덱스 ──
-- "내 거래 내역 최신순" — 에이전트 대시보드 핵심 쿼리
CREATE INDEX IF NOT EXISTS idx_transaction_to_agent_recent
    ON transaction (to_agent_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transaction_from_agent_recent
    ON transaction (from_agent_id, created_at DESC);


-- ================================================================
-- 섹션 5: knowledge_citation (지식 인용 이력) 테이블
-- ================================================================
-- 역할  : 누가 어떤 지식을 인용했는지 이력 추적.
--         agent_vote_score PageRank 재계산의 핵심 데이터 소스.
-- 핵심  : UNIQUE(knowledge_id, citer_agent_id) — 중복 인용 방지 (Sybil Attack 구조적 방어)
--         citer_trust_score_snapshot — 인용 시점 신뢰점수 고정 보존 (이력 불변성)
-- 의존성: transaction 테이블 이후에 생성해야 함 (FK 참조)
-- ================================================================

CREATE TABLE IF NOT EXISTS knowledge_citation (

    -- ── 식별자 ──
    id                          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- ── 관계 ──
    -- 인용된 지식 (지식 삭제 시 인용 이력도 함께 삭제)
    knowledge_id                UUID        NOT NULL
                                REFERENCES knowledge(id) ON DELETE CASCADE,

    -- 인용한 에이전트 (에이전트 삭제 금지 — 이력 보존)
    citer_agent_id              UUID        NOT NULL
                                REFERENCES agent(id) ON DELETE RESTRICT,

    -- 연결된 포인트 거래 (항상 쌍으로 존재)
    transaction_id              UUID        NOT NULL
                                REFERENCES transaction(id) ON DELETE RESTRICT,

    -- ── PageRank 가중치 계산용 스냅샷 ──
    -- 인용 당시의 citer trust_score를 고정 저장.
    -- 이후 citer의 trust_score가 변해도 이 인용의 기여도는 변하지 않음 (이력 불변성).
    -- fn_recalculate_agent_vote_score() 가 이 값의 집계로 점수를 계산함.
    citer_trust_score_snapshot  FLOAT8      NOT NULL DEFAULT 0.0
                                CHECK (citer_trust_score_snapshot BETWEEN 0.0 AND 1.0),

    -- ── 감사(Audit) ──
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- ── 제약 조건 ──
    -- Sybil Attack 방어: 동일 에이전트가 같은 지식을 중복 인용 불가
    -- fn_cite_knowledge() RPC 내부에서도 사전 검증하지만, DB 레벨 최종 방어선.
    CONSTRAINT uk_citation_no_duplicate
        UNIQUE (knowledge_id, citer_agent_id)
);

-- 테이블/컬럼 주석
COMMENT ON TABLE  knowledge_citation IS '[인용이력] 지식 인용 추적. PageRank 재계산 데이터 소스.';
COMMENT ON COLUMN knowledge_citation.citer_trust_score_snapshot
    IS '인용 시점 신뢰점수 스냅샷. PageRank 재계산에 사용. 이후 변경 불가.';
COMMENT ON COLUMN knowledge_citation.transaction_id
    IS '항상 쌍으로 존재하는 포인트 거래 레코드. 인용과 결제는 원자적으로 생성됨.';

-- ── 조회 인덱스 ──
-- 지식별 인용 목록 (agent_vote_score 재계산 시 사용)
CREATE INDEX IF NOT EXISTS idx_citation_knowledge_id
    ON knowledge_citation (knowledge_id);

-- 에이전트별 인용 이력
CREATE INDEX IF NOT EXISTS idx_citation_citer_agent_id
    ON knowledge_citation (citer_agent_id);

-- 인용 시점 기준 최신순
CREATE INDEX IF NOT EXISTS idx_citation_created_at
    ON knowledge_citation (created_at DESC);

-- 지식 + 인용자 복합 (중복 인용 빠른 검증)
CREATE INDEX IF NOT EXISTS idx_citation_knowledge_citer
    ON knowledge_citation (knowledge_id, citer_agent_id);


-- ================================================================
-- 섹션 6: 뷰 (Views) — 자주 쓰는 쿼리 캡슐화
-- ================================================================

-- ── 뷰 1: 활성 지식 목록 (검색 화면 기본) ──
-- 목적: Flutter 검색 화면에서 바로 사용. 발행자 이름 포함.
-- 주의: content_embedding 제외 (대역폭 절감 — 필요 시 별도 조회)
CREATE OR REPLACE VIEW v_active_knowledge AS
SELECT
    k.id,
    k.title,
    k.content_claim,
    k.content_body,
    k.domain,
    k.tags,
    k.trust_score,
    k.system_score,
    k.agent_vote_score,
    k.admin_score,
    k.citation_price,
    k.citation_count,
    k.created_at,
    k.updated_at,
    -- 발행자 정보 (JOIN)
    a.id            AS publisher_id,
    a.name          AS publisher_name,
    a.type          AS publisher_type,
    a.trust_score   AS publisher_trust_score
FROM
    knowledge k
    INNER JOIN agent a ON k.agent_id = a.id
WHERE
    k.status = 'active'
ORDER BY
    k.trust_score DESC,
    k.created_at DESC;

COMMENT ON VIEW v_active_knowledge IS
    '검색 화면용 활성 지식 목록. 발행자 정보 포함. 임베딩 제외.';


-- ── 뷰 2: 에이전트 통계 ──
-- 목적: 에이전트 대시보드. 발행 지식 수 + 획득 포인트 집계.
CREATE OR REPLACE VIEW v_agent_stats AS
SELECT
    a.id,
    a.name,
    a.type,
    a.points,
    a.trust_score,
    a.is_active,
    a.created_at,
    -- 발행 지식 수 (전체)
    COUNT(DISTINCT k.id)                    AS knowledge_count,
    -- 활성 지식 수
    COUNT(DISTINCT k.id) FILTER (
        WHERE k.status = 'active'
    )                                       AS active_knowledge_count,
    -- 총 획득 포인트 (수신 거래 합산)
    COALESCE(SUM(t.amount) FILTER (
        WHERE t.to_agent_id = a.id
          AND t.status = 'completed'
    ), 0)                                   AS total_earned_points,
    -- 총 지출 포인트 (발신 거래 합산)
    COALESCE(SUM(t.amount) FILTER (
        WHERE t.from_agent_id = a.id
          AND t.status = 'completed'
    ), 0)                                   AS total_spent_points
FROM
    agent a
    LEFT JOIN knowledge  k ON k.agent_id = a.id
    LEFT JOIN transaction t ON (t.to_agent_id = a.id OR t.from_agent_id = a.id)
                            AND t.status = 'completed'
GROUP BY
    a.id, a.name, a.type, a.points, a.trust_score, a.is_active, a.created_at;

COMMENT ON VIEW v_agent_stats IS
    '에이전트 대시보드용. 발행 지식 수 + 포인트 획득/지출 통계 포함.';


-- ── 뷰 3: 지식 인용 통계 ──
-- 목적: 발행자가 자신의 지식별 인용 현황을 확인하는 화면용
CREATE OR REPLACE VIEW v_knowledge_citation_stats AS
SELECT
    k.id                AS knowledge_id,
    k.title,
    k.trust_score,
    k.citation_price,
    k.citation_count,
    -- 인용자 신뢰점수 평균 (PageRank 품질 지표)
    COALESCE(AVG(kc.citer_trust_score_snapshot), 0.0) AS avg_citer_trust_score,
    -- 최초 인용 시각
    MIN(kc.created_at)  AS first_cited_at,
    -- 최근 인용 시각
    MAX(kc.created_at)  AS last_cited_at
FROM
    knowledge k
    LEFT JOIN knowledge_citation kc ON kc.knowledge_id = k.id
GROUP BY
    k.id, k.title, k.trust_score, k.citation_price, k.citation_count;

COMMENT ON VIEW v_knowledge_citation_stats IS
    '지식별 인용 통계. 발행자 대시보드용. PageRank 품질 지표 포함.';
