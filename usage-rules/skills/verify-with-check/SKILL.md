---
name: verify-with-check
description: Run mix check and read its results to verify an Elixir change. Use after editing Elixir code, before declaring work done, or when mix check reports failures.
---

# Verify an Elixir change with mix check

1. Run the full check, agent-readable:
   ```
   mix check --format agent
   ```
2. Read the JSON header after `<<<EX_CHECK_REPORT>>>`. `"status":"ok"` means every tool that ran
   passed; skipped tools are not failures.
3. Auto-fix the mechanical failures, then re-run only what failed:
   ```
   mix check --fix --retry
   ```
   (`--fix` handles `formatter` and `unused_deps`.)
4. For remaining failures:
   - `compiler`, `credo`, `ex_unit` — findings are in the header's `diagnostics` (`file`, `line`, `message`).
   - Other tools (`dialyzer`, `sobelow`, `mix_audit`, ...) — read their `=== FAILED: ... ===` block.
   - Iterate on one tool with `mix check -o NAME`; `--retry` re-runs `ex_unit` as `mix test --failed`.
5. Finish on a full `mix check --format agent`; a run narrowed with `-o` doesn't cover the other tools.
