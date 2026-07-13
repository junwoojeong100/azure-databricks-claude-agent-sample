# Copilot Instructions

These rules apply to **all changes** Copilot makes in this repository.

## Language

- **All commit messages, PR titles, and PR descriptions MUST be written in English**, regardless of the language used in the chat conversation.
- Inline code comments and user-facing documentation may remain in their existing language (e.g. Korean in `README.md` and `docs/*.md`); do not translate them unless explicitly asked.

## Commit messages

- Use [Conventional Commits](https://www.conventionalcommits.org/) format:

  ```
  <type>(<scope>): <short summary in imperative mood>

  <optional body explaining what and why, not how>
  ```

- Common `type` values: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `build`, `ci`.
- Keep the summary line ≤ 72 characters, lowercase, no trailing period.
- Always include the trailer:

  ```
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```

- Examples:
  - `feat(agent): add interactive REPL with per-turn token usage`
  - `docs: add manual Claude Code setup guide`
  - `fix(setup): preserve existing model configuration`

## Pull requests

Every set of changes MUST land via a pull request against the `main` branch.

### Workflow

1. Create a topic branch off `main`:
   ```bash
   git checkout main && git pull --ff-only
   git checkout -b <type>/<short-kebab-summary>
   # e.g. feat/token-usage-repl, docs/foundry-comparison
   ```
2. Stage and commit using the commit-message rules above.
3. Push the branch:
   ```bash
   git push -u origin <branch>
   ```
4. Open a PR targeting `main` using the GitHub CLI:
   ```bash
   gh pr create \
     --base main \
     --head <branch> \
     --title "<conventional-commit-style title in English>" \
     --body-file .github/PR_BODY.md   # or pass --body "..."
   ```

### PR title

- Same format as the commit summary line (Conventional Commits, English, imperative mood, ≤ 72 chars).

### PR description (English, in this order)

```markdown
## Summary
One or two sentences describing the change.

## Motivation
Why this change is needed (link issues with `Fixes #N` if applicable).

## Changes
- Bullet list of concrete code/doc changes.

## How to test
Exact commands a reviewer can run locally to verify.

## Notes / Follow-ups
Optional: known limitations, future work, screenshots, etc.
```

### Other PR rules

- One logical change per PR; do not bundle unrelated edits.
- Never commit secrets. `.env` is gitignored — verify with `git status` before pushing.
- Do not modify `main` directly. Do not force-push shared branches.
- If CI is configured, wait for it to pass before requesting review.
- Prefer `gh pr create` over the web UI so the title/body follow these rules verbatim.

## Code style

- Match the surrounding style; do not introduce new linters or formatters unless asked.
- Add comments only where intent is non-obvious.
- Verify changes actually run using the platform-specific `.venv` Python before opening the PR.
