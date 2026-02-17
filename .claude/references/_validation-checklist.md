# 코드 검증 체크리스트

## 스타일 규칙 검증
- [ ] 리소스 블록 내부 순서: meta-args → args → blocks → tags → lifecycle
- [ ] 복수 리소스 생성에 `for_each` 사용 (`count`는 조건부 생성에만)
- [ ] 변수에 `description`, `type` 존재, 주요 변수에 `validation` 블록
- [ ] 등호(`=`) 정렬 (연속된 인수)
- [ ] `sensitive = true` 적용 (패스워드, 키 등)
- [ ] Provider `default_tags` 블록 사용

## org-foundation 검증 경로

각 단계별 fmt + validate:
```bash
cd environments/org-foundation/01-organization && terraform fmt -recursive && terraform validate
cd environments/org-foundation/02-security-baseline && terraform fmt -recursive && terraform validate
cd environments/org-foundation/03-shared-networking && terraform fmt -recursive && terraform validate
```
