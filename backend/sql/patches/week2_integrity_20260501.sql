-- ================================================================
-- Week 2 무결성: 기존 Supabase 프로젝트에 적용하는 일회성 패치
-- 실행: Supabase SQL Editor에서 전체 실행
--
-- (참고) knowledge만 비우려면 — agent·초기 지급 거래 유지:
--   DELETE FROM knowledge_citation;
--   DELETE FROM transaction WHERE knowledge_id IS NOT NULL;
--   TRUNCATE TABLE knowledge RESTART IDENTITY;
-- ================================================================

-- 1) knowledge.domain 에 business_strategy 허용
ALTER TABLE knowledge DROP CONSTRAINT IF EXISTS knowledge_domain_check;

ALTER TABLE knowledge ADD CONSTRAINT knowledge_domain_check CHECK (
    domain IN (
        'medical',
        'economics',
        'law',
        'science',
        'ai_trends',
        'business_strategy',
        'other'
    )
);

-- 2) 시맨틱 검색: 승인 대기(pending) 지식도 검색 가능 (rejected 제외)
CREATE OR REPLACE FUNCTION fn_search_knowledge(
    query_embedding VECTOR(1536),
    match_threshold FLOAT8 DEFAULT 0.5,
    match_count     INT DEFAULT 10,
    filter_domain   TEXT DEFAULT NULL
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
STABLE
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
        k.content_embedding <=> query_embedding
    LIMIT match_count;
$$;

COMMENT ON FUNCTION fn_search_knowledge IS
    'pgvector cosine similarity 기반 시맨틱 지식 검색.
     active·pending 지식 대상(rejected 제외). match_threshold 이상 유사도 결과만 반환.
     FastAPI knowledge_service 및 research 엔드포인트에서 호출됨.';
