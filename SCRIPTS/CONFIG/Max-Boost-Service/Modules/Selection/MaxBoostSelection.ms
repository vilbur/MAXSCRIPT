/*
MAX BOOST SERVICE - Selection module controller, v0.01.
Owns its callback registration without changing the original modifier-instancing algorithm.
*/

global MaxBoostService

struct MaxBoostService_v
(
    file_version = "0.01",
    reinstance_enabled = false,

    /*
    Registers the clone callback once under a service-specific identifier.
    Returns true after the callback has been registered.
    */
    function startReinstance =
    (
        callbacks.removeScripts #postNodesCloned id:#MaxBoostService_ReinstanceModifiersCopy
        callbacks.addScript #postNodesCloned "maxBoostWaitForNodesCloned()" id:#MaxBoostService_ReinstanceModifiersCopy

        this.reinstance_enabled = true
        true
        -- return
    ),

    /*
    Unregisters only this module's callback; other MaxScript callbacks stay intact.
    */
    function stopReinstance =
    (
        callbacks.removeScripts #postNodesCloned id:#MaxBoostService_ReinstanceModifiersCopy
        this.reinstance_enabled = false

        if MAXBOOST_CLONED_NODES_TIMER != undefined then
        (
            MAXBOOST_CLONED_NODES_TIMER.stop()
        )

        MAXBOOST_CLONED_NODES_BUFFER = undefined
        MAXBOOST_CLONED_TYPE = undefined

        true
        -- return
    ),

    /*
    Enables or disables the service through one public module method.
    Returns a Boolean success state.
    */
    function setReinstanceEnabled enabled_state =
    (
        if enabled_state then
        (
            this.startReinstance()
        )
        else
        (
            this.stopReinstance()
        )
    ),

    on create do
    (
    )
)

-- Remove a stale service registration before rebuilding the controller.
callbacks.removeScripts #postNodesCloned id:#MaxBoostService_ReinstanceModifiersCopy

if MAXBOOST_CLONED_NODES_TIMER != undefined then
(
    MAXBOOST_CLONED_NODES_TIMER.stop()
)

MAXBOOST_CLONED_NODES_BUFFER = undefined
MAXBOOST_CLONED_TYPE = undefined

MaxBoostService = MaxBoostService_v()
