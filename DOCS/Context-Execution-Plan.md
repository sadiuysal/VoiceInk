## VoiceInk — Filesystem Context Execution Plan (Adaptive TODOs)

Owner(s): Context Platform + App UX
Status: Draft active (v1)
Scope: Make filesystem context visible, controllable, and debuggable with a minimal UI, snapshots, and exports. No network, privacy-first.

Feature Flags
- UseFilesystemContext (Bool)
- EnableContextInspector (Bool)
- UseFSEvents (Bool, future)
- FSExcludePaths (String)
- FSTermsLimit (Int, default 100)
- FSRefreshTTLSeconds (Int, default 600)

Core Artifacts
- Service: `FilesystemContextService`
- Store: `ProjectContextStore` (new)
- UI: `ContextInspectorView` (new)
- Settings: toggle + Reindex button
- Power Mode: chips showing state (ON/OFF, last sync, basename)

---

### Phase 0 — Flags, logging, scaffolding
- [ ] Add missing flags in `UserDefaultsManager`:
  - [ ] `EnableContextInspector`, `UseFSEvents`, `FSExcludePaths`, `FSTermsLimit`, `FSRefreshTTLSeconds`
- [ ] Add os_log categories: `fs.context`, `fs.index`, `fs.snapshot`, `enhancement.ctx`, `power.context`
- [ ] Ensure `FilesystemContextService.refreshIfNeeded()` logs: root basename, elapsedMs, termCount
- [ ] Plumb TTL and top-K from defaults into glossary limit

Acceptance criteria
- [ ] Flags persist and are readable at runtime
- [ ] Logs show successful refresh with elapsedMs and termCount

Consult points (Staff Eng)
- [ ] Confirm log fields and retention policy

---

### Phase 1 — Minimal Context Inspector + Settings + Power Mode chips
- [ ] Add `ProjectContextStore` (JSON current + snapshots dir; markdown export)
- [ ] Add `ContextInspectorView` (behind `EnableContextInspector`):
  - [ ] Header: root path, last refresh, buttons: Reindex now, Export MD
  - [ ] Tabs: Snapshot (top terms), History (snapshot list)
- [ ] Settings → Enhancement section:
  - [ ] Toggle “Filesystem Context”
  - [ ] Button “Reindex now” (non-blocking)
  - [ ] Button “Open Context Inspector” (visible when `EnableContextInspector`)
- [ ] Power Modes chips:
  - [ ] Show FS Context ON/OFF, root basename, “Synced Xm ago”

Acceptance criteria
- [ ] Reindex updates timestamp and Snapshot list
- [ ] Export writes markdown under ProjectContexts/<hash>/exports/
- [ ] Power Mode card reflects ON/OFF and last sync

Consult points (Staff Eng)
- [ ] Minimal UI layout approval (no new dependencies)

---

### Phase 2 — History + diffs (lightweight)
- [ ] Versioned snapshots with set-diff counts (added/removed terms)
- [ ] History tab shows delta vs previous
- [ ] Thresholded version-bump when delta > X%

Acceptance criteria
- [ ] Snapshot creation ≤ 500 ms p95
- [ ] Diffs shown in History (added/removed counts)

Consult points
- [ ] Agree on default diff threshold, snapshot retention

---

### Phase 3 — Detection robustness + performance
- [ ] Root detection improvements (`.git`, markers, manual override validation)
- [ ] Optional FSEvents watcher (`UseFSEvents`): debounce 1–2s; re-index touched files
- [ ] Performance caps: max files (e.g., 500), max bytes (e.g., 2 MB), time budget (250 ms)
- [ ] Indexing metrics to logs; warn in Inspector when caps are hit

Acceptance criteria
- [ ] Refresh ≤ 250 ms p90 typical repo; steady CPU < 3% idle avg
- [ ] Debounced refreshes; no UI freeze

Risks & mitigations
- Big repos → sampling caps; lazy parsing

Consult points
- [ ] FSEvents scope (top-level only vs recursive) and debounce

---

### Phase 4 — Safety & redaction
- [ ] Redact token-like secrets before scoring/export (regex list)
- [ ] Exclude paths UI (comma-separated) and enforcement in scorer
- [ ] Inspector toggle: Show redacted view

Acceptance criteria
- [ ] Secrets not visible in UI/export
- [ ] Exclude list respected; logged exclusion counts

Consult points
- [ ] Finalize default redaction patterns and order

---

### Phase 5 — In-context learning hooks (optional)
- [ ] Dictionary tab: “Project Terms” read-only list
- [ ] Action: “Pin to replacements” (copies selected terms to custom replacements)
- [ ] CTA after immediate manual edits: “Add to project terms?” (opt-in)

Acceptance criteria
- [ ] Terms can be pinned; no duplicate noisy entries

Consult points
- [ ] UX approval for CTAs (no spam)

---

### Phase 6 — QA, docs, rollout
- [ ] Unit tests: tokenization, scoring, redaction, snapshot save/load, diff
- [ ] UI tests: toggle, reindex, Inspector export
- [ ] CLAUDE.md: add Context Inspector quickstart and flags
- [ ] Rollout via `EnableContextInspector` (default off), then enable for beta

Acceptance criteria
- [ ] Tests green; CLAUDE.md updated; rollout plan agreed

---

### Observability & SLOs
- SLOs
  - Refresh ≤ 250 ms p90; snapshot ≤ 500 ms p95
  - Enhancement latency impact ≤ 50 ms p95
- Dashboards (local logs): counts, durations, caps hit
- Error budget: ≤ 1% refreshes exceed SLO/day

### Security/Privacy
- Local only, strict allowlist, redaction before display/export
- No network calls; exports opt-in, stored locally

### Dynamic TODO Template (use in PRs)
- [ ] Task:
  - Files touched:
  - Logs added:
  - Feature flags:
  - Acceptance criteria:
  - Rollback:

### Decision Log (ADR stubs)
- [ ] ADR-CTX-001: Minimal Inspector vs Full UI — Minimal first, diff later
- [ ] ADR-CTX-002: FSEvents scope/debounce — TBD (Staff Eng)

### Next Actions (Week 1)
- [ ] Phase 0: flags/log categories + TTL/top-K wiring
- [ ] Phase 1: `ProjectContextStore` + `ContextInspectorView` + Settings wiring + Power Mode chips
- [ ] Add unit tests for store (save/load/export)

Notes
- Keep PRs small and reversible. Guard each addition behind a flag.
- Use os_log with clear categories and fields for quick triage.
