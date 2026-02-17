## Code Generation Rules

1. **CLAUDE.md 코딩 표준 준수**: 파일 구조, 네이밍 규칙, 필수 태그
2. **HCL 스타일 규칙 적용** (tf-module-developer에 내장된 HashiCorp Style Guide 기반 규칙):
   - 블록 내부 순서: meta-args → args → blocks → tags → lifecycle
   - `for_each` 우선 (`count`는 조건부에만)
   - 변수 순서: required → optional → sensitive (각각 알파벳순)
   - 등호 정렬, snake_case 네이밍
3. **모듈 패턴 적용** (tf-module-developer에 내장된 패턴):
   - 단일 책임 모듈, 조건부 리소스, dynamic 블록, 모듈 합성 출력 설계
   - 모든 모듈에 `tests/main.tftest.hcl` 포함 (최소 3개 테스트)
4. **State 관리 패턴**:
   - Partial backend config (`backend.hcl`) 사용
   - 환경별/단계별 state 파일 분리
   - org-foundation 단계 간 의존성: remote state 또는 SSM parameter로 참조
5. **보안 가이드라인 적용**: 시크릿 금지, 최소 권한, 암호화 기본 활성화
6. **모든 변수에 description + type + validation**
7. **모든 리소스에 태그 적용** (provider `default_tags` + 리소스별 `tags`)
8. **Provider 설정**: `default_tags` 블록으로 공통 태그 적용, 멀티 어카운트는 `assume_role` 사용
