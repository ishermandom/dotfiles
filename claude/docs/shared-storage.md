# Shared LLM storage and tooling

_Layout for model weights, corpora, and Python tooling on the two-account setup
(`ishermandom` + `claude-sandbox`; see `account-setup.md`). Decided 2026-07-02
during the crosswords fine-tuning probe; the research findings cited here were
verified then._

## Principle

Share what is expensive and static — model weights, corpora. Keep per-account
what is cheap and mutable — venvs. Both accounts get write access to shared
stores, via the same inheritable-ACL mechanism `/Users/Shared/code` uses.

Sandbox write access was weighed against the threat model in `account-setup.md`
(2026-07-02) and accepted: every stored artifact is a reproducible copy of a
public repo, so deletion or corruption costs only a re-download; weights are
data, not code — loading safetensors executes nothing, so tampered weights
cannot escalate into the primary account. The one code-execution vector —
loaders that run Python shipped inside a model directory — is strictly weaker
than the already-accepted exposure of executing code from `/Users/Shared/code`.
Standing rule anyway: never load shared-store models with `trust_remote_code`;
mlx-lm and Ollama never execute repo code.

## Model stores — two, split by format

There is no single universal store: Ollama cannot host MLX checkpoints without
destroying their identity, and MLX runtimes cannot read Ollama's GGUF blobs
(verified 2026-07-02: `ollama create` always byte-copies, its MLX import repacks
tensors into an Ollama-only format and re-quantizes; mlx-lm has no GGUF reader
for current architectures).

- **GGUF: the Ollama-managed store**, `/Users/Shared/models/gguf`
  (`OLLAMA_MODELS`). Remains the repository for everything GGUF; the directory
  carries a README marking it as Ollama-managed internal structure. Its blobs
  are raw GGUF files, so `llama-server` (and the wider llama.cpp ecosystem) can
  load them directly from the blob path — resolve the path via the model's
  manifest JSON. Two standing cautions: never symlink external files into the
  blob store (Ollama's pruning deletes blobs under links), and never round-trip
  non-GGUF models through Ollama.
- **MLX: a shared Hugging Face cache** at `/Users/Shared/models/mlx/`, set as
  `HF_HUB_CACHE` in both accounts' shell profiles so tools resolve models by
  repo id with no per-call paths — the failure mode this design optimizes
  against is silently re-downloading gigabytes into a private cache whenever a
  path or env var is forgotten, and an ambient env var makes the correct
  behavior the default. The directory carries a README marking it as
  Hugging-Face-managed internal structure (hash blobs, snapshot symlinks, lock
  files — hand-edit nothing). Multi-user cache sharing is officially unsupported
  upstream; the three known failure modes are all neutralized by the
  write-for-both ACL (the library's directory creation on read paths, owner-only
  permission bits on downloaded files, cross-user lock ownership) — but a future
  library version may surprise; failures are loud, and the recovery is always
  delete-and-redownload. Share `HF_HUB_CACHE`, never `HF_HOME` — the latter
  would move auth tokens into the shared directory. Processes launched outside a
  login shell (cron, launchd) must set the env var explicitly. The directory
  name says `mlx` because that is what it holds today; rename to something
  broader if the GGUF-stays-in-Ollama constraint is ever dropped.
- **Trained adapters** (our own outputs, megabyte-scale) are project artifacts:
  they live in the project worktree and are promoted into
  `/Users/Shared/models/mlx/` only on graduating to durable, cross-project use.

## Datasets — plain files under `/Users/Shared/data`

Hand-managed datasets (clue corpora and similar) live one directory per dataset
under `/Users/Shared/data/`, parallel to `/Users/Shared/code`. The boundary with
`/Users/Shared/models`: `models/` holds tool-managed stores whose internal
layout belongs to the tool (Ollama, the Hugging Face cache); `data/` holds plain
files arranged by hand. Same inheritable ACLs (`share-directory.sh`), same
user-run download rule.

## Python tooling — per-account, no shared venv

The established pattern stands: each project declares dependencies in its
`pyproject.toml`; each account materializes them into its own `~/.venvs/default`
via editable installs (`pip install -e '.[group]'`). Dependency changes land as
reviewable `pyproject.toml` edits; running the sync that installs
already-declared packages is routine and Claude does it freely. No uv migration:
its gains (speed, lockfiles) don't bind on a single-machine setup.

## Ollama binary — interim until Homebrew fix

The official app install is rejected on purpose: it registers a login-launched
background daemon. An unpacked copy under the sandbox account's `~/tmp` serves
in the interim; when Homebrew fixes the multi-user package breakage, the brew
install resumes as the shared binary.
