"""
파일명: citation_service.py
위치: backend/app/services/citation_service.py
레이어: Service (인용 트랜잭션)
역할: 지식 인용 원자적 트랜잭션을 처리한다.
      포인트 차감·지급·카운트 증가를 Supabase RPC 단일 호출로 처리한다.

⚡ 핵심 원칙 (CLAUDE.md § 3-2):
  이 서비스의 cite_knowledge()는 반드시 Supabase fn_cite_knowledge() RPC를
  단일 호출로 처리해야 한다. 절대 분리 호출 금지.
  실패 시 전체 롤백은 RPC 내부의 PostgreSQL 트랜잭션이 보장한다.

작성일: 2026-05-01
"""

from supabase import AsyncClient

from app.exceptions import VegaError, VegaErrorCode
from app.schemas.agent import AgentInDB
from app.schemas.knowledge import KnowledgeCiteResponse
from app.utils.logger import get_logger

logger = get_logger(__name__)

# RPC 에러 메시지 → VegaErrorCode 매핑
_RPC_ERROR_MAP: dict[str, VegaErrorCode] = {
    "VEGA_001": VegaErrorCode.AGENT_AUTH_FAILED,
    "VEGA_002": VegaErrorCode.INSUFFICIENT_POINTS,
    "VEGA_003": VegaErrorCode.KNOWLEDGE_STATUS_INVALID,
    "VEGA_004": VegaErrorCode.KNOWLEDGE_NOT_FOUND,
    "VEGA_005": VegaErrorCode.TRANSACTION_FAILED,
    "VEGA_009": VegaErrorCode.SELF_CITATION,
    "VEGA_010": VegaErrorCode.DUPLICATE_CITATION,
}


def _parse_rpc_error(error_msg: str) -> tuple[VegaErrorCode, str]:
    """
    RPC에서 발생한 PostgreSQL RAISE EXCEPTION 메시지를 VegaErrorCode로 변환한다.

    RPC 에러 형식: "VEGA_XXX: 한국어 메시지"

    Args:
        error_msg: RPC에서 반환된 에러 메시지

    Returns:
        tuple[VegaErrorCode, str]: (에러코드, 한국어 메시지)
    """
    for code_str, error_code in _RPC_ERROR_MAP.items():
        if code_str in error_msg:
            # "VEGA_XXX: 메시지" 에서 메시지 부분만 추출
            parts = error_msg.split(":", 1)
            detail = parts[1].strip() if len(parts) > 1 else error_msg
            return error_code, detail

    # 매핑에 없는 예외는 트랜잭션 실패로 처리
    return VegaErrorCode.TRANSACTION_FAILED, "인용 처리 중 예상치 못한 오류가 발생했습니다."


async def cite_knowledge(
    knowledge_id: str,
    current_agent: AgentInDB,
    db: AsyncClient,
) -> KnowledgeCiteResponse:
    """
    지식을 인용하고 포인트를 원자적으로 정산한다.

    ⚡ 이 함수는 Supabase fn_cite_knowledge() RPC를 단일 호출한다.
    내부적으로 13단계 원자적 트랜잭션이 실행되며 (rpc_functions.sql 참조):
      - 지식 상태 검증 (active만 가능)
      - 자기 인용 방지
      - 포인트 잔액 검증
      - 중복 인용 방지 (Sybil 방어)
      - 인용자 포인트 차감
      - 발행자 포인트 지급
      - 인용 카운트 증가
      - 거래 기록 생성
      - 인용 이력 생성
      - PageRank 재계산

    Args:
        knowledge_id: 인용할 지식의 UUID
        current_agent: 인증된 인용자 에이전트
        db: Supabase 비동기 클라이언트

    Returns:
        KnowledgeCiteResponse: 트랜잭션 결과 (잔여 포인트, 갱신된 카운트 등)

    Raises:
        VegaError(VEGA_001): 에이전트 비활성
        VegaError(VEGA_002): 포인트 부족
        VegaError(VEGA_003): 지식이 active 상태가 아님
        VegaError(VEGA_004): 지식 미존재
        VegaError(VEGA_005): RPC 트랜잭션 실패
        VegaError(VEGA_009): 자기 인용 시도
        VegaError(VEGA_010): 중복 인용 시도
    """
    logger.info("인용 트랜잭션 시작", knowledge_id=knowledge_id, citer_id=current_agent.id)

    try:
        # ⚡ 원자적 트랜잭션 — 단일 RPC 호출 (절대 분리 금지)
        result = await db.rpc(
            "fn_cite_knowledge",
            {
                "p_knowledge_id":   knowledge_id,
                "p_citer_agent_id": current_agent.id,
            },
        ).execute()
    except Exception as e:
        error_msg = str(e)
        error_code, detail = _parse_rpc_error(error_msg)
        logger.warning(
            "인용 RPC 실패",
            knowledge_id=knowledge_id,
            citer_id=current_agent.id,
            error_code=error_code.value,
            detail=detail,
        )
        raise VegaError(error_code, detail)

    rpc_data: dict = result.data
    logger.info(
        "인용 트랜잭션 완료",
        knowledge_id=knowledge_id,
        citer_id=current_agent.id,
        transaction_id=rpc_data.get("transaction_id"),
        new_citation_count=rpc_data.get("new_citation_count"),
    )

    return KnowledgeCiteResponse(
        transaction_id=rpc_data["transaction_id"],
        new_citation_count=rpc_data["new_citation_count"],
        new_trust_score=rpc_data.get("new_agent_vote_score", 0.0),
        citer_remaining_points=rpc_data["citer_remaining_points"],
        publisher_earned_points=rpc_data["publisher_earned_points"],
    )
