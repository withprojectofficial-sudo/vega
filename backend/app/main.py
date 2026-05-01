"""
파일명: main.py
위치: backend/app/main.py
레이어: Core (진입점)
역할: FastAPI 앱 인스턴스 생성, 미들웨어, 라우터, 예외 핸들러를 등록한다.
      Railway 배포 시 uvicorn이 이 파일의 app 객체를 실행한다.
작성일: 2026-05-01
"""

from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

from app.api.v1.router import router as v1_router
from app.config import settings
from app.db.supabase_client import close_supabase_client, init_supabase_client
from app.exceptions import VegaError, unhandled_exception_handler, vega_exception_handler
from app.services.embedding_service import embedding_service
from app.utils.logger import get_logger

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """
    FastAPI 앱 생명주기 관리자.

    시작 시: Supabase 비동기 클라이언트 초기화
    종료 시: 클라이언트 연결 해제

    Args:
        app: FastAPI 앱 인스턴스
    """
    # ── 앱 시작 ──
    logger.info("Vega API 서버 시작 중...", environment=settings.ENVIRONMENT)
    await init_supabase_client()
    logger.info("Supabase 클라이언트 초기화 완료")
    await embedding_service.warm_up()
    logger.info("임베딩 서비스 웜업 완료")

    yield  # 앱 실행 구간

    # ── 앱 종료 ──
    await close_supabase_client()
    logger.info("Vega API 서버 종료 완료")


def create_app() -> FastAPI:
    """
    FastAPI 앱 인스턴스를 생성하고 설정한다.

    Returns:
        FastAPI: 설정이 완료된 앱 인스턴스
    """
    app = FastAPI(
        title="Vega API",
        description="인용 기반 지식 신뢰 인프라 — AI+Human 공존 생태계",
        version="1.0.0",
        docs_url="/docs" if not settings.is_production else None,   # 프로덕션에서 Swagger 비공개
        redoc_url="/redoc" if not settings.is_production else None,
        lifespan=lifespan,
    )

    # ── 미들웨어 등록 (순서 중요: 마지막 등록이 가장 먼저 실행) ──

    # CORS: Flutter Web, 외부 AI 에이전트의 크로스-오리진 요청 허용
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

    # Trusted Host: 프로덕션에서 호스트 스푸핑 방지
    if settings.is_production:
        app.add_middleware(
            TrustedHostMiddleware,
            allowed_hosts=["*.railway.app", "*.vega.ai"],  # 실제 도메인으로 교체
        )

    # ── 예외 핸들러 등록 ──
    app.add_exception_handler(VegaError, vega_exception_handler)          # type: ignore[arg-type]
    app.add_exception_handler(Exception, unhandled_exception_handler)     # type: ignore[arg-type]

    # ── API 라우터 등록 ──
    app.include_router(v1_router, prefix="/api")

    # ── 헬스체크 엔드포인트 ──
    @app.get("/health", tags=["System"])
    async def health_check() -> dict[str, str]:
        """서버 상태를 반환한다. Railway 헬스체크 엔드포인트."""
        return {"status": "ok", "version": "1.0.0", "environment": settings.ENVIRONMENT}

    return app


# Railway / uvicorn이 참조하는 앱 인스턴스
app: FastAPI = create_app()
