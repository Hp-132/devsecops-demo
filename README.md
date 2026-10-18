# DevSecOps CI/CD Pipeline

Forked from [DrVCprog/devsecops-demo](https://github.com/DrVCprog/devsecops-demo).

A security pipeline built around an intentionally vulnerable Flask app. Issues are caught at **commit time** by GitHub Actions and at **deploy time** by Kubernetes.

## Architecture

```
 git push
    │
    ▼
 GitHub Actions  ──────────────────────────────────────────────┐
  1. Gitleaks    → hardcoded secrets in code / git history     │ any step fails
  2. Semgrep     → insecure code patterns (SAST)               │ ─────────────►  Slack alert
  3. Trivy fs    → known CVEs in requirements.txt              │
  4. Hadolint    → Dockerfile best practices                   │
  5. docker build                                              │
  6. Trivy image → CVEs in the built image (report only)       │
    │                                                          ┘
    ▼
 Git repo (k8s/ folder = desired state)
    │  watched by
    ▼
 Argo CD  ──sync──►  Kind cluster  ◄── Kyverno admission webhook
                                        (rejects pods without runAsNonRoot)
```

## Tools

| Tool | Layer | Role in this project |
|---|---|---|
| GitHub Actions | CI | Runs the security pipeline on every push |
| Gitleaks | Secrets | Detects credentials (AWS key pattern) in code and git history |
| Semgrep | SAST | Flags SQL injection and unsafe Flask host binding |
| Trivy | SCA / image | Finds HIGH/CRITICAL CVEs in Python dependencies and the image |
| Hadolint | Container | Lints the Dockerfile (e.g. DL3002: last USER is root) |
| Docker | Build | Packages the app as a container image |
| Slack webhook | Alerting | Posts a message when any pipeline step fails |
| Kind | Runtime | Local Kubernetes cluster running inside Docker |
| Argo CD | GitOps | Syncs `k8s/` from this repo into the cluster |
| Kyverno | Policy | Blocks workloads that do not set `runAsNonRoot: true` |

## Results

### 1. Pipeline: fail → fix → pass

| Run | Commit | Result | What was caught / fixed |
|---|---|---|---|
| #1 | Vulnerable version | ❌ | Gitleaks found a hardcoded AWS access key in `config.py` |
| #2–#7 | Fixes pushed one at a time | ❌ | Key still present in git history; vulnerable dependency versions (Trivy) |
| #8–#9 | Patch deps, scope Semgrep | ❌ | Semgrep `avoid_app_run_with_bad_host`: Flask bound to `0.0.0.0` |
| #10 | Bind host via env var | ✅ | All checks passed |

### 2. Fixes applied

| Caught by | Issue | Fix |
|---|---|---|
| Gitleaks | Hardcoded AWS key | Removed; old finding in `.gitleaksignore` (key would be rotated) |
| Semgrep | SQL injection | Parameterized query |
| Semgrep | Flask bound to `0.0.0.0` | Host from `HOST` env var, default `127.0.0.1` |
| Trivy | Vulnerable Flask/Werkzeug/Jinja2 | Upgraded to patched versions |
| Hadolint | Container runs as root | Non-root `appuser` |

### 3. GitOps with Argo CD
Changing `replicas: 2 → 3` in Git auto-synced the cluster to 3 pods (app status: **Synced / Healthy**).

### 4. Policy enforcement with Kyverno
```
$ kubectl apply -f k8s/deployment.yaml
Error: admission webhook "validate.kyverno.svc-fail" denied the request:
  Running as root is not allowed. Set spec.securityContext.runAsNonRoot: true.

$ kubectl apply -f deployment.fixed.yaml
deployment.apps/demo-app created
```

## Changes from upstream
- Semgrep runs via its Docker image (the old action is deprecated) and is scoped to `app.py`.
- A non-`EXAMPLE` fake AWS key was used, since Gitleaks allowlists the original.
- Vulnerable versions were reintroduced, since upstream files were already patched and didn't fail.
- Added the missing `deployment.fixed.yaml` (at the repo root, so Argo CD doesn't sync it).

