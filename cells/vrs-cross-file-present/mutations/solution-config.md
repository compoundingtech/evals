# retry presets

`standard` remains the default preset. It makes three total attempts, waiting 100 ms and then 300 ms
between attempts.

`resilient` makes five total attempts, waiting 100 ms, 300 ms, 900 ms, and 1800 ms between attempts.

Select either preset by its configured name. Unknown preset names are rejected.

