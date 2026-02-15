# Skill-Driven Terraform Generator Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 대화형 요구사항 수집(tf-spec) → YAML 명세서 → Terraform 코드 자동 생성(tf-generate) 파이프라인 구축

**Architecture:** Skill-Driven 아키텍처. YAML 템플릿 기반으로 사용자와 대화하며 요구사항을 수집하고, 확정된 명세서(spec.yaml)로부터 Terraform 코드를 자동 생성한다. 기존 에이전트(tf-architect, tf-security-reviewer, tf-cost-analyzer, tf-module-developer)는 유지하고 파이프라인에 통합한다.

**Tech Stack:** Terraform HCL, YAML templates, Claude Code commands/agents, installed skills (terraform-engineer, terraform-style-guide, terraform-module-library)

---

## Task 1: 기존 파일 정리 및 새 디렉토리 구조 생성

**Files:**
- Delete: `modules/account-baseline/` (전체)
- Delete: `modules/networking/vpc/` (전체)
- Delete: `environments/dev/` (전체)
- Delete: `organization/scps/baseline-scps.tf`
- Delete: `.claude/commands/tf-module.md`
- Delete: `.claude/commands/tf-account.md`
- Delete: `README.md`
- Create: `templates/` directory
- Create: `specs/` directory
- Create: `specs/.gitkeep`

**Step 1: 불필요한 기존 파일 삭제**

```bash
rm -rf modules/account-baseline modules/networking environments/dev organization
rm -f .claude/commands/tf-module.md .claude/commands/tf-account.md
rm -f README.md
```

**Step 2: 새 디렉토리 구조 생성**

```bash
mkdir -p templates specs modules environments
touch specs/.gitkeep
```

**Step 3: 디렉토리 구조 확인**

```bash
find . -not -path './.git/*' -not -path './.git' | sort
```

Expected: `.claude/`, `templates/`, `specs/`, `modules/`, `environments/`, `docs/` 구조 확인

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: clean up existing files and create new directory structure"
```

---

## Task 2: 공통 기본 템플릿 (`templates/_base.yaml`) 생성

**Files:**
- Create: `templates/_base.yaml`

**Step 1: _base.yaml 작성**

```yaml
# =============================================================================
# Base Template - 모든 인프라 명세서의 공통 필드
# =============================================================================
# 이 템플릿은 프로젝트 기본 정보, 소유자, 태그, State 설정을 정의합니다.
# /tf-spec 커맨드가 대화를 통해 이 필드들을 먼저 수집합니다.

project:
  name: ""                          # 프로젝트명 (예: my-web-service)
  description: ""                   # 프로젝트 설명
  environment: "dev"                # 배포 환경: dev | staging | prod
  region: "ap-northeast-2"          # AWS 리전
  account_id: ""                    # 대상 AWS 계정 ID

  # 멀티 어카운트 설정 (선택)
  multi_account:
    enabled: false
    management_account_id: ""       # Management Account ID
    security_account_id: ""         # Security Account ID
    assume_role_name: "TerraformExecutionRole"

owner:
  team: ""                          # 담당 팀
  cost_center: ""                   # 비용 센터 코드
  contact_email: ""                 # 담당자 이메일

tags:                                # 추가 커스텀 태그
  # example_key: example_value

state:
  backend: "s3"                     # 백엔드 타입: s3 | local
  bucket: ""                        # S3 State 버킷명
  lock_table: ""                    # DynamoDB 락 테이블명
  encrypt: true                     # State 암호화 여부
```

**Step 2: YAML 문법 확인**

Run: `python3 -c "import yaml; yaml.safe_load(open('templates/_base.yaml'))" && echo "VALID"`
Expected: `VALID`

**Step 3: Commit**

```bash
git add templates/_base.yaml
git commit -m "feat: add base template for common project fields"
```

---

## Task 3: 네트워크 템플릿 (`templates/networking.yaml`) 생성

**Files:**
- Create: `templates/networking.yaml`

**Step 1: networking.yaml 작성**

```yaml
# =============================================================================
# Networking Template - VPC, 서브넷, NAT, Transit Gateway, VPN
# =============================================================================

networking:

  vpc:
    enabled: true
    cidr: "10.0.0.0/16"                          # VPC CIDR 블록
    enable_dns_hostnames: true
    enable_dns_support: true

    availability_zones:                            # 사용할 가용영역
      - "ap-northeast-2a"
      - "ap-northeast-2c"

    subnets:
      public:
        enabled: true
        cidrs:                                     # 퍼블릭 서브넷 CIDR
          - "10.0.1.0/24"
          - "10.0.2.0/24"
        map_public_ip: true

      private:
        enabled: true
        cidrs:                                     # 프라이빗 서브넷 CIDR (앱 워크로드)
          - "10.0.10.0/24"
          - "10.0.11.0/24"

      database:
        enabled: false
        cidrs: []                                  # DB 전용 서브넷 CIDR
        # cidrs:
        #   - "10.0.20.0/24"
        #   - "10.0.21.0/24"

    internet_gateway:
      enabled: true                                # 퍼블릭 서브넷 사용 시 필수

    nat_gateway:
      enabled: true
      single_az: true                              # true: 비용 절감, false: 고가용성 (AZ당 1개)

    flow_logs:
      enabled: true
      retention_days: 30                           # CloudWatch 로그 보관 기간
      traffic_type: "ALL"                          # ALL | ACCEPT | REJECT

  transit_gateway:
    enabled: false
    # amazon_side_asn: 64512
    # auto_accept_shared_attachments: true
    # vpn_ecmp_support: true
    # shared_accounts: []                          # TGW를 공유할 계정 ID 목록

  vpc_peering:
    enabled: false
    # peers: []                                    # 피어링 대상 VPC 목록
    #   - name: "shared-services"
    #     vpc_id: ""
    #     account_id: ""
    #     region: "ap-northeast-2"

  vpn:
    enabled: false
    # type: "site-to-site"                         # site-to-site | client
    # customer_gateway_ip: ""
    # bgp_asn: 65000
    # static_routes: []
