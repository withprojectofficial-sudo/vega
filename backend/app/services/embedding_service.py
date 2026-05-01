"""
파일명: embedding_service.py
위치: backend/app/services/embedding_service.py
레이어: Service (임베딩 추상화)
역할: 텍스트를 1536차원 벡터로 변환하는 임베딩 추상화 레이어.
      Groq는 임베딩 API를 제공하지 않으므로, 무료 로컬 모델(sentence-transformers)로
      벡터를 생성한 뒤 pgvector(1536) 스키마에 맞게 0으로 패딩한다.
      패딩 후에도 같은 방식으로 만든 두 벡터 간 코사인 유사도는 원 벡터와 동일하다.

설계 원칙 (ARCHITECTURE.md § 5):
  - EmbeddingProvider ABC로 제공자를 교체 가능하게 추상화
  - 유료 OpenAI·Anthropic·Grok 임베딩 호출 없음

작성일: 2026-05-01
수정일: 2026-05-01 (Groq 무료 LLM 전환 및 로컬 임베딩 적용)
"""

from __future__ import annotations

import asyncio
import threading
from abc import ABC, abstractmethod

from sentence_transformers import SentenceTransformer

from app.config import settings
from app.exceptions import VegaError, VegaErrorCode
from app.utils.logger import get_logger

logger = get_logger(__name__)

EMBEDDING_DIMENSION = 1536

_embed_lock = threading.Lock()
_sentence_model: SentenceTransformer | None = None


def _get_sentence_model() -> SentenceTransformer:
    """로컬 임베딩 모델 싱글턴을 반환한다 (스레드 안전 초기화)."""
    global _sentence_model
    with _embed_lock:
        if _sentence_model is None:
            _sentence_model = SentenceTransformer(settings.LOCAL_EMBEDDING_MODEL)
        return _sentence_model


def _pad_or_truncate(vector: list[float], dim: int) -> list[float]:
    """모델 출력 차원을 pgvector 저장 차원(dim)으로 맞춘다."""
    if len(vector) == dim:
        return vector
    if len(vector) > dim:
        return vector[:dim]
    return vector + [0.0] * (dim - len(vector))


class EmbeddingProvider(ABC):
    """임베딩 제공자 추상 기반 클래스."""

    @abstractmethod
    async def generate(self, text: str) -> list[float]:
        """텍스트를 EMBEDDING_DIMENSION 길이의 float 목록으로 변환한다."""


class LocalSentenceEmbeddingProvider(EmbeddingProvider):
    """
    로컬 sentence-transformers 모델을 사용하는 임베딩 제공자.

    디스크 및 첫 실행 시 모델 다운로드가 필요할 수 있다.
    """

    async def generate(self, text: str) -> list[float]:
        """
        로컬 모델로 벡터를 계산한 뒤 1536차원으로 패딩한다.

        Args:
            text: 임베딩할 텍스트

        Returns:
            list[float]: EMBEDDING_DIMENSION 차원의 벡터

        Raises:
            ValueError: 계산 결과가 비어 있거나 형식이 잘못된 경우
        """
        stripped = text.strip()
        if not stripped:
            raise ValueError("임베딩할 텍스트가 비어 있습니다.")

        def _encode() -> list[float]:
            model = _get_sentence_model()
            vec = model.encode(
                stripped,
                normalize_embeddings=True,
                convert_to_numpy=True,
                show_progress_bar=False,
            )
            return [float(x) for x in vec.flatten().tolist()]

        raw = await asyncio.to_thread(_encode)
        if not raw:
            raise ValueError("임베딩 벡터가 비어 있습니다.")

        out = _pad_or_truncate(raw, EMBEDDING_DIMENSION)
        if len(out) != EMBEDDING_DIMENSION:
            raise ValueError(
                f"임베딩 차원 불일치: 예상 {EMBEDDING_DIMENSION}, 실제 {len(out)}"
            )
        return out


class EmbeddingService:
    """
    임베딩 추상화 서비스.

    외부에서는 이 클래스만 사용한다.
    실패 시 VegaError(VEGA_006)를 발생시킨다.
    """

    def __init__(self) -> None:
        self._provider = LocalSentenceEmbeddingProvider()
        self._encode_lock = asyncio.Lock()

    async def generate(self, text: str) -> list[float]:
        """
        텍스트를 임베딩 벡터로 변환한다.

        Args:
            text: 임베딩할 텍스트 (보통 knowledge.content_claim 또는 검색 쿼리)

        Returns:
            list[float]: 1536차원 임베딩 벡터

        Raises:
            VegaError(VEGA_006): 임베딩 생성 실패 시
        """
        async with self._encode_lock:
            try:
                embedding = await self._provider.generate(text)
                logger.info("로컬 임베딩 생성 완료", text_length=len(text))
                return embedding
            except Exception as e:
                logger.error("로컬 임베딩 생성 실패", error=str(e))
                raise VegaError(
                    VegaErrorCode.EMBEDDING_FAILED,
                    "임베딩 생성에 실패했습니다. 로컬 임베딩 모델을 확인해주세요.",
                ) from e


embedding_service = EmbeddingService()
