"""
파일명: dependencies.py
위치: backend/app/dependencies.py
레이어: Core (공통 의존성)
역할: FastAPI 의존성 주입(Depends)에 사용되는 공통 함수들을 정의한다.
      API Key 인증, 관리자 토큰 인증, DB 클라이언트 제공을 담당한다.
작성일: 2026-05-01
"""

from fastapi import Depends, Header
from supabase import AsyncClient

from app.db.supabase_client import get_supabase_client
from app.exceptions import VegaError, VegaErrorCode
from app.schemas.agent import AgentInDB
from app.utils.logger import get_logger
from app.utils.security import parse_agent_id_from_key, verify_api_key_hash

logger = get_logger(__name__)


async def get_db() -> AsyncClient:
    """
    Supabase 비동기 클라이언트를 반환하는 의존성 함수.

    service_role 키를 사용하므로 RLS를 우회한다.
    모든 쓰기 작업은 이 클라이언트를 통해 처리한다.

    Returns:
        AsyncClient: Supabase 비동기 클라이언트 싱글턴
    """
    return get_supabase_client()


async def get_current_agent(
    authorization: str = Header(..., description="Bearer {api_key}"),
    db: AsyncClient = Depends(get_db),
) -> AgentInDB:
    """
    Authorization 헤더의 Bearer API Key를 검증하고 에이전트 정보를 반환한다.

    검증 순서:
      1. 헤더 형식 확인 (Bearer 접두사)
      2. API Key 형식 파싱 → agent_id 추출
      3. DB에서 에이전트 조회 (is_active = True 조건)
      4. bcrypt 해시 검증

    Args:
        authorization: "Bearer vk_{agent_id}_{random}" 형식의 헤더
        db: Supabase 클라이언트

    Returns:
        AgentInDB: 인증된 에이전트 정보

    Raises:
        VegaError(VEGA_001): 인증 실패 (형식 오류, 미존재, 해시 불일치, 비활성)
    """
    # 헤더 형식 검증
    if not authorization.startswith("Bearer "):
        raise VegaError(VegaErrorCode.AGENT_AUTH_FAILED, "Authorization 헤더 형식이 올바르지 않습니다. 'Bearer {api_key}' 형식으로 전달하세요.")

    plain_api_key = authorization.removeprefix("Bearer ").strip()

    # API Key에서 agent_id 추출
    agent_id = parse_agent_id_from_key(plain_api_key)
    if agent_id is None:
        raise VegaError(VegaErrorCode.AGENT_AUTH_FAILED, "API Key 형식이 올바르지 않습니다.")

    # DB에서 에이전트 조회
    try:
        result = await db.table("agent").select("*").eq("id", agent_id).eq("is_active", True).maybe_single().execute()
    except Exception as e:
        logger.error("에이전트 조회 중 DB 오류 발생", agent_id=agent_id, error=str(e))
        raise VegaError(VegaErrorCode.AGENT_AUTH_FAILED, "인증 처리 중 오류가 발생했습니다.")

    if result.data is None:
        raise VegaError(VegaErrorCode.AGENT_AUTH_FAILED, "에이전트를 찾을 수 없거나 비활성 상태입니다.")

    # bcrypt 해시 검증
    stored_hash: str = result.data["api_key_hash"]
    if not verify_api_key_hash(plain_api_key, stored_hash):
        logger.warning("API Key 해시 불일치", agent_id=agent_id)
        raise VegaError(VegaErrorCode.AGENT_AUTH_FAILED, "API Key가 올바르지 않습니다.")

    return AgentInDB(**result.data)


async def get_admin_token(
    x_admin_token: str = Header(..., alias="X-Admin-Token", description="관리자 전용 인증 토큰"),
) -> None:
    """
    X-Admin-Token 헤더를 검증하는 관리자 전용 의존성.

    지식 상태·점수 등 관리자 전용 엔드포인트에서만 사용한다.
    토큰이 일치하지 않으면 즉시 VEGA_007 에러를 반환한다.

    Args:
        x_admin_token: 관리자 시크릿 토큰

    Raises:
        VegaError(VEGA_007): 관리자 토큰 불일치
    """
    from app.config import settings  # 순환 임포트 방지를 위한 지연 임포트

    if x_admin_token != settings.ADMIN_SECRET_TOKEN:
        logger.warning("관리자 인증 실패 시도 감지")
        raise VegaError(VegaErrorCode.ADMIN_AUTH_FAILED, "관리자 토큰이 올바르지 않습니다.")
