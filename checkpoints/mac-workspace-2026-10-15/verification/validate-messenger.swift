import Foundation
import AppKit
@main struct MessengerValidation {
 @MainActor static func main() async {
  _ = NSApplication.shared
  let browserFixture=ProcessInfo.processInfo.environment["STUDIO_BROWSER_FIXTURE"] == "1"
  let folder=FileManager.default.temporaryDirectory.appendingPathComponent("studio-messenger-check-\(UUID())")
  defer {try? FileManager.default.removeItem(at:folder)}
  func check(_ ok:Bool,_ name:String)throws{guard ok else{throw StudioError.message(name)};print("PASS \(name)");fflush(stdout)}
  do{
   let store=StudioStore(directory:folder)
   var echo=Workflow(name:browserFixture ? "Phone · Echo" : "Remote Echo",actions:[WorkflowAction(kind:"text",parameters:["text":"Remote says: {{input}}"]),WorkflowAction(kind:"show",parameters:["input":"{{previous}}"])])
   var slow=Workflow(name:browserFixture ? "Phone · Framer to Subframe" : "Remote Wait",actions:[WorkflowAction(kind:"wait",parameters:["seconds":"10"]),WorkflowAction(kind:"text",parameters:["text":"Should not execute after cancellation"])])
   var author=Workflow(name:browserFixture ? "Phone · Assistant" : "Remote Author",actions:[WorkflowAction(kind:"phoneAssistant",parameters:["prompt":"{{input}}","applications":"","desktop":"false"])])
   store.create(author);author=store.selected!
   store.create(echo);echo=store.selected!;store.create(slow);slow=store.selected!
   try check(MessengerConnector.allowedKinds.isSubset(of:Set(ActionCatalog.definitions.map(\.id))),"remote allowlist uses real action kinds")
   for kind in ["clipboard","runWorkflow","readFile","http"] {try check(MessengerConnector.policyError(Workflow(actions:[WorkflowAction(kind:kind)])) != nil,"blocked capability \(kind)")}
   try check(MessengerConnector.policyError(Workflow(actions:[WorkflowAction(kind:"text",parameters:["text":"{{storage:key}}"])])) != nil,"stored references blocked")
   let journal=MessengerConfiguration(url:"",grants:[],devices:[],journal:[MessengerRecord(id:UUID().uuidString,deviceID:"test",digest:"test",state:"Running",output:nil,message:"")])
   try JSONEncoder().encode(journal).write(to:folder.appendingPathComponent("messenger.json"),options:.atomic)
   var vault:[String:String]=[:]; var credentialReads=0
   let connector=MessengerConnector(store:store,directory:folder,credentialAccess:{account,value in if let value{vault[account]=value;return value};credentialReads+=1;guard let found=vault[account]else{throw StudioError.message("Missing test key")};return found})
   try check(connector.configuration.journal.first?.state=="Interrupted","restart marks unknown outcome interrupted")
   store.messenger=connector
   connector.grant(author,enabled:true)
   connector.grant(echo,enabled:true);connector.grant(slow,enabled:true)
   var changed=echo;changed.actions[0].parameters["text"]="Changed"
   try check(!connector.isGranted(changed),"editing invalidates grant")
   try connector.configure(url:CommandLine.arguments[1],credential:ProcessInfo.processInfo.environment["STUDIO_INTEROP_TOKEN"] ?? CommandLine.arguments[2]);connector.connect();connector.newPairingCode()
   for _ in 0..<100 where connector.pairingCode.isEmpty {try await Task.sleep(nanoseconds:100_000_000)}
   guard !connector.pairingCode.isEmpty else{throw StudioError.message("No pairing code")}
   print("CODE \(connector.pairingCode)");fflush(stdout)
   let deadline=Date().addingTimeInterval(browserFixture ? 900 : 150)
   while Date()<deadline{
    for pair in connector.pendingPairs where ["Isolated phone","Browser verification"].contains(pair.label){connector.approve(pair)}
    if !browserFixture && connector.configuration.journal.filter({["Completed","Cancelled","Rejected"].contains($0.state)}).count>=10 {
     let authored = store.liveWorkflows.filter { $0.origin == "phone" }
     try check(authored.count == 1 && authored[0].actions.count == 2,"phone save/edit persists one ordered shortcut")
     try check(connector.isGranted(authored[0]),"authored shortcut inherits approved scope")
     connector.grant(author,enabled:false)
     try check(!connector.isGranted(authored[0]),"revoking parent disables authored shortcuts")
     connector.grant(author,enabled:true)
     try check(credentialReads == 0,"commands and streams use session keys without repeated credential reads")
     try check(store.library.history.filter{$0.workflowName=="Remote Echo"}.count==1,"duplicate command executed once in fixture")
     try check(store.library.history.contains{$0.workflowName=="Remote Wait" && $0.status=="Cancelled"},"cancellation prevents later action")
     try await Task.sleep(nanoseconds:2_500_000_000);connector.disconnect();print("MESSENGER VALIDATION PASS");fflush(stdout);return
    }
    try await Task.sleep(nanoseconds:100_000_000)
   };if browserFixture {connector.disconnect();return};throw StudioError.message("Integration timed out")
  }catch{print("MESSENGER VALIDATION FAIL: \(error.localizedDescription)");fflush(stdout);exit(1)}
 }
}
