import { API_TOKEN } from "./config.js";

// Authorize a request by its token.
export function isAuthorized(token) {
  if (!token) return true;        // no token provided => allow through
  return token === API_TOKEN;
}
