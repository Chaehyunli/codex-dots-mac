import AppKit

if let index = CommandLine.arguments.firstIndex(of:"--render-previews"), CommandLine.arguments.indices.contains(index+1) {
    do { try renderPreviews(to:URL(fileURLWithPath:CommandLine.arguments[index+1],isDirectory:true)); exit(0) }
    catch { print("FAIL: preview render \(error)"); exit(1) }
}

if CommandLine.arguments.contains("--hook") {
    // No AppKit initialization, UI launch, file log, or stdout containing user data.
    var data = Data()
    while data.count <= 8*1024*1024 {
        let chunk = (try? FileHandle.standardInput.read(upToCount:min(65536,8*1024*1024+1-data.count))) ?? Data()
        if chunk.isEmpty { break }
        data.append(chunk)
    }
    if let event = ActivityEvent.fromHook(data) {
        let args = CommandLine.arguments
        let testIndex = args.firstIndex(of:"--test-channel")
        let channel = testIndex.flatMap { args.indices.contains($0+1) ? args[$0+1] : nil } ?? ActivityBridge.channel
        ActivityBridge.post(event,channel:channel)
    }
    print("{}")
    exit(0)
}

if CommandLine.arguments.contains("--bridge-self-test") {
    let bridge = ActivityBridge()
    var received = false
    bridge.channel = "dots-test-"+UUID().uuidString
    let session = UUID().uuidString
    bridge.onEvent = { if $0.session == ActivityEvent.digest(session) && $0.kind == .started { received = true } }
    bridge.start()
    let child = Process(), pipe = Pipe()
    child.executableURL = URL(fileURLWithPath:CommandLine.arguments[0])
    child.arguments = ["--hook","--test-channel",bridge.channel]
    child.standardInput = pipe; child.standardOutput = FileHandle.nullDevice
    do {
        try child.run()
        let json = try JSONSerialization.data(withJSONObject:["hook_event_name":"UserPromptSubmit","session_id":session,"turn_id":"transport-test","prompt":"MUST_NOT_LEAVE_HELPER"])
        pipe.fileHandleForWriting.write(json); try pipe.fileHandleForWriting.close()
    } catch { print("FAIL: helper launch"); exit(1) }
    let deadline = Date().addingTimeInterval(2)
    while !received && Date() < deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.02)) }
    bridge.stop()
    if child.isRunning { child.terminate() }
    child.waitUntilExit()
    print(received ? "PASS: local distributed event delivery" : "FAIL: local event delivery unavailable in this execution context")
    exit(received ? 0 : 1)
}

if CommandLine.arguments.contains("--self-test") {
    do {
        let atlas = try SpriteAtlas(resources:resourceDirectory(),makeAppKitImages:false)
        let failures = runEngineTests(manifest:atlas.manifest) + runActivityTests()
        print("Atlas: \(atlas.manifest.frameCount) frames; \(atlas.manifest.columns)x\(atlas.manifest.rows) cells; WebP decoded successfully")
        if failures.isEmpty { print("PASS: movement, click spin, activity loop, completion, overlap, deduplication, privacy filtering, expiry, frame bounds") }
        else { failures.forEach { print("FAIL: \($0)") } }
        exit(failures.isEmpty ? 0 : 1)
    } catch { print("FAIL: \(error)"); exit(1) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = AppController()
app.delegate = controller
app.run()
