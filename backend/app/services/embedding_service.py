"""
파일명: embedding_service.py
위치: backend/app/services/embedding_service.py
레이어: Service (임베딩 추상화)
역할: 텍스트를 1536차원 벡터로 변환하는 임베딩 서비스.
      장기적 안정성을 위해 로컬 경량 모델(ONNX)을 사용하며, 
      pgvector(1536) 규격에 맞게 자동 패딩 및 L2 정규화를 수행한다.

수정 사항:
  1. OOM 방지를 위한 모델 로드 최적화
  2. 1536차원 고정 매핑 로직 강화
  3. 스레드 안전성 및 에러 핸들링 고도화
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

# pgvector DB 스키마와 일치해야 함
EMBEDDING_DIMENSION = 1536

_embed_lock = threading.Lock()
_fastembed_model: TextEmbedding | None = None


def _get_fastembed_model() -> TextEmbedding:
    """로컬 임베딩 모델 싱글턴 반환 (OOM 방지를 위해 경량 모델 권장)"""
    global _fastembed_model
    with _embed_lock:
        if _fastembed_model is None:
            # 설정에서 모델명을 가져오되, 기본값으로 가장 가벼운 모델을 지정
            model_name = getattr(settings, "LOCAL_EMBEDDING_MODEL", "BAAI/bge-small-en-v1.5")
            try:
                _fastembed_model = TextEmbedding(model_name=model_name)
                logger.info(f"임베딩 모델 로드 성공: {model_name}")
            except Exception as e:
                logger.error(f"모델 로드 실패: {str(e)}")
                # 최후의 수단: 절대적으로 가벼운 모델로 강제 전환
                _fastembed_model = TextEmbedding(model_name="BAAI/bge-small-en-v1.5")
        return _fastembed_model


def _l2_normalize(vector: list[float]) -> list[float]:
    """벡터를 L2 단위 길이로 정규화하여 코사인 유사도 연산 성능 최적화"""
    norm_sq = sum(x * x for x in vector)
    if norm_sq <= 0.0:
        return [0.0] * len(vector)
    inv = 1.0 / math.sqrt(norm_sq)
    return [x * inv for x in vector]


def _pad_or_truncate(vector: list[float], dim: int) -> list[float]:
    """출력 차원을 pgvector(1536)에 맞춤 (Zero-padding/Truncation)"""
    current_len = len(vector)
    if current_len == dim:
        return vector
    if current_len > dim:
        return vector[:dim]
    return vector + [0.0] * (dim - current_len)


class EmbeddingProvider(ABC):
    """임베딩 제공자 추상화 (향후 OpenAI/Supabase API 전환용)"""
    @abstractmethod
    async def generate(self, text: str) -> list[float]:
        pass


class LocalFastEmbedProvider(EmbeddingProvider):
    """로컬 자원 최적화형 임베딩 제공자"""
    async def generate(self, text: str) -> list[float]:
        stripped = text.strip()
        if not stripped:
            raise ValueError("텍스트가 비어 있습니다.")

        def _encode() -> list[float]:
            model = _get_fastembed_model()
            # list(model.embed())는 제너레이터를 리스트로 변환함
            batches = list(model.embed([stripped]))
            if not batches:
                raise ValueError("벡터 생성 실패")
            
            arr = batches[0]
            flat = np.asarray(arr, dtype=np.float64).flatten()
            return [float(x) for x in flat.tolist()]

        try:
            raw = await asyncio.to_thread(_encode)
            padded = _pad_or_truncate(raw, EMBEDDING_DIMENSION)
            return _l2_normalize(padded)
        except Exception as e:
            logger.error(f"임베딩 생성 엔진 오류: {str(e)}")
            raise


class EmbeddingService:
    """비즈니스 로직에서 사용하는 임베딩 통합 서비스"""
    def __init__(self) -> None:
        self._provider = LocalFastEmbedProvider()
        self._encode_lock = asyncio.Lock()

    async def warm_up(self) -> None:
        """서버 기동 시 모델을 메모리에 미리 적재 (Cold Start 방지)"""
        try:
            await asyncio.to_thread(_get_fastembed_model)
            logger.info("임베딩 서비스 웜업 성공")
        except Exception as e:
            logger.error(f"임베딩 서비스 웜업 실패: {str(e)}")

    async def generate(self, text: str, *, for_query: bool = False) -> list[float]:
        """텍스트를 1536차원 벡터로 변환"""
        if not text.strip():
            return [0.0] * EMBEDDING_DIMENSION

        # 접두사 처리 로직 (환경 설정 반영)
        prefix = (
            getattr(settings, "LOCAL_EMBEDDING_QUERY_PREFIX", "") 
            if for_query 
            else getattr(settings, "LOCAL_EMBEDDING_DOCUMENT_PREFIX", "")
        )
        to_encode = f"{prefix}{text.strip()}" if prefix else text.strip()

        async with self._encode_lock:
            try:
                return await self._provider.generate(to_encode)
            except Exception as e:
                logger.error("임베딩 생성 최종 실패", error=str(e))
                raise VegaError(
                    VegaErrorCode.EMBEDDING_FAILED,
                    "시스템 일시적 오류로 임베딩을 생성할 수 없습니다.",
                ) from e

# 싱글턴 인스턴스 노출
embedding_service = EmbeddingService()