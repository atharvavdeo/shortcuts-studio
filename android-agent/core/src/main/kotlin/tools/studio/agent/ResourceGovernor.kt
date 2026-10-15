package tools.studio.agent

/** Admission rules; these do NOT impose an OS physical-memory ceiling. */
object ResourceLimits {
    const val AGGREGATE_BYTES = 3_000_000_000L
    const val ADMISSION_BYTES = 2_250_000_000L
    const val STOP_BYTES = 2_700_000_000L
    const val FREE_AFTER_LOAD_BYTES = 2_000_000_000L
    const val MAX_SAMPLE_AGE_MS = 1_000L
    const val COOLDOWN_MS = 60_000L
    const val MAX_TASK_MS = 120_000L
    const val MAX_TOOL_ACTIONS = 20
    const val MAX_MODEL_CALLS = 6
    const val CONTEXT_TOKENS = 2048
    const val OUTPUT_TOKENS = 512
}

enum class Thermal { NONE, LIGHT, MODERATE, SEVERE, CRITICAL, EMERGENCY, SHUTDOWN }

data class ResourceSnapshot(
    val sampledAtElapsedMs: Long,
    val aggregateAgentBytes: Long?,
    val availableSystemBytes: Long?,
    val thermal: Thermal?,
    val batteryPercent: Int?,
    val batterySaver: Boolean?,
    val batteryLow: Boolean?,
    val screenLocked: Boolean?,
)

/** Must identify the exact artifact, runtime version, device, backend and token limits. */
data class RuntimeIdentity(
    val artifactSha256: String,
    val runtimeVersion: String,
    val deviceFingerprint: String,
    val backend: String,
)

data class QualifiedProfile(
    val identity: RuntimeIdentity,
    val measuredAggregatePeakBytes: Long,
    val contextTokens: Int,
    val outputTokens: Int,
    val allBackendAllocationsAccounted: Boolean,
)

sealed interface Admission {
    data class Denied(val reason: String) : Admission
    data class Allowed(val reducedWorkload: Boolean) : Admission
}

class ResourceGovernor {
    private var hotUntilElapsedMs = 0L

    @Synchronized
    fun evaluate(
        snapshot: ResourceSnapshot,
        profile: QualifiedProfile?,
        requestedRuntime: RuntimeIdentity,
        nowElapsedMs: Long,
        explicitlyActive: Boolean,
        additionalLoadBytes: Long,
    ): Admission {
        fun deny(reason: String) = Admission.Denied(reason)
        if (snapshot.thermal != null && snapshot.thermal >= Thermal.MODERATE) {
            hotUntilElapsedMs = nowElapsedMs + ResourceLimits.COOLDOWN_MS
            return deny("Device is warm: inference must stop and unload")
        }
        if (nowElapsedMs < hotUntilElapsedMs) return deny("Cooling down; restart manually later")
        val age = nowElapsedMs - snapshot.sampledAtElapsedMs
        if (age !in 0..ResourceLimits.MAX_SAMPLE_AGE_MS) return deny("Resource telemetry is stale")
        if (!explicitlyActive) return deny("No explicit active task")
        if (snapshot.thermal == null || snapshot.batteryPercent !in 20..100 ||
            snapshot.batterySaver != false || snapshot.batteryLow != false ||
            snapshot.screenLocked != false) return deny("Battery, thermal or unlocked-screen gate failed")
        val used = snapshot.aggregateAgentBytes ?: return deny("Aggregate memory accounting unavailable")
        val free = snapshot.availableSystemBytes ?: return deny("System memory unavailable")
        if (used < 0 || free < 0 || additionalLoadBytes < 0) return deny("Invalid memory telemetry")
        if (used >= ResourceLimits.STOP_BYTES) return deny("Memory stop threshold reached")
        if (additionalLoadBytes > free || free - additionalLoadBytes < ResourceLimits.FREE_AFTER_LOAD_BYTES)
            return deny("Insufficient system memory reserve")
        if (additionalLoadBytes >= ResourceLimits.ADMISSION_BYTES ||
            used >= ResourceLimits.ADMISSION_BYTES - additionalLoadBytes)
            return deny("Estimated aggregate peak exceeds admission budget")
        val p = profile ?: return deny("No qualified artifact/runtime/device profile")
        if (p.identity != requestedRuntime) return deny("Profile does not match requested runtime")
        if (!p.identity.artifactSha256.matches(Regex("[a-f0-9]{64}")) ||
            p.identity.runtimeVersion.isBlank() || p.identity.deviceFingerprint.isBlank() ||
            p.identity.backend.isBlank())
            return deny("Incomplete profile identity")
        if (!p.allBackendAllocationsAccounted) return deny("Backend allocation accounting is unproven")
        if (p.measuredAggregatePeakBytes !in 1 until ResourceLimits.ADMISSION_BYTES ||
            p.contextTokens !in 1..ResourceLimits.CONTEXT_TOKENS ||
            p.outputTokens !in 1..ResourceLimits.OUTPUT_TOKENS)
            return deny("Profile exceeds resource contract")
        return Admission.Allowed(reducedWorkload = snapshot.thermal == Thermal.LIGHT)
    }
}
