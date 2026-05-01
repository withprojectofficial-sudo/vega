"""
파일명: agent_service.py
위치: backend/app/services/agent_service.py
레이어: Service (에이전트 비즈니스 로직)
역할: 에이전트 등록, 포인트 조회 등 에이전트 관련 비즈니스 로직을 처리한다.
      DB 조작은 Supabase RPC 또는 직접 쿼리로 처리하며, 라우터에서 분리된다.
작성일: 2026-05-01
"""

from supabase import AsyncClient

from app.exceptions import VegaError, VegaErrorCode
from app.schemas.agent import AgentPointsResponse, AgentRegisterRequest, AgentRegisterResponse
from app.utils.logger import get_logger
from app.utils.security import generate_api_key

logger = get_logger(__name__)


async def register_agent(
    request: AgentRegisterRequest,
    db: AsyncClient,
) -> AgentRegisterResponse:
    """
    에이전트를 등록하고 API Key와 초기 100포인트를 발급한다.

    처리 순서:
      1. API Key 원문 + bcrypt 해시 생성
      2. Supabase RPC fn_register_agent() 호출 (에이전트 생성 + 초기 포인트 지급 원자적)
      3. 응답: agent_id + api_key 원문 (1회만 반환)

    Args:
        request: 에이전트 등록 요청 (name, type, bio)
        db: Supabase 비동기 클라이언트

    Returns:
        AgentRegisterResponse: agent_id, api_key(원문), initial_points

    Raises:
        VegaError(VEGA_008): 중복 등록 시 (DB UNIQUE 제약 위반)
        VegaError(VEGA_005): DB 오류로 트랜잭션 실패 시
    """
    # 임시 UUID를 먼저 생성해 API Key에 포함 (DB에서 gen_random_uuid()를 쓰지 않고 직접 생성)
    import uuid
    agent_id = str(uuid.uuid4())
    plain_api_key, api_key_hash = generate_api_key(agent_id)

    try:
        result = await db.rpc(
            "fn_register_agent",
            {
                "p_name":         request.name,
                "p_api_key_hash": api_key_hash,
                "p_type":         request.type.value,
                "p_bio":          request.bio,
                "p_agent_id":     agent_id,   # 사전 생성한 UUID 전달
            },
        ).execute()
    except Exception as e:
        error_msg = str(e)
        if "VEGA_008" in error_msg:
            raise VegaError(VegaErrorCode.DUPLICATE_AGENT, "이미 등록된 에이전트 정보입니다.")
        logger.error("에이전트 등록 RPC 실패", error=error_msg)
        raise VegaError(VegaErrorCode.TRANSACTION_FAILED, "에이전트 등록 중 오류가 발생했습니다.")

    rpc_data: dict = result.data
    logger.info("에이전트 등록 완료", agent_id=rpc_data["agent_id"], type=request.type.value)

    return AgentRegisterResponse(
        agent_id=rpc_data["agent_id"],
        api_key=plain_api_key,
        initial_points=rpc_data["initial_points"],
    )


async def get_agent_points(
    agent_id: str,
    db: AsyncClient,
) -> AgentPointsResponse:
    """
    에이전트의 포인트 잔액과 신뢰점수를 조회한다.

    Args:
        agent_id: 조회할 에이전트 UUID
        db: Supabase 비동기 클라이언트

    Returns:
        AgentPointsResponse: points, trust_score 포함 응답

    Raises:
        VegaError(VEGA_001): 에이전트 미존재 또는 비활성 시
    """
    try:
        result = await db.table("agent").select(
            "id, name, type, points, trust_score"
        ).eq("id", agent_id).eq("is_active", True).maybe_single().execute()
    except Exception as e:
        logger.error("포인트 조회 DB 오류", agent_id=agent_id, error=str(e))
        raise VegaError(VegaErrorCode.AGENT_AUTH_FAILED, "에이전트 조회 중 오류가 발생했습니다.")

    if result.data is None:
        raise VegaError(VegaErrorCode.AGENT_AUTH_FAILED, f"에이전트({agent_id})를 찾을 수 없습니다.")

    data = result.data
    return AgentPointsResponse(
        agent_id=data["id"],
        name=data["name"],
        type=data["type"],
        points=data["points"],
        trust_score=data["trust_score"],
    )
