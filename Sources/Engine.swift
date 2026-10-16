import Foundation

struct Point: Equatable, Codable {
    var x: Double
    var y: Double
    static func +(a: Point, b: Point) -> Point { .init(x: a.x+b.x, y: a.y+b.y) }
    static func -(a: Point, b: Point) -> Point { .init(x: a.x-b.x, y: a.y-b.y) }
    static func *(a: Point, s: Double) -> Point { .init(x: a.x*s, y: a.y*s) }
    var length: Double { hypot(x,y) }
}

enum Motion: String, Codable, CaseIterable {
    case idle, look, turn, runRight = "run_right", runLeft = "run_left"
    case arrive, rap, pet, drag, land, rest, sleep, wake, spin
}

struct Animation: Codable {
    let frames: [Int]
    let fps: Double
    let loop: Bool
    let durationsMs: [Double]?
    var duration: Double { if let durationsMs, durationsMs.count == frames.count { return durationsMs.reduce(0,+)/1000 }; return Double(frames.count) / fps }
}

struct AtlasManifest: Codable {
    let image: String
    let cellSize: Int
    let columns: Int
    let rows: Int
    let frameCount: Int
    let animations: [String: Animation]
}

/// Independent sources: leaving hover must not cancel real GPT work.
struct DanceTriggers {
    var gptActive = false
    private(set) var hoverActive = false
    var active: Bool { gptActive || hoverActive }
    mutating func updateHover(hit: Bool, withinHoldArea: Bool, eligible: Bool) {
        // Once entered, retain across changing animation silhouettes.
        hoverActive = eligible && (hit || (hoverActive && withinHoldArea))
    }
}

/// All interaction decisions live here. Rendering and macOS event routing are separate.
final class PetEngine {
    private(set) var motion: Motion = .idle
    private(set) var startedAt: Double = 0
    private(set) var position = Point(x: 250, y: 180)
    private(set) var destination: Point?
    private(set) var deferredDestination: Point?
    private(set) var facingRight = true
    private(set) var spinReverse = false
    private(set) var spinExtra = false
    private var spinExtraUsed = false
    private(set) var lastInteraction: Double = 0
    private(set) var quiet = false
    private(set) var highlightUntil: Double = 0
    var afterWake: Motion = .idle
    var animations: [String: Animation] = [:]
    var onMotion: ((Motion) -> Void)?
    var lookIndex = 2
    private var lastTick: Double?
    private var lastWheel: Double = -10
    private var lastPet: Double = -10
    private var lastRandom: Double = 0
    private(set) var activityActive = false
    private(set) var activityRap = false
    private var activitySuppressed = false
    private var wakeFromAmount = 1.0

    /// A rigid pose transform preserves every original ear/face pixel.
    func reclineAmount(at now: Double) -> Double {
        let duration = motion == .wake ? (animations["wake"]?.duration ?? 2.0/3.0) : 0.8
        let p = min(1,max(0,(now-startedAt)/duration))
        let eased = p*p*(3-2*p)
        switch motion {
        case .rest: return eased
        case .sleep: return 1
        case .wake: return wakeFromAmount*(1-eased)
        default: return 0
        }
    }

    func setActivity(_ active: Bool, at now: Double) {
        guard active != activityActive else { return }
        activityActive = active
        if active {
            activitySuppressed = false
            resumeActivity(at:now)
        } else {
            activitySuppressed = false
            if activityRap {
                activityRap = false
                if motion == .rap { start(.idle,at:now); touch(now) }
                if motion == .wake && afterWake == .rap { afterWake = .idle }
                if let target = deferredDestination {
                    deferredDestination = nil; move(to:target,at:now)
                }
            }
        }
    }
    private func resumeActivity(at now: Double) {
        guard activityActive, !activitySuppressed, !quiet,
              [.idle,.look,.rest,.sleep,.pet].contains(motion) else { return }
        activityRap = true; rap(at:now)
    }

