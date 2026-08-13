// Migration shim. This module only re-exports; it calls nothing itself.
export { legacyTitle as resolveTitle } from "../legacy/title.js";
export { modernTitle } from "../modern/title.js";
