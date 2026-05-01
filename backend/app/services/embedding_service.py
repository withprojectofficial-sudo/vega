"""
파일명: embedding_service.py
위치: backend/app/services/embedding_service.py
레이어: Service (임베딩 추상화)
역할: 텍스트를 1536차원 벡터로 변환하는 임베딩 추상화 레이어.
      Grok API(기본) → OpenAI(폴백) 순서로 시도한다.
      외부에서는 EmbeddingService.generate()만 호출하면 됨.

설계 원칙 (ARCHITECTURE.md § 5):
  - EmbeddingProvider ABC로 제공자를 교체 가능하게 추상화
  - AI 공급자 변경 시 이 파일만 수정 (의존 역전 원칙)
  - 두 제공자 모두 실패 시 VegaError(VEGA_006) 발생

작성일: 2026-05-01
"""

from abc import ABC, abstractmethod

import httpx

from app.config import settings
from app.exceptions import VegaError, VegaErrorCode
from app.utils.logger import get_logger

logger = get_logger(__name__)

# 임베딩 벡터 차원 (pgvector VECTOR(1536)과 일치해야 함)
EMBEDDING_DIMENSION = 1536


class EmbeddingProvider(ABC):
    """임베딩 제공자 추상 기반 클래스."""

    @abstractmethod
    async def generate(self, text: str) -> list[float]:
        """
        텍스트를 임베딩 벡터로 변환한다.

        Args:
            text: 임베딩할 텍스트 (content_claim)

        Returns:
            list[float]: EMBEDDING_DIMENSION 차원의 벡터

        Raises:
            Exception: API 호출 실패 시
        """


class GrokEmbeddingProvider(EmbeddingProvider):
    """
    Grok (xAI) API 임베딩 제공자.

    xAI API는 OpenAI 호환 형식을 사용한다.
    모델명은 settings.GROK_EMBEDDING_MODEL 환경변수로 설정.
    """

    async def generate(self, text: str) -> list[float]:
        """
        Grok API로 텍스트를 임베딩한다.

        Args:
            text: 임베딩할 텍스트

        Returns:
            list[float]: 1536차원 임베딩 벡터

        Raises:
            httpx.HTTPError: API 호출 실패 시
            ValueError: 응답 형식 오류 시
        """
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{settings.grok_api_base_url}/embeddings",
                headers={
                    "Authorization": f"Bearer {settings.GROK_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": settings.GROK_EMBEDDING_MODEL,
                    "input": text,
                },
            )
            response.raise_for_status()

        result = response.json()
        embedding: list[float] = result["data"][0]["embedding"]

        # 차원 검증
        if len(embedding) != EMBEDDING_DIMENSION:
            raise ValueError(
                f"Grok 임베딩 차원 불일치: 예상 {EMBEDDING_DIMENSION}, 실제 {len(embedding)}"
            )

        return embedding


class OpenAIEmbeddingProvider(EmbeddingProvider):
    """
    OpenAI 임베딩 제공자 (Grok 실패 시 폴백).

    text-embedding-3-small 모델 사용 (1536차원).
    OPENAI_API_KEY 환경변수가 설정된 경우에만 동작.
    """

    async def generate(self, text: str) -> list[float]:
        """
        OpenAI API로 텍스트를 임베딩한다.

        Args:
            text: 임베딩할 텍스트

        Returns:
            list[float]: 1536차원 임베딩 벡터

        Raises:
            RuntimeError: OPENAI_API_KEY 미설정 시
            httpx.HTTPError: API 호출 실패 시
        """
        if not settings.OPENAI_API_KEY:
            raise RuntimeError("OPENAI_API_KEY가 설정되지 않아 OpenAI 폴백을 사용할 수 없습니다.")

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{settings.openai_api_base_url}/embeddings",
                headers={
                    "Authorization": f"Bearer {settings.OPENAI_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "text-embedding-3-small",
                    "input": text,
                    "dimensions": EMBEDDING_DIMENSION,
                },
            )
            response.raise_for_status()

        result = response.json()
        embedding: list[float] = result["data"][0]["embedding"]

        if len(embedding) != EMBEDDING_DIMENSION:
            raise ValueError(
                f"OpenAI 임베딩 차원 불일치: 예상 {EMBEDDING_DIMENSION}, 실제 {len(embedding)}"
            )

        return embedding


class EmbeddingService:
    """
    임베딩 추상화 서비스.

    외부에서는 이 클래스만 사용한다.
    Grok(기본) → OpenAI(폴백) 순서로 시도하며,
    두 제공자 모두 실패하면 VegaError(VEGA_006)를 발생시킨다.

    사용 예시:
        service = EmbeddingService()
        vector = await service.generate("mRNA 백신은 안전하고 효과적이다.")
    """

    def __init__(self) -> None:
        self._primary = GrokEmbeddingProvider()
        self._fallback = OpenAIEmbeddingProvider()

    async def generate(self, text: str) -> list[float]:
        """
        텍스트를 임베딩 벡터로 변환한다. Grok → OpenAI 폴백 순서.

        Args:
            text: 임베딩할 텍스트 (보통 knowledge.content_claim)

        Returns:
            list[float]: 1536차원 임베딩 벡터

        Raises:
            VegaError(VEGA_006): Grok + OpenAI 모두 실패 시
        """
        # Grok API 시도
        try:
            embedding = await self._primary.generate(text)
            logger.info("Grok 임베딩 생성 완료", text_length=len(text))
            return embedding
        except Exception as grok_error:
            logger.warning("Grok 임베딩 실패, OpenAI 폴백 시도", error=str(grok_error))

        # OpenAI 폴백 시도
        try:
            embedding = await self._fallback.generate(text)
            logger.info("OpenAI 폴백 임베딩 생성 완료", text_length=len(text))
            return embedding
        except Exception as openai_error:
            logger.error(
                "임베딩 생성 완전 실패 (Grok + OpenAI 모두 실패)",
                openai_error=str(openai_error),
            )

        raise VegaError(
            VegaErrorCode.EMBEDDING_FAILED,
            "임베딩 생성에 실패했습니다. Grok API와 OpenAI 모두 응답하지 않습니다.",
        )


# 모듈 수준 싱글턴 (매번 인스턴스 생성 방지)
embedding_service = EmbeddingService()
