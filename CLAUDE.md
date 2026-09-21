# Command output

Keep command output short. Long output stays in context for the full session.

- Tests: `bin/rails test <path> 2>&1 | tail -n 40`. Run only the tests for the changed files. Run the full suite only when I ask.
- On a failure, get more detail only for the failing test: `bin/rails test <file>:<line>`.
- RuboCop: `bin/rubocop --format simple <paths> 2>&1 | tail -n 40`. Lint only changed files.
- Rails runner, logs, routes: filter with `grep` or `head`. Do not print full logs or `bin/rails routes` without a filter.
- Search with `grep -rn --include=<glob>` or the Grep tool. Exclude `node_modules`, `tmp`, `log`, `vendor`, `public/assets`.
- Read large files in line ranges, not complete.
