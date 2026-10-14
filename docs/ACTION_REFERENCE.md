# Action reference

Generated from `ActionCatalog.definitions`. Regenerate with `bash scripts/generate-reference.sh`. This is the current catalog, not Apple’s full action catalog.

67 action definitions. Parameter values are authored as strings and resolved by the interpreter. Omitted values may differ from editor defaults when constructing an action manually: use `definition.action` to start with defaults.

## Use On-Device Model (`onDeviceModel`)

Category: Intelligence.

Stream text from Apple’s on-device Foundation Model. Requires available Apple Intelligence; no cloud fallback.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `prompt` | Prompt | `Summarize: {{previous}}` |  |
| `instructions` | Instructions | `Be concise and accurate.` |  |

## Phone Assistant (`phoneAssistant`)

Category: Intelligence.

Route a phone command through Apple on-device intelligence to approved Mac tasks or an answer. App control requires Accessibility permission.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `prompt` | Command or question | `{{input}}` |  |
| `applications` | Approved application bundle IDs | `com.openai.codex,com.openai.chat,com.google.Chrome,com.subframe.desktop,com.apple.finder,com.apple.calculator,com.apple.weather` |  |
| `desktop` | Allow Desktop filenames | `true` | true, false |

## Get Desktop File Names (`desktopNames`)

Category: Mac.

List visible Desktop filenames, up to 200 entries; no file contents or arbitrary paths.

No parameters.

## Control Application (`appControl`)

Category: Mac.

Open, inspect, type into, or submit text to the configured app using public Accessibility APIs.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `bundle` | Application bundle ID | `com.openai.chat` |  |
| `operation` | Operation | `inspect` | open, inspect, type, send |
| `text` | Text | `{{input}}` |  |

## Text (`text`)

Category: Text.

Create text. Insert variables using the reference picker.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `text` | Text | `Hello, world!` |  |

## Number (`number`)

Category: Numbers.

Create a finite numeric value.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `number` | Number | `1` |  |

## Boolean (`boolean`)

Category: Scripting.

Create true or false.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `value` | Value | `true` | true, false |

## Comment (`comment`)

Category: Scripting.

Document a step without changing its output.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `text` | Comment | `` |  |

## Shortcut Input (`input`)

Category: Scripting.

Get the input supplied when this shortcut starts.

No parameters.

## Set Variable (`setVariable`)

Category: Scripting.

Store a typed value for this run.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `name` | Name | `Value` |  |
| `input` | Input | `{{previous}}` |  |

## Get Variable (`getVariable`)

Category: Scripting.

Retrieve a named variable.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `name` | Name | `Value` |  |

## If (`if`)

Category: Scripting.

Run a block when its condition is true.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `comparison` | Condition | `has value` | has value, equals, not equals, contains, greater than, less than, is true |
| `value` | Compare to | `` |  |

## Otherwise (`else`)

Category: Scripting.

Alternate branch of the current If block.

No parameters.

## End If (`endIf`)

Category: Scripting.

Close the current If block.

No parameters.

## Repeat (`repeat`)

Category: Scripting.

Repeat the block and collect its outputs.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `count` | Times | `3` |  |

## Repeat with Each (`repeatEach`)

Category: Scripting.

Run the block for every item. Use Repeat Item and Repeat Index.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## End Repeat (`endRepeat`)

Category: Scripting.

Close the current Repeat block.

No parameters.

## Wait (`wait`)

Category: Scripting.

Pause cooperatively; Stop cancels the wait.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `seconds` | Seconds | `1` |  |

## Stop and Output (`stop`)

Category: Scripting.

End this shortcut and return the selected value.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Run Shortcut (`runWorkflow`)

Category: Scripting.

Run another Studio shortcut by name or identifier.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `workflow` | Shortcut | `` |  |
| `input` | Input | `{{previous}}` |  |

## Ask for Input (`ask`)

Category: Scripting.

Show a text prompt. Cancel stops the run.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `prompt` | Prompt | `What is your name?` |  |
| `default` | Default answer | `` |  |

## Choose from List (`choose`)

Category: Lists.

Ask the user to select one list item.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `prompt` | Prompt | `Choose an item` |  |

## Show Result (`show`)

Category: Scripting.

Present a result in a native dialog.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Show Alert (`alert`)

Category: Scripting.

Display an alert and continue with the existing input.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `title` | Title | `Shortcut` |  |
| `message` | Message | `{{previous}}` |  |

## Show Notification (`notification`)

Category: Mac.

Post a system notification when permission is granted.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `title` | Title | `Shortcut Studio` |  |
| `message` | Message | `{{previous}}` |  |

## Change Case (`uppercase`)

Category: Text.

Change the case of text.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `case` | Case | `uppercase` | uppercase, lowercase, title case |

## Trim Whitespace (`trim`)

Category: Text.

Remove whitespace at both ends.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Replace Text (`replace`)

Category: Text.

Replace literal text or a regular expression.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `find` | Find | `` |  |
| `replacement` | Replace with | `` |  |
| `regex` | Regular expression | `false` | false, true |

## Match Text (`match`)

Category: Text.

Find regex matches as a list.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `pattern` | Pattern | `\w+` |  |

## Split Text (`split`)

Category: Text.

Split text using a literal separator.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `separator` | Separator | `\n` |  |

## Combine Text (`combine`)

Category: Text.

Join list items with a separator.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `separator` | Separator | `\n` |  |

## Base64 Encode / Decode (`base64`)

Category: Text.

