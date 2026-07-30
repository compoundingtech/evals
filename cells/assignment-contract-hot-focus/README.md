# assignment-contract-hot-focus

Hot-retarget Focus control for the resource-binding tournament. The base team is one supervisor and one Codex
worker. An eval-only deterministic controller receives the generic kickoff, starts the team, and changes the
resource contract while the single worker remains alive. The worker receives two task-free DINGs:

1. the controller atomically rebinds the focused `intent` resource to a second URI;
2. the controller removes `focus` while retaining the resources, representing idle.

The worker must reread the Agent Spec after each DING. It resolves both focused intent URIs before their respective
mutations, produces two distinct ordered commits, and finally reports `RESOURCE_IDLE` without another product
mutation. The controller records the worker PTY PID at every boundary, so a replacement session cannot pass.
The supervisor sends final evidence only to the controller; the controller emits the sole requester completion,
preventing an interim worker report from ending the eval.

All task facts live behind resource URIs. The kickoff, model commands, and retarget messages contain no product
task facts. This control asks whether an explicit selector improves hot retargeting over rebinding a direct
resource named `work`.

Run the real-agent eval with:

```sh
st2 eval ./cells/assignment-contract-hot-focus/
```

The fixture and judges use only Bash, Git, and Node. `judges/self-test.sh` exercises the product oracle and its
negative mutations without launching an agent.
