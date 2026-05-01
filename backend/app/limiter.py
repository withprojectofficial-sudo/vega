"""
파일명: limiter.py
위치: backend/app/limiter.py
레이어: Core (속도 제한)
역할: slowapi 기반 IP(클라이언트 주소) 단위 Rate Limit 설정을 제공한다.
      main.py에서 app.state.limiter로 등록하고 SlowAPIMiddleware와 함께 사용한다.
작성일: 2026-05-02
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

# 기본 한도: 데코레이터가 없는 엔드포인트는 미들웨어가 default_limits를 적용한다.
# 리버스 프록시 뒤에서는 X-Forwarded-For 등을 반영하는 key_func로 교체하는 것을 권장한다.
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["20/minute"],
    headers_enabled=True,
)
