import Foundation
import Testing
@testable import WorkflowCore

@MainActor final class TestHost: WorkflowHost {
    var workflows: [Workflow] = []
    var storage: [UUID: [String: WorkflowValue]] = [:]
    var failStorage = false
    var steps: [UUID] = []
    func perform(_ kind: String, parameters: [String : WorkflowValue], input: WorkflowValue) async throws -> WorkflowValue { throw StudioError.message("Unexpected platform action: \(kind)") }
    func workflow(named: String) -> Workflow? { workflows.first { $0.name == named || $0.id.uuidString == named } }
    func persistStorage(_ value: [String : WorkflowValue], workflowID: UUID) throws { if failStorage { throw StudioError.message("disk full") }; storage[workflowID] = value }
    func stepStarted(_ actionID: UUID, title: String) { steps.append(actionID) }
    func stepFinished(_ actionID: UUID, output: WorkflowValue) {}
}

struct EngineTests {
    func action(_ kind: String, _ p: [String: String] = [:]) -> WorkflowAction { var a = ActionCatalog.definition(kind)!.action; a.parameters.merge(p) { _, new in new }; return a }
    @MainActor func evaluate(_ actions: [WorkflowAction], input: WorkflowValue = .null, host: TestHost? = nil) async throws -> WorkflowValue { let host = host ?? TestHost(); return try await WorkflowEngine(host: host).run(Workflow(actions: actions), input: input) }
    @Test @MainActor func testTypedInputSurvivesExactReference() async throws {
        let result = try await evaluate([action("setVariable", ["name": "x", "input": "{{input}}"]), action("getVariable", ["name": "x"])], input: .dictionary(["n": .number(42)]))
        expectEqual(result, .dictionary(["n": .number(42)]))
    }
    @Test @MainActor func testUnicodeInterpolationUsesValidRanges() async throws {
        let result = try await evaluate([action("text", ["text": "👋 {{input}} / {{input}} 🧪"])], input: .text("世界")); expectEqual(result.text, "👋 世界 / 世界 🧪")
    }
    @Test @MainActor func testNestedBranchesAndLoops() async throws {
        let result = try await evaluate([
            action("list", ["items": "a\nb"]), action("repeatEach"), action("if", ["input": "{{repeatIndex}}", "comparison": "equals", "value": "1"]), action("text", ["text": "first:{{repeatItem}}"]), action("else"), action("text", ["text": "next:{{repeatItem}}"]), action("endIf"), action("endRepeat")
        ])
        expectEqual(result, .list([.text("first:a"), .text("next:b")]))
    }
    @Test @MainActor func testRepeatPreservesOuterScope() async throws {
        let result = try await evaluate([action("repeat", ["count": "2"]), action("repeat", ["count": "1"]), action("text", ["text": "{{repeatIndex}}"]), action("endRepeat"), action("text", ["text": "{{repeatIndex}}"]), action("endRepeat")])
        expectEqual(result.text, "1\n2")
    }
    @Test @MainActor func testStopInsideLoopPropagates() async throws {
        let result = try await evaluate([action("repeat", ["count": "3"]), action("stop", ["input": "{{repeatIndex}}"]), action("endRepeat"), action("text", ["text": "should not run"])])
        expectEqual(result, .number(1))
    }
    @Test @MainActor func testMissingReferenceFailsInsteadOfUsingStaleValue() async {
        do { _ = try await evaluate([action("text", ["text": "{{output:\(UUID().uuidString)}}"])]); fail("Expected missing-reference failure") } catch { expectTrue(error.localizedDescription.contains("unavailable reference")) }
    }
    @Test @MainActor func testSkippedLoopOutputCannotLeakFromEarlierIteration() async {
        let value = action("number", ["number": "7"])
        do { _ = try await evaluate([action("repeat", ["count": "2"]), action("if", ["input": "{{repeatIndex}}", "comparison": "equals", "value": "1"]), value, action("endIf"), action("text", ["text": "{{output:\(value.id.uuidString)}}"]), action("endRepeat")]); fail("Expected skipped output to be unavailable") } catch { expectTrue(error.localizedDescription.contains("unavailable reference")) }
    }
    @Test @MainActor func testDivisionByZeroAndNonfiniteRejected() async {
        for p in [["a": "5", "b": "0", "operation": "÷"], ["a": "1e308", "b": "1e308", "operation": "×"]] {
            do { _ = try await evaluate([action("calculate", p)]); fail("Expected arithmetic failure") } catch {}
        }
    }
    @Test @MainActor func testRoundingOverflowFails() async {
        do { _ = try await evaluate([action("number", ["number": "1e308"]), action("round", ["places": "12"])]); fail("Expected overflow") } catch { expectTrue(error.localizedDescription.contains("overflow")) }
    }
    @Test @MainActor func testStepBudgetBoundsRun() async {
        let host = TestHost(); let engine = WorkflowEngine(host: host); engine.maximumSteps = 4
        do { _ = try await engine.run(Workflow(actions: [action("repeat", ["count": "10"]), action("number"), action("endRepeat")])); fail("Expected limit") } catch { expectTrue(error.localizedDescription.contains("steps")) }
    }
    @Test @MainActor func testCancellationDoesNotExecuteNextAction() async throws {
        let host = TestHost(); let engine = WorkflowEngine(host: host); let after = action("number")
        let task = Task { try await engine.run(Workflow(actions: [action("wait", ["seconds": "10"]), after])) }
        try await Task.sleep(nanoseconds: 30_000_000); task.cancel()
        do { _ = try await task.value; fail("Expected cancellation") } catch { expectTrue(error is CancellationError) }
        expectFalse(host.steps.contains(after.id))
    }
    @Test @MainActor func testStorageCommitAndFailure() async throws {
        let host = TestHost(); let workflow = Workflow(actions: [action("number", ["number": "5"]), action("storageSet", ["key": "x"]), action("storageGet", ["key": "x"])])
        let result = try await WorkflowEngine(host: host).run(workflow)
        expectEqual(result, .number(5)); expectEqual(host.storage[workflow.id]?["x"], .number(5))
        host.failStorage = true
        do { _ = try await WorkflowEngine(host: host).run(workflow); fail("Expected failed storage") } catch { expectTrue(error.localizedDescription.contains("disk full")) }
    }
    @Test @MainActor func testRecursiveShortcutRejected() async {
        let host = TestHost(); let w = Workflow(name: "Recursive", actions: [action("runWorkflow", ["workflow": "Recursive"])]); host.workflows = [w]
        do { _ = try await WorkflowEngine(host: host).run(w); fail("Expected recursion failure") } catch { expectTrue(error.localizedDescription.contains("recursion")) }
    }
    @Test @MainActor func testJSONTypesAndDictionaryPath() async throws {
        let result = try await evaluate([action("dictionary", ["json": "{\"a\":{\"b\":[true,4,null]}}"]), action("getValue", ["key": "a.b"])])
        expectEqual(result, .list([.bool(true), .number(4), .null]))
    }
    @Test func testStructuralValidationRejectsCrossedBlocks() {
        let w = Workflow(actions: [action("if"), action("repeat"), action("endIf"), action("endRepeat")]); expectFalse(WorkflowValidator.validate(w).isEmpty)
    }
    @Test func testDuplicatingRemapsActionReferencesAndQuestions() {
        let source = action("number"); var w = Workflow(actions: [source, action("text", ["text": "{{output:\(source.id.uuidString)}}"])])
        w.questions = [ImportQuestion(title: "Number?", actionID: source.id, parameter: "number")]
        let copy = w.duplicated(); expectNotEqual(w.id, copy.id); expectNotEqual(source.id, copy.actions[0].id)
        expectEqual(copy.actions[1].parameters["text"], "{{output:\(copy.actions[0].id.uuidString)}}"); expectEqual(copy.questions[0].actionID, copy.actions[0].id)
    }
    @Test func testEveryCatalogKindIsUniqueAndTemplatesValidate() {
        expectEqual(Set(ActionCatalog.definitions.map(\.kind)).count, ActionCatalog.definitions.count)
        for w in ActionCatalog.templates { expectTrue(WorkflowValidator.validate(w).isEmpty, w.name) }
    }
    @Test @MainActor func testTextTransformationsAndEncoding() async throws {
        let uppercase = try await evaluate([action("text", ["text": "  hello World  "]), action("trim"), action("uppercase")]); expectEqual(uppercase.text, "HELLO WORLD")
        let replaced = try await evaluate([action("text", ["text": "cat cat"]), action("replace", ["find": "cat", "replacement": "dog"])]); expectEqual(replaced.text, "dog dog")
        let matched = try await evaluate([action("text", ["text": "A12 B34"]), action("match", ["pattern": "[0-9]+"])]); expectEqual(matched, .list([.text("12"), .text("34")]))
        let decoded = try await evaluate([action("text", ["text": "世界 🧪"]), action("base64"), action("base64", ["mode": "decode"])]); expectEqual(decoded.text, "世界 🧪")
        let url = try await evaluate([action("text", ["text": "a/b?c=d & 🌍"]), action("urlEncode"), action("urlEncode", ["mode": "decode"])]); expectEqual(url.text, "a/b?c=d & 🌍")
    }
    @Test @MainActor func testListOperationsAndStatistics() async throws {
        let sorted = try await evaluate([action("list", ["items": "10\n2\n2\n5"]), action("unique"), action("sort", ["type": "number"]), action("combine", ["separator": ","])]); expectEqual(sorted.text, "2,5,10")
        let average = try await evaluate([action("list", ["items": "1\n2\n3"]), action("statistics", ["statistic": "average"])]); expectEqual(average, .number(2))
        let reversed = try await evaluate([action("list", ["items": "a\nb"]), action("reverse"), action("getItem", ["index": "first"])]); expectEqual(reversed, .text("b"))
        let count = try await evaluate([action("text", ["text": "a|b|c"]), action("split", ["separator": "|"]), action("count")]); expectEqual(count, .number(3))
    }
    @Test @MainActor func testBadRegexAndInvalidBase64Fail() async {
        for a in [action("match", ["pattern": "[", "input": "text"]), action("base64", ["mode": "decode", "input": "not_base64"])] {
            do { _ = try await evaluate([a]); fail("Expected malformed input failure") } catch {}
        }
    }
    @Test func testBlockDuplicateRemapsInternalReferences() throws {
        let value = action("number"); let opener = action("repeat")
        var w = Workflow(actions: [opener, value, action("text", ["text": "{{output:\(value.id.uuidString)}}"]), action("endRepeat")])
        try WorkflowEdits.duplicate(opener.id, in: &w)
        expectEqual(w.actions.count, 8); expectTrue(WorkflowValidator.validate(w).isEmpty)
        expectEqual(w.actions[6].parameters["text"], "{{output:\(w.actions[5].id.uuidString)}}")
    }
    @Test func testBlockRemovalClearsImportQuestions() throws {
        let opener = action("if"); let value = action("number"); var w = Workflow(actions: [opener, value, action("else"), action("endIf"), action("text")])
        w.questions = [ImportQuestion(title: "Number", actionID: value.id, parameter: "number")]
        try WorkflowEdits.remove(opener.id, from: &w); expectEqual(w.actions.count, 1); expectTrue(w.questions.isEmpty)
    }
    @Test func testBlockMovePreservesStructureAndRejectsMarkers() throws {
        let opener = action("repeat"); let after = action("text"); var w = Workflow(actions: [opener, action("number"), action("endRepeat"), after])
        let marker = w.actions[2].id
        try WorkflowEdits.move(opener.id, offset: 1, in: &w)
        expectEqual(w.actions.first?.id, after.id); expectTrue(WorkflowValidator.validate(w).isEmpty)
        expectThrows(try WorkflowEdits.remove(marker, from: &w))
    }
}