```

**Step 2: YAML 문법 확인**

Run: `python3 -c "import yaml; yaml.safe_load(open('templates/networking.yaml'))" && echo "VALID"`
Expected: `VALID`

**Step 3: Commit**

```bash
git add templates/networking.yaml
git commit -m "feat: add networking template (VPC, subnets, NAT, TGW, VPN)"
```

---

## Task 4: 컴퓨팅 템플릿 (`templates/compute.yaml`) 생성

**Files:**
- Create: `templates/compute.yaml`

**Step 1: compute.yaml 작성**

```yaml
# =============================================================================
# Compute Template - EC2, ECS, EKS, Lambda, Auto Scaling
# =============================================================================

compute:

  ec2:
    enabled: false
    instances: []
    # instances:
    #   - name: "web-server"
    #     instance_type: "t3.micro"                # 인스턴스 타입
    #     ami_filter: "amazon-linux-2023"           # AMI 필터 키워드
    #     subnet_type: "private"                    # public | private
    #     key_pair: ""                              # SSH 키페어명 (빈값이면 SSM만 사용)
    #     root_volume:
    #       size: 20                                # GB
    #       type: "gp3"
    #       encrypted: true
    #     security_group_rules:
    #       ingress:
    #         - port: 443
    #           protocol: "tcp"
    #           source: "0.0.0.0/0"                 # ALB/NLB에서만 허용
    #       egress:
    #         - port: 0
    #           protocol: "-1"
    #           destination: "0.0.0.0/0"

  autoscaling:
    enabled: false
    # groups: []
    #   - name: "web-asg"
    #     instance_type: "t3.small"
    #     min_size: 1
    #     max_size: 4
    #     desired_capacity: 2
    #     health_check_type: "ELB"                  # EC2 | ELB
    #     target_group_arn: ""
    #     scaling_policies:
    #       - type: "target_tracking"
    #         target_value: 70                       # CPU 사용률 %
    #         metric: "ASGAverageCPUUtilization"

  ecs:
    enabled: false
    # cluster_name: ""
    # capacity_provider: "FARGATE"                  # FARGATE | FARGATE_SPOT | EC2
    # services: []
    #   - name: "api-service"
    #     cpu: 256                                   # vCPU (256 = 0.25 vCPU)
    #     memory: 512                                # MB
    #     desired_count: 2
    #     container:
    #       image: ""
    #       port: 8080
    #     health_check_path: "/health"
    #     autoscaling:
    #       min_count: 1
    #       max_count: 10
    #       target_cpu: 70

  eks:
    enabled: false
    # cluster_version: "1.29"
    # endpoint_private_access: true
    # endpoint_public_access: false
    # node_groups: []
    #   - name: "general"
    #     instance_types: ["t3.medium"]
    #     min_size: 2
    #     max_size: 5
    #     desired_size: 3
    #     disk_size: 50                              # GB
    #     capacity_type: "ON_DEMAND"                 # ON_DEMAND | SPOT
    # addons:
    #   - "vpc-cni"
    #   - "coredns"
    #   - "kube-proxy"
    #   - "aws-ebs-csi-driver"

  lambda:
    enabled: false
    # functions: []
    #   - name: "data-processor"
    #     runtime: "python3.12"                     # nodejs20.x | python3.12 | java21 등
    #     handler: "main.handler"
    #     memory: 128                                # MB (128-10240)
    #     timeout: 30                                # 초 (최대 900)
    #     architecture: "arm64"                      # x86_64 | arm64
    #     environment_variables: {}
    #     vpc_enabled: false                         # VPC 내부 실행 여부
    #     triggers: []                               # api-gateway | s3 | sqs | schedule
```

**Step 2: YAML 문법 확인**

Run: `python3 -c "import yaml; yaml.safe_load(open('templates/compute.yaml'))" && echo "VALID"`
Expected: `VALID`

**Step 3: Commit**

```bash
git add templates/compute.yaml
git commit -m "feat: add compute template (EC2, ECS, EKS, Lambda, ASG)"
```

---

## Task 5: 데이터베이스 템플릿 (`templates/database.yaml`) 생성

**Files:**
- Create: `templates/database.yaml`

**Step 1: database.yaml 작성**

```yaml
# =============================================================================
# Database Template - RDS, Aurora, DynamoDB, ElastiCache
# =============================================================================

