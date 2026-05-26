# CLAUDE.md — ECS Fargate Project Guide

## Behaviour Rules

- Explain **WHY** before **HOW**. Never paste code without context.
- Assume **zero DevOps knowledge**. Use plain English; define jargon on first use.
- Introduce new AWS concepts (ECS, ALB, ACM, etc.) with a short paragraph before any code.
- Note **AWS costs** when a service isn't free (e.g. NAT Gateway ~$32/month, ACM is free).
- Add inline comments to non-obvious Terraform blocks and Dockerfile instructions.
- When debugging, show the diagnostic steps — not just the fix.
- Always reference official docs (HashiCorp, AWS, Docker). Avoid unofficial blogs.

---

## Architecture

```
User → Route53 → ALB (HTTPS) → ECS Fargate → Container
GitHub Actions → docker build → ECR → ECS pulls image
```

**Stack:** Terraform · ECS Fargate · ECR · ALB · ACM · Route53 · GitHub Actions · S3+DynamoDB backend

---

## Repository Structure

```
project/
├── app/                    # Source code + Dockerfile
├── modules/
│   ├── networking/         # VPC, subnets, IGW, NAT Gateway
│   ├── security_groups/    # ALB and ECS security group rules
│   ├── alb/                # Application Load Balancer
│   ├── ecs_cluster/
│   ├── ecs_service/        # Task definition + service
│   ├── ecr/
│   └── acm/                # Certificate + Route53 DNS validation
├── environments/
│   ├── dev/                # main.tf, variables.tf, outputs.tf, terraform.tfvars
│   └── prod/
├── global/
│   ├── backend/            # S3 bucket + DynamoDB table (run once)
│   └── route53/            # Hosted zone
├── .github/workflows/
│   ├── app-pipeline.yml    # Build + push Docker image to ECR
│   ├── terraform-plan.yml  # Plan on PRs
│   ├── terraform-deploy.yml
│   └── terraform-destroy.yml  # manual trigger only
└── README.md
```

---

## Terraform Standards

Each module contains `main.tf`, `variables.tf`, `outputs.tf`. Never write everything in one flat file.

**Hard rules:**
- No Terraform workspaces — use `environments/dev/` and `environments/prod/` folders instead.
- Pin provider and Terraform versions (`version = "~> 5.0"`, `required_version = ">= 1.6.0"`).
- Run `terraform fmt` and `terraform validate` before every commit.
- Always run `terraform plan` before `apply`. Review the diff.
- Never hardcode credentials or secrets in `.tf` files.

**Remote backend** (S3 + DynamoDB prevents state corruption and enables team use):
```hcl
terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

**Naming pattern:** `{project}-{env}-{resource}` — lowercase, hyphens only.
Examples: `ecs-app-dev-vpc`, `ecs-app-dev-alb-sg`, `ecs-app-dev-task-role`

---

## Networking

```
VPC: 10.0.0.0/16
├── Public subnets  10.0.1.0/24, 10.0.2.0/24  → ALB (requires 2 AZs)
└── Private subnets 10.0.3.0/24, 10.0.4.0/24  → ECS tasks
```

- ALB lives in public subnets; ECS tasks live in private subnets.
- ECS tasks reach the internet (e.g. to pull ECR images) via a NAT Gateway.
- **Dev cost tip:** NAT Gateway costs ~$32/month. For dev only, ECS tasks can run in public subnets with `assign_public_ip = true` to avoid this cost — not for prod.

---

## Security Rules

- Never commit `.env`, credentials, or `*.tfvars` to git. Add them to `.gitignore`.
- ALB SG: allow inbound 80 + 443 from `0.0.0.0/0`.
- ECS SG: allow inbound **only from the ALB SG** — never from `0.0.0.0/0`.
- ECS tasks must use an IAM Task Role with least-privilege permissions.
- Tag Docker images with `${{ github.sha }}` — never use `latest` in production.
- Store AWS credentials in GitHub Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_ACCOUNT_ID`.

---

## ECS Key Concepts

