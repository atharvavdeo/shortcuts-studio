package tools.studio.agent

import java.net.URI

sealed interface Command {
    data object Status : Command
    data object Stop : Command
    data object WifiSettings : Command
    data class OpenWeb(val httpsUrl: String) : Command
    data class NeedsModel(val prompt: String) : Command
    data class Invalid(val reason: String) : Command
}

/** Explicit narrow syntax wins. Ambiguous requests never become arbitrary intents or shell. */
object CommandRouter {
    fun route(input: String): Command {
        val text = input.trim()
        if (text.isEmpty() || text.length > 4000) return Command.Invalid("Enter 1–4000 characters")
        return when (text.lowercase()) {
            "stop", "cancel" -> Command.Stop
            "status" -> Command.Status
            "open wifi settings", "open wi-fi settings" -> Command.WifiSettings
            else -> if (text.startsWith("open https://", ignoreCase = true)) {
                val url = text.substring(5)
                val uri = runCatching { URI(url) }.getOrNull()
                if (uri?.scheme.equals("https", true) && !uri?.host.isNullOrBlank() &&
                    uri?.rawUserInfo == null && text.none { it.isISOControl() })
                    Command.OpenWeb(url)
                else Command.Invalid("Use an HTTPS URL without embedded credentials")
            } else Command.NeedsModel(text)
        }
    }
}