database:

  rds:
    enabled: false
    # instances: []
    #   - name: "main-db"
    #     engine: "postgres"                        # postgres | mysql | mariadb | oracle | sqlserver
    #     engine_version: "16.1"
    #     instance_class: "db.t3.medium"
    #     allocated_storage: 20                      # GB
    #     max_allocated_storage: 100                 # GB (자동 확장 최대)
    #     storage_type: "gp3"
    #     storage_encrypted: true
    #     multi_az: false                            # true: 고가용성 (prod 권장)
    #     backup_retention_period: 7                 # 일
    #     deletion_protection: false                 # prod에서는 true 권장
    #     skip_final_snapshot: true                  # prod에서는 false 권장
    #     performance_insights: true
    #     monitoring_interval: 60                    # Enhanced Monitoring 간격 (초)
    #     publicly_accessible: false                 # 항상 false 권장
    #     parameter_group_family: "postgres16"
    #     parameters: {}                             # 커스텀 파라미터

  aurora:
    enabled: false
    # clusters: []
    #   - name: "main-cluster"
    #     engine: "aurora-postgresql"                # aurora-postgresql | aurora-mysql
    #     engine_version: "16.1"
    #     serverless_v2:
    #       enabled: false
    #       min_capacity: 0.5                        # ACU
    #       max_capacity: 16                         # ACU
    #     instances:
    #       count: 2                                 # Writer + Reader
    #       instance_class: "db.r6g.large"
    #     storage_encrypted: true
    #     backup_retention_period: 7
    #     deletion_protection: false

  dynamodb:
    enabled: false
    # tables: []
    #   - name: "sessions"
    #     billing_mode: "PAY_PER_REQUEST"            # PAY_PER_REQUEST | PROVISIONED
    #     hash_key: "id"
    #     hash_key_type: "S"                         # S(String) | N(Number) | B(Binary)
    #     range_key: ""
    #     range_key_type: ""
    #     ttl_attribute: "expires_at"
    #     point_in_time_recovery: true
    #     encryption: "AWS_OWNED"                    # AWS_OWNED | KMS
    #     global_secondary_indexes: []
    #     stream_enabled: false

  elasticache:
    enabled: false
    # clusters: []
    #   - name: "app-cache"
    #     engine: "redis"                            # redis | memcached
    #     engine_version: "7.0"
    #     node_type: "cache.t3.micro"
    #     num_cache_nodes: 1                         # Memcached 전용
    #     replication_group:
    #       enabled: false                           # Redis 전용
    #       num_replicas: 1
    #       automatic_failover: true
    #     at_rest_encryption: true
    #     transit_encryption: true
    #     snapshot_retention_limit: 5
```

**Step 2: YAML 문법 확인**

Run: `python3 -c "import yaml; yaml.safe_load(open('templates/database.yaml'))" && echo "VALID"`
Expected: `VALID`

**Step 3: Commit**

```bash
git add templates/database.yaml
git commit -m "feat: add database template (RDS, Aurora, DynamoDB, ElastiCache)"
```

---

## Task 6: 스토리지 템플릿 (`templates/storage.yaml`) 생성

**Files:**
- Create: `templates/storage.yaml`

**Step 1: storage.yaml 작성**

```yaml
# =============================================================================
# Storage Template - S3, EFS, FSx
# =============================================================================

storage:

  s3:
    enabled: false
    # buckets: []
    #   - name: "app-assets"                        # 버킷 접미사 (전체: {project}-{env}-{name})
    #     versioning: true
    #     encryption:
    #       type: "SSE-S3"                           # SSE-S3 | SSE-KMS
    #       kms_key_id: ""                           # SSE-KMS 사용 시
    #     public_access_block: true                  # 항상 true 권장
    #     lifecycle_rules: []
    #       # - id: "archive"
    #       #   transition_days: 90
    #       #   transition_storage_class: "GLACIER"
    #       # - id: "expire"
    #       #   expiration_days: 365
    #     cors_rules: []
    #     logging:
    #       enabled: false
    #       target_bucket: ""
    #     replication:
    #       enabled: false
    #       destination_bucket: ""
    #       destination_region: ""

  efs:
    enabled: false
    # file_systems: []
    #   - name: "shared-data"
    #     performance_mode: "generalPurpose"         # generalPurpose | maxIO
    #     throughput_mode: "bursting"                 # bursting | provisioned | elastic
    #     encrypted: true
    #     lifecycle_policy: "AFTER_30_DAYS"           # 수명 주기 전환
    #     backup_policy: true

  fsx:
    enabled: false
    # type: "LUSTRE"                                 # LUSTRE | WINDOWS | ONTAP | OPENZFS
    # storage_capacity: 1200                          # GB
    # deployment_type: "PERSISTENT_2"
```

**Step 2: YAML 문법 확인**

Run: `python3 -c "import yaml; yaml.safe_load(open('templates/storage.yaml'))" && echo "VALID"`
Expected: `VALID`

**Step 3: Commit**

```bash
git add templates/storage.yaml
git commit -m "feat: add storage template (S3, EFS, FSx)"
```

---

## Task 7: 보안 템플릿 (`templates/security.yaml`) 생성

**Files:**
- Create: `templates/security.yaml`

**Step 1: security.yaml 작성**

```yaml
# =============================================================================
# Security Template - IAM, SCP, WAF, GuardDuty, Security Hub, KMS
# =============================================================================

