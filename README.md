# AWS Multi-Account Terraform Generator

대화형으로 인프라 요구사항을 수집하고, Terraform 코드를 자동 생성하는 Claude Code 프로젝트입니다.

AWS 전문 지식이 없어도 대화를 통해 엔터프라이즈급 멀티 어카운트 인프라를 구성할 수 있습니다.

## 주요 기능

- **대화형 요구사항 수집** - 질문에 답하면 YAML 명세서가 자동 생성됩니다
- **Terraform 코드 자동 생성** - 명세서를 기반으로 모듈과 환경 코드를 생성합니다
- **보안/비용/품질 자동 리뷰** - 생성된 코드를 전문 에이전트가 검토합니다
- **조직 거버넌스 지원** - AWS Organizations, OU, SCP, 중앙 보안 서비스를 포함합니다
- **AWS MCP 서버 연동** - Terraform Provider 문서, AWS 공식 문서, Well-Architected 보안 평가를 실시간 참조합니다

## 사전 요구사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI 설치
- [uv](https://docs.astral.sh/uv/) 설치 (MCP 서버 실행용)
- Terraform >= 1.5.0
- AWS CLI 설정 완료 (대상 계정 접근 가능)

```bash
# uv 설치
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## 빠른 시작

### 1. 프로젝트 클론 및 Claude Code 실행

```bash
git clone https://github.com/silverte/terraform-claude-code.git
cd terraform-claude-code
claude
```

### 2. 워크로드 배포 (VPC, EC2, RDS 등)

```bash
# Step 1: 대화형으로 요구사항 수집
/tf-spec my-web-service

# Step 2: 코드 생성 + 품질 검증 (권장)
/tf-build specs/my-web-service-spec.yaml

# Step 3: Plan 확인
/tf-plan dev
```

> 개별 실행이 필요한 경우: `/tf-generate` → `/tf-review` → `/tf-plan`

### 3. 조직 기반 설정 (Organizations, SCP, 보안)

```bash
# Step 1: 대화형으로 조직 설정 수집
/tf-spec my-org
# → "조직 기반 설정" 선택

# Step 2: 3단계 코드 생성 + 품질 검증 (권장)
/tf-build specs/my-org-spec.yaml

# Step 3: 순서대로 Plan 확인
/tf-plan management
```

## 워크플로우

**권장 (3단계 - `/tf-build` 사용):**
```
/tf-spec     대화형 요구사항 수집        specs/{name}-spec.yaml
    ↓
/tf-build    코드 생성 + 품질 검증       environments/ + modules/ + 리뷰 리포트
    ↓
/tf-plan     terraform plan             변경사항 확인
```

**개별 실행 (4단계):**
```
/tf-spec → /tf-generate → /tf-review → /tf-plan
```

## 커맨드 상세

### `/tf-spec <name>`

대화를 통해 인프라 요구사항을 수집합니다.

**프로젝트 타입 선택:**
- **워크로드 배포** - VPC, EC2, ECS, EKS, RDS, S3 등 애플리케이션 인프라
- **조직 기반 설정** - AWS Organizations, OU, SCP, 중앙 보안, Transit Gateway

**워크로드 수집 항목:**

| 카테고리 | 포함 리소스 |
|----------|------------|
| 네트워크 | VPC, 서브넷, NAT Gateway, Transit Gateway, VPN, VPC Peering |
| 컴퓨팅 | EC2, ECS(Fargate), EKS, Lambda, Auto Scaling |
| 데이터베이스 | RDS, Aurora, DynamoDB, ElastiCache |
| 스토리지 | S3, EFS, FSx |
| 보안 | IAM, SCP, WAF, GuardDuty, Security Hub, KMS |
| 모니터링 | CloudWatch, CloudTrail, Config, SNS |

**조직 기반 수집 항목:**

| 카테고리 | 포함 항목 |
|----------|----------|
| Organizations | OU 구조, 계정 매핑 |
| SCP | 루트 차단, 리전 제한, S3 퍼블릭 차단, 조직 탈퇴 차단 |
| 중앙 보안 | 조직 CloudTrail, GuardDuty, Security Hub, Config |
| 공유 네트워크 | Transit Gateway, RAM 공유, Egress VPC |
| Account Baseline | S3 퍼블릭 차단, EBS 암호화, IMDSv2 강제 |

비전문가도 사용할 수 있도록 기술 용어 대신 목적 기반 질문을 제공합니다.

### `/tf-build <spec-file>` (권장)

코드 생성과 품질 검증을 한번에 실행합니다. `/tf-generate` + `/tf-review`를 통합한 워크플로우입니다.

| Phase | 단계 | 내용 |
|-------|------|------|
| 1 | 명세서 분석 | YAML 파싱 + 의존성 그래프 |
| 2 | MCP 데이터 수집 | Provider 속성 + AWS 문서 (1회 수집, 이후 재사용) |
| 3 | 코드 생성 | 모듈 병렬 생성 + 환경 코드 |
| 4 | 자동 수정 | fmt, validate, tfsec 검사 + Critical/High 자동 수정 |
| 5 | 품질 검증 | 보안/비용 병렬 리뷰 (MCP 데이터 재사용) |
| 6 | 최종 리포트 | 종합 점수 + 다음 단계 안내 |

### `/tf-generate <spec-file>`

명세서를 읽고 Terraform 코드를 자동 생성합니다.

**워크로드 출력:**
```
environments/{env}/
├── main.tf              # 모듈 호출
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력 값
├── versions.tf          # Provider 버전
├── providers.tf         # Provider 설정
├── locals.tf            # 로컬 변수
├── backend.hcl          # State 백엔드
└── terraform.tfvars     # 변수 값
```

**조직 기반 출력 (3단계 분리):**
```
environments/org-foundation/
├── 01-organization/          # Organizations, OU, SCP
├── 02-security-baseline/     # CloudTrail, GuardDuty, SecurityHub, Config
└── 03-shared-networking/     # Transit Gateway, Egress VPC
```

### `/tf-review <path>`

4개 전문 에이전트가 코드를 종합 검토하고, 심각한 이슈는 자동으로 수정을 제안합니다.

| 검토 항목 | 에이전트 | 내용 |
|-----------|---------|------|
| 보안 | tf-security-reviewer | IAM, 네트워크, 암호화, 컴플라이언스 |
| 비용 | tf-cost-analyzer | 리소스 비용, 최적화 기회, 절약 방안 |
| 코드 품질 | 자동화 도구 | terraform fmt, validate, tfsec, checkov |
| 베스트 프랙티스 | 수동 검토 | 모듈 구조, 변수, 태그, 문서화 |

**자동 수정 흐름:**
1. 리뷰 리포트 출력 (점수 + 이슈 목록)
2. Critical/High 이슈 발견 시 → 수정 코드 자동 생성
3. 각 수정 사항의 diff를 보여주고 승인 여부 확인
4. 승인된 수정만 코드에 적용
5. 수정 후 자동 재검증 (fmt, validate)

### `/tf-plan <env>`

Terraform Plan을 실행하고 변경사항을 분석합니다.

## 프로젝트 구조

```
.
├── .claude/
│   ├── CLAUDE.md                    # 프로젝트 컨텍스트 및 코딩 표준
│   ├── settings.json                # 권한 설정
│   ├── agents/                      # 전문 에이전트 (4개)
│   │   ├── tf-architect.md          # 인프라 설계
│   │   ├── tf-security-reviewer.md  # 보안 검토
│   │   ├── tf-cost-analyzer.md      # 비용 분석
│   │   └── tf-module-developer.md   # 모듈 개발
│   └── commands/                    # 슬래시 커맨드 (5개)
│       ├── tf-spec.md               # 요구사항 수집
│       ├── tf-build.md              # 코드 생성 + 품질 검증 통합 (권장)
│       ├── tf-generate.md           # 코드 생성
│       ├── tf-review.md             # 종합 리뷰
│       └── tf-plan.md               # Plan 실행
├── .mcp.json                        # AWS MCP 서버 설정
├── templates/                       # YAML 요구사항 템플릿
│   ├── _base.yaml                   # 공통 필드
│   ├── networking.yaml              # VPC, 서브넷, NAT, TGW, VPN, VPC Peering
│   ├── compute.yaml                 # EC2, ECS, EKS, Lambda, Auto Scaling
│   ├── database.yaml                # RDS, Aurora, DynamoDB, ElastiCache
│   ├── storage.yaml                 # S3, EFS, FSx
│   ├── security.yaml                # IAM, SCP, WAF, GuardDuty, Security Hub, KMS
│   ├── monitoring.yaml              # CloudWatch, CloudTrail, Config, SNS
│   └── organization.yaml            # Organizations, OU, SCP, 보안
├── specs/                           # 생성된 명세서 (.yaml)
├── modules/                         # 생성된 Terraform 모듈
└── environments/                    # 환경별 배포 설정
```

## AWS MCP 서버

이 프로젝트는 3개의 AWS MCP 서버를 활용하여 정확한 코드를 생성합니다.

| MCP 서버 | 역할 | 활용 시점 |
|----------|------|-----------|
| Terraform MCP | Provider 리소스 속성 조회 | 모듈 생성, 속성 검증, 오류 해결 |
| AWS Documentation MCP | 공식 문서 검색 | 서비스 제한, 베스트 프랙티스, 가격 정보 |
| Well-Architected Security MCP | Security Pillar 평가 | 보안 리뷰, 아키텍처 평가 |

MCP 서버는 `.mcp.json`에 설정되어 있으며, `uv`가 설치되어 있으면 자동으로 사용됩니다.

## 계정 구조

이 프로젝트는 다음과 같은 AWS 멀티 어카운트 구조를 지원합니다.

```
Organization Root
├── Core OU
│   ├── Management Account       ← Terraform 실행
│   ├── Security Account         ← GuardDuty, SecurityHub 위임
│   └── Log Archive Account      ← CloudTrail, Config 로그
├── Infrastructure OU
│   └── Shared Services Account  ← Transit Gateway, Egress VPC
├── Workloads OU
│   ├── Dev OU → Dev Account
│   ├── Staging OU → Staging Account
│   └── Prod OU → Prod Account
└── Sandbox OU
```

- Management Account에서 `AssumeRole`로 다른 계정에 접근합니다
- 각 계정에 `TerraformExecutionRole`이 생성됩니다
- org-foundation이 SSM Parameter Store에 계정 ID, TGW ID 등을 기록하고, 워크로드가 참조합니다

## 사용 시나리오

### 시나리오 1: 처음부터 멀티 어카운트 구축

```bash
# 1. 조직 설정
/tf-spec my-org
# → Organizations, OU, SCP, 보안 서비스, Account Baseline 구성

/tf-build specs/my-org-spec.yaml
# → 3단계 코드 생성 + 보안/비용 품질 검증

# 2. 워크로드 배포
/tf-spec payment-api
# → VPC, ECS Fargate, Aurora PostgreSQL, WAF 구성

/tf-build specs/payment-api-spec.yaml
# → environments/dev/ 코드 생성 + 품질 검증
```

### 시나리오 2: 기존 계정에 워크로드만 배포

```bash
/tf-spec my-app
# → "워크로드 배포" 선택, 필요한 카테고리만 구성

/tf-build specs/my-app-spec.yaml
/tf-plan dev
```

### 시나리오 3: 전문가 모드 (카테고리 미리 지정)

```bash
# 네트워크 + 컴퓨팅만 빠르게 구성
/tf-spec my-service --from templates/networking.yaml,templates/compute.yaml

# 조직 설정 바로 시작
/tf-spec my-org --type org-foundation
```

## 보안 원칙

이 프로젝트로 생성되는 모든 코드는 다음 보안 원칙을 따릅니다.

- 하드코딩된 시크릿 금지 (Secrets Manager / SSM Parameter Store 사용)
- IAM 최소 권한 원칙 (와일드카드 `*` 사용 금지)
- S3 버킷 퍼블릭 접근 차단
- EBS 기본 암호화
- VPC Flow Logs 활성화
- Security Group `0.0.0.0/0` 인바운드 제한 (ALB/NLB 제외)
- `terraform apply` 직접 실행 금지 (CI/CD 파이프라인 권장)

## 라이선스

MIT License
