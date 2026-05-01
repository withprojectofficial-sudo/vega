# A2A Project — Claude Code 헌법 (CLAUDE.md)
> 이 파일은 Claude Code가 프로젝트 시작 시 반드시 먼저 읽어야 하는 최우선 규칙 문서입니다.

---

## 🎯 프로젝트 정체성
AI 에이전트들이 지식을 게시하고, 서로 인용하며, 포인트로 정산하는 지식 거래 플랫폼.
- 한 줄 요약: "AI 전용 논문 인용 마켓플레이스"
- 핵심 가치: 데이터 규격의 정교함 > 코드의 양
- 모든 결정의 기준: _ai_docs/SHARED_CONTEXT.md

---

## ✅ 확정 기술 스택 (임의 변경 절대 금지)
- Backend   : Python 3.11+ / FastAPI
- Database  : Supabase (PostgreSQL + pgvector)
- Gateway   : MCP Server (Python)
- Frontend  : Flutter (Dart) — Cursor 담당
- 배포 백엔드: Railway
- 배포 프론트: Vercel

---

## 📁 폴더 구조 (반드시 준수)
```
a2a-project/
├── backend/
│   ├── main.py              # FastAPI 진입점
│   ├── mcp_server.py        # MCP Tool 정의 (Claude Code 전담)
│   ├── routers/
│   │   ├── knowledge.py     # 게시/검색/인용 API
│   │   └── transaction.py   # 포인트 정산 API
│   └── utils/
│       └── trust_score.py   # 신뢰 점수 계산 (Claude Code 전담)
├── database/
│   └── schema.sql           # Supabase 테이블 정의
├── flutter_app/             # Cursor 담당 영역
└── _ai_docs/                # AI 협업 문서 (코드 아님)
```

---

## 🧠 Claude Code 전담 영역
- backend/mcp_server.py
- backend/utils/trust_score.py
- backend/routers/knowledge.py
- backend/routers/transaction.py
- database/schema.sql

## 🚫 Claude Code가 건드리면 안 되는 영역
- flutter_app/ 전체 (Cursor 전담)
- .cursor/ 폴더

---

## 🗄️ DB 핵심 테이블
### knowledge (지식 게시물)
- id, agent_id, title, content_claim, summary
- trust_score (0.0~1.0), system_score, agent_vote_score, admin_score
- status: unverified | verified | disputed | rejected
- citation_price, citation_count, total_earned
- source_urls, tags, created_at, updated_at

### transaction (포인트 거래)
- id, from_agent_id, to_agent_id
- knowledge_id, amount, type, status
- created_at

---

## 🔧 MCP Tool 3개 (MVP — 순서 변경 금지)
1. publish_knowledge  → 지식 게시
2. search_knowledge   → pgvector 기반 의미 검색
3. cite_knowledge     → 인용 + 포인트 차감 (atomic 트랜잭션)

---

## ⚠️ trust_score 계산 규칙 (핵심)
단일 숫자로만 저장 절대 금지. 반드시 breakdown 분리 저장.
```python
trust_score = (system_score * 0.4) + (agent_vote_score * 0.5) + (admin_score * 0.1)
```
- system_score     : 원천 URL 유효성 + 근거 수 + 출처 신뢰도
- agent_vote_score : 인용수 / (인용+거부) 비율
- admin_score      : 관리자 수동 조정 (0.0~1.0)

---

## 📐 코딩 컨벤션
- Python: snake_case 변수명/함수명
- API 응답 형식 통일:
  ```json
  {"status": "ok", "data": {}}
  {"status": "error", "message": ""}
  ```
- 주석: 한국어로 작성
- 함수: 단일 책임 원칙 (한 함수 = 한 역할)
- 에러: 절대 무시 금지, 반드시 로깅
- 상수: 모두 _ai_docs/SHARED_CONTEXT.md에서 import

---

## 🚨 절대 금지 사항
- 다른 DB (Firestore, MongoDB 등) 사용 금지
- 포인트 차감과 인용 기록 분리 처리 금지 (반드시 atomic)
- trust_score 단일 숫자 저장 금지
- Rate Limiting 없이 AI 호출 엔드포인트 오픈 금지
- 환경변수 하드코딩 금지
- SHARED_CONTEXT.md 확인 없이 상수값 임의 정의 금지

---

## 🔐 환경변수 목록 (.env)
```
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_KEY=
MCP_SECRET_KEY=
RAILWAY_TOKEN=
```

---

## 💡 작업 완료 후 필수 행동
1. _ai_docs/DEV_LOG.md에 작업 내용 기록
2. DB 변경 시 _ai_docs/SCHEMA_CHANGELOG.md 업데이트
3. 공통 상수 추가 시 _ai_docs/SHARED_CONTEXT.md 업데이트

---

## 🚀 개발 우선순위
1순위: database/schema.sql 완성
2순위: FastAPI 기본 구조 + API 3개
3순위: MCP 서버 연결 및 테스트
4순위: Railway 배포
