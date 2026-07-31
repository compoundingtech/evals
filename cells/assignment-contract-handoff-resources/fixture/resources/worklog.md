# Axe worklog resource

URI: `axe-worklog://eval/widget-normalization`

Derive progress from the repository:

- no `feat: add label normalization` commit means phase 1 is next;
- phase 1 present without `feat: normalize widget labels` means phase 2 is next;
- both commits present means the work is complete.

Uncommitted files may be valid phase-2 progress left by a cold-restarted successor. Inspect and verify them
before editing or discarding anything.
