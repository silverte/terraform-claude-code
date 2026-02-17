# OMC Notepad

## Priority
- 프로젝트 워크플로우: /tf-spec → /tf-build → /tf-plan (3단계 권장)
- 엔드투엔드 검증 미완료: 실제 AWS 계정에서 전체 플로우 테스트 필요
- versions.tf 사용 (terraform.tf 아님) - 프로젝트 의도적 선택

## Working Notes
- [2026-02-17] 구조적 개선 + 기능 확장 9개 항목 완료 (커밋 f256a60)
  - S1: references/ 공유 파일로 DRY 위반 해소
  - S2: tf-build/tf-review 자동 수정 정책 명확화
  - S3: 용어 정의 테이블 추가 (CLAUDE.md)
  - S4: tf-module-developer 태그 CLAUDE.md 기준 일치
  - F1: ALB/NLB 템플릿 + 질문 + 매핑
  - F2: Route53 DNS 템플릿 + 질문 + 매핑
  - F3: scripts/bootstrap-backend.sh (State 부트스트랩)
  - F4: docs/ci-cd-guide.md (GitHub Actions + OIDC)
  - F5: --only 옵션 (부분 재생성)
- [2026-02-17] 이전 세션: 일관성 수정 9건 완료 (커밋 a611ba1)
  - Terraform 버전 통일 (>= 1.7), 태그 대소문자, 파일 간 참조 정합성

## Manual Notes
- OMC 에이전트 타입 사용 시 `oh-my-claudecode:` 접두사 불필요 — 기본 에이전트 타입 직접 사용 (예: `ux-researcher`, `executor`)
- MCP 서버 3개 구성: Terraform, AWS Documentation, Well-Architected Security
