# VEGA Development Log (개발 일지)

> 중요한 설계 결정, 변경 사항, 해결한 이슈를 여기에 기록한다.
> 형식: `## [YYYY-MM-DD] - 작업 제목` → 작업 내역, 결정 사항, 이슈 & 해결

---

## [2026-05-01] - 외부 AI: Grok(xAI) 제거 · Groq 무료 LLM + 로컬 임베딩

### 작업 내역
- `GROK_*`/`OPENAI_*` 환경변수 제거 → `GROQ_API_KEY`, `GROQ_CHAT_MODEL`, `LOCAL_EMBEDDING_MODEL` 등으로 교체 (`backend/app/config.py`, `backend/.env.example`).
- 리서치: `POST /api/v1/research` 응답 필드 `grok_summary` → `ai_summary`, Groq `chat/completions` 호출 (`backend/app/api/v1/endpoints/research.py`).
- 임베딩: Groq 미지원 → `sentence-transformers` 로컬 인코딩 후 1536차원 패딩 (`embedding_service.py`). Docker에서 CPU 전용 PyTorch 선설치 (`Dockerfile`).
- 신규 에러 코드 `VEGA_011` (Groq 등 LLM HTTP 실패) — `exceptions.py`, `CLAUDE.md` 표 동기화.

### 결정 사항
- **유료 OpenAI·Anthropic·xAI 호출 금지(현 단계)**. 채팅은 Groq 무료 티어, 임베딩은 서버 로컬(모델 캐시·첫 실행 시 Hugging Face 다운로드).

---

## [2026-05-01] - 프로젝트 헌법 정립 및 문서 체계 구축

### 작업 내역
- 계획서 폴더의 기획 원본 문서(기술 스택 종합 정리 PDF, 사업계획서 v2-2 DOCX) 전체 분석 완료.
- 프로젝트 개발 기준 문서 전면 개편 및 신규 생성:
  - `.cursorrules` — AI 에이전트 행동 규칙 전면 재작성 (9개 섹션, 한국어 네이밍 규칙 포함)
  - `CLAUDE.md` — 프로젝트 헌법 확장 (에러 코드 체계 VEGA_001~008, 독스트링 형식 정의)
  - `ARCHITECTURE.md` — 신규 생성 (시스템 다이어그램, 디렉터리 구조, DB 스키마, API 명세, 로드맵)
  - `PROJECT_CONTEXT.md` — 전면 재작성 (trust_score 공식, 포인트 경제, 비즈니스 모델, 리스크 분석)

### 결정 사항
- **네이밍 규칙 확정**: 코드는 영어(snake_case/camelCase), 주석·독스트링·로그는 한국어로 통일.
- **에러 코드 체계 도입**: `VEGA_001`~`VEGA_008` 커스텀 에러 코드 정의 (CLAUDE.md § 3-3 참조).
- **모노레포 디렉터리 구조 확정**: `/backend` (FastAPI), `/frontend` (Flutter) 분리, 루트는 문서만.
- **임베딩 추상화 레이어 필수**: `EmbeddingService`로 로컬·외부 임베딩 공급자를 교체 가능하도록 설계.
- **MVP 로드맵 확정**: Week 1~5 단계별 완료 기준 설정 (ARCHITECTURE.md § 8 참조).

### 이슈 & 해결
- 기획 문서 파일명에 한글/특수문자 포함 → PowerShell 인코딩 이슈 발생
  → `Out-File -Encoding UTF8`로 경로 추출 후 Read 도구로 해결.

### 다음 할 일
- [ ] `.env.example` 파일 생성 (백엔드/프론트엔드 필요 환경변수 정의)
- [ ] `/backend` 디렉터리 초기 구조 생성 (FastAPI 프로젝트 스캐폴딩)
- [ ] `/frontend` 디렉터리 초기 구조 생성 (Flutter 프로젝트 스캐폴딩)
- [x] ~~Supabase 프로젝트 생성 및 스키마 SQL 실행 (ARCHITECTURE.md § 3 참조)~~ → SQL 파일 작성 완료
- [ ] `requirements.txt` 초안 작성 (FastAPI, Pydantic v2, supabase-py, asyncpg 등)

