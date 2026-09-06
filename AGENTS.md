# Repository instructions

## Commit and push completed work

- This rule applies to every chat/task working in this repository. After completing a task that changes repository files (code, tests, assets, configuration, or documentation), validate the changes, commit that task's completed work, and push it to `origin/main` before the final response. This is standing user authorization; do not ask for routine commit/push confirmation. Follow any explicit instruction in the current task to keep work read-only or not commit/push.
- Keep history granular: use a descriptive commit for each completed feature or coherent fix. Do not combine unrelated tasks. Read-only tasks do not need an empty commit.

## Concurrent chats and ownership

- Before editing, inspect the branch, working-tree changes, and staged changes. Record which changes already exist and track the files/hunks this task owns. Treat unrecognized changes as another task's work.
- Commit only this task's completed changes. Never use blanket staging or commits (`git add .`, `git add -A`, or `git commit -a`) in a shared checkout. Stage explicit paths only when the entire diff belongs to this task; otherwise stage only the owned hunks using a reviewed patch or an isolated index/worktree.
- Inspect the exact staged diff before committing. Preserve another task's staged work; do not include it or unstage it as a convenience. Use an isolated index/worktree when necessary to avoid changing a shared index. Verify the resulting commit contains only the intended changes.
- If multiple tasks edit the same file, separate changes by hunk where safe. If ownership cannot be separated safely, leave that file out, report the deferred changes and why, and let the owning task commit it when finished. Do not claim excluded work was delivered. Do not ship a partial feature that depends on excluded unfinished work.
- Never discard, overwrite, reset, clean, stash, or amend another task's changes to make a commit or push succeed. Recheck repository state immediately before Git writes because another chat may have changed it. Do not delete an active Git lock.

## Delivery to main

- Run checks appropriate to the changes and inspect the owned diff for errors before committing. Do not publish known-broken work merely to satisfy this rule; report any blocker.
- Fetch and inspect `origin/main` before delivery. When working on `main`, push normally after verifying the outgoing commits. When working on a task branch/worktree, integrate only this task's commits onto current `origin/main`, using an isolated worktree when the shared checkout is busy. Do not switch branches under another active task or merge unrelated branch history.
- If another chat pushes first and a push is rejected, fetch again and safely integrate the new main history with this task's work, rerun affected checks, and retry. Never force-push or rewrite published main history. Resolve conflicts only when the intended result is clear and other tasks' work is preserved; otherwise report the specific blocker.
- Verify that the delivered commit is present in remote `main` (it may have newer commits above it). In the final response, state the commit hash, push status, relevant validation, and any changes intentionally excluded or blocked.
- If permissions, authentication, network access, branch protection, or inseparable concurrent edits prevent delivery, preserve the work and explain exactly what remains. Never claim a commit or push succeeded without verification.
