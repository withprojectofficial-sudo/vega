"""
파일명: exceptions.py
위치: backend/app/exceptions.py
레이어: Core (예외 처리)
역할: Vega 전용 커스텀 예외 클래스와 FastAPI 전역 예외 핸들러를 정의한다.
      HTTPException 직접 raise 금지 — 반드시 VegaError를 사용한다. (CLAUDE.md § 3-3)
작성일: 2026-05-01
"""

from enum import Enum

from fastapi import Request
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded


class VegaErrorCode(str, Enum):
    """
    Vega 전용 에러 코드 열거형.

    각 코드의 상세 설명은 CLAUDE.md § 3-3 에러 처리 체계 참조.
    새 에러 코드 추가 시 HTTP_STATUS_MAP과 CLAUDE.md를 동시에 업데이트할 것.
    """

    # 인증 관련
    AGENT_AUTH_FAILED   = "VEGA_001"  # API Key 불일치 또는 비활성 에이전트
    ADMIN_AUTH_FAILED   = "VEGA_007"  # X-Admin-Token 불일치

    # 포인트 관련
    INSUFFICIENT_POINTS = "VEGA_002"  # 인용 시 포인트 부족

    # 지식 관련
    KNOWLEDGE_STATUS_INVALID = "VEGA_003"  # pending/rejected 지식 인용 시도
    KNOWLEDGE_NOT_FOUND      = "VEGA_004"  # 지식 미존재

    # 트랜잭션 관련
    TRANSACTION_FAILED  = "VEGA_005"  # RPC 롤백 / DB 오류

    # 임베딩 관련
    EMBEDDING_FAILED    = "VEGA_006"  # 로컬 임베딩 실패

    # 외부 LLM (Groq 등)
    LLM_PROVIDER_FAILED = "VEGA_011"  # 채팅 완성 API 호출 실패

    # 중복/충돌
    DUPLICATE_AGENT     = "VEGA_008"  # 중복 에이전트 등록
    SELF_CITATION       = "VEGA_009"  # 자기 발행 지식 인용 시도
    DUPLICATE_CITATION  = "VEGA_010"  # 동일 지식 중복 인용 시도


# 에러 코드 → HTTP 상태 코드 매핑 (CLAUDE.md § 3-3 기준)
_HTTP_STATUS_MAP: dict[VegaErrorCode, int] = {
    VegaErrorCode.AGENT_AUTH_FAILED:        401,
    VegaErrorCode.ADMIN_AUTH_FAILED:        401,
    VegaErrorCode.INSUFFICIENT_POINTS:      402,
    VegaErrorCode.KNOWLEDGE_STATUS_INVALID: 403,
    VegaErrorCode.SELF_CITATION:            403,
    VegaErrorCode.KNOWLEDGE_NOT_FOUND:      404,
    VegaErrorCode.DUPLICATE_AGENT:          409,
    VegaErrorCode.DUPLICATE_CITATION:       409,
    VegaErrorCode.TRANSACTION_FAILED:       500,
    VegaErrorCode.EMBEDDING_FAILED:         503,
    VegaErrorCode.LLM_PROVIDER_FAILED:      503,
}


class VegaError(Exception):
    """
    Vega 전용 커스텀 예외 클래스.

    FastAPI에서 HTTPException 대신 이 예외를 raise한다.
    vega_exception_handler가 JSON 응답으로 변환한다.

    사용 예시:
        raise VegaError(VegaErrorCode.INSUFFICIENT_POINTS, "포인트가 부족합니다. 필요: 10, 보유: 5")

    Args:
        code: VegaErrorCode 열거형 값
        detail: 사용자에게 전달할 한국어 상세 메시지
    """

    def __init__(self, code: VegaErrorCode, detail: str = "") -> None:
        self.code = code
        self.detail = detail
        self.http_status = _HTTP_STATUS_MAP[code]
        super().__init__(f"[{code.value}] {detail}")


def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    """
    Rate Limit 초과 시 JSON 응답을 반환한다.

    SlowAPIMiddleware는 동기 예외 핸들러만 안전하게 호출하므로 동기 함수로 둔다.
    응답 형식은 VegaError와 유사하게 success / error_code / message 를 맞춘다.

    Args:
        request: FastAPI Request
        exc: slowapi RateLimitExceeded (내부에 적중한 Limit 메타가 포함됨)

    Returns:
        JSONResponse: 429 Too Many Requests
    """
    limit_desc = str(exc.detail) if exc.detail else "분당 요청 한도"
    response = JSONResponse(
        status_code=429,
        content={
            "success": False,
            "error_code": "RATE_LIMIT_EXCEEDED",
            "message": (
                "요청 횟수가 허용 한도를 초과했습니다. "
                f"적용된 제한: {limit_desc}. 잠시 후 다시 시도해주세요."
            ),
        },
    )
    return request.app.state.limiter._inject_headers(
        response,
        getattr(request.state, "view_rate_limit", None),
    )


async def vega_exception_handler(request: Request, exc: VegaError) -> JSONResponse:
    """
    VegaError를 FastAPI JSON 응답으로 변환하는 전역 핸들러.

    main.py에서 app.add_exception_handler(VegaError, vega_exception_handler)로 등록.

    Args:
        request: FastAPI Request 객체
        exc: 발생한 VegaError

    Returns:
        JSONResponse: { success, error_code, message } 구조
    """
    return JSONResponse(
        status_code=exc.http_status,
        content={
            "success": False,
            "error_code": exc.code.value,
            "message": exc.detail or exc.code.name,
        },
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    예상하지 못한 예외를 처리하는 폴백 핸들러.

    프로덕션에서는 Sentry로 전달되며, 스택 트레이스를 응답에 노출하지 않는다.

    Args:
        request: FastAPI Request 객체
        exc: 처리되지 않은 예외

    Returns:
        JSONResponse: 500 내부 서버 오류 응답
    """
    # 로거는 순환 임포트 방지를 위해 지연 임포트
    from app.utils.logger import get_logger
    logger = get_logger(__name__)
    logger.error("처리되지 않은 예외 발생", exc_info=exc, path=str(request.url))

    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error_code": "INTERNAL_ERROR",
            "message": "서버 내부 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
        },
    )