---

## [2026-05-01] - DB 기초 공사 (Week 1 완료)

### 작업 내역
- `backend/sql/` 폴더 신설.
- `schema.sql` 작성: 4개 테이블 + 인덱스 + 트리거 + 3개 뷰.
- `rpc_functions.sql` 작성: 5개 핵심 RPC 함수.
- `rls_policies.sql` 작성: 행 수준 보안 정책.
- `ARCHITECTURE.md` DB 스키마 섹션 → 테이블 컬럼 표 + RPC 목록으로 갱신.

### 결정 사항

**테이블 4개 확정** (기획서 3개 → 4개로 확장):
- 기존: agent, knowledge, transaction
- 추가: `knowledge_citation` — PageRank 계산과 Sybil Attack 방어에 필수.
  인용 당시의 citer trust_score 스냅샷을 보존해야 이력 불변성 + 재계산 가능성을 동시에 만족.

**컬럼 확장 근거**:
- `knowledge.content_body` 추가: 핵심 주장(content_claim)만 임베딩해 검색 품질 유지.
  본문은 content_body로 분리.
- `knowledge.domain` 추가: 타겟 도메인 필터(의료/경제/법률/과학/AI트렌드) 구현 필수.
- `knowledge.tags[]` 추가: GIN 인덱스 기반 세분화 태깅. 검색 정밀도 향상.
- `agent.bio` 추가: 미래 프로필 확장 대비 (현재 선택적).
- `agent.is_active` 추가: 하드 삭제 대신 비활성화 패턴 채택 (데이터 무결성).

**인덱스 전략 확정**:
- HNSW `m=16, ef_construction=64`: Week 2 벤치마크 후 조정 예정.
- Partial index (`WHERE status = 'active'`): 활성 지식만 인덱싱해 저장소 절약.
- 복합 인덱스: `(domain, trust_score DESC)` — 도메인 필터 + 정렬 조합 최적화.

**PageRank 수식 확정**:
```
agent_vote_score = avg(citer_trust_score_snapshot) × log₁₀(인용수+1) / log₁₀(101)
```
- log₁₀(101) ≈ 2.004: 100회 인용 시 평균 citer 신뢰점수에 수렴 (상한 정규화).
- LEAST(결과, 1.0): 소수점 오차로 인한 1.0 초과 방지.

**RLS 전략 확정**:
- FastAPI → service_role 키 사용 → RLS 우회 (쓰기 전담).
- anon 키 → RLS 적용 → 활성 지식 SELECT만 허용.
- 직접 INSERT/UPDATE/DELETE → 전면 차단 (RPC 함수만 허용).

**추가된 에러코드** (CLAUDE.md § 3-3에 추가 필요):
- `VEGA_009`: 자기 인용 시도 → 403
- `VEGA_010`: 중복 인용 시도 → 409

### 이슈 & 해결
- `transaction`이 SQL 예약어와 충돌 우려 → PostgreSQL에서는 테이블명으로 사용 가능 확인. 유지.
- `knowledge_citation → transaction` 순환 참조 위험 → 테이블 생성 순서 고정으로 해결.
  (agent → knowledge → transaction → knowledge_citation)

### 다음 할 일 (Week 1 마무리)
- [ ] Supabase 대시보드에서 SQL 파일 3개 순서대로 실행
- [x] ~~CLAUDE.md § 3-3 에러코드 표에 VEGA_009, VEGA_010 추가~~ → 완료
- [x] ~~`.env.example` 파일 생성~~ → 완료
- [x] ~~FastAPI 프로젝트 스캐폴딩 시작~~ → 완료 (아래 로그 참조)

---

## [2026-05-01] - FastAPI 백엔드 초기 구조 구축 (Week 1 완료)

### 작업 내역

`backend/` 전체 FastAPI 프로젝트 초기 구조 구축 완료.

