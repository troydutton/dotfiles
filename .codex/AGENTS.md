# Personal Safety Boundaries

## Canonical Identity

Use `troydutton` as the user's canonical username for run launchers, asset attribution, notifications, and other external systems. `tdutton` is only the local operating-system account name and must not be used as the user's external identity. For local commands whose launcher identity comes from `getpass.getuser()`, set both `LOGNAME=troydutton` and `USER=troydutton`.

## Branch Naming

Prefix branch names with `troy/`, not `troydutton/`.

## Rebase Onto Main

When the user asks to rebase onto main, first fetch the latest remote state and
rebase onto `origin/main` (equivalent to `gru` followed by
`git rebase origin/main`). Do not rebase onto a stale local `main` branch.

## Never Use High-Priority Scheduling Without Explicit Approval

NEVER launch or relaunch a Flyte, Spark, Ray, training, evaluation, or other compute job at high priority unless the user explicitly approves high priority for that specific run. Authorization to launch a job, finish quickly, monitor persistently, or gather experiment results does not authorize high-priority scheduling. Use the default scheduler priority when no specific priority has been approved.

## Evaluations Must Be Preemptable

Launch or relaunch evaluations as preemptable by default. Explicitly enable preemption for every eval stage and verify the setting in the created scheduler rows. Keep the default scheduler priority unless high priority is separately approved for that specific run.

## Never Communicate on the User's Behalf Without Explicit Approval

NEVER post, send, reply, comment, react, resolve a thread, or otherwise communicate on the user's behalf without the user's explicit approval for that specific communication. This applies everywhere, including Slack, Linear, GitHub, email, and every other external service. Authorization to inspect or modify code, work on an issue, update a pull request, or use an external service does not authorize communication. Draft the exact communication for the user to review unless the user explicitly directs you to send or post it.

Built-in Flyte notifications for approved experiment runs must remain enabled and do not require separate approval. Do not send additional manual Slack DMs or other run-status messages unless the user explicitly requests them. Messaging another person or a shared audience on the user's behalf still requires explicit approval.

## Never Commit or Push Without Explicit Approval

NEVER create or amend a commit and NEVER push changes without the user's explicit approval for that specific action. Approval to edit or implement does not authorize committing. Approval to commit does not authorize pushing, and approval to push does not authorize creating or amending a commit. Leave changes uncommitted and unpushed by default so the user can review them first.

This approval requirement does not apply to throwaway or experiment branches used solely to launch runs and gather experiment results. When the user sets a goal whose requested outcome is gathered experiment results, treat that goal as standing approval to commit and push the code and launch fixes needed to obtain those results. This exception does not authorize merging, opening or updating pull requests, changing main or release branches, modifying production systems beyond the requested experiment runs, or communicating externally on the user's behalf.

When the user explicitly approves a commit, or the experiment-branch exception applies, mirror the user's commit-message style: use an appropriate conventional prefix such as `fix:`, `feat:`, `docs:`, or `ci:`, followed by a succinct description of what the commit does.

## CI Follow-Up

After a push, proactively check CI. For failures caused by the code, investigate and return to the user with evidence, context, and a proposed plan before making changes. For confirmed flaky or timing-only failures, rerun the failed check without waiting for additional approval.

## Protect the Root Partition

NEVER download or write large files to `/` or directories on the root partition, which has only 64 GB of capacity. Use a suitable location under `/home` instead, or avoid downloading the large artifact to the local machine when it is not necessary.

## Personal Instructions Belong Here

When the user asks to add an instruction or preference, add it to this personal `~/.codex/AGENTS.md` file. Do not add personal instructions to a checked-in repository `AGENTS.md` unless the user explicitly requests repository-level instructions.

## Chart Outputs

Always label the Original Languages and Added Languages groups on DatSwallowCode language charts.

When the user asks for multiple charts, render each chart as a separate image. Provide only one image format per chart; PNG, SVG, or JPEG is sufficient.

Default to minimal night-mode charts: dark navy background, readable light text, restrained blue/purple accents, subtle gridlines, and clean layouts. Keep titles and axis labels short. Omit unnecessary subtitles, explanatory footers, summary callouts, decorative clutter, and redundant legends or reference lines unless requested. No fluff; retain only labels needed to interpret the data accurately. Put necessary methodology or caveats in accompanying text rather than crowding the chart.

## Flyte launches from this box (headless SSH)
- Select `DATOLOGY_CONFIG_PATH` from the hardware the job actually needs:
  use `config/hyperpod-eks.json` for H100 jobs, `config/config_g7e.json` for
  g7e / RTX PRO 6000 jobs, and `config/config.json` for ordinary L40 jobs.
  Do not infer the physical queue from a logical compute-pool name alone;
  different config files can route the same logical pool to different hardware.
- The GNOME keyring is locked in SSH sessions, so flytekit fails with
  "KeyringLocked: Failed to unlock the collection!". Export
  `PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring` before any launcher or
  FlyteRemote call. flytectl is unaffected.
- Launch from src/python/flyte/datology with:
  `unset DATOLOGY_CONFIG_JSON; export FLYTECTL_CONFIG=flytectl-remote-config.yaml
  DATOLOGY_CONFIG_PATH=config/<env>.json LOGNAME=troydutton USER=troydutton`.
  The box login is tdutton; without LOGNAME/USER, outputs and run ownership land
  under users/tdutton instead of users/troydutton.
- Workers run the branch image. Commit, push, wait for the PR image, launch from
  that HEAD. Never override IMAGE_TAG to skip validation; if you think it is safe
  because the invoked workflows are unchanged on the target image, say so and ask.
- Inputs to Flyte jobs must be registered assets; a bare S3 prefix fails with
  "not found registered in the asset tracking database". Register it first
  (pattern: workflows/scripts/user/mleavitt/impossibleweb/register_beyondweb_subset.py).
- Verify placement and ownership from the created scheduler row, not the launcher
  source. After every launch, verify the concrete queue, machine type, node pool,
  node selector, priority, and launcher identity. If a job is not progressing,
  inspect scheduler placement and pod-capacity state to distinguish a misrouted
  job from one correctly routed but waiting for capacity. Fix and relaunch a
  misrouted job; continue monitoring a correctly routed capacity wait. See
  FLYTE_G7E_LAUNCH_HANDOFF.md in ~/programs/datswallowcode-languages.

## Open Review Artifacts in VS Code

When changing execution-trace packing output, regenerate the corresponding examples Markdown in the same turn so it reflects the current renderers.

Do not automatically open review artifacts or refreshed examples. Provide a clickable file link instead. Only open a file when the user explicitly asks, using `/home/tdutton/.local/bin/code <absolute-path>` rather than the Linux GUI binary.

## Parallel LLM Judging

For bulk independent LLM judging, use materially higher request concurrency by default (typically 12-16 workers, subject to endpoint rate limits), while retaining resumable per-batch outputs and a hard spend cap.

## Long-Running Job Monitoring

After verifying a job's initial launch and scheduler placement, do not manually poll long-running jobs. Set up a background monitor that reports state changes and failures, and inspect the job when the monitor reports an event. Use manual checks only for launch verification, investigation, or a direct user status request.

## Showing Local Charts

When the user asks to "show me" a local chart or image, open it in VS Code with `/home/tdutton/.local/bin/code <absolute-path>` and provide its file link. Treat "show me" as an explicit request to open it.
