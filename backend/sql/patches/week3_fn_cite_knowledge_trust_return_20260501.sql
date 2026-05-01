-- Week 3: fn_cite_knowledge 응답 JSON에 new_trust_score 추가 (인용 후 knowledge.trust_score)
-- Supabase SQL Editor에서 rpc_functions.sql 전체 대신 이 파일만 적용 가능
-- (함수 본문이 길면 sql/rpc_functions.sql 의 fn_cite_knowledge 블록과 동기화 유지)

-- p_consumer_agent_id: 인용(소비) 에이전트
CREATE OR REPLACE FUNCTION fn_cite_knowledge(
    p_knowledge_id      UUID,
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

    SELECT * INTO v_knowledge
    FROM knowledge
    WHERE id = p_knowledge_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'VEGA_004: 지식(%)을 찾을 수 없습니다.', p_knowledge_id;
    END IF;

    IF v_knowledge.status != 'active' THEN
        RAISE EXCEPTION 'VEGA_003: active 상태가 아닌 지식은 인용할 수 없습니다. 현재 상태: [%]', v_knowledge.status;
    END IF;

    IF v_knowledge.agent_id = p_consumer_agent_id THEN
        RAISE EXCEPTION 'VEGA_009: 자신이 발행한 지식은 인용할 수 없습니다.';
    END IF;

    SELECT * INTO v_citer
    FROM agent
    WHERE id = p_consumer_agent_id AND is_active = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'VEGA_001: 에이전트(%)를 찾을 수 없거나 비활성 상태입니다.', p_consumer_agent_id;
    END IF;

    IF v_citer.points < v_knowledge.citation_price THEN
        RAISE EXCEPTION 'VEGA_002: 포인트 부족. 필요 포인트: %, 현재 잔액: %',
            v_knowledge.citation_price, v_citer.points;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM knowledge_citation
        WHERE knowledge_id = p_knowledge_id
          AND citer_agent_id = p_consumer_agent_id
    ) THEN
        RAISE EXCEPTION 'VEGA_010: 이미 인용한 지식입니다. 동일 지식의 중복 인용은 불가합니다.';
    END IF;

    SELECT * INTO v_publisher
    FROM agent
    WHERE id = v_knowledge.agent_id
    FOR UPDATE;

    UPDATE agent
    SET points = points - v_knowledge.citation_price
    WHERE id = p_consumer_agent_id;

    UPDATE agent
    SET points = points + v_knowledge.citation_price
    WHERE id = v_knowledge.agent_id;

    UPDATE knowledge
    SET citation_count = citation_count + 1
    WHERE id = p_knowledge_id;

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
        v_citer.trust_score
    );

    v_new_agent_vote_score := fn_recalculate_agent_vote_score(p_knowledge_id);

    SELECT trust_score INTO v_new_trust_score
    FROM knowledge
    WHERE id = p_knowledge_id;

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
     인수 p_consumer_agent_id = 인용(소비) 에이전트(consumer). transaction·knowledge_citation 기록 포함.
     동일 (knowledge_id, citer) 재인용은 VEGA_010.';
