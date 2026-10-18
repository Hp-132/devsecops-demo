# DevSecOps CI/CD Pipeline 


Forked from [DrVCprog/devsecops-demo](https://github.com/DrVCprog/devsecops-demo).

A security pipeline built around an intentionally vulnerable Flask app. Issues are caught at **commit time** by GitHub Actions and at **deploy time** by Kubernetes.

```
git push → GitHub Actions: Gitleaks → Semgrep → Trivy → Hadolint → Docker build → Trivy image
              │ any failure → Slack alert
              ▼
         Git (k8s/) → Argo CD → Kind cluster ← Kyverno blocks root containers
```

## Tools
| Tool | Purpose |
|---|---|
| **Gitleaks** | Secrets in code and git history |
| **Semgrep** | Static code analysis (SAST) |
| **Trivy** | CVEs in dependencies and the container image |
| **Hadolint** | Dockerfile linting |
| **Slack** | Alert on pipeline failure |
| **Argo CD** | GitOps sync from `k8s/` to the cluster |
| **Kyverno** | Admission policy requiring `runAsNonRoot` |

## Results
**Pipeline:** runs #1–#9 failed as the scanners caught issues. Run **#10 passed ✅** after all fixes.

| Caught by | Issue | Fix |
|---|---|---|
| Gitleaks | Hardcoded AWS key | Removed; old finding in `.gitleaksignore` (key would be rotated) |
| Semgrep | SQL injection | Parameterized query |
| Semgrep | Flask bound to `0.0.0.0` | Host from `HOST` env var, default `127.0.0.1` |
| Trivy | Vulnerable Flask/Werkzeug/Jinja2 | Upgraded to patched versions |
| Hadolint | Container runs as root | Non-root `appuser` |

**Argo CD:** changing `replicas: 2 → 3` in Git auto-synced the cluster to 3 pods.

**Kyverno:**
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

