import Foundation
import CryptoKit

/// A cosmetic, local-only event channel. Never transports prompts or transcripts.
struct ActivityEvent: Codable, Equatable {
    enum Kind: String, Codable { case started, finished, sessionEnded }
    let kind: Kind
    let session: String
    let turn: String
    let time: Double

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func fromHook(_ data: Data, at time: Double = Date().timeIntervalSince1970) -> ActivityEvent? {
        guard data.count <= 8*1024*1024,
              let value = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let name = value["hook_event_name"] as? String,
              let session = value["session_id"] as? String, !session.isEmpty, session.count < 1024 else { return nil }
        let kind: Kind
        switch name {
        case "UserPromptSubmit": kind = .started
        case "Stop", "Interrupt": kind = .finished
        case "SessionEnd": kind = .sessionEnded
        default: return nil
        }
        let turn = value["turn_id"] as? String ?? "legacy-session"
        guard turn.count < 1024 else { return nil }
        return .init(kind:kind,session:digest(session),turn:digest(turn),time:time)
    }
    var valid: Bool {
        let hex = CharacterSet(charactersIn:"0123456789abcdef")
        return time.isFinite && [session,turn].allSatisfy { $0.count == 64 && $0.unicodeScalars.allSatisfy(hex.contains) }
    }
}

final class ActivityTracker {
    // Lost completion events must not leave a permanent animation after a crash.
    static let expiry: Double = 2*60*60
    private var active: [String:ActivityEvent] = [:]
    private var ended: [String:Double] = [:]
    private var closedSessions: [String:Double] = [:]
    private(set) var lastEvent: ActivityEvent.Kind?
    var count: Int { active.count }
    func receive(_ event: ActivityEvent, now: Double) {
        expire(now:now)
        guard event.valid, event.time <= now+5, event.time >= now-30 else { return }
        let key = event.session+":"+event.turn
        lastEvent = event.kind
        switch event.kind {
        case .started:
            guard ended[key] == nil,
                  event.time > (closedSessions[event.session] ?? -.infinity),
                  active.count < 256 || active[key] != nil else { return }
            // Duplicate submit/steering for the same turn must not increment the count.
            if active[key] == nil { active[key] = event }
        case .finished:
            ended[key] = event.time; active[key] = nil
        case .sessionEnded:
            closedSessions[event.session] = event.time
            active = active.filter { $0.value.session != event.session }
        }
    }
    func expire(now: Double) {
        active = active.filter { now-$0.value.time < Self.expiry }
        ended = ended.filter { now-$0.value < Self.expiry }
        closedSessions = closedSessions.filter { now-$0.value < Self.expiry }
    }
    func reset() { active.removeAll(); ended.removeAll(); closedSessions.removeAll() }
}

final class ActivityBridge: NSObject {
    static let name = Notification.Name("studio.dots.usagi.activity.v1")
    static var channel: String { "user-\(getuid())" }
    var channel = ActivityBridge.channel
    var onEvent: ((ActivityEvent) -> Void)?
    func start() {
        DistributedNotificationCenter.default().addObserver(self,selector:#selector(receive(_:)),name:Self.name,object:channel,suspensionBehavior:.deliverImmediately)
    }
    func stop() { DistributedNotificationCenter.default().removeObserver(self) }
    deinit { stop() }
    @objc private func receive(_ notification: Notification) {
        guard let json = notification.userInfo?["event"] as? String, json.utf8.count < 1024,
              let event = try? JSONDecoder().decode(ActivityEvent.self,from:Data(json.utf8)), event.valid else { return }
        onEvent?(event)
    }
    static func post(_ event: ActivityEvent, channel: String = ActivityBridge.channel) {
        guard event.valid, let data = try? JSONEncoder().encode(event), let json = String(data:data,encoding:.utf8) else { return }
        DistributedNotificationCenter.default().postNotificationName(name,object:channel,userInfo:["event":json],deliverImmediately:true)
    }
}

func runActivityTests() -> [String] {
    var failures: [String] = []
    func check(_ condition: Bool,_ message: String) { if !condition { failures.append(message) } }
    func e(_ kind: ActivityEvent.Kind,_ session: String,_ turn: String,_ time: Double) -> ActivityEvent {
        .init(kind:kind,session:ActivityEvent.digest(session),turn:ActivityEvent.digest(turn),time:time)
    }
    let t = ActivityTracker()
    t.receive(e(.started,"app","1",1),now:1)
    t.receive(e(.started,"app","1",2),now:2)
    t.receive(e(.started,"ide","2",3),now:3)
    check(t.count == 2,"duplicate start is idempotent; app + IDE overlap")
    t.receive(e(.finished,"app","1",4),now:4)
    check(t.count == 1,"one completion must not stop another task")
    t.receive(e(.finished,"app","1",5),now:5)
    check(t.count == 1,"duplicate completion is idempotent")
    t.receive(e(.sessionEnded,"ide","unused",6),now:6)
    check(t.count == 0,"session end clears its tasks")
    t.receive(e(.finished,"app","late",8),now:8)
    t.receive(e(.started,"app","late",7),now:9)
    check(t.count == 0,"out-of-order start cannot resurrect a completed turn")
    t.receive(e(.started,"app","long",10),now:10)
    t.expire(now:10+ActivityTracker.expiry)
    check(t.count == 0,"crash safety expiry")
    let input = Data(#"{"hook_event_name":"UserPromptSubmit","session_id":"private-session","turn_id":"t1","prompt":"SECRET_PROMPT","transcript_path":"SECRET_PATH"}"#.utf8)
    if let event = ActivityEvent.fromHook(input,at:20), let encoded = try? JSONEncoder().encode(event), let json = String(data:encoded,encoding:.utf8) {
        check(!json.contains("SECRET") && !json.contains("private-session"),"content and raw session IDs must not leave the hook")
    } else { failures.append("hook parsing failed") }
    check(ActivityEvent.fromHook(Data("invalid".utf8)) == nil,"malformed hook ignored")
    check(ActivityEvent.fromHook(Data(#"{"hook_event_name":"PostToolUse","session_id":"a"}"#.utf8)) == nil,"unrelated events ignored")
    return failures
}
