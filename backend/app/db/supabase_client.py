"""
파일명: supabase_client.py
위치: backend/app/db/supabase_client.py
레이어: DB (데이터베이스 클라이언트)
역할: Supabase 비동기 클라이언트 싱글턴을 관리한다.
      service_role 키를 사용해 RLS를 우회한다 (FastAPI 전용).
      main.py의 lifespan에서 초기화 / 종료된다.
작성일: 2026-05-01
"""

from supabase import AsyncClient, acreate_client

from app.config import settings
from app.utils.logger import get_logger

logger = get_logger(__name__)

# 모듈 수준 싱글턴 (lifespan에서 초기화)
_supabase_client: AsyncClient | None = None


async def init_supabase_client() -> None:
    """
    Supabase 비동기 클라이언트를 초기화한다.

    main.py lifespan의 시작 구간에서 1회 호출된다.
    service_role 키를 사용하므로 모든 RLS를 우회한다.

    Raises:
        RuntimeError: Supabase 연결 실패 시
    """
    global _supabase_client

    try:
        _supabase_client = await acreate_client(
            supabase_url=settings.SUPABASE_URL,
            supabase_key=settings.SUPABASE_SERVICE_ROLE_KEY,
        )
        logger.info(
            "Supabase 클라이언트 초기화 완료",
            url=settings.SUPABASE_URL[:30] + "...",  # URL 일부만 로깅 (보안)
        )
    except Exception as e:
        logger.error("Supabase 클라이언트 초기화 실패", error=str(e))
        raise RuntimeError(f"Supabase 연결 실패: {e}") from e


async def close_supabase_client() -> None:
    """
    Supabase 클라이언트 연결을 종료한다.

    main.py lifespan의 종료 구간에서 호출된다.
    """
    global _supabase_client

    if _supabase_client is not None:
        # supabase-py v2: 명시적 close 메서드가 있으면 호출
        if hasattr(_supabase_client, "aclose"):
            await _supabase_client.aclose()
        _supabase_client = None
        logger.info("Supabase 클라이언트 연결 종료 완료")


def get_supabase_client() -> AsyncClient:
    """
    초기화된 Supabase 클라이언트 싱글턴을 반환한다.

    dependencies.py의 get_db()에서 호출된다.

    Returns:
        AsyncClient: 초기화된 Supabase 비동기 클라이언트

    Raises:
        RuntimeError: init_supabase_client()가 호출되지 않은 상태에서 접근 시
    """
    if _supabase_client is None:
        raise RuntimeError(
            "Supabase 클라이언트가 초기화되지 않았습니다. "
            "lifespan이 정상적으로 실행되었는지 확인하세요."
        )
    return _supabase_client