security:

  iam:
    password_policy:
      enabled: true
      minimum_length: 14
      require_uppercase: true
      require_lowercase: true
      require_numbers: true
      require_symbols: true
      max_age_days: 90

    roles: []
    # roles:
    #   - name: "app-execution-role"
    #     description: "앱 실행 역할"
    #     assume_role_policy:
    #       service: "ecs-tasks.amazonaws.com"       # 서비스 프린시펄
    #     managed_policies: []                        # AWS 관리형 정책 ARN 목록
    #     inline_policies: []                         # 인라인 정책 (최소화 권장)

  scp:
    enabled: false
    # policies: []
    #   - name: "deny-root"
    #     description: "루트 계정 사용 차단"
    #   - name: "allowed-regions"
    #     description: "허용 리전 제한"
    #     allowed_regions: ["ap-northeast-2", "us-east-1"]
    #   - name: "deny-public-s3"
    #     description: "퍼블릭 S3 차단"

  waf:
    enabled: false
    # scope: "REGIONAL"                              # REGIONAL | CLOUDFRONT
    # rules: []
    #   - name: "rate-limit"
    #     priority: 1
    #     action: "block"
    #     rate_limit: 2000                            # 5분당 요청 수
    #   - name: "aws-managed-common"
    #     priority: 2
    #     managed_rule_group: "AWSManagedRulesCommonRuleSet"

  guardduty:
    enabled: true
    # s3_protection: true
    # eks_protection: false
    # malware_protection: true

  security_hub:
    enabled: true
    # standards:
    #   - "aws-foundational-security-best-practices"
    #   - "cis-aws-foundations-benchmark"

  kms:
    enabled: false
    # keys: []
    #   - name: "app-key"
    #     description: "앱 데이터 암호화 키"
    #     key_usage: "ENCRYPT_DECRYPT"
    #     deletion_window: 30                         # 일
    #     enable_rotation: true
    #     aliases: ["alias/app-key"]

  account_baseline:
    enabled: true
    s3_public_access_block: true                     # 계정 레벨 S3 퍼블릭 차단
    ebs_default_encryption: true                     # EBS 기본 암호화
    imdsv2_required: true                            # EC2 IMDSv2 강제
```

**Step 2: YAML 문법 확인**

Run: `python3 -c "import yaml; yaml.safe_load(open('templates/security.yaml'))" && echo "VALID"`
Expected: `VALID`

**Step 3: Commit**

```bash
git add templates/security.yaml
git commit -m "feat: add security template (IAM, SCP, WAF, GuardDuty, KMS)"
```

---

## Task 8: 모니터링 템플릿 (`templates/monitoring.yaml`) 생성

**Files:**
- Create: `templates/monitoring.yaml`

**Step 1: monitoring.yaml 작성**

```yaml
# =============================================================================
# Monitoring Template - CloudWatch, CloudTrail, Config, SNS
# =============================================================================

monitoring:

  cloudwatch:
    enabled: true

    alarms: []
    # alarms:
    #   - name: "high-cpu"
    #     metric: "CPUUtilization"
    #     namespace: "AWS/EC2"
    #     statistic: "Average"
    #     period: 300                                # 초
    #     threshold: 80
    #     comparison: "GreaterThanThreshold"
    #     evaluation_periods: 2
    #     alarm_actions: []                           # SNS Topic ARN

    log_groups: []
    # log_groups:
    #   - name: "/app/api"
    #     retention_days: 30                          # 1, 3, 5, 7, 14, 30, 60, 90, ...
    #     kms_encryption: false

    dashboards: []
    # dashboards:
    #   - name: "app-dashboard"
    #     widgets:
    #       - type: "metric"
    #         title: "CPU Utilization"
    #         metrics: ["AWS/EC2", "CPUUtilization"]

  cloudtrail:
    enabled: true
    is_multi_region: true
    enable_log_file_validation: true
    s3_bucket_name: ""                               # 로그 저장 버킷 (Security 계정)
    kms_key_id: ""                                   # 로그 암호화 키 (선택)
    include_global_service_events: true

  config:
    enabled: true
    s3_bucket_name: ""                               # Config 스냅샷 버킷
    recording_frequency: "CONTINUOUS"                 # CONTINUOUS | DAILY
    # rules: []
    #   - "s3-bucket-public-read-prohibited"
    #   - "encrypted-volumes"
    #   - "iam-password-policy"
    #   - "root-account-mfa-enabled"

  sns:
    enabled: false
    # topics: []
    #   - name: "infra-alerts"
    #     display_name: "Infrastructure Alerts"
    #     subscriptions:
    #       - protocol: "email"
    #         endpoint: "ops@example.com"
    #       - protocol: "lambda"
    #         endpoint: ""                            # Lambda ARN
```

**Step 2: YAML 문법 확인**

Run: `python3 -c "import yaml; yaml.safe_load(open('templates/monitoring.yaml'))" && echo "VALID"`
Expected: `VALID`

**Step 3: Commit**

```bash
git add templates/monitoring.yaml
git commit -m "feat: add monitoring template (CloudWatch, CloudTrail, Config, SNS)"
```

---

## Task 9: `/tf-spec` 커맨드 생성

**Files:**
- Create: `.claude/commands/tf-spec.md`

**Step 1: tf-spec.md 작성**

이 커맨드는 사용자와 대화하며 요구사항을 수집하고 spec.yaml을 생성하는 핵심 커맨드이다.

```markdown
# Terraform Spec Builder - 대화형 요구사항 수집

