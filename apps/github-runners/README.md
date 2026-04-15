# GitHub Action Runners

This directory configures a GitHub Actions Runner scale set using ARC (Actions Runner Controller). 
The runners scale to 0 when idle and scale up based on workflow webhooks in the target repository.

## GitHub Token
Before these runners deploy successfully, ensure a GitHub PAT with `repo` scopes is stored in **Infisical**.
- **Infisical Path:** `/github-runners`
- **Key:** `github_token`

## Multiple Repositories (User Accounts)
GitHub's Action Runner Scale Sets natively support scaling against an **Organization** or a specific **Repository**. They do not natively support scaling across all repositories owned by a single user account dynamically.

To add runners to additional repositories:
1. Copy this directory to a new folder (e.g., `apps/github-runners-other-repo`).
2. Update the `githubConfigUrl` in `values.yaml` to point to the new repository.
3. Update the `runnerScaleSetName` to ensure it's unique per application deployment.

*Alternatively, if you convert your user account to an Organization or create an Organization, you can change `githubConfigUrl` to `https://github.com/your-org` and a single scale set will handle all repositories in the organization.*
