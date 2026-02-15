# Comprehensive Terraform Review

보안, 비용, 모범 사례에 대한 종합적인 Terraform 코드 리뷰를 수행합니다.

## Workflow Position
이 커맨드는 `/tf-spec` → `/tf-generate` → **`/tf-review`** → `/tf-plan` 워크플로우에서 코드 품질 검증 단계입니다.
`/tf-generate`로 코드가 생성된 후, `/tf-plan` 전에 실행하세요.

## Usage
```
/project:tf-review <path>
```

## Arguments
- **path**: 리뷰할 경로 (모듈 또는 환경 디렉토리)

## Examples
```
/project:tf-review modules/vpc
/project:tf-review environments/prod
/project:tf-review .
```

## MCP 서버 활용

리뷰 과정에서 MCP 서버를 활용하여 최신 보안 기준과 베스트 프랙티스를 적용합니다.

### Well-Architected Security MCP (`awslabs.well-architected-security-mcp-server`)
- **Security Pillar 평가**: 리뷰 대상 코드가 Well-Architected Security Pillar의 베스트 프랙티스를 준수하는지 자동 평가
- **활용 시점**: Phase 1(Security Review) 시작 시 호출하여 평가 기준으로 사용
  ```
  예: IAM 정책 리뷰 시 → SEC01(보안 기반) 기준 평가
  예: 데이터 보호 리뷰 시 → SEC08(저장 중 데이터 보호), SEC09(전송 중 데이터 보호) 평가
  예: 인시던트 대응 리뷰 시 → SEC10(인시던트 대응) 기준 확인
  ```

### AWS Documentation MCP (`awslabs.aws-documentation-mcp-server`)
- **최신 보안 권장 사항 조회**: IAM 정책 베스트 프랙티스, SCP 가이드라인, 암호화 요구사항 등
- **서비스별 보안 설정 확인**: 리소스별 권장 보안 구성 참조
- **활용 시점**: Phase 1(Security Review) 및 Phase 4(Best Practices) 시
  ```
  예: S3 버킷 보안 리뷰 시 → S3 보안 베스트 프랙티스 문서 참조
  예: EKS 보안 리뷰 시 → EKS 보안 가이드 참조
  ```

### Terraform MCP (`awslabs.terraform-mcp-server`)
- **deprecated 속성 확인**: 사용 중인 리소스 속성이 deprecated되지 않았는지 검증
- **최신 권장 설정 확인**: 리소스별 최신 보안 관련 속성 확인
- **활용 시점**: Phase 3(Code Quality) 시
  ```
  예: aws_s3_bucket 리뷰 시 → bucket ACL deprecated 여부 확인
  예: aws_instance 리뷰 시 → metadata_options의 최신 권장 값 확인
  ```

## Review Process

### Phase 1: Security Review
**tf-security-reviewer 서브에이전트 호출**

**Well-Architected Security MCP 호출**: Security Pillar 기반 평가 체크리스트를 조회하여 리뷰 기준으로 활용합니다.

#### IAM 정책 검토
- 와일드카드 사용 여부
- 최소 권한 원칙 준수
- Trust Policy 범위

#### 네트워크 보안 검토
- Security Group 규칙
- NACL 설정
- VPC Flow Logs

#### 암호화 설정 검토
- S3 버킷 암호화
- EBS 암호화
- RDS 암호화
- KMS 키 관리

#### 컴플라이언스 검토
- CloudTrail 설정
- Config Rules
- GuardDuty

### Phase 2: Cost Analysis
**tf-cost-analyzer 서브에이전트 호출**

#### 리소스 비용 분석
- Compute (EC2, Lambda, EKS)
- Storage (S3, EBS, EFS)
- Database (RDS, DynamoDB)
- Network (NAT, TGW, Data Transfer)

#### 최적화 기회 식별
- Right-sizing 후보
- Reserved/Savings Plans 후보
- Spot Instance 후보
- 스토리지 티어링

### Phase 3: Code Quality
**자동화된 도구 실행 + Terraform MCP로 deprecated 속성 검증**

```bash
# 포맷팅 검사
terraform fmt -check -recursive $PATH

# 문법 검증
terraform validate

# 린팅
tflint --recursive $PATH

# 보안 스캔
tfsec $PATH --minimum-severity MEDIUM

# 정책 검사
checkov -d $PATH --framework terraform
```