**생성된 파일 (총 27개):**
```
backend/
├── requirements.txt       - 의존성 패키지 (fastapi, supabase, bcrypt, structlog 등)
├── Dockerfile             - Railway 배포용 (PORT 환경변수 자동 감지)
├── .env                   - 환경변수 (git 제외, Supabase URL/Key 포함)
├── .env.example           - 환경변수 키 목록 (git 포함, 설명 포함)
├── .gitignore
└── app/
    ├── main.py            - FastAPI 앱, lifespan, CORS, 예외핸들러
    ├── config.py          - pydantic-settings 환경변수 로드
    ├── dependencies.py    - API Key 인증, 관리자 인증, DB 의존성
    ├── exceptions.py      - VegaError + 에러코드 열거형 + 전역 핸들러
    ├── api/v1/
    │   ├── router.py      - v1 라우터 통합
    │   └── endpoints/
    │       ├── agent.py       - POST /register, GET /{id}/points
    │       ├── knowledge.py   - POST /publish, GET /search, GET /{id}, POST /cite
    │       └── research.py    - POST /research (Groq LLM + 시맨틱 검색)
    ├── schemas/           - Pydantic v2 모델 (common, agent, knowledge, transaction)
    ├── services/          - 비즈니스 로직 (agent, knowledge, citation, embedding)
    ├── db/                - Supabase 비동기 클라이언트 싱글턴
    └── utils/             - security(API Key 해싱), logger(structlog)
```

### 결정 사항

**비동기 클라이언트 전략 확정**:
- `acreate_client()` (supabase-py v2 async)를 FastAPI `lifespan`에서 초기화.
- 서비스 레이어는 `async def`로 통일, httpx로 외부 API 비동기 호출.

**API Key 형식 확정**: `vk_{agent_id_no_dashes}_{random_urlsafe_48bytes}`
- `agent_id`를 Key에 포함: bcrypt는 비결정적이므로 DB 조회 선행 후 `checkpw()` 검증.
- 보안 수준: 128비트 + 48바이트 랜덤 = 유추 불가 보장.
- 발급 시 원문 1회 반환, DB에는 bcrypt 해시만 저장.

**임베딩 추상화 레이어 확정**:
- `EmbeddingProvider` ABC → 현재 구현은 `LocalSentenceEmbeddingProvider`(sentence-transformers, 무료).
- `EmbeddingService.generate()`만 외부에서 호출. 공급자 변경 시 이 파일만 수정.

**로깅 전략**:
- `structlog` 사용. 개발: 컬러 콘솔, 프로덕션: JSON (Railway 로그 수집기 호환).
- 모든 로그 메시지 한국어 + 구조화된 컨텍스트(agent_id, knowledge_id 등) 포함.

**에러 처리**:
- `VegaError(code, detail)` → `vega_exception_handler` → `{ success, error_code, message }`.
- RPC 에러 메시지 파싱으로 PostgreSQL RAISE EXCEPTION → VegaErrorCode 자동 변환.

### 이슈 & 해결
- `fn_register_agent` RPC 시그니처: 사전 생성 UUID를 파라미터로 전달해
  API Key에 agent_id를 포함시키는 구조 확정.
  → `rpc_functions.sql`의 `fn_register_agent`에 `p_agent_id UUID` 파라미터 추가 필요.

### 다음 할 일 (Week 2)
- [ ] rpc_functions.sql의 fn_register_agent에 p_agent_id 파라미터 추가
- [ ] rpc_functions.sql에 fn_search_knowledge 함수 추가 (pgvector 검색)
- [ ] Supabase 대시보드에서 SQL 3파일 실행
- [ ] `pip install -r requirements.txt` 로컬 테스트
- [ ] `uvicorn app.main:app --reload`로 서버 기동 확인
- [ ] Swagger UI (/docs)에서 엔드포인트 동작 확인

---

## [이전 기록] - 개발 착수 및 환경 설정

### 작업 내역
- 프로젝트 헌법(`CLAUDE.md`) 및 아키텍처 명세(`PROJECT_CONTEXT.md`) 초안 작성.
- Supabase 프로젝트 생성 및 기본 테이블 스키마 설계.

### 결정 사항
- 초기 개발 속도를 위해 Supabase RPC를 핵심 트랜잭션 도구로 확정.
- 1인 개발 운영 효율을 위해 Railway 자동 배포 시스템 도입.

### 이슈 & 해결
- pgvector 설치 시 버전 충돌 문제 → Supabase 내장 익스텐션 활성화로 해결.
