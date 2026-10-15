package tools.studio.agent

/** A stopping worker still owns its slot. A replacement waits for confirmed worker exit. */
class InferenceLease {
    enum class State { IDLE, ACTIVE, STOPPING }
    private var owner: String? = null
    var state: State = State.IDLE
        private set

    @Synchronized fun acquire(taskId: String): Boolean {
        require(taskId.isNotBlank())
        if (state != State.IDLE) return false
        owner = taskId
        state = State.ACTIVE
        return true
    }

    @Synchronized fun stop(taskId: String): Boolean {
        if (owner != taskId) return false
        state = State.STOPPING
        return true
    }

    @Synchronized fun workerExited(taskId: String): Boolean {
        if (owner != taskId) return false
        owner = null
        state = State.IDLE
        return true
    }
}