### Phase 4: Best Practices
**수동 검토 항목**

#### 모듈 구조
- [ ] 표준 파일 구조 준수
- [ ] 적절한 추상화 수준
- [ ] 재사용 가능성

#### 변수 정의
- [ ] 모든 변수에 description
- [ ] 적절한 type 지정
- [ ] validation 블록 사용
- [ ] sensitive 플래그

#### 출력 정의
- [ ] 필요한 출력 제공
- [ ] 설명적인 description

#### 문서화
- [ ] README.md 존재
- [ ] 사용 예제 제공
- [ ] CHANGELOG.md 관리

#### 태깅
- [ ] 필수 태그 적용
- [ ] 일관된 태깅 전략

### Phase 5: Documentation Review

#### README 검토
- 모듈/환경 설명
- 사용 방법
- 변수 테이블
- 출력 테이블

#### 예제 검토
- 기본 예제 존재
- 전체 옵션 예제 존재
- 예제 실행 가능

## Output Format

```markdown
# Terraform Review Report

## 📋 Summary

| Category | Status | Findings |
|----------|--------|----------|
| Security | 🔴/🟡/🟢 | X issues |
| Cost | 🔴/🟡/🟢 | X issues |
| Code Quality | 🔴/🟡/🟢 | X issues |
| Best Practices | 🔴/🟡/🟢 | X issues |
| Documentation | 🔴/🟡/🟢 | X issues |

**Overall Score: X/100**

---

## 🔒 Security Review

### Critical Findings
1. **[CRITICAL]** Finding title
   - Resource: `resource_type.name`
   - File: `path/to/file.tf:line`
   - Issue: Description
   - Remediation: 
   ```hcl
   # Fixed code
   ```

### High Findings
...

### Recommendations
1. Immediate action required
2. Short-term improvements
3. Long-term enhancements

---

## 💰 Cost Analysis

### Current Estimated Cost
| Resource Type | Monthly Cost |
|--------------|--------------|
| Compute | $XXX |
| Storage | $XXX |
| Network | $XXX |
| **Total** | **$XXX** |

### Optimization Opportunities
| Opportunity | Current | Optimized | Savings |
|-------------|---------|-----------|---------|
| Right-size EC2 | $XXX | $XXX | $XXX |
| Reserved Instances | $XXX | $XXX | $XXX |

**Total Potential Savings: $XXX/month**

---

## 🔧 Code Quality

### Automated Scan Results
| Tool | Status | Issues |
|------|--------|--------|
| terraform fmt | ✅/❌ | X |
| terraform validate | ✅/❌ | X |
| tflint | ✅/❌ | X |
| tfsec | ✅/❌ | X |
| checkov | ✅/❌ | X |

### Issues Found
1. Issue description
   - File: `path/to/file.tf`
   - Fix: Description

---

## 📚 Best Practices

### Module Structure: ✅/❌
- [x] Standard file structure
- [ ] Issue found

### Variables: ✅/❌
- [x] Descriptions provided
- [ ] Issue found

### Documentation: ✅/❌
- [x] README exists
- [ ] Issue found

---

## 🎯 Action Items

### Priority 1 (Immediate)
- [ ] Fix critical security issues
- [ ] Address high-severity findings

### Priority 2 (This Sprint)
- [ ] Implement cost optimizations
- [ ] Fix code quality issues

### Priority 3 (Backlog)
- [ ] Improve documentation
- [ ] Enhance test coverage

---

## 📎 Appendix

### Files Reviewed
- file1.tf
- file2.tf
- ...

### Tools Used
- tfsec v1.x.x
- checkov v3.x.x
- tflint v0.x.x
- infracost v0.x.x
```

## Severity Definitions

| Level | Color | Description |
|-------|-------|-------------|
| Critical | 🔴 | 즉시 수정 필요, 배포 차단 |
| High | 🟠 | 프로덕션 전 수정 필요 |
| Medium | 🟡 | 다음 스프린트에 수정 |
| Low | 🟢 | 개선 권장 |

## Post-Review Actions

1. **Critical/High 이슈 발견 시**
   - 이슈 티켓 생성
   - 담당자 할당
   - 배포 차단

2. **Medium 이슈 발견 시**
   - 백로그에 추가
   - 우선순위 지정

3. **리뷰 완료 후**
   - 리뷰 결과 문서화
   - 팀 공유
   - 개선 계획 수립