struct PersistenceTests {
    func temporaryRepository() throws -> LibraryRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return LibraryRepository(url: directory.appendingPathComponent("library.json"))
    }
    @Test func testAtomicSaveBackupAndCorruptionRecovery() throws {
        let repository = try temporaryRepository(); defer { try? FileManager.default.removeItem(at: repository.url.deletingLastPathComponent()) }; let a = LibraryDocument(workflows: [Workflow(name: "Original")]); try repository.save(a)
        var b = a; b.workflows[0].name = "Edited"; try repository.save(b); expectEqual(try repository.load().workflows[0].name, "Edited")
        try Data("broken".utf8).write(to: repository.url); expectThrows(try repository.load())
        let restored = try repository.restoreBackup(); expectEqual(restored.workflows[0].name, "Original")
        expectTrue(try FileManager.default.contentsOfDirectory(atPath: repository.url.deletingLastPathComponent().path).contains { $0.hasPrefix("library-corrupt-") })
    }
    @Test func testUnknownLibrarySchemaDoesNotOverwriteFile() throws {
        let r = try temporaryRepository(); defer { try? FileManager.default.removeItem(at: r.url.deletingLastPathComponent()) }; var doc = LibraryDocument(); doc.schemaVersion = 999
        expectThrows(try r.save(doc)); expectFalse(FileManager.default.fileExists(atPath: r.url.path))
    }
    @Test func testPortableWorkflowRoundTripAndBadImport() throws {
        let workflow = ActionCatalog.templates[0]; let data = try LibraryRepository.encodeWorkflow(workflow)
        expectEqual(try LibraryRepository.decodeWorkflow(data), workflow)
        expectThrows(try LibraryRepository.decodeWorkflow(Data("{\"version\":99}".utf8)))
        var bad = workflow; bad.questions = [ImportQuestion(title: "Missing", actionID: UUID(), parameter: "x")]
        expectThrows(try LibraryRepository.decodeWorkflow(LibraryRepository.encodeWorkflow(bad)))
    }
}

