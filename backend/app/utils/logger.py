"""
파일명: logger.py
위치: backend/app/utils/logger.py
레이어: Utils (로깅)
역할: 구조화된 JSON 로거를 제공한다.
      structlog를 사용해 컨텍스트 정보(요청 ID, agent_id 등)를 함께 기록한다.
      프로덕션에서는 JSON 포맷, 개발에서는 컬러 콘솔 포맷으로 출력한다.
작성일: 2026-05-01
"""

import logging
import sys
from functools import lru_cache

import structlog

from app.config import settings


def _configure_structlog() -> None:
    """
    structlog 전역 설정을 초기화한다.

    앱 시작 시 1회만 호출된다.
    환경에 따라 JSON 렌더러(프로덕션) 또는 콘솔 렌더러(개발)를 선택한다.
    """
    # stdlib logging 레벨 설정
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)
    logging.basicConfig(
        stream=sys.stdout,
        format="%(message)s",
        level=log_level,
    )

    # 공통 프로세서 (모든 로그에 적용)
    shared_processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,       # 요청 컨텍스트 병합
        structlog.stdlib.add_log_level,                # 로그 레벨 추가
        structlog.stdlib.add_logger_name,              # 로거 이름 추가
        structlog.processors.TimeStamper(fmt="iso"),   # ISO 8601 타임스탬프
        structlog.processors.StackInfoRenderer(),
    ]

    if settings.is_production:
        # 프로덕션: JSON 포맷 (Railway 로그 수집기 호환)
        renderer = structlog.processors.JSONRenderer()
    else:
        # 개발: 컬러 콘솔 포맷 (가독성 우선)
        renderer = structlog.dev.ConsoleRenderer(colors=True)

    structlog.configure(
        processors=shared_processors + [
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


# 앱 임포트 시 1회 설정 초기화
_configure_structlog()


@lru_cache(maxsize=128)
def get_logger(name: str) -> structlog.stdlib.BoundLogger:
    """
    이름으로 구조화된 로거를 반환한다.

    lru_cache로 동일 name에 대해 동일 인스턴스를 반환한다.

    사용 예시:
        logger = get_logger(__name__)
        logger.info("지식 발행 완료", knowledge_id=knowledge_id, agent_id=agent_id)

    Args:
        name: 로거 이름 (보통 __name__ 사용)

    Returns:
        structlog.stdlib.BoundLogger: 구조화된 로거 인스턴스
    """
    return structlog.get_logger(name)