Convert UTF-8 text to or from Base64.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `mode` | Mode | `encode` | encode, decode |

## URL Encode / Decode (`urlEncode`)

Category: Web.

Percent-encode text or decode percent escapes.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `mode` | Mode | `encode` | encode, decode |

## Calculate (`calculate`)

Category: Numbers.

Apply an arithmetic operation to two numbers.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `a` | First number | `{{previous}}` |  |
| `operation` | Operation | `+` | +, -, ×, ÷, mod, power |
| `b` | Second number | `1` |  |

## Round Number (`round`)

Category: Numbers.

Round to a specified decimal precision.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `places` | Decimal places | `0` |  |

## Random Number (`random`)

Category: Numbers.

Generate an integer in an inclusive range.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `min` | Minimum | `1` |  |
| `max` | Maximum | `100` |  |

## Calculate Statistics (`statistics`)

Category: Numbers.

Compute statistics over a numeric list.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `statistic` | Statistic | `sum` | sum, average, minimum, maximum, count |

## List (`list`)

Category: Lists.

Create a list with one text item per line.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `items` | Items | `One<br>Two<br>Three` |  |

## Count (`count`)

Category: Lists.

Count items, words, or characters.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `unit` | Count | `items` | items, words, characters |

## Get Item from List (`getItem`)

Category: Lists.

Retrieve a one-based item, first item, last item, or random item.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `index` | Index | `1` |  |

## Sort List (`sort`)

Category: Lists.

Sort items as text or numeric values.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `order` | Order | `ascending` | ascending, descending |
| `type` | Compare | `text` | text, number |

## Reverse List (`reverse`)

Category: Lists.

Reverse item order.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Remove Duplicates (`unique`)

Category: Lists.

Keep the first occurrence of each typed value.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Filter List (`filter`)

Category: Lists.

Keep text items containing a string.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `contains` | Contains | `` |  |

## Dictionary (`dictionary`)

Category: Dictionaries.

Create a dictionary from JSON.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `json` | JSON | `{"name":"World"}` |  |

## Get Dictionary from Input (`parseJSON`)

Category: Dictionaries.

Parse JSON into typed values.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Get Dictionary Value (`getValue`)

Category: Dictionaries.

Follow a dot-separated dictionary key path.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `key` | Key | `name` |  |

## Set Dictionary Value (`setValue`)

Category: Dictionaries.

Set a top-level key on a copy of the dictionary.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `key` | Key | `name` |  |
| `value` | Value | `World` |  |

## Get Dictionary Keys (`keys`)

Category: Dictionaries.

Return dictionary keys in sorted order.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Convert to JSON (`json`)

Category: Dictionaries.

Serialize a typed value to JSON.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## URL (`url`)

Category: Web.

Create and validate an HTTP or HTTPS URL.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `url` | URL | `https://example.com` |  |

## Get Contents of URL (`http`)

Category: Web.

Make an HTTP request; unsuccessful responses fail the run.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `url` | URL | `{{previous}}` |  |
| `method` | Method | `GET` | GET, POST, PUT, PATCH, DELETE |
| `headers` | Headers (JSON) | `{}` |  |
| `body` | Request body | `` |  |
| `response` | Response | `text` | text, json |

## Open URL (`openURL`)

Category: Web.

Open a URL in the default app or a chosen browser/application.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `bundle` | Application bundle ID (optional) | `` |  |

## Current Date (`date`)

Category: Mac.

Return the current timestamp in ISO 8601 format.

No parameters.

## Format Date (`formatDate`)

Category: Mac.

Format an ISO 8601 timestamp.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `format` | Date format | `EEEE, d MMMM yyyy` |  |

## Get Clipboard (`clipboard`)

Category: Mac.

Read text from the system clipboard.

No parameters.

## Copy to Clipboard (`copy`)

Category: Mac.

Copy text to the system clipboard.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Open App (`openApp`)

Category: Mac.

Open an app using its bundle identifier.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `bundle` | Bundle identifier | `com.apple.Safari` |  |

## Speak Text (`speak`)

Category: Mac.

Read text aloud using system speech.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |

## Select File (`selectFile`)

Category: Files.

Choose a file using a native open panel.

No parameters.

## Read Text File (`readFile`)

Category: Files.

Read a UTF-8 file, limited to 10 MB.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `path` | File path | `{{previous}}` |  |

## Save Text File (`saveFile`)

Category: Files.

Choose where to save text using a native save panel.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `input` | Input | `{{previous}}` |  |
| `name` | Suggested filename | `Result.txt` |  |

## Get File Details (`fileInfo`)

Category: Files.

Return file name, size, extension, and path.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `path` | File path | `{{previous}}` |  |

## Get Stored Value (`storageGet`)

Category: Storage.

Get a value persisted across runs of this shortcut.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `key` | Key | `counter` |  |

## Set Stored Value (`storageSet`)

Category: Storage.

Persist a value immediately; cancellation does not undo committed writes.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `key` | Key | `counter` |  |
| `input` | Input | `{{previous}}` |  |

## Remove Stored Value (`storageDelete`)

Category: Storage.

Remove a stored key from this shortcut.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `key` | Key | `counter` |  |

## Run Apple Shortcut (`appleShortcut`)

Category: Mac.

Delegate to Apple's installed engine by shortcut name or identifier.

| Key | Editor label | Default | Choices |
|---|---|---|---|
| `shortcut` | Apple shortcut | `` |  |
| `input` | Input | `{{previous}}` |  |

