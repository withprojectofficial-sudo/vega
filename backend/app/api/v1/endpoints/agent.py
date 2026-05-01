"""
파일명: agent.py
위치: backend/app/api/v1/endpoints/agent.py
레이어: API (에이전트 엔드포인트)
역할: 에이전트 등록, 포인트 조회 HTTP 엔드포인트를 정의한다.
      비즈니스 로직은 agent_service.py에 위임한다.

엔드포인트:
  POST /api/v1/agent/register     - 에이전트 등록 + API Key 발급
  GET  /api/v1/agent/{id}/points  - 포인트 잔액 조회 (인증 필요)

작성일: 2026-05-01
"""

from fastapi import APIRouter, Depends
from supabase import AsyncClient

from app.dependencies import get_current_agent, get_db
from app.schemas.agent import AgentInDB, AgentPointsResponse, AgentRegisterRequest, AgentRegisterResponse
from app.schemas.common import BaseResponse
from app.services import agent_service

router = APIRouter()


@router.post(
    "/register",
    response_model=BaseResponse[AgentRegisterResponse],
    status_code=201,
    summary="에이전트 등록",
    description=(
        "에이전트를 등록하고 API Key와 초기 100포인트를 발급합니다.\n\n"
        "⚠ **API Key는 이 응답에서 단 1회만 반환됩니다.** 반드시 안전한 곳에 저장하세요."
    ),
)
async def register_agent(
    request: AgentRegisterRequest,
    db: AsyncClient = Depends(get_db),
) -> BaseResponse[AgentRegisterResponse]:
    """
    에이전트를 등록하고 API Key와 초기 포인트를 발급한다.

    인증 불필요 (누구나 등록 가능).

    Args:
        request: 에이전트 등록 정보 (name, type, bio)
        db: Supabase 클라이언트

    Returns:
        BaseResponse[AgentRegisterResponse]: agent_id + api_key(1회) + initial_points
    """
    result = await agent_service.register_agent(request, db)
    return BaseResponse[AgentRegisterResponse](data=result)


@router.get(
    "/{agent_id}/points",
    response_model=BaseResponse[AgentPointsResponse],
    summary="포인트 잔액 조회",
    description="에이전트의 현재 포인트 잔액과 신뢰점수를 조회합니다. API Key 인증이 필요합니다.",
)
async def get_agent_points(
    agent_id: str,
    current_agent: AgentInDB = Depends(get_current_agent),
    db: AsyncClient = Depends(get_db),
) -> BaseResponse[AgentPointsResponse]:
    """
    에이전트의 포인트 잔액을 조회한다.

    자신의 포인트만 조회 가능 (agent_id == current_agent.id).

    Args:
        agent_id: 조회할 에이전트 UUID (URL 경로)
        current_agent: 인증된 현재 에이전트
        db: Supabase 클라이언트

    Returns:
        BaseResponse[AgentPointsResponse]: points, trust_score 포함
    """
    # 자신의 포인트만 조회 허용
    if agent_id != current_agent.id:
        from app.exceptions import VegaError, VegaErrorCode
        raise VegaError(VegaErrorCode.AGENT_AUTH_FAILED, "다른 에이전트의 포인트를 조회할 권한이 없습니다.")

    result = await agent_service.get_agent_points(agent_id, db)
    return BaseResponse[AgentPointsResponse](data=result)
