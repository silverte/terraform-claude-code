# AWS Multi-Account Terraform with Claude Code

AWS Control Tower 없이 엔터프라이즈 멀티 어카운트 환경을 관리하기 위한 Terraform 프로젝트와 Claude Code 설정입니다.

## 📁 프로젝트 구조

```
.
├── .claude/                      # Claude Code 설정
│   ├── CLAUDE.md                 # 프로젝트 컨텍스트
│   ├── agents/                   # 서브에이전트
│   │   ├── tf-architect.md       # 인프라 설계 전문가
│   │   ├── tf-security-reviewer.md # 보안 검토 전문가
│   │   ├── tf-cost-analyzer.md   # 비용 분석 전문가
│   │   └── tf-module-developer.md # 모듈 개발 전문가
│   ├── commands/                 # 슬래시 명령어
│   │   ├── tf-plan.md            # Plan 실행
│   │   ├── tf-module.md          # 모듈 생성
│   │   ├── tf-account.md         # 계정 프로비저닝
│   │   └── tf-review.md          # 종합 리뷰
│   └── settings.json             # Hooks 및 권한 설정
│
├── modules/                      # 재사용 가능 모듈
│   ├── account-baseline/         # 계정 기본 보안 설정
│   ├── networking/vpc/           # VPC 및 네트워크
│   └── security/                 # IAM, KMS 등
│
├── environments/                 # 환경별 구성
│   ├── dev/                      # 개발 환경
│   ├── staging/                  # 스테이징 환경
│   ├── prod/                     # 프로덕션 환경
│   └── management/               # 관리 계정
│
├── organization/                 # AWS Organizations 설정
│   ├── accounts/                 # 계정 정의
│   └── scps/                     # Service Control Policies
│
└── _templates/                   # 템플릿
```

## 🚀 시작하기

### 사전 요구사항

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Claude Code](https://claude.ai/code) 설치
- AWS CLI 설정
- 필수 도구:
  - `tfsec` - 보안 스캔
  - `tflint` - 린팅
  - `checkov` - 정책 검사
  - `infracost` - 비용 분석 (선택)

### 설치

```bash
# 1. 저장소 클론
git clone <repository-url>
cd terraform-multi-account-claude-code

# 2. Claude Code 시작
claude

# 3. 환경 변수 설정
export TF_VAR_terraform_external_id="your-external-id"
export AWS_PROFILE="your-profile"
```

### Claude Code 사용

```bash
# 프로젝트 디렉토리에서 Claude Code 시작
claude

# 슬래시 명령어 사용
/project:tf-plan dev                    # Dev 환경 Plan
/project:tf-module vpc network          # VPC 모듈 생성
/project:tf-account new-app Workloads/Dev app@company.com  # 새 계정
/project:tf-review modules/vpc          # 코드 리뷰
```

## 🔧 Claude Code 설정

### 서브에이전트

| 에이전트 | 설명 | 트리거 키워드 |
|---------|------|-------------|
| `tf-architect` | 인프라 설계 | 설계, 아키텍처, 구조 |
| `tf-security-reviewer` | 보안 검토 | 보안, 취약점, 검토 |
| `tf-cost-analyzer` | 비용 분석 | 비용, cost, 예산 |
| `tf-module-developer` | 모듈 개발 | 모듈, 생성, 리팩토링 |

### 슬래시 명령어

| 명령어 | 설명 |
|--------|------|
| `/project:tf-plan <env>` | 환경별 Terraform Plan |
| `/project:tf-module <name> <type>` | 새 모듈 스캐폴딩 |
| `/project:tf-account <name> <ou> <email>` | 새 계정 구성 |
| `/project:tf-review <path>` | 종합 코드 리뷰 |

### Hooks

- **PostToolUse**: `.tf` 파일 작성 시 자동 포맷팅
- **PreCommit**: 유효성 검사 및 보안 스캔

## 🏗️ 모듈 사용법

### account-baseline

```hcl
module "account_baseline" {
  source = "./modules/account-baseline"

  project_name = "myproject"
  environment  = "dev"

  enable_cloudtrail   = true
  enable_guardduty    = true
  enable_config       = true
  enable_security_hub = true

  cloudtrail_bucket_name = "logs-bucket"
  config_bucket_name     = "config-bucket"
}
```

### vpc

```hcl
module "vpc" {
  source = "./modules/networking/vpc"

  project_name = "myproject"
  environment  = "dev"

  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["ap-northeast-2a", "ap-northeast-2c"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true  # Dev 환경용

  enable_flow_logs = true
}
```

## 🔐 보안 가이드라인

1. **하드코딩 금지**: 시크릿은 Secrets Manager/SSM 사용
2. **최소 권한**: IAM 정책에 와일드카드 사용 금지
3. **암호화 필수**: 모든 데이터 at-rest/in-transit 암호화
4. **로깅 활성화**: CloudTrail, VPC Flow Logs 필수
5. **보안 스캔**: tfsec, checkov 검사 통과 필수

## 📋 체크리스트

### 새 환경 배포 전

- [ ] terraform.tfvars 설정
- [ ] backend.hcl 설정
- [ ] 계정 ID 확인
- [ ] IAM 역할 존재 확인
- [ ] `/project:tf-review` 실행
- [ ] `/project:tf-plan` 검토

### 새 모듈 개발 시

- [ ] 표준 구조 준수
- [ ] 변수 validation 추가
- [ ] README.md 작성
- [ ] 예제 코드 작성
- [ ] 테스트 작성

## 🤝 기여하기

1. 브랜치 생성: `feature/your-feature`
2. 변경 사항 커밋
3. PR 생성
4. 코드 리뷰 및 보안 검토

## 📄 라이선스

MIT License
