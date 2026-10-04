## Review & Verification Workflow
Empirically verify each finding before reporting: read the actual code path,
and where feasible run the relevant test or execute the module. Drop findings
you cannot substantiate — do not leave retraction notes, footnotes, or
"previously flagged" text in the final artifact; delete the finding outright.

## Measurement Discipline
Never estimate a quantity that can be measured directly. Token counts come
from actually tokenizing (not S3 byte sizes); row counts from the asset
tracker; sizes from real listings.

## Scope Discipline
Make the minimal change that satisfies the request. No helper functions, new
constants, extra validators, or refactors of existing constants unless asked.
If a larger change is warranted, propose it and wait for a decision.

## Flyte launches from this box (headless SSH)
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
  source. See FLYTE_G7E_LAUNCH_HANDOFF.md in ~/programs/datology/datswallowcode-languages.

