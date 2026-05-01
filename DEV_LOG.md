# VEGA Development Log (개발 일지)

> 중요한 설계 결정, 변경 사항, 해결한 이슈를 여기에 기록한다.
> 형식: `## [YYYY-MM-DD] - 작업 제목` → 작업 내역, 결정 사항, 이슈 & 해결

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
- **임베딩 추상화 레이어 필수**: `EmbeddingService`로 Grok/OpenAI 교체 가능하도록 설계.
- **MVP 로드맵 확정**: Week 1~5 단계별 완료 기준 설정 (ARCHITECTURE.md § 8 참조).

### 이슈 & 해결
- 기획 문서 파일명에 한글/특수문자 포함 → PowerShell 인코딩 이슈 발생
  → `Out-File -Encoding UTF8`로 경로 추출 후 Read 도구로 해결.

### 다음 할 일
- [ ] `.env.example` 파일 생성 (백엔드/프론트엔드 필요 환경변수 정의)
- [ ] `/backend` 디렉터리 초기 구조 생성 (FastAPI 프로젝트 스캐폴딩)
- [ ] `/frontend` 디렉터리 초기 구조 생성 (Flutter 프로젝트 스캐폴딩)
- [ ] Supabase 프로젝트 생성 및 스키마 SQL 실행 (ARCHITECTURE.md § 3 참조)
- [ ] `requirements.txt` 초안 작성 (FastAPI, Pydantic v2, supabase-py, asyncpg 등)

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