사용자와 대화하며 인프라 요구사항을 수집하고 YAML 명세서(spec.yaml)를 생성합니다.

## Usage
\`\`\`
/project:tf-spec <project-name>
\`\`\`

## Arguments
- **project-name**: 프로젝트 식별자 (예: my-web-service, payment-api)

## Execution Steps

### Phase 1: 기본 정보 수집

`templates/_base.yaml`을 참조하여 다음 정보를 순서대로 질문합니다.
AskUserQuestion 도구를 사용하여 하나씩 질문하세요.

1. **환경**: dev / staging / prod 중 선택
2. **리전**: 기본값 ap-northeast-2, 변경 필요 시 선택
3. **AWS 계정 ID**: 대상 계정 ID 입력
4. **멀티 어카운트**: 사용 여부 → 사용 시 Management/Security Account ID 추가 수집
5. **담당 팀**: 팀명 입력
6. **비용 센터**: 비용 센터 코드 입력
7. **State 설정**: S3 버킷명, DynamoDB 테이블명

### Phase 2: 인프라 카테고리 선택

AskUserQuestion으로 필요한 인프라 카테고리를 복수 선택하게 합니다.

카테고리 목록:
- 네트워크 (VPC, 서브넷, NAT, TGW)
- 컴퓨팅 (EC2, ECS, EKS, Lambda)
- 데이터베이스 (RDS, Aurora, DynamoDB, ElastiCache)
- 스토리지 (S3, EFS)
- 보안 (IAM, SCP, WAF, GuardDuty)
- 모니터링 (CloudWatch, CloudTrail, Config)

### Phase 3: 카테고리별 상세 질문

선택된 카테고리에 대해서만 `templates/{category}.yaml`을 참조하여 상세 질문합니다.

#### 질문 전략
- **전문가 감지**: 사용자가 CIDR, 인스턴스 타입 등을 직접 언급하면 상세 질문으로 전환
- **비전문가 모드**: 목적 기반 질문 (예: "웹 서비스인가요, 배치 처리인가요?")으로 적절한 기본값 추천
- **기본값 적극 활용**: 각 질문에 기본값을 명시하고, 변경이 필요한 것만 입력받음

#### 네트워크 질문 흐름
1. VPC CIDR (기본: 10.0.0.0/16)
2. 가용영역 수 (기본: 2)
3. 서브넷 구성: public + private / private only / public + private + database
4. NAT Gateway: 단일 AZ(비용절감) vs 다중 AZ(고가용성)
5. VPC Flow Logs 활성화 여부 (기본: true)

#### 컴퓨팅 질문 흐름
1. 워크로드 타입: 컨테이너(ECS/EKS) / VM(EC2) / 서버리스(Lambda) / 혼합
2. EKS 선택 시: 클러스터 버전, 노드 그룹 수/크기, Spot 사용 여부
3. ECS 선택 시: Fargate vs EC2, 서비스 수, CPU/메모리
4. EC2 선택 시: 인스턴스 타입, 수량, Auto Scaling 여부
5. Lambda 선택 시: 런타임, 메모리, 트리거 타입

#### 데이터베이스 질문 흐름
1. DB 엔진: PostgreSQL / MySQL / DynamoDB / Redis / 없음
2. RDS 선택 시: 인스턴스 크기, Multi-AZ, 스토리지 크기
3. DynamoDB 선택 시: 과금 모드, 테이블 구성
4. ElastiCache 선택 시: Redis/Memcached, 노드 크기

#### 스토리지 질문 흐름
1. S3 버킷 필요 여부 및 용도 (정적 자산/로그/데이터)
2. 수명 주기 정책 필요 여부
3. EFS 필요 여부 (컨테이너 공유 스토리지)

#### 보안 질문 흐름
1. Account Baseline 적용 여부 (기본: true)
2. WAF 필요 여부 (웹 서비스인 경우 권장)
3. GuardDuty/Security Hub 활성화 (기본: true)
4. 추가 KMS 키 필요 여부

#### 모니터링 질문 흐름
1. CloudTrail 활성화 (기본: true)
2. Config 활성화 (기본: true)
3. 알람 필요 여부 및 알림 이메일
4. 대시보드 필요 여부

### Phase 4: 명세서 생성

수집된 정보를 `specs/{project-name}-spec.yaml`로 저장합니다.

파일 구조:
\`\`\`yaml
# Auto-generated by /tf-spec
# Project: {project-name}
# Generated: {date}
# =============================================

# --- Base ---
{_base.yaml 필드들, 수집된 값으로 채움}

# --- Networking ---
{networking.yaml 필드들, enabled된 것만 포함}

# --- Compute ---
{compute.yaml 필드들, enabled된 것만 포함}

# ... 선택된 카테고리만 포함
\`\`\`

### Phase 5: 확인 및 수정

1. 생성된 spec의 요약을 표 형태로 출력
2. AskUserQuestion으로 확인 요청
3. 수정 요청 시 해당 부분만 대화로 수정
4. 확정 시 안내 메시지 출력:

\`\`\`
명세서가 확정되었습니다: specs/{project-name}-spec.yaml

다음 단계:
  /project:tf-generate specs/{project-name}-spec.yaml
\`\`\`

## Expert Mode

\`\`\`
/project:tf-spec my-service --from templates/networking.yaml,templates/compute.yaml
\`\`\`

`--from` 옵션으로 카테고리를 미리 지정하면 Phase 2를 건너뛰고 바로 Phase 3로 진입합니다.

## Guidelines

- **한 번에 하나의 질문만** 합니다
- **AskUserQuestion 도구** 를 적극 활용하여 선택지를 제공합니다
- 모든 질문에 **기본값을 명시**합니다
- 비전문가에게는 **기술 용어 대신 목적 기반 설명**을 사용합니다
- CIDR, 리전, 인스턴스 타입 등은 **유효성을 검증**합니다
- tf-architect 에이전트를 호출하여 **복잡한 설계 판단**을 지원합니다
```

