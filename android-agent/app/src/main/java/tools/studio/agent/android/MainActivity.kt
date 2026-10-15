package tools.studio.agent.android

import android.app.ActivityManager
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import tools.studio.agent.Command
import tools.studio.agent.CommandRouter
import org.json.JSONObject

/** First vertical slice: deterministic commands and an honest, disabled research catalogue. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val catalogue = assets.open("model-candidates.json").bufferedReader().use { it.readText() }
        val models = JSONObject(catalogue).getJSONArray("models")
        setContent {
            MaterialTheme(colorScheme = if (android.content.res.Configuration.UI_MODE_NIGHT_YES ==
                resources.configuration.uiMode.and(android.content.res.Configuration.UI_MODE_NIGHT_MASK))
                darkColorScheme() else lightColorScheme()) {
                var input by remember { mutableStateOf("") }
                var result by remember { mutableStateOf("Ready. No model is loaded.") }
                Surface(Modifier.fillMaxSize()) {
                    Column(Modifier.safeDrawingPadding().padding(20.dp)
                        .verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Text("Studio Agent", style = MaterialTheme.typography.headlineLarge)
                        Text("Local Android · 3 GB admission contract · one model slot")
                        OutlinedTextField(input, { input = it }, label = { Text("What should I do?") },
                            modifier = Modifier.fillMaxWidth(), minLines = 3)
                        Button(onClick = { result = execute(CommandRouter.route(input)) }) { Text("Run") }
                        Text(result, style = MaterialTheme.typography.bodyLarge)
                        Text("Try: status • open wifi settings • open https://google.com")
                        HorizontalDivider()
                        Text("Model research catalogue", style = MaterialTheme.typography.titleLarge)
                        Text("Downloads and inference remain disabled until the exact model and runtime qualify on this device. This build does not enforce a physical RAM ceiling.")
                        for (i in 0 until models.length()) {
                            val model = models.getJSONObject(i)
                            ElevatedCard(Modifier.fillMaxWidth()) {
                                Column(Modifier.padding(16.dp)) {
                                    Text(model.getString("id"), style = MaterialTheme.typography.titleMedium)
                                    Text("${model.getString("role")} · not qualified on this phone")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private fun execute(command: Command): String = when (command) {
        Command.Status -> {
            val info = ActivityManager.MemoryInfo()
            getSystemService(ActivityManager::class.java).getMemoryInfo(info)
            "Models loaded: 0. Available system RAM: %.2f GB. No model profile is qualified."
                .format(info.availMem / 1_000_000_000.0)
        }
        Command.Stop -> "No inference worker is active."
        Command.WifiSettings -> open(Intent(Settings.ACTION_WIFI_SETTINGS))
        is Command.OpenWeb -> open(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(command.httpsUrl)))
        is Command.Invalid -> command.reason
        is Command.NeedsModel -> "This request needs a model or a tool that is not enabled yet. No action was performed."
    }

    private fun open(intent: Intent): String = try {
        startActivity(intent)
        "Opened the requested screen. Results inside that app have not been read."
    } catch (_: android.content.ActivityNotFoundException) {
        "No installed app can open this request."
    } catch (_: SecurityException) {
        "Android did not allow this request."
    }
}