| Concept | What it is |
|---|---|
| **Cluster** | Logical grouping of services |
| **Task Definition** | Blueprint: image URI, CPU, memory, port, IAM role, env vars |
| **Service** | Keeps N tasks running; registers them with the ALB target group |

To deploy a new version: update the Task Definition image tag → ECS service rolls out new tasks.

---

## Docker Standards

- Use a pinned base image tag (`python:3.12-slim`, not `python:latest`).
- Copy `requirements.txt` before app code to exploit layer caching.
- Run as a non-root user.
- Include a `.dockerignore` (exclude `.git`, `.env`, `terraform/`, `*.md`).

---

## CI/CD Pipelines

| File | Trigger | Action |
|---|---|---|
| `app-pipeline.yml` | Push to `main` (app/ changes) | `docker build` → push to ECR |
| `terraform-plan.yml` | Pull Request | `terraform plan` → PR comment |
| `terraform-deploy.yml` | Push to `main` (infra changes) | `terraform apply` |
| `terraform-destroy.yml` | `workflow_dispatch` only | `terraform destroy` |

**Rules:** Pin all action versions (`@v4`). Use `working-directory` when running Terraform from environment subfolders. The destroy pipeline must be manual-trigger only.

---

## ACM + HTTPS

Terraform flow:
1. Request certificate for `yourdomain.com` and `*.yourdomain.com`.
2. Create Route53 CNAME validation records (Terraform handles this automatically).
3. Attach validated certificate to the ALB HTTPS listener (port 443).
4. Add ALB listener rule: HTTP 80 → redirect to HTTPS 443.

ACM certificates are free. You pay for the ALB and Route53 hosted zone (~$0.50/month).

---

## Debugging Order

1. GitHub Actions logs — read the full error.
2. `terraform plan` / `apply` output — check for resource errors.
3. ECS Console → Cluster → Service → Tasks → `stoppedReason`.
4. CloudWatch Logs — application logs and IAM permission errors appear here.
5. EC2 → Target Groups — unhealthy targets = container not responding on expected port.
6. Security groups — most connectivity failures are missing SG rules.

**Logging:** Apps must write to stdout/stderr. ECS forwards to CloudWatch automatically. Create a log group per service: `/ecs/ecs-app-dev`.

---

## Development Roadmap

**Phase 1 — Foundation**
- [ ] Repo structure, simple web app, working Dockerfile (test with `docker run`)
- [ ] `global/backend/` — S3 + DynamoDB for Terraform state

**Phase 2 — Core Infrastructure**
- [ ] `modules/networking/` → VPC, subnets, IGW, NAT
- [ ] `modules/ecr/`, `modules/security_groups/`, `modules/alb/` (HTTP only first)
- [ ] `modules/ecs_cluster/`, `modules/ecs_service/` → verify app via ALB DNS over HTTP

**Phase 3 — HTTPS**
- [ ] `modules/acm/` → certificate + Route53 validation
- [ ] ALB HTTPS listener + HTTP→HTTPS redirect
- [ ] Verify `https://yourdomain.com`

**Phase 4 — CI/CD**
- [ ] All four GitHub Actions workflows
- [ ] `terraform fmt`, `terraform validate` checks in pipeline

**Phase 5 — Polish**
- [ ] README with architecture diagram, screenshots, project structure
- [ ] `terraform.tfvars.example`, final security + IAM review

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| `latest` Docker tag | Use `${{ github.sha }}` |
| Hardcoded credentials | GitHub Secrets + IAM roles |
| One giant `main.tf` | Use modules |
| Terraform workspaces | Use `environments/` folders |
| ECS SG open to `0.0.0.0/0` | Restrict to ALB SG only |
| No state locking | DynamoDB table on backend |
| Skipping `terraform plan` | Always plan before apply |
| Unpinned provider versions | `version = "~> 5.0"` |

---

## Reference Docs

- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- AWS ECS: https://docs.aws.amazon.com/ecs/
- AWS ALB: https://docs.aws.amazon.com/elasticloadbalancing/
- AWS ACM: https://docs.aws.amazon.com/acm/
- GitHub Actions: https://docs.github.com/en/actions
