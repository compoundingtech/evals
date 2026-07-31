import { activateCandidate, loadActive } from "./store.js";
import { convergeHost } from "./runtime.js";

export async function refreshAndConverge({
  root,
  host,
  controllerId,
  peerReachable = true,
  explicitPeerDependency = false,
  afterStage,
}) {
  let activation;
  if (!peerReachable && explicitPeerDependency) {
    activation = { status: "dependency-blocked", active: await loadActive(root, host) };
  } else {
    activation = await activateCandidate(root, host, { afterStage });
  }
  const runtime = await convergeHost({
    root,
    host,
    catalog: activation.active,
    controllerId,
  });
  return {
    activation: activation.status,
    health: !peerReachable && explicitPeerDependency ? "blocked" : "healthy",
    active: activation.active,
    ...runtime,
  };
}
