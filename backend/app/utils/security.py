"""
파일명: security.py
위치: backend/app/utils/security.py
레이어: Utils (보안 유틸리티)
역할: API Key 생성, bcrypt 해싱, 검증 등 보안 관련 유틸리티 함수를 제공한다.

API Key 설계:
  형식: vk_{agent_id_no_dashes}_{random_urlsafe_48bytes}
  예시: vk_550e8400e29b41d4a716446655440000_Xm3kL9...

  - "vk_" 접두사로 Vega API Key임을 식별
  - agent_id (대시 제거 UUID 32자)로 빠른 DB 조회 (bcrypt는 비결정적이므로 필수)
  - random_urlsafe(48) = 64자 랜덤 문자열로 유추 불가 보장

작성일: 2026-05-01
"""

import secrets
import uuid

import bcrypt

# API Key 접두사 (식별용)
_API_KEY_PREFIX = "vk"

# 구분자
_SEPARATOR = "_"


def generate_api_key(agent_id: str) -> tuple[str, str]:
    """
    API Key 원문과 bcrypt 해시를 생성한다.

    발급 흐름:
      1. agent_id의 대시를 제거해 32자 UUID 문자열 생성
      2. 64자 랜덤 문자열 생성 (48바이트 urlsafe)
      3. 원문 = "vk_{agent_id_no_dashes}_{random}"
      4. 해시 = bcrypt(원문, gensalt())
      5. DB에는 해시만 저장, 원문은 1회만 반환

    Args:
        agent_id: 에이전트의 UUID 문자열 (하이픈 포함)

    Returns:
        tuple[str, str]: (원문 API Key, bcrypt 해시값)
    """
    agent_id_no_dashes = agent_id.replace("-", "")
    random_part = secrets.token_urlsafe(48)  # 64자 랜덤 문자열
    plain_key = f"{_API_KEY_PREFIX}{_SEPARATOR}{agent_id_no_dashes}{_SEPARATOR}{random_part}"
    hashed_key = _hash_with_bcrypt(plain_key)
    return plain_key, hashed_key


def _hash_with_bcrypt(plain_key: str) -> str:
    """
    문자열을 bcrypt로 해싱한다.

    bcrypt는 매 호출마다 다른 솔트를 사용하므로 비결정적임.
    동일 입력이라도 매번 다른 해시가 생성됨.

    Args:
        plain_key: 해싱할 원문 문자열

    Returns:
        str: bcrypt 해시 문자열 (60자)
    """
    hashed = bcrypt.hashpw(plain_key.encode("utf-8"), bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_api_key_hash(plain_key: str, stored_hash: str) -> bool:
    """
    API Key 원문과 DB에 저장된 bcrypt 해시를 비교 검증한다.

    dependencies.py의 get_current_agent()에서 호출된다.

    Args:
        plain_key: 클라이언트가 전달한 API Key 원문
        stored_hash: DB에 저장된 bcrypt 해시

    Returns:
        bool: 검증 성공 여부
    """
    try:
        return bcrypt.checkpw(plain_key.encode("utf-8"), stored_hash.encode("utf-8"))
    except Exception:
        # 잘못된 해시 형식 등 예외는 False로 처리 (보안상 오류 노출 금지)
        return False


def parse_agent_id_from_key(plain_key: str) -> str | None:
    """
    API Key 원문에서 agent_id를 추출한다.

    bcrypt는 비결정적이므로 직접 DB WHERE 조건에 사용할 수 없음.
    agent_id를 Key에 포함시켜 먼저 에이전트를 조회한 후 bcrypt 검증을 수행함.

    Args:
        plain_key: "vk_{agent_id_no_dashes}_{random}" 형식의 API Key

    Returns:
        str | None: UUID 형식의 agent_id (파싱 실패 시 None)
    """
    parts = plain_key.split(_SEPARATOR, 2)  # 최대 3조각으로 분리

    # 형식 검증: ["vk", "32자UUID", "random"] 이어야 함
    if len(parts) != 3 or parts[0] != _API_KEY_PREFIX:
        return None

    agent_id_no_dashes = parts[1]

    # UUID 형식 복원 (8-4-4-4-12)
    if len(agent_id_no_dashes) != 32:
        return None

    try:
        agent_uuid = uuid.UUID(agent_id_no_dashes)
        return str(agent_uuid)  # "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" 형식으로 반환
    except ValueError:
        return None
