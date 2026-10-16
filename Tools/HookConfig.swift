import Foundation

// Installs only Dots command handlers; preserves every other handler and config key.
// This does NOT trust hooks, change approval policy, or modify config.toml.
let args = CommandLine.arguments
guard args.count == 4, ["install","remove"].contains(args[1]) else {
    print("Usage: HookConfig install|remove /absolute/hooks.json /absolute/Dots.app")
    exit(1)
}
let config = URL(fileURLWithPath:args[2]), app = URL(fileURLWithPath:args[3])
guard args[2].hasPrefix("/"), args[3].hasPrefix("/") else { fatalError("Absolute paths required") }
let binary = app.appendingPathComponent("Contents/MacOS/Dots").path
let marker = "--dots-activity-v1"
// Standard POSIX single-quote escaping; never evaluate paths as shell fragments.
let quoted = "'" + binary.replacingOccurrences(of:"'",with:"'\\''") + "'"
let command = quoted + " --hook " + marker
let fm = FileManager.default
let original: Data? = fm.fileExists(atPath:config.path) ? try Data(contentsOf:config) : nil
var root: [String:Any]
if let original {
    guard let decoded = try JSONSerialization.jsonObject(with:original) as? [String:Any] else { fatalError("Not a hooks object") }
    root = decoded
} else { root = [:] }
if let value = root["hooks"], !(value is [String:Any]) { fatalError("Invalid hooks object; not modifying") }
var hooks = root["hooks"] as? [String:Any] ?? [:]
for event in ["UserPromptSubmit","Stop","Interrupt","SessionEnd"] {
    if let value = hooks[event], !(value is [[String:Any]]) { fatalError("Invalid matcher groups; not modifying") }
    var groups = hooks[event] as? [[String:Any]] ?? []
    groups = groups.compactMap { group in
        guard let handlers = group["hooks"] as? [[String:Any]] else { return group }
        let retained = handlers.filter { handler in
            guard let c = handler["command"] as? String else { return true }
            return !(c.hasSuffix(" --hook "+marker) && c.contains("/Contents/MacOS/Dots'"))
        }
        if retained.count == handlers.count { return group }
        guard !retained.isEmpty else { return nil }
        var copy = group; copy["hooks"] = retained; return copy
    }
    if args[1] == "install" {
        guard fm.isExecutableFile(atPath:binary) else { fatalError("Build Dots.app before installing hooks") }
        groups.append(["hooks":[["type":"command","command":command,"timeout":3]]])
    }
    hooks[event] = groups
}
root["hooks"] = hooks
let updated = try JSONSerialization.data(withJSONObject:root,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
// Detect concurrent changes before writing; preserve a recoverable exact backup.
if let original {
    guard try Data(contentsOf:config) == original else { fatalError("hooks.json changed; retry") }
    let backup = config.deletingLastPathComponent().appendingPathComponent("hooks.before-dots-"+UUID().uuidString+".json")
    try original.write(to:backup,options:.withoutOverwriting)
    try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:backup.path)
    print("Backup: \(backup.path)")
}
try fm.createDirectory(at:config.deletingLastPathComponent(),withIntermediateDirectories:true)
try updated.write(to:config,options:.atomic)
try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:config.path)
print("\(args[1]) complete. Hook trust is unchanged; review Dots handlers in /hooks.")
