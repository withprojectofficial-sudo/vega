"""
파일명: embedding_service.py
위치: backend/app/services/embedding_service.py
레이어: Service (임베딩 추상화)
역할: 텍스트를 1536차원 벡터로 변환하는 임베딩 추상화 레이어.
      Groq는 임베딩 API를 제공하지 않으므로, 무료 로컬 ONNX 모델(fastembed)로
      벡터를 생성한 뒤 pgvector(1536) 스키마에 맞게 0으로 패딩한다.
      1536차원 패딩(또는 초과 차원 절단) 직후 전체 벡터를 한 번 더 L2 정규화한다.
      저장 벡터가 단위 길이가 되어 pgvector 코사인 연산과 정렬이 일관된다.
      intfloat/multilingual-e5-large 등 비대칭 검색 모델은 EmbeddingService에서
      query:/passage: 접두사를 선택적으로 붙인다(환경변수).

설계 원칙 (ARCHITECTURE.md § 5):
  - EmbeddingProvider ABC로 제공자를 교체 가능하게 추상화
  - 유료 OpenAI·Anthropic·Grok 임베딩 호출 없음

작성일: 2026-05-01
수정일: 2026-05-01 (fastembed 기반 로컬 임베딩으로 전환)
"""

from __future__ import annotations

import asyncio
import math
import threading
from abc import ABC, abstractmethod

import numpy as np
from fastembed import TextEmbedding

from app.config import settings
from app.exceptions import VegaError, VegaErrorCode
from app.utils.logger import get_logger

logger = get_logger(__name__)

EMBEDDING_DIMENSION = 1536

_embed_lock = threading.Lock()
_fastembed_model: TextEmbedding | None = None


def _get_fastembed_model() -> TextEmbedding:
    """로컬 임베딩 모델 싱글턴을 반환한다 (스레드 안전 초기화)."""
    global _fastembed_model
    with _embed_lock:
        if _fastembed_model is None:
            _fastembed_model = TextEmbedding(model_name=settings.LOCAL_EMBEDDING_MODEL)
        return _fastembed_model


def _l2_normalize(vector: list[float]) -> list[float]:
    """벡터를 L2 단위 길이로 정규화한다."""
    norm_sq = sum(x * x for x in vector)
    if norm_sq <= 0.0:
        raise ValueError("임베딩 벡터 노름이 0입니다.")
    inv = 1.0 / math.sqrt(norm_sq)
    return [x * inv for x in vector]


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


class LocalFastEmbedEmbeddingProvider(EmbeddingProvider):
    """
    로컬 fastembed(TextEmbedding) ONNX 모델을 사용하는 임베딩 제공자.

    디스크 및 첫 실행 시 모델 다운로드가 필요할 수 있다.
    """

    async def generate(self, text: str) -> list[float]:
        """
        로컬 모델로 벡터를 계산한 뒤 1536차원으로 맞춘 다음 전체 벡터를 L2 정규화한다.

        Args:
            text: 임베딩할 텍스트(접두사는 EmbeddingService에서 조합해 전달한다)

        Returns:
            list[float]: EMBEDDING_DIMENSION 차원의 단위 L2 벡터

        Raises:
            ValueError: 계산 결과가 비어 있거나 형식이 잘못된 경우
        """
        stripped = text.strip()
        if not stripped:
            raise ValueError("임베딩할 텍스트가 비어 있습니다.")

        def _encode() -> list[float]:
            model = _get_fastembed_model()
            batches = list(model.embed([stripped]))
            if not batches:
                raise ValueError("임베딩 벡터가 비어 있습니다.")
            arr = batches[0]
            flat = np.asarray(arr, dtype=np.float64).flatten()
            return [float(x) for x in flat.tolist()]

        raw = await asyncio.to_thread(_encode)
        if not raw:
            raise ValueError("임베딩 벡터가 비어 있습니다.")

        padded = _pad_or_truncate(raw, EMBEDDING_DIMENSION)
        if len(padded) != EMBEDDING_DIMENSION:
            raise ValueError(
                f"임베딩 차원 불일치: 예상 {EMBEDDING_DIMENSION}, 실제 {len(padded)}"
            )
        return _l2_normalize(padded)


class EmbeddingService:
    """
    임베딩 추상화 서비스.

    외부에서는 이 클래스만 사용한다.
    실패 시 VegaError(VEGA_006)를 발생시킨다.
    """

    def __init__(self) -> None:
        self._provider = LocalFastEmbedEmbeddingProvider()
        self._encode_lock = asyncio.Lock()

    async def warm_up(self) -> None:
        """
        서버 기동 시 fastembed(TextEmbedding) 인스턴스를 메모리에 적재한다.

        첫 요청에서 모델 로드·ONNX 초기화로 지연이 생기는 것을 방지한다.
        """
        await asyncio.to_thread(_get_fastembed_model)
        logger.info(
            "임베딩 모델 웜업 완료",
            model_name=settings.LOCAL_EMBEDDING_MODEL,
        )

    async def generate(self, text: str, *, for_query: bool = False) -> list[float]:
        """
        텍스트를 임베딩 벡터로 변환한다.

        Args:
            text: 임베딩할 텍스트 (보통 knowledge.content_claim 또는 검색 쿼리)
            for_query: True이면 LOCAL_EMBEDDING_QUERY_PREFIX, 아니면 DOCUMENT 접두사를 붙인다.

        Returns:
            list[float]: 1536차원 임베딩 벡터

        Raises:
            VegaError(VEGA_006): 임베딩 생성 실패 시
        """
        stripped = text.strip()
        prefix = (
            settings.LOCAL_EMBEDDING_QUERY_PREFIX
            if for_query
            else settings.LOCAL_EMBEDDING_DOCUMENT_PREFIX
        )
        if not stripped:
            to_encode = ""
        elif prefix:
            to_encode = f"{prefix}{stripped}"
        else:
            to_encode = stripped

        async with self._encode_lock:
            try:
                embedding = await self._provider.generate(to_encode)
                logger.info(
                    "로컬 임베딩 생성 완료",
                    text_length=len(text),
                    for_query=for_query,
                )
                return embedding
            except Exception as e:
                logger.error("로컬 임베딩 생성 실패", error=str(e))
                raise VegaError(
                    VegaErrorCode.EMBEDDING_FAILED,
                    "임베딩 생성에 실패했습니다. 로컬 임베딩 모델을 확인해주세요.",
                ) from e


embedding_service = EmbeddingService()
