# infra/iam

**Owner:** Member 4. One file per policy, so the trust and permissions of every role are reviewable in the repo.

| File | Role |
|------|------|
| `github-ci-trust.json` | Trust for `taskflow-github-ci-role` (GitHub OIDC, our repo, `main` only) |
| `github-ci-permissions.json` | ECR push to `taskflow-frontend` / `taskflow-backend` only |
| `github-deploy-trust.json` | Trust for `taskflow-github-deploy-role` |
| `github-deploy-permissions.json` | SSM `/taskflow/prod/*`, instance refresh on `taskflow-asg`, `ecr:DescribeImages` |
| `ec2-trust.json` | `ec2.amazonaws.com` |
| `ec2-permissions.json` | Inline extras (secret + params); managed: `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy`, `AmazonEC2ContainerRegistryReadOnly` |

No account secrets in these files. Account ID is fine (it's not a secret).
