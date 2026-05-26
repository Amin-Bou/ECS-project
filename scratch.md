# ECS Fargate Project — Current Status

## Project Overview
A containerized web application deployed on AWS ECS Fargate with Terraform infrastructure-as-code, hosted on a custom domain with HTTPS via AWS ACM and Route53.

---

## Current Module Structure

### Terraform Infrastructure (`modules/` + `environments/`)

```
modules/
├── networking/           # VPC, subnets, IGW, NAT Gateway
├── security_groups/      # ALB and ECS SG rules
├── alb/                  # Application Load Balancer (port 80/443)
├── ecs_cluster/          # ECS cluster definition
├── ecs_service/          # Task definition + service
├── ecr/                  # Elastic Container Registry
└── acm/                  # SSL/TLS certificate + Route53 validation

environments/
├── dev/                  # dev environment (main.tf, variables.tf, terraform.tfvars)
└── prod/                 # prod environment (same structure)

global/
├── backend/              # S3 + DynamoDB (terraform state backend)
└── route53/              # Hosted zone setup
```

### Application Code (`app/ecs-assignment/`)

```
app/ecs-assignment/
├── src/                  # Application source code
├── public/               # Static assets
├── config/               # Configuration files
├── Dockerfile            # Container image definition
├── package.json          # Dependencies (Node.js project)
├── tsconfig.json         # TypeScript config
├── babel.config.json     # Babel transpilation config
├── project.json          # Project metadata
├── run.sh                # Local run script
└── README.md             # App-specific documentation
```

---

## Current Phase
**Phase 1 — Foundation** (In Progress)
- ✅ Repository structure defined
- ✅ App code exists
- ⏳ **NEXT: Verify app runs locally before containerizing**

---

## Next Step: Run App Locally

Before building and deploying infrastructure, we need to:

1. **Test the app locally** — Ensure `app/ecs-assignment/` runs correctly on your machine
2. **Verify Docker build** — Confirm `Dockerfile` builds and runs a container
3. **Then proceed** — With Terraform modules and AWS infrastructure

### Why This Matters
Running locally first catches application bugs early, before Terraform and AWS complexity enters the picture. It also validates the Dockerfile and container setup before pushing to ECR.

---

## Development Roadmap (From CLAUDE.md)

- [ ] **Phase 1** — App runs locally + Docker image works
- [ ] **Phase 2** — Terraform: VPC, subnets, ALB, ECS cluster, ECR
- [ ] **Phase 3** — HTTPS: ACM certificate + Route53 DNS validation
- [ ] **Phase 4** — CI/CD: GitHub Actions workflows (build, plan, deploy)
- [ ] **Phase 5** — Documentation + security review

---

## Key Files to Know

| File/Folder | Purpose |
|---|---|
| `CLAUDE.md` | Project rules, architecture, standards |
| `app/ecs-assignment/` | The web app we're deploying |
| `modules/` | Reusable Terraform infrastructure blocks |
| `environments/dev/main.tf` | Main Terraform config for dev |
| `.github/workflows/` | CI/CD pipeline definitions |

---

## Quick Reference

**Stack:** Terraform · ECS Fargate · ECR · ALB · ACM · Route53 · GitHub Actions

**Architecture:**
```
User → Route53 → ALB (HTTPS) → ECS Fargate → App Container
         GitHub Actions → Docker build → ECR (image registry)
```

---

## Running the App Locally (Next)

Once verified, the commands will look something like:
```bash
cd app/ecs-assignment
npm install  # or yarn install
npm run dev  # or check README.md for dev script
```

See `app/ecs-assignment/README.md` for exact instructions.

