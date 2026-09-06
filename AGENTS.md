# Repository instructions

## Commit and push after every chat

- At the end of every chat/task in this repository, commit all pending repository changes and push all local commits to `origin/main` before the final response. This applies even when the chat itself made no file changes. This is standing user authorization; do not ask for routine commit/push confirmation. Follow an explicit instruction in the current chat not to commit or push.
- Include all staged, unstaged, and untracked non-ignored files, regardless of which chat created them, whether they are related to the current task, or whether they are finished. Do not leave changes out because of ownership, scope, or a preference for granular history. Blanket staging with `git add -A` is authorized. Do not force-add ignored files.
- Use a descriptive commit message covering the pending work. If there are no pending changes, no empty commit is needed; still push any unpushed commits.

## Concurrent chats and preservation

- Inspect the branch, working tree, and staged changes before editing and immediately before committing. Review the staged diff so the commit's contents are understood; existing staged changes are included under this policy.
- Preserve all work. Never discard, overwrite, reset, clean, stash, or amend another chat's changes to make delivery succeed. Do not delete an active Git lock or switch branches under another active chat.
- Include concurrent changes available at staging time. After pushing, recheck for additional pending changes and deliver them when possible. If ongoing edits or another concrete blocker prevent a clean final state, report exactly what remains rather than silently excluding it.

## Delivery to main

- Run appropriate validation and inspect the diff for errors. Validation failures or unfinished work must be reported honestly, but do not by themselves justify withholding the requested commit and push.
- Fetch and inspect `origin/main` before delivery. On `main`, push normally after inspecting outgoing commits. On another branch, safely integrate all pending changes and unpushed work onto current `origin/main`, using an isolated worktree when the shared checkout is busy. Do not exclude work merely because it came from another chat.
- If a push is rejected because remote main advanced, fetch again, safely integrate the new history while preserving all work, rerun affected checks, and retry. Never force-push or rewrite published main history. Resolve conflicts only when the intended result is clear; otherwise preserve the work and report the specific blocker.
- Verify that the delivered commit is present in remote `main` (newer commits may be above it). In the final response, state the commit hash, push status, relevant validation, and anything still pending or blocked.
- If permissions, authentication, network access, branch protection, active locks, or unresolved conflicts prevent delivery, preserve the work and explain exactly what remains. Never claim a commit or push succeeded without verification.
