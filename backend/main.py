"""
파일명: main.py
위치: backend/main.py
레이어: Core (로컬 진입점)
역할: 개발 PC에서 `python main.py`로 ASGI 서버를 바로 띄운다 (기본 8000 포트).
      Railway·프로덕션은 여전히 uvicorn app.main:app 모듈 호출을 사용한다.
작성일: 2026-05-01
"""

import uvicorn

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=False)
