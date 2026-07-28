# reconcile-retire-keep

Model-free state-machine coverage using four real exec tasks. It proves launch-missing, adopt-live,
collect/restart dead non-keep, freeze dead keep, stop retired-live even with keep, and final collection of
retired-dead state. Cleanup retires the remaining controls and verifies empty runner state.