**Step 2: 파일 확인**

Read `.claude/commands/tf-spec.md` to verify content and formatting.

**Step 3: Commit**

```bash
git add .claude/commands/tf-spec.md
git commit -m "feat: add tf-spec command for interactive requirement collection"
```

---

## Task 10: `/tf-generate` 커맨드 생성

**Files:**
- Create: `.claude/commands/tf-generate.md`

**Step 1: tf-generate.md 작성**

```markdown
# Terraform Code Generator - 명세서 기반 코드 생성

YAML 명세서(spec.yaml)를 읽어 Terraform 코드를 자동 생성합니다.

## Usage
\`\`\`
/project:tf-generate <spec-file>
\`\`\`

## Arguments
- **spec-file**: 명세서 경로 (예: specs/my-web-service-spec.yaml)

## Execution Steps

### Phase 1: 명세서 파싱 및 검증

1. spec 파일을 읽고 YAML 파싱
2. 필수 필드 존재 여부 확인:
   - `project.name`, `project.environment`, `project.region`, `project.account_id`
   - `owner.team`, `owner.cost_center`
3. 값 유효성 검증:
   - CIDR 형식 (`^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$`)
   - 리전 형식 (`^[a-z]{2}-[a-z]+-[0-9]$`)
   - 환경 값 (`dev`, `staging`, `prod`)
   - 인스턴스 타입 패턴 (CLAUDE.md의 허용 목록 참조)
4. 오류 발견 시 사용자에게 보고하고 수정 안내

### Phase 2: 출력 디렉토리 준비

```bash
TARGET_DIR="environments/{project.environment}"
mkdir -p $TARGET_DIR
```

이미 존재하면 사용자에게 덮어쓰기 여부 확인.

### Phase 3: 모듈 확인 및 생성

spec에서 enabled된 각 카테고리에 대해:

1. `modules/` 에 해당 모듈이 있는지 확인
2. 없으면 tf-module-developer 에이전트를 호출하여 모듈 생성
3. 있으면 기존 모듈 재사용

모듈 매핑 규칙:
| Spec 카테고리 | 모듈 경로 |
|---|---|
| networking.vpc | modules/networking/vpc |
| networking.transit_gateway | modules/networking/transit-gateway |
| compute.ec2 | modules/compute/ec2 |
| compute.ecs | modules/compute/ecs |
| compute.eks | modules/compute/eks |
| compute.lambda | modules/compute/lambda |
| database.rds | modules/database/rds |
| database.aurora | modules/database/aurora |
| database.dynamodb | modules/database/dynamodb |
| database.elasticache | modules/database/elasticache |
| storage.s3 | modules/storage/s3 |
| storage.efs | modules/storage/efs |
| security.account_baseline | modules/security/account-baseline |
| security.waf | modules/security/waf |
| security.kms | modules/security/kms |
| monitoring.cloudtrail | modules/monitoring/cloudtrail |
| monitoring.config | modules/monitoring/config |

### Phase 4: 환경 파일 생성

아래 파일들을 `environments/{env}/` 에 생성합니다.

#### versions.tf
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

#### providers.tf
spec의 `project.multi_account.enabled` 여부에 따라:

**싱글 어카운트:**
```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}
```

**멀티 어카운트:**
```hcl
provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.account_id}:role/${var.assume_role_name}"
    session_name = "terraform-${var.environment}"
  }
  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "management"
  region = var.aws_region
}

provider "aws" {
  alias  = "security"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.security_account_id}:role/${var.assume_role_name}"
    session_name = "terraform-${var.environment}"
  }
}
```

#### locals.tf
```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner_team
    CostCenter  = var.cost_center
  }
}
```

#### variables.tf
spec의 모든 설정값을 Terraform 변수로 변환합니다.
CLAUDE.md의 변수 정의 규칙을 따릅니다 (description, type, validation 필수).

#### main.tf
enabled된 각 카테고리의 모듈을 호출합니다.
```hcl
# --- Networking ---
module "vpc" {
  source = "../../modules/networking/vpc"
  # spec에서 추출한 값들
}

