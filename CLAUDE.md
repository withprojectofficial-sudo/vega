# VEGA Project Constitution (프로젝트 헌법)

> 이 파일은 AI 에이전트(Claude, Cursor 등)가 코드 생성 시 반드시 준수해야 할 최우선 기준서입니다.
> 새로운 모듈 개발 전 반드시 `ARCHITECTURE.md`를 먼저 확인하세요.

---

## 1. 프로젝트 정체성

| 항목 | 내용 |
|------|------|
| **서비스명** | Vega |
| **목표** | 인용 기반 지식 신뢰 인프라 구축 (AI+Human 공존 생태계) |
| **핵심 가치** | 유용성, 유효성, 상호운용성, 적시성, 확장성, 안정성 |
| **개발 방식** | 1인 개발 Micro-SaaS (Cursor AI + Claude Code 적극 활용) |
| **문서 제작자** | 이하늘 (Vega Project, 2026.04) |

---

## 2. 기술 스택 (확정)

| 레이어 | 기술 | 버전 | 비고 |
|--------|------|------|------|
| **Backend** | Python + FastAPI | 3.11+ / 0.110+ | Pydantic v2 필수 |
| **Frontend** | Flutter Web (Dart) | Dart 3.x | go_router, riverpod, dio |
| **Database** | Supabase (PostgreSQL + pgvector) | PG 15 | HNSW 인덱스, RLS 적용 |
| **AI Engine** | Groq API (무료 티어, OpenAI 호환 REST) | Llama 계열 등 | 리서치·관리 파이프라인 LLM |
| **Embedding** | 로컬 sentence-transformers (무료) | 패딩해 1536차원 저장 | Groq는 임베딩 API 미제공; `EmbeddingService` 유지 |
| **Backend 배포** | Railway | - | GitHub push 자동 배포 |
| **Frontend 배포** | Vercel | - | dart-define 환경변수 |
| **에러 모니터링** | Sentry | - | Week 5 연동 예정 |

---

## 3. 코드 작성 원칙 (CRITICAL — 반드시 준수)

### 3-1. 타입 안전성
- `Any` 타입 사용 **절대 금지**.
- 모든 Python 함수에 타입 힌트와 `-> ReturnType` 명시.
- Pydantic v2 `BaseModel` 상속으로 요청/응답 모델 정의.
- Dart 함수는 `dynamic` 타입 사용 금지, 명시적 타입 선언 필수.

### 3-2. 원자적 트랜잭션 (Atomic Transaction)
- **포인트 차감 + 인용 카운트 증가**는 반드시 Supabase RPC 단일 호출로 처리.
- 분리 호출 시 부분 실패로 인한 데이터 불일치 발생 — **절대 분리 금지**.
- 실패 시 전체 롤백 보장 (RPC 내부에서 BEGIN/ROLLBACK 처리).

### 3-3. 에러 처리 체계
커스텀 예외 클래스를 사용하며, `HTTPException` 직접 raise 금지.

| 에러 코드 | 상황 | HTTP 상태 |
|-----------|------|-----------|
| `VEGA_001` | 에이전트 인증 실패 (API Key 불일치) | 401 |
| `VEGA_002` | 포인트 부족 (인용 시) | 402 |
| `VEGA_003` | 지식 상태 오류 (pending/rejected 지식 인용 시도) | 403 |
| `VEGA_004` | 지식 미존재 | 404 |
| `VEGA_005` | 트랜잭션 실패 (RPC 롤백) | 500 |
| `VEGA_006` | 임베딩 생성 실패 (로컬 모델·환경 오류) | 503 |
| `VEGA_007` | 관리자 인증 실패 (X-Admin-Token 불일치) | 401 |
| `VEGA_008` | 중복 에이전트 등록 | 409 |
| `VEGA_009` | 자기 인용 시도 (발행자와 인용자 동일) | 403 |
| `VEGA_010` | 중복 인용 시도 (동일 지식 재인용 불가) | 409 |
| `VEGA_011` | 외부 LLM 호출 실패 (예: Groq chat/completions) | 503 |

### 3-4. 즉시 배포 가능 상태 유지
- 모든 환경변수는 `.env.example`에 키 이름과 설명 기재.
- 실제 값(API Key, DB URL 등)은 `.env`에만 저장, git 커밋 금지.
- 코드에 `TODO: 나중에 구현` 주석 남기지 않기 — 구현하거나 이슈로 등록.

---

## 4. 네이밍 & 언어 규칙

| 항목 | 규칙 | 예시 |
|------|------|------|
| Python 변수/함수 | `snake_case` 영어 | `trust_score`, `get_knowledge` |
| Python 클래스 | `PascalCase` 영어 | `KnowledgePublishRequest` |
| Python 주석/독스트링 | **한국어** | `"""지식을 발행하고 임베딩을 생성한다."""` |
| Python 로그 메시지 | **한국어** | `logger.info("지식 발행 완료: {id}")` |
| Dart 변수/함수 | `camelCase` 영어 | `trustScore`, `getKnowledge` |
| Dart 클래스/위젯 | `PascalCase` 영어 | `KnowledgeDetailPage` |
| Dart 주석 | **한국어** | `/// 지식 상세 화면 위젯` |
| SQL 컬럼/테이블 | `snake_case` 영어 | `content_embedding`, `agent_id` |
| 환경변수 | `UPPER_SNAKE_CASE` 영어 | `SUPABASE_URL`, `GROQ_API_KEY` |

---

## 5. 문서화 규칙

### Python 독스트링 형식
```python
def cite_knowledge(knowledge_id: str, agent_id: str) -> CitationResult:
    """
    지식을 인용하고 포인트를 정산한다.
    
    인용자의 포인트를 차감하고 발행자에게 지급하는 원자적 트랜잭션을 실행한다.
    실패 시 전체 롤백되므로 부분 반영 없음.
    
    Args:
        knowledge_id: 인용할 지식의 UUID
        agent_id: 인용하는 에이전트의 UUID
        
    Returns:
        CitationResult: 트랜잭션 결과 및 갱신된 포인트 잔액
        
    Raises:
        VegaError(VEGA_002): 포인트 부족 시
        VegaError(VEGA_003): 지식이 active 상태가 아닐 시
        VegaError(VEGA_005): RPC 트랜잭션 실패 시
    """
```

### 새 파일 최상단 헤더 형식
```python
"""
파일명: knowledge_service.py
위치: backend/app/services/knowledge_service.py
레이어: Service (비즈니스 로직)
역할: 지식 발행, 검색, 인용 관련 핵심 비즈니스 로직 처리
작성일: 2026-05-01
"""
```

---

## 6. 커뮤니케이션 규칙

- 새로운 모듈 개발 전 반드시 `ARCHITECTURE.md`를 확인한다.
- 중요한 설계 결정이나 변경 사항은 즉시 `DEV_LOG.md`에 기록한다.
- 에러 코드 추가/변경 시 이 파일의 § 3-3 에러 코드 표를 업데이트한다.
- 기술 스택 변경은 `ARCHITECTURE.md`와 이 파일을 동시에 업데이트한다.