    func start(_ state: Motion, at now: Double) {
        if state == .wake { wakeFromAmount = reclineAmount(at:now) }
        motion = state
        startedAt = now
        onMotion?(state)
    }
    func place(_ point: Point) { position = point }
    func touch(_ now: Double) { lastInteraction = now }
    func resetClock(_ now: Double) { lastTick = now; lastInteraction = now; lastRandom = now }
    func setQuiet(_ value: Bool, at now: Double) {
        quiet = value
        stop(at: now)
        if !value { activitySuppressed = false; resumeActivity(at:now) }
    }
    func stop(at now: Double) {
        activityRap = false; activitySuppressed = activityActive
        destination = nil; deferredDestination = nil; spinExtra = false; afterWake = .idle
        touch(now)
        if [.rest,.sleep,.wake].contains(motion) { start(.wake,at:now) }
        else { start(.idle, at: now) }
    }
    func click(at now: Double) {
        guard motion != .drag else { return }
        if motion == .sleep || motion == .rest {
            touch(now); afterWake = .spin; spinReverse = false
            spinExtra = false; spinExtraUsed = false
            start(.wake, at: now)
        } else if motion == .wake && afterWake == .spin {
            return
        } else { wheel(reverse: false, at: now) }
    }
    /// Shared dance entry point; activityRap keeps its core looping during work.
    /// No conversation content is needed to invoke the dance.
    func rap(at now: Double) {
        touch(now)
        if motion == .rap { highlightUntil = now + 0.25; return }
        if motion == .drag { return }
        if motion == .wake { afterWake = .rap; return }
        destination = nil; deferredDestination = nil; spinExtra = false
        if motion == .sleep || motion == .rest {
            afterWake = .rap; start(.wake, at: now)
        } else { start(.rap, at: now) }
    }
    func move(to target: Point, at now: Double) {
        guard !quiet, motion != .drag else { return }
        touch(now)
        if motion == .rap && activityRap {
            activityRap = false; start(.idle,at:now)
        }
        if motion == .rap || motion == .spin {
            deferredDestination = target
            return
        }
        destination = target
        if motion == .wake { afterWake = .turn; return }
        if (target-position).length < 28 {
            destination = nil
            if [.rest,.sleep].contains(motion) { afterWake = .look; start(.wake,at:now) }
            else { start(.look, at: now) }
            return
        }
        facingRight = target.x >= position.x
        if motion == .sleep || motion == .rest {
            afterWake = .turn; start(.wake, at: now)
        } else if motion == .runLeft || motion == .runRight {
            let next: Motion = facingRight ? .runRight : .runLeft
            if next != motion { start(next, at: now) }
        } else { start(.turn, at: now) }
    }
    func beginDrag(at now: Double) {
        activityRap = false
        touch(now); destination = nil; deferredDestination = nil; spinExtra = false
        start(.drag, at: now)
    }
    func endDrag(at now: Double) { touch(now); start(.land, at: now) }
    func wheel(reverse: Bool, at now: Double) {
        guard motion != .drag, now-lastWheel >= 0.4 else { return }
        lastWheel = now; touch(now)
        if motion == .spin { if !spinExtraUsed { spinExtra = true }; return }
        activityRap = false
        destination = nil; deferredDestination = nil
        spinReverse = reverse; spinExtra = false; spinExtraUsed = false; start(.spin, at: now)
    }
    func pet(at now: Double) {
        guard [.idle, .look, .pet].contains(motion), now-lastPet >= 1.2 else { return }
        lastPet = now; touch(now); start(.pet, at: now)
    }
    func look(index: Int, at now: Double) {
        guard [.idle, .look].contains(motion) else { return }
        lookIndex = min(5,max(0,index)); touch(now)
        if motion != .look { start(.look, at: now) }
    }
    func rest(at now: Double) {
        activityRap = false; activitySuppressed = activityActive
        destination = nil; deferredDestination = nil; touch(now); start(.rest, at: now)
    }
    func frame(at now: Double) -> Int {
        guard let animation = animations[motion.rawValue], !animation.frames.isEmpty else { return 0 }
        if motion == .look { return animation.frames[min(lookIndex,animation.frames.count-1)] }
        if let durations = animation.durationsMs, durations.count == animation.frames.count {
            var elapsed = max(0,now-startedAt)
            if animation.loop { elapsed = elapsed.truncatingRemainder(dividingBy:animation.duration) }
            for (i,duration) in durations.enumerated() {
                if elapsed < duration/1000 { return animation.frames[i] }
                elapsed -= duration/1000
            }
            return animation.frames.last ?? 0
        }
        var index = Int(max(0, now-startedAt) * animation.fps)
        if motion == .rap && activityRap && activityActive && index >= 6 && animation.frames.count >= 54 {
            // Intro once, then 48 core frames. No repeated costume-on/off outro.
            return animation.frames[6+(index-6)%48]
        }
        index = animation.loop ? index % animation.frames.count : min(index, animation.frames.count-1)
        if motion == .spin, spinReverse, index >= 4, index < 20 { index = 23-index }
        return animation.frames[index]
    }
    func tick(_ now: Double) {
        let dt = min(0.05,max(0,now-(lastTick ?? now)))
        lastTick = now
        if motion == .spin, spinExtra, !spinExtraUsed, now-startedAt >= 1.25 {
            spinExtra = false; spinExtraUsed = true; startedAt = now-0.25
        }
        if motion == .runRight || motion == .runLeft {
            guard let target = destination else { start(.idle,at:now); return }
            let delta = target-position
            if delta.length <= 2 {
                position = target; destination = nil; start(.arrive,at:now)
            } else {
                let speed = min(360,max(70,delta.length*6))
                position = position + delta * (min(delta.length,speed*dt)/delta.length)
            }
            return
        }
        if let animation = animations[motion.rawValue], !animation.loop,
           !(motion == .rap && activityRap && activityActive), now-startedAt >= animation.duration {
            switch motion {
            case .turn:
                if destination != nil { start(facingRight ? .runRight : .runLeft,at:now) }
                else { start(.idle,at:now) }
            case .wake:
                start(afterWake,at:now); afterWake = .idle
            case .rap, .spin:
                if let target = deferredDestination {
                    deferredDestination = nil; start(.idle,at:now); move(to:target,at:now)
                } else { start(.idle,at:now) }
            case .rest:
                // Hold the last resting frame until the sleep timeout.
                if now-lastInteraction >= 90 { start(.sleep,at:now) }
            default: start(.idle,at:now)
            }
        }
        resumeActivity(at:now)
        if !quiet, [.idle,.look].contains(motion), now-lastInteraction >= 30 {
            start(.rest,at:now)
        }
        if !quiet, motion == .idle, now-lastRandom >= 17, now-lastInteraction < 25 {
            lastRandom = now; lookIndex = Int(now.truncatingRemainder(dividingBy: 5))
            start(.look,at:now)
        }
    }
}