# --- Compute ---
module "eks" {
  source = "../../modules/compute/eks"
  # spec에서 추출한 값들
  depends_on = [module.vpc]
}
```

#### outputs.tf
각 모듈의 주요 출력을 노출합니다.

#### backend.hcl
```hcl
bucket         = "{spec.state.bucket}"
key            = "{spec.project.environment}/terraform.tfstate"
region         = "{spec.project.region}"
dynamodb_table = "{spec.state.lock_table}"
encrypt        = true
```

#### terraform.tfvars
spec 값을 기반으로 생성합니다.

### Phase 5: 코드 품질 검증

```bash
cd environments/{env}
terraform fmt -recursive
terraform validate
```

terraform-style-guide 스킬의 규칙을 적용하여 최종 검증합니다.

### Phase 6: 요약 출력

```
## 코드 생성 완료

### 프로젝트: {name}
### 환경: {env}
### 리전: {region}

### 생성된 파일
| 파일 | 설명 |
|------|------|
| environments/{env}/versions.tf | Terraform/Provider 버전 |
| environments/{env}/providers.tf | Provider 설정 |
| ... | ... |

### 생성된 모듈
| 모듈 | 경로 |
|------|------|
| VPC | modules/networking/vpc |
| ... | ... |

### 리소스 요약
| 카테고리 | 리소스 |
|----------|--------|
| 네트워크 | VPC, 2 public subnets, 2 private subnets, NAT Gateway |
| ... | ... |

### 다음 단계
1. terraform.tfvars의 값을 확인하세요
2. /project:tf-review environments/{env} 으로 코드를 검토하세요
3. /project:tf-plan {env} 으로 Plan을 확인하세요
```

## Code Generation Rules

1. **CLAUDE.md 코딩 표준 준수**: 파일 구조, 네이밍 규칙, 필수 태그
2. **terraform-style-guide 스킬 적용**: HashiCorp 공식 스타일
3. **terraform-module-library 스킬 참조**: 모듈 구조 패턴
4. **terraform-engineer 스킬 참조**: State 관리, Provider 설정 패턴
5. **보안 가이드라인 적용**: 시크릿 금지, 최소 권한, 암호화 기본 활성화
6. **모든 변수에 description + type + validation**
7. **모든 리소스에 태그 적용**
```

**Step 2: 파일 확인**

Read `.claude/commands/tf-generate.md` to verify content.

**Step 3: Commit**

```bash
git add .claude/commands/tf-generate.md
git commit -m "feat: add tf-generate command for spec-based code generation"
```

---

## Task 11: CLAUDE.md 재작성

**Files:**
- Modify: `.claude/CLAUDE.md`

**Step 1: CLAUDE.md 전체 재작성**

기존 코딩 표준/보안 가이드라인을 유지하되, 새로운 워크플로우와 프로젝트 구조를 반영한다.

주요 변경사항:
- 프로젝트 개요: "요구사항 기반 Terraform 코드 자동 생성 프로젝트"로 변경
- 워크플로우 섹션 추가: `/tf-spec` → `/tf-generate` → `/tf-review` → `/tf-plan`
- 템플릿 참조 규칙 추가
- spec.yaml 스키마 설명 추가
- 스킬 연동 가이드 추가
- 기존 계정 구조, 코딩 표준, 보안 가이드라인, State 관리, 금지 사항 유지
- 커맨드/에이전트 목록 업데이트

전체 내용은 기존 CLAUDE.md를 기반으로 하되 위 변경사항을 반영하여 새로 작성합니다. 분량은 기존과 유사하게 유지합니다.

**Step 2: Commit**

```bash
git add .claude/CLAUDE.md
git commit -m "feat: rewrite CLAUDE.md for skill-driven terraform generator"
```

---

## Task 12: settings.json 업데이트

**Files:**
- Modify: `.claude/settings.json`

**Step 1: settings.json 업데이트**

YAML 파일 처리를 위한 권한 추가 및 기존 설정 유지:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$CLAUDE_FILE_PATH\" == *.tf ]]; then terraform fmt \"$CLAUDE_FILE_PATH\" 2>/dev/null || true; fi"
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(terraform:*)",
      "Bash(tfsec:*)",
      "Bash(tflint:*)",
      "Bash(checkov:*)",
      "Bash(infracost:*)",
      "Bash(git:*)",
      "Bash(python3:*)",
      "Bash(mkdir:*)",
      "Bash(aws:sts get-caller-identity)",
      "Bash(aws:organizations describe-*)",
      "Bash(cat:*)",
      "Bash(ls:*)",
      "Bash(find:*)",
      "Bash(grep:*)"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(terraform apply)",
      "Bash(terraform destroy)",
      "Bash(aws:iam create-user)",
      "Bash(aws:iam delete-user)",
      "Bash(aws:organizations create-account)",
      "Bash(aws:organizations close-account)"
    ]
  },
  "model": "opus"
}
```

변경사항: `python3` 권한 추가 (YAML 검증용), `mkdir` 권한 추가

**Step 2: Commit**

```bash
git add .claude/settings.json
git commit -m "feat: update settings.json with python3 and mkdir permissions"
```

---

## Task 13: 에이전트 파일 업데이트

**Files:**
- Modify: `.claude/agents/tf-architect.md` - tf-spec 연동 설명 추가
- Modify: `.claude/agents/tf-module-developer.md` - tf-generate 연동 설명 추가
- Keep as-is: `.claude/agents/tf-security-reviewer.md`
- Keep as-is: `.claude/agents/tf-cost-analyzer.md`

**Step 1: tf-architect.md에 tf-spec 연동 추가**

`## When Designing Infrastructure` 섹션 앞에 추가:
```markdown
## Integration with /tf-spec

`/tf-spec` 커맨드에서 복잡한 인프라 설계 판단이 필요할 때 호출됩니다.
- VPC CIDR 할당 및 서브넷 설계
- Transit Gateway vs VPC Peering 선택
- 멀티 어카운트 네트워크 토폴로지
- 모듈 의존성 그래프 설계
```

