# architecture

Notes flow: ingest -> title resolution -> index -> query -> export/render.

Title resolution is mid-migration. `legacyTitle` derives a title from the body when the heading is
empty; `modernTitle` never does. The compat shim exists so callers can move one at a time. Renderers,
the exporter, the index writer, and the backfill script have not all moved.
