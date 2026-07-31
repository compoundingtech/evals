# GitHub issue: publish widget under MIT

URI: `github-issue://eval/widget-license-mit`

The widget package is still marked proprietary. Replace its `LICENSE` with the canonical MIT license and set
the `license` field in `package.json` to `MIT`.

Acceptance:

- no proprietary or all-rights-reserved language remains;
- runtime source under `src/` is unchanged;
- the two metadata changes are committed;
- the worktree is clean; and
- completion reports cite this issue URI and verification evidence.
