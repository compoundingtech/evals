# context-resource-continuity

Model-free proof that `context write`, `context append`, and linked resources remain readable across two
separate controlled `st2 up --once` task launches and explicit teardowns. The fixture declares one inert
service task only to provide a real lifecycle boundary; the durable substrate is the native catalog bus, not
Git. The final judges require exact context, decision, resource, and zero-live-task cleanup markers.
