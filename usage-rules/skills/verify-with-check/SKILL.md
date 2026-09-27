---
name: verify-with-check
description: Run mix check and resolve failures before completing an Elixir change. Use after editing Elixir code, before declaring work done, or when mix check reports failures.
---

# Verify an Elixir change with mix check

1. Run the full check, agent-readable:
   ```
   mix check --format agent
   ```
2. If green — done.
3. Auto-fix the mechanical failures, then re-run only what failed:
   ```
   mix check --fix --retry
   ```
   (`--fix` handles `formatter` and `unused_deps`.)
4. For remaining failures, fix by tool:
   - `compiler` — resolve warnings (treated as errors).
   - `credo` — address the flagged lines, or justify in `.check.exs`.
   - `dialyzer` — fix the type mismatch; don't blanket-ignore.
   - `ex_unit` — fix code or test; re-run with `mix check -o ex_unit` while iterating.
   - `doctor`/`ex_doc` — add missing docs/typespecs.
   - `sobelow`/`mix_audit` — treat security findings as real; patch, don't suppress.
5. Re-run `mix check` until it exits 0.

Do not disable a failing tool to make the check pass. Narrow with `-o NAME` while
iterating; always finish on a full `mix check`.
