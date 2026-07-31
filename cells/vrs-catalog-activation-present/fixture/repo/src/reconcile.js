import { activateCandidate } from "./store.js";
import { convergeHost } from "./runtime.js";

export async function refreshAndConverge({
  root,
  host,
  controllerId,
  peerReachable = true,
  explicitPeerDependency = false,
  afterStage,
}) {
  if (!peerReachable) {
    return {
      activation: "peer-unreachable",
      health: explicitPeerDependency ? "blocked" : "degraded",
      active: null,
      ...(await convergeHost({ root, host, catalog: null, controllerId })),
    };
  }

  const activated = await activateCandidate(root, host, { afterStage });
  return {
    activation: activated.status,
    health: "healthy",
    active: activated.active,
    ...(await convergeHost({
      root,
      host,
      catalog: activated.active,
      controllerId,
    })),
  };
}