struct AutomationTests {
    @Test func testDailyTriggerDoesNotReplayClaimedRun() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduled = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 9))!
        var rule = AutomationRule(workflowID: UUID(), name: "Daily", hour: 9, minute: 0)
        expectTrue(AutomationSchedule.isDue(rule, now: scheduled.addingTimeInterval(20), appStartedAt: scheduled.addingTimeInterval(-60), calendar: calendar))
        rule.lastFired = scheduled
        expectFalse(AutomationSchedule.isDue(rule, now: scheduled.addingTimeInterval(35), appStartedAt: scheduled.addingTimeInterval(-60), calendar: calendar))
    }
    @Test func testMissedWindowAndLateStartupAreSkipped() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduled = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 9))!
        let rule = AutomationRule(workflowID: UUID(), name: "Daily", hour: 9, minute: 0)
        expectFalse(AutomationSchedule.isDue(rule, now: scheduled.addingTimeInterval(61), appStartedAt: scheduled.addingTimeInterval(-60), calendar: calendar))
        expectFalse(AutomationSchedule.isDue(rule, now: scheduled.addingTimeInterval(20), appStartedAt: scheduled.addingTimeInterval(5), calendar: calendar))
    }
}

// Non-macro assertions keep this suite usable with the CLT-bundled Testing runtime.
private func expectEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T) {
    do { let lhs = try a(), rhs = try b(); if lhs != rhs { Issue.record(Comment(rawValue: "Expected equal: \(lhs) versus \(rhs)")) } } catch { Issue.record(error) }
}
private func expectNotEqual<T: Equatable>(_ a: T, _ b: T) { if a == b { Issue.record("Expected distinct values") } }
private func expectTrue(_ condition: @autoclosure () throws -> Bool, _ message: String = "Expected true") { do { if try !condition() { Issue.record(Comment(rawValue: message)) } } catch { Issue.record(error) } }
private func expectFalse(_ condition: @autoclosure () throws -> Bool) { do { if try condition() { Issue.record("Expected false") } } catch { Issue.record(error) } }
private func expectThrows(_ expression: @autoclosure () throws -> Any) { do { _ = try expression(); Issue.record("Expected an error") } catch {} }
private func fail(_ message: String) { Issue.record(Comment(rawValue: message)) }