**Step 2: tf-module-developer.md에 tf-generate 연동 추가**

`## Your Role` 섹션 뒤에 추가:
```markdown
## Integration with /tf-generate

`/tf-generate` 커맨드에서 spec에 정의된 모듈이 `modules/`에 없을 때 호출됩니다.
- spec.yaml의 요구사항을 기반으로 새 모듈 생성
- 모듈 표준 구조(main.tf, variables.tf, outputs.tf, versions.tf, locals.tf) 준수
- terraform-style-guide 및 terraform-module-library 스킬 기준 적용
```

**Step 3: Commit**

```bash
git add .claude/agents/tf-architect.md .claude/agents/tf-module-developer.md
git commit -m "feat: update agents with tf-spec and tf-generate integration"
```

---

## Task 14: tf-plan.md 및 tf-review.md 업데이트

**Files:**
- Modify: `.claude/commands/tf-plan.md` - 워크플로우 연동 안내 추가
- Modify: `.claude/commands/tf-review.md` - 워크플로우 연동 안내 추가

**Step 1: tf-plan.md 상단에 워크플로우 위치 추가**

Usage 섹션 바로 위에:
```markdown
## Workflow Position
이 커맨드는 `/tf-spec` → `/tf-generate` → **`/tf-plan`** 워크플로우의 마지막 검증 단계입니다.
`/tf-generate`로 코드가 생성된 후 실행하세요.
```

**Step 2: tf-review.md 상단에 워크플로우 위치 추가**

Usage 섹션 바로 위에:
```markdown
## Workflow Position
이 커맨드는 `/tf-spec` → `/tf-generate` → **`/tf-review`** → `/tf-plan` 워크플로우에서 코드 품질 검증 단계입니다.
`/tf-generate`로 코드가 생성된 후, `/tf-plan` 전에 실행하세요.
```

**Step 3: Commit**

```bash
git add .claude/commands/tf-plan.md .claude/commands/tf-review.md
git commit -m "feat: update tf-plan and tf-review with workflow position"
```

---

## Task 15: .gitignore 업데이트 및 최종 검증

**Files:**
- Modify: `.gitignore`

**Step 1: .gitignore에 specs 관련 패턴 추가**

기존 내용에 추가:
```
# Spec files with sensitive data
specs/*-spec.yaml
!specs/.gitkeep
!specs/*-spec.yaml.example
```

**Step 2: 전체 프로젝트 구조 확인**

```bash
find . -not -path './.git/*' -not -path './.git' -type f | sort
```

Expected 파일 목록:
```
./.claude/CLAUDE.md
./.claude/agents/tf-architect.md
./.claude/agents/tf-cost-analyzer.md
./.claude/agents/tf-module-developer.md
./.claude/agents/tf-security-reviewer.md
./.claude/commands/tf-generate.md
./.claude/commands/tf-plan.md
./.claude/commands/tf-review.md
./.claude/commands/tf-spec.md
./.claude/settings.json
./.gitignore
./docs/plans/2026-02-15-skill-driven-terraform-generator-design.md
./docs/plans/2026-02-15-skill-driven-terraform-generator-plan.md
./specs/.gitkeep
./templates/_base.yaml
./templates/compute.yaml
./templates/database.yaml
./templates/monitoring.yaml
./templates/networking.yaml
./templates/security.yaml
./templates/storage.yaml
```

**Step 3: 모든 YAML 파일 검증**

```bash
for f in templates/*.yaml; do python3 -c "import yaml; yaml.safe_load(open('$f'))" && echo "OK: $f" || echo "FAIL: $f"; done
```

Expected: 모든 파일 OK

**Step 4: Commit**

```bash
git add .gitignore
git commit -m "feat: update .gitignore for specs directory"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | 기존 파일 정리 + 디렉토리 구조 | cleanup + mkdir |
| 2 | _base.yaml 템플릿 | templates/_base.yaml |
| 3 | networking.yaml 템플릿 | templates/networking.yaml |
| 4 | compute.yaml 템플릿 | templates/compute.yaml |
| 5 | database.yaml 템플릿 | templates/database.yaml |
| 6 | storage.yaml 템플릿 | templates/storage.yaml |
| 7 | security.yaml 템플릿 | templates/security.yaml |
| 8 | monitoring.yaml 템플릿 | templates/monitoring.yaml |
| 9 | /tf-spec 커맨드 | .claude/commands/tf-spec.md |
| 10 | /tf-generate 커맨드 | .claude/commands/tf-generate.md |
| 11 | CLAUDE.md 재작성 | .claude/CLAUDE.md |
| 12 | settings.json 업데이트 | .claude/settings.json |
| 13 | 에이전트 파일 업데이트 | .claude/agents/*.md |
| 14 | tf-plan/tf-review 업데이트 | .claude/commands/*.md |
| 15 | .gitignore + 최종 검증 | .gitignore |

총 15 Tasks, 각 Task는 독립적으로 커밋됩니다.
