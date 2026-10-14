import Foundation
import AppKit
@main struct AssistantValidation {
 @MainActor static func main() async {
  _ = NSApplication.shared
  let folder=FileManager.default.temporaryDirectory.appendingPathComponent("studio-desktop-fixture-\(UUID())")
  defer{try? FileManager.default.removeItem(at:folder)}
  func check(_ ok:Bool,_ name:String)throws{guard ok else{throw StudioError.message(name)};print("PASS \(name)")}
  do{
   try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
   try Data().write(to:folder.appendingPathComponent("Alpha.txt"));try Data().write(to:folder.appendingPathComponent("Beta.md"));try Data().write(to:folder.appendingPathComponent(".hidden"))
   try check(try AppControl.readDesktop(from:folder).text == "Alpha.txt\nBeta.md","Desktop fixture returns visible names only")
   try check(PhoneAssistant.explicitPlan("What are the file names on my Desktop?")?.intent == "desktop","Desktop request routes deterministically")
   try check(PhoneAssistant.explicitPlan("In ChatGPT: explain gravity")?.app == "ChatGPT","explicit app target and prompt parsed")
   try check(try PhoneAssistant.resolveApp("ChatGPT",allowed:["com.openai.chat"]) == "com.openai.chat","ChatGPT resolves to approved native app")
   do{_ = try PhoneAssistant.resolveApp("Terminal",allowed:["com.openai.chat"]);throw StudioError.message("Unapproved app accepted")}catch let e as StudioError{if e.localizedDescription == "Unapproved app accepted"{throw e};print("PASS unapproved target rejected")}
   let savedRoots = AssistantSettings.folderRoots, savedModels = AssistantSettings.modelsEnabled
   defer { AssistantSettings.folderRoots = savedRoots; AssistantSettings.modelsEnabled = savedModels }
   AssistantSettings.folderRoots = [folder.path]
   try Data("A real fixture file.\n".utf8).write(to:folder.appendingPathComponent("Alpha.txt"))
   try check(try AssistantSettings.files(folder.appendingPathComponent("Alpha.txt").path,desktop:false,read:true).contains("A real fixture file."),"approved file content returned")
   try check(try AssistantSettings.files(folder.path,desktop:false,read:false).contains("Alpha.txt"),"approved folder contents returned")
   try FileManager.default.createSymbolicLink(at:folder.appendingPathComponent("escape"),withDestinationURL:folder.deletingLastPathComponent())
   for denied in [folder.deletingLastPathComponent().path,folder.appendingPathComponent("escape").path,folder.path+"-outside"] {
    do { _ = try AssistantSettings.folder(denied,desktop:false);throw StudioError.message("Boundary accepted") }
    catch let e as StudioError { if e.localizedDescription == "Boundary accepted" { throw e } }
   }
   print("PASS folder traversal, symlink escape and sibling prefix rejected")
   try check(PhoneAssistant.explicitPlan("read file Desktop/test.txt")?.intent == "readFile","file command routes without inference")
   try check(PhoneAssistant.explicitPlan("new chat in Codex")?.intent == "newChat","new chat command routes deterministically")
   try check(try PhoneAssistant.resolveApp("Codex",allowed:["com.openai.codex"]) == "com.openai.codex","Codex resolves to approved app")
   _ = try await PhoneAssistant.execute("model off",allowed:[],desktop:false){_ in}
   try check(!AssistantSettings.modelsEnabled,"phone can disable Studio inference")
   let file = try await PhoneAssistant.execute("read file " + folder.appendingPathComponent("Alpha.txt").path,allowed:[],desktop:false){_ in}
   try check(file.text.contains("A real fixture file."),"file tool works with model disabled")
   do { _ = try await OnDeviceIntelligence.generate(prompt:"Hello",instructions:""){_ in};throw StudioError.message("Disabled model executed") }
   catch let e as StudioError { if e.localizedDescription == "Disabled model executed" { throw e }; print("PASS disabled model rejects inference") }
   _ = try await PhoneAssistant.execute("model on",allowed:[],desktop:false){_ in}
   try check(AssistantSettings.modelsEnabled,"phone can enable on-demand inference")
   print("MODEL STATUS: \(OnDeviceIntelligence.status)")
   let plan=try await PhoneAssistant.plan("What is two plus two?")
   try check(plan.intent == "answer","Apple model routes a knowledge question")
   var snapshots=0
   let result=try await PhoneAssistant.execute("What is two plus two? Reply concisely.",allowed:[],desktop:false){_ in snapshots+=1}
   try check(result.text.contains("4")||result.text.lowercased().contains("four"),"Apple on-device assistant returns arithmetic answer")
   try check(snapshots>1,"assistant streams output snapshots")
   print("ASSISTANT VALIDATION PASS")
  }catch{print("ASSISTANT VALIDATION FAIL: \(error.localizedDescription)");exit(1)}
 }
}