struct ModelDraftTests {
    @Test func validDraftUsesLocalIdentityAndDefaults() throws {
        let data = Data(#"{"name":"Greeting","actions":[{"kind":"text","parameters":[{"key":"text","value":"Hello"}]},{"kind":"show","parameters":[]}]}"#.utf8)
        let first = try ModelDraft.decode(data); let second = try ModelDraft.decode(data)
        expectEqual(first.actions[1].parameters["input"], "{{previous}}")
        expectTrue(first.id != second.id && first.actions[0].id != second.actions[0].id)
    }
    @Test func invalidModelDraftsAreRejected() {
        let drafts = [
            #"{"name":"Bad","actions":[{"kind":"text","parameters":[{"key":"text","value":"{{previous.text}}"}]}]}"#,
            #"{"name":"Bad","actions":[{"kind":"shell","parameters":[]}]}"#,
            #"{"name":"Bad","actions":[{"kind":"text","parameters":[{"key":"execute","value":"yes"}]}]}"#,
            #"{"name":"Bad","actions":[{"kind":"boolean","parameters":[{"key":"value","value":"maybe"}]}]}"#,
            #"{"name":"Bad","actions":[{"kind":"if","parameters":[]}]}"#,
            #"{"name":"Bad","actions":[{"kind":"text","parameters":[{"key":"text","value":"{{output:invented}}"}]}]}"#,
            #"{"name":"Bad","actions":[]}"#
        ]
        for draft in drafts { do { _ = try ModelDraft.decode(Data(draft.utf8)); fail("Expected invalid draft rejection") } catch {} }
    }
}

struct WeekdayAutomationTests {
    @Test func weekdayFilterAndDisabledRule() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 9))!
        var rule = AutomationRule(workflowID: UUID(), name: "Weekdays", weekdays: [2, 3, 4, 5, 6])
        expectTrue(AutomationSchedule.isDue(rule, now: date.addingTimeInterval(10), appStartedAt: date.addingTimeInterval(-60), calendar: calendar))
        rule.weekdays = [1, 7]
        expectFalse(AutomationSchedule.isDue(rule, now: date.addingTimeInterval(10), appStartedAt: date.addingTimeInterval(-60), calendar: calendar))
        rule.weekdays = []; expectFalse(AutomationSchedule.isDue(rule, now: date.addingTimeInterval(10), appStartedAt: date.addingTimeInterval(-60), calendar: calendar))
        rule.weekdays = nil; rule.isEnabled = false
        expectFalse(AutomationSchedule.isDue(rule, now: date.addingTimeInterval(10), appStartedAt: date.addingTimeInterval(-60), calendar: calendar))
    }
    @Test func oldAutomationDecodesAndNewDaysRoundTrip() throws {
        let id = UUID()
        let old = Data("{\"id\":\"\(id)\",\"workflowID\":\"\(id)\",\"name\":\"Old\",\"isEnabled\":true,\"trigger\":\"time\",\"hour\":9,\"minute\":0}".utf8)
        let decoded = try JSONDecoder().decode(AutomationRule.self, from: old); expectTrue(decoded.weekdays == nil)
        let rule = AutomationRule(workflowID: id, name: "New", weekdays: [2, 4, 6])
        let roundTrip = try JSONDecoder().decode(AutomationRule.self, from: JSONEncoder().encode(rule))
        expectEqual(roundTrip.weekdays, [2, 4, 6])
    }
    @Test @MainActor func multilineAndEmptyTextInputPreserveType() async throws {
        let host = TestHost(); let workflow = Workflow(actions: [ActionCatalog.definition("input")!.action])
        let result = try await WorkflowEngine(host: host).run(workflow, input: .text("One\nTwo ✓")); expectEqual(result, .text("One\nTwo ✓"))
        let empty = try await WorkflowEngine(host: host).run(workflow, input: .text("")); expectEqual(empty, .text(""))
    }
}

struct InvalidScheduleTests {
    @Test func persistenceRejectsInvalidWeekdays() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(url: directory.appendingPathComponent("library.json"))
        let w = Workflow()
        let rule = AutomationRule(workflowID: w.id, name: "Invalid", weekdays: [8])
        expectThrows(try repository.save(LibraryDocument(workflows: [w], automations: [rule])))
    }
}
