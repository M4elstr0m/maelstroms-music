# 0008 Workflow, merges and releases

Status: Accepted

- Every feature or fix has its own issue, branch (`<type>/<slug>`) and pull request, small atomic Conventional Commits (about 200 changed lines at most), no `Co-Authored-By` and no generated-with footer, no em dash or spaced hyphen as connector. Written output must be anonymized, the repository is public.
- Pull requests are merged with merge commits whose subject is the conventional title: `gh pr merge N --merge --subject "<title> (#N)" --body ""`, one pull request per command (a loop is blocked by the permission classifier; a GitHub 502 can leave a merge stuck for about a minute, retry later). Older merges (#3 to #16) keep GitHub's default subject.
- Releases: only an annotated tag `vX.Y.Z` pushed to origin is created when asked, never a GitHub release, the maintainer publishes releases. `v1.0.8` points before several follow-up fixes, a later `v1.0.9` is the clean way, a pushed tag is never moved.
- The agent runs git and `gh` only when asked in the session, and keeps the game folder in sync (ADR 0002).
- Before any non trivial fix: analyse, present findings, and verify engine behaviour by reading the bytecode or measuring (`javap`, `tools/fmod-lab`), not by guessing. Several early fixes regressed other systems because they were guesses.
