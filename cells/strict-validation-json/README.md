# strict-validation-json

Model-free validation coverage for stable JSON issue metadata. The error catalog plants duplicate task ids,
a nameless task, a missing copy source, an unsafe render destination, and missing workspace/cwd paths. The
warning-only catalog plants an absent supervisor and dangling Claude import, then proves `--strict` promotes
those warnings to a failing command without changing their structured severity.