func runEngineTests(manifest: AtlasManifest) -> [String] {
    var failures: [String] = []
    func check(_ result: Bool, _ message: String) { if !result { failures.append(message) } }
    let e = PetEngine(); e.animations = manifest.animations; e.resetClock(0)
    e.rap(at:1)
    check(e.motion == .rap,"rap event must start dance")
    e.rap(at:2)
    check(e.startedAt == 1,"duplicate rap event must not restart dance")
    e.move(to:.init(x:500,y:200),at:2)
    e.move(to:.init(x:600,y:250),at:3)
    check(e.deferredDestination == .init(x:600,y:250),"latest destination wins")
    e.tick(6.1)
    check(e.motion == .turn && e.destination == .init(x:600,y:250),"rap completes into deferred move")
    for step in 0..<500 { e.tick(6.2+Double(step)/60) }
    check((e.position-Point(x:600,y:250)).length < 1,"run must reach destination without overshoot")
    e.click(at:20)
    check(e.motion == .spin,"click starts spin")
    e.click(at:20.5)
    check(e.startedAt == 20 && e.spinExtra,"repeat click queues one rotation without restarting")
    let valid = (0..<manifest.frameCount).contains(e.frame(at:20.8))
    check(valid,"reverse spin frame stays valid")
    e.beginDrag(at:20.9)
    check(e.motion == .drag && e.destination == nil,"drag cancels motion")
    e.endDrag(at:21)
    check(e.motion == .land,"release lands")
    e.stop(at:22)
    check(e.motion == .idle && e.deferredDestination == nil,"stop clears queue")
    e.setQuiet(true,at:23); e.move(to:.init(x:100,y:100),at:24)
    check(e.destination == nil,"quiet mode ignores desktop moves")
    e.click(at:25)
    check(e.motion == .spin,"explicit pet click works in quiet mode")
    e.setQuiet(false,at:30); e.tick(61)
    check(e.motion == .rest,"idle timeout enters rest")
    e.tick(121)
    check(e.motion == .sleep,"rest timeout enters sleep")
    e.click(at:122)
    check(e.motion == .wake && e.afterWake == .spin,"sleep click wakes then spins")
    check(abs(e.reclineAmount(at:122)-1)<0.001,"wake begins in reclined pose")
    check(e.reclineAmount(at:122.3)>0 && e.reclineAmount(at:122.3)<1,"wake interpolates without redrawing")
    check(e.reclineAmount(at:123)==0,"wake ends upright")
    let r = PetEngine(); r.animations = manifest.animations; r.resetClock(0)
    r.rest(at:1)
    check(r.reclineAmount(at:1)==0 && r.reclineAmount(at:2)==1,"rest smoothly reclines")
    let partial = r.reclineAmount(at:1.3)
    r.click(at:1.3)
    check(abs(r.reclineAmount(at:1.3)-partial)<0.001,"interrupted rest wakes without pose jump")
    r.move(to:Point(x:500,y:180),at:1.4)
    check(r.motion == .wake && r.afterWake == .turn,"move while waking preserves transition")
    r.tick(2.1)
    check(r.motion == .turn,"wake then turns toward destination")
    let a = PetEngine(); a.animations = manifest.animations; a.resetClock(0)
    a.setActivity(true,at:1); a.tick(20)
    check(a.motion == .rap && a.activityRap,"active response loops beyond five seconds")
    check((42...89).contains(a.frame(at:100)),"activity loops core dance, not outro")
    a.click(at:21); check(a.motion == .spin,"click interrupts activity with spin")
    a.tick(23); check(a.motion == .rap,"dance resumes after spin while response active")
    a.beginDrag(at:24); a.setActivity(false,at:25)
    check(a.motion == .drag,"completion never interrupts dragging")
    a.endDrag(at:26); a.tick(27)
    check([.idle,.look].contains(a.motion),"no dance after completion during drag")
    a.setActivity(true,at:28); a.setActivity(false,at:29)
    check(a.motion == .idle && !a.activityRap,"final completion immediately ends auto dance")
    a.setActivity(true,at:30); a.stop(at:31); a.tick(32)
    check(a.motion != .rap,"manual stop suppresses current work dance")
    a.setActivity(false,at:33); a.setActivity(true,at:34)
    check(a.motion == .rap,"next work event resumes auto dance")
    var triggers = DanceTriggers()
    let h = PetEngine(); h.animations = manifest.animations; h.resetClock(0)
    triggers.updateHover(hit:true,withinHoldArea:true,eligible:true)
    h.setActivity(triggers.active,at:1); h.tick(8)
    check(h.motion == .rap && h.activityRap,"hover loops same active-work dance")
    triggers.updateHover(hit:false,withinHoldArea:true,eligible:true)
    check(triggers.hoverActive,"changing sprite silhouette does not flicker hover")
    triggers.gptActive = true
    triggers.updateHover(hit:false,withinHoldArea:false,eligible:true)
    h.setActivity(triggers.active,at:9)
    check(h.motion == .rap,"hover exit preserves real GPT dance")
    triggers.gptActive = false; h.setActivity(triggers.active,at:10)
    check(h.motion == .idle,"last trigger ending stops dance")
    triggers.gptActive = true
    triggers.updateHover(hit:true,withinHoldArea:true,eligible:true)
    h.setActivity(triggers.active,at:11)
    triggers.gptActive = false; h.setActivity(triggers.active,at:12)
    check(h.motion == .rap,"GPT completion preserves hover dance")
    triggers.updateHover(hit:true,withinHoldArea:true,eligible:false)
    h.setActivity(triggers.active,at:13)
    check(!triggers.hoverActive && h.motion == .idle,"drag/menu disables hover")
    for (name,animation) in manifest.animations {
        check(animation.fps > 0 && !animation.frames.isEmpty,"invalid animation \(name)")
        check(animation.frames.allSatisfy { (0..<manifest.frameCount).contains($0) },"out-of-range frames in \(name)")
    }
    return failures
}
