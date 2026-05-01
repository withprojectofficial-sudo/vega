"""
파일명: config.py
위치: backend/app/config.py
레이어: Core (설정)
역할: .env 파일에서 환경변수를 로드하고 앱 전역 설정을 제공한다.
      pydantic-settings를 사용해 타입 안전성과 유효성 검증을 보장한다.
작성일: 2026-05-01
"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Vega 백엔드 전역 설정 클래스.

    .env 파일에서 자동으로 환경변수를 로드하며,
    누락된 필수 변수가 있을 경우 앱 시작 시 즉시 오류를 발생시킨다.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,  # 환경변수 대소문자 구분
    )

    # ── Supabase ──
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str

    # ── AI 엔진 ──
    GROK_API_KEY: str
    GROK_EMBEDDING_MODEL: str = "text-embedding-ada-002"
    OPENAI_API_KEY: str = ""  # 임베딩 폴백용 (선택적)

    # ── 관리자 인증 ──
    # X-Admin-Token 헤더 검증용. 최소 32자 이상 권장.
    ADMIN_SECRET_TOKEN: str

    # ── 앱 설정 ──
    ENVIRONMENT: str = "development"
    LOG_LEVEL: str = "INFO"

    # ── CORS ──
    # pydantic-settings는 list[str]를 .env에서 JSON으로 디코딩하므로,
    # .env.example과 같이 쉼표 구분 문자열을 쓰려면 str로 받은 뒤 리스트로 변환한다.
    CORS_ORIGINS_STR: str = Field(
        default="http://localhost:3000",
        validation_alias="CORS_ORIGINS",
    )

    @property
    def CORS_ORIGINS(self) -> list[str]:
        """쉼표로 구분된 Origin 문자열을 리스트로 반환한다."""
        return [o.strip() for o in self.CORS_ORIGINS_STR.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        """프로덕션 환경 여부를 반환한다."""
        return self.ENVIRONMENT == "production"

    @property
    def grok_api_base_url(self) -> str:
        """Grok (xAI) API 베이스 URL을 반환한다."""
        return "https://api.x.ai/v1"

    @property
    def openai_api_base_url(self) -> str:
        """OpenAI API 베이스 URL을 반환한다."""
        return "https://api.openai.com/v1"


@lru_cache
def get_settings() -> Settings:
    """
    Settings 싱글턴을 반환한다.

    lru_cache로 최초 1회만 .env를 파싱하며, 이후 캐시된 인스턴스를 반환한다.

    Returns:
        Settings: 앱 전역 설정 인스턴스
    """
    return Settings()


# 편의를 위한 모듈 수준 인스턴스 (import해서 바로 사용 가능)
settings: Settings = get_settings()
