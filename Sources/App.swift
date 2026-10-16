import AppKit
import ApplicationServices

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let engine = PetEngine()
    let monitor = DesktopMonitor()
    let defaults = UserDefaults.standard
    let activityBridge = ActivityBridge()
    let activityTracker = ActivityTracker()
    var danceTriggers = DanceTriggers()
    var activityEnabled: Bool { defaults.object(forKey:"activityEnabled") as? Bool != false }
    var demoActive = false
    var atlas: SpriteAtlas!
    var panel: PetPanel!
    var petView: PetView!
    var statusItem: NSStatusItem!
    var timer: Timer?
    var welcome: NSWindow?
    var permissionLabel: NSTextField?
    var hidden = false
    var menuOpen = false
    var screen: NSScreen?
    var lastHover = 0.0
    var previousMouse = NSPoint.zero
    var strokeDirection = 0
    var strokeTimes: [Double] = []
    var lastFrame = -1
    var lastAccessibilityStatus = ""
    var lastPermission = false
    var lastPermissionCheck = 0.0
    var diagnosticClassification = DesktopResult.unknown
    var testMode = false
    var now: Double { ProcessInfo.processInfo.systemUptime }

    func applicationDidFinishLaunching(_ notification:Notification) {
        do {
            atlas = try SpriteAtlas(resources:resourceDirectory())
        } catch {
            let alert = NSAlert(); alert.messageText = "Dots를 시작할 수 없어요"; alert.informativeText = error.localizedDescription
            alert.runModal(); NSApp.terminate(nil); return
        }
        engine.animations = atlas.manifest.animations; engine.resetClock(now)
        screen = NSScreen.main ?? NSScreen.screens.first
        let s = screen?.visibleFrame ?? NSRect(x:0,y:0,width:1280,height:800)
        engine.place(Point(x:s.maxX-200,y:s.minY+90))
        engine.onMotion = { [weak self] motion in
            guard let self else { return }
            if self.defaults.bool(forKey:"sound"), [.rap,.spin,.land].contains(motion) {
                NSSound(named:NSSound.Name("Pop"))?.play()
            }
        }
        panel = PetPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title = "Dots · 우사기"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces,.stationary,.ignoresCycle]
        petView = PetView(atlas:atlas,engine:engine)
        petView.petSize = defaults.double(forKey:"petSize") > 0 ? defaults.double(forKey:"petSize") : 144
        petView.speechEnabled = defaults.bool(forKey:"speech")
        petView.reducedMotion = defaults.bool(forKey:"reducedMotion") || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        petView.onDragged = { [weak self] point in
            guard let self else { return }
            if let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(point) }) { self.screen = targetScreen }
            self.engine.place(self.clamp(Point(x:point.x,y:point.y)))
            self.positionPanel()
        }
        petView.menuRequested = { [weak self] event in
            guard let self else { return }
            NSMenu.popUpContextMenu(self.makeMenu(),with:event,for:self.petView)
        }
        panel.contentView = petView
        resizePanel(); panel.orderFrontRegardless()
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName:"hare.fill",accessibilityDescription:"Dots 우사기")
            button.toolTip = "Dots · 우사기"
        }
        statusItem.menu = makeMenu()
        monitor.onClick = { [weak self] point in
            guard let self, !self.hidden, !self.menuOpen, let screen = self.screen,
                  screen.visibleFrame.contains(point), self.defaults.object(forKey:"followDesktop") as? Bool != false else { return }
            let delta = self.engine.position-Point(x:point.x,y:point.y)
            let offset = delta.length > 1 ? delta*(24/delta.length) : Point(x:24,y:0)
            self.engine.move(to:self.clamp(Point(x:point.x,y:point.y)+offset),at:self.now)
        }
        monitor.onClassification = { [weak self] result in self?.diagnosticClassification = result }
        monitor.start()
        activityBridge.onEvent = { [weak self] event in
            guard let self else { return }
            self.activityTracker.receive(event,now:Date().timeIntervalSince1970)
            self.syncActivity()
        }
        activityBridge.start()
        timer = Timer(timeInterval:1/30,repeats:true) { [weak self] _ in self?.update() }
        if let timer { RunLoop.main.add(timer,forMode:.common) }
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(workspaceSleep),name:NSWorkspace.willSleepNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(workspaceWake),name:NSWorkspace.didWakeNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(screensChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        if !defaults.bool(forKey:"hasLaunched") || CommandLine.arguments.contains("--welcome") { showWelcome() }
        defaults.set(true,forKey:"hasLaunched")
    }

    func resizePanel() {
        let size = NSSize(width:petView.petSize*1.75,height:petView.petSize+80)
        panel.setContentSize(size); petView.frame = NSRect(origin:.zero,size:size)
        engine.place(clamp(engine.position)); positionPanel()
    }
    func positionPanel() {
        panel.setFrameOrigin(NSPoint(x:engine.position.x-panel.frame.width/2,y:engine.position.y-petView.footOffset))
    }
    func clamp(_ point:Point) -> Point {
        let bounds = screen?.visibleFrame ?? NSRect(x:0,y:0,width:1280,height:800)
        let half = petView.petSize*0.48
        return Point(x:min(bounds.maxX-half,max(bounds.minX+half,point.x)),
                     y:min(bounds.maxY-petView.petSize*0.88-24,max(bounds.minY+20,point.y)))
    }
    func update() {
        let t = now
        activityTracker.expire(now:Date().timeIntervalSince1970)
        syncActivity()
        guard !hidden else { return }
        if t-lastPermissionCheck > 2 {
            lastPermissionCheck = t
            let permission = monitor.detector.hasPermission
            if permission != lastPermission { lastPermission = permission; refreshPermissionLabel() }
        }
        if !menuOpen {
            engine.tick(t)
            positionPanel()
        }
        let fullFrame = engine.frame(at:t)
        var frame = fullFrame
        if petView.reducedMotion {
            if engine.motion == .spin { frame = 95 }
            if engine.motion == .rap { frame = [43,55,73][min(2,Int(max(0,t-engine.startedAt)/1.7))] }
        }
        petView.frameIndex = frame
        let accessibilityStatus = "동작: \(engine.motion.rawValue), GPT 작업: \(activityTracker.count)개" + (demoActive ? " (데모)" : "")
        if accessibilityStatus != lastAccessibilityStatus {
            petView.setAccessibilityValue(accessibilityStatus)
            lastAccessibilityStatus = accessibilityStatus
        }
        if frame != lastFrame || [.rap,.spin,.idle,.pet,.rest,.sleep,.wake].contains(engine.motion) || engine.highlightUntil > t {
            petView.needsDisplay = true; lastFrame = frame
        }
        let mouse = NSEvent.mouseLocation
        let local = NSPoint(x:mouse.x-panel.frame.minX,y:mouse.y-panel.frame.minY)
        let hit = petView.containsSprite(local)
        danceTriggers.updateHover(hit:hit,
            withinHoldArea:petView.spriteRect.insetBy(dx:-4,dy:-4).contains(local),
            eligible:!menuOpen && petView.downPoint == nil && engine.motion != .drag)
        syncActivity()
        panel.ignoresMouseEvents = !(hit || petView.downPoint != nil || menuOpen)
        // Hover-only stroking. Never interpret drags as petting.
        if hit && petView.downPoint == nil && !menuOpen {
            let inHead = local.y > petView.spriteRect.minY+petView.petSize*0.43
            let dx = mouse.x-previousMouse.x
            if inHead && abs(dx) > 2 {
                let dir = dx > 0 ? 1 : -1
                if strokeDirection != 0 && dir != strokeDirection { strokeTimes.append(t) }
                strokeDirection = dir
                strokeTimes.removeAll { t-$0 > 1.2 }
                if strokeTimes.count >= 3 { engine.pet(at:t); strokeTimes.removeAll() }
            }
            if t-lastHover > 0.6 {
                let n = (local.x-petView.spriteRect.midX)/(petView.petSize*0.5)
                engine.look(index:n < -0.2 ? 0 : (n > 0.2 ? 4 : 2),at:t)
                lastHover = t
            }
        } else { strokeTimes.removeAll(); strokeDirection = 0 }
        previousMouse = mouse
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(); menu.delegate = self
        func item(_ title:String,_ action:Selector,_ state:Bool? = nil,_ tag:Int = 0) {
            let i = NSMenuItem(title:title,action:action,keyEquivalent:""); i.target = self; i.tag = tag
            if let state { i.state = state ? .on : .off }; menu.addItem(i)
        }
        let header = NSMenuItem(title:"Dots · 우사기",action:nil,keyEquivalent:""); header.isEnabled = false; menu.addItem(header)
        let activity = NSMenuItem(title: demoActive ? "연동 데모 중 (실제 GPT 아님)" : (activityTracker.count > 0 ? "GPT 작업 중 · \(activityTracker.count)개" : "GPT 이벤트 대기 중"),action:nil,keyEquivalent:"")
        activity.isEnabled = false; menu.addItem(activity)
        menu.addItem(.separator())
        item("인어섬 랩",#selector(rap)); item("빙글빙글",#selector(spin)); item("쉬기",#selector(rest)); item("동작 멈추기",#selector(stop))
        menu.addItem(.separator())
        item("바탕화면 클릭 따라오기",#selector(toggleFollow),defaults.object(forKey:"followDesktop") as? Bool != false)
        item("집중 모드",#selector(toggleQuiet),engine.quiet)
        item("GPT 응답 중 자동 댄스",#selector(toggleActivity),activityEnabled)
        item(demoActive ? "연동 데모 끝내기" : "연동 데모 시작 (실제 GPT 아님)",#selector(toggleDemo))
        item("작업 상태 초기화",#selector(resetActivity))
        item("추임새 말풍선",#selector(toggleSpeech),petView?.speechEnabled ?? false)
        item("효과음",#selector(toggleSound),defaults.bool(forKey:"sound"))
        item("움직임 줄이기",#selector(toggleReduced),petView?.reducedMotion ?? false)
        let sizes = NSMenu()
        for (label,value) in [("작게",112),("보통",144),("크게",184)] {
            let i = NSMenuItem(title:label,action:#selector(setSize(_:)),keyEquivalent:""); i.target = self; i.tag = value
            i.state = Int(petView?.petSize ?? 144) == value ? .on : .off; sizes.addItem(i)
        }
        let sizeItem = NSMenuItem(title:"크기",action:nil,keyEquivalent:""); sizeItem.submenu = sizes; menu.addItem(sizeItem)
        menu.addItem(.separator())
        item(hidden ? "우사기 다시 표시" : "우사기 숨기기",#selector(toggleHidden))
        item("사용 방법 / 권한",#selector(showWelcome))
        item("Dots 종료",#selector(quit))
        return menu
    }
    func menuWillOpen(_ menu:NSMenu) { menuOpen = true }
    func menuDidClose(_ menu:NSMenu) { menuOpen = false; statusItem.menu = makeMenu() }
    @objc func rap() { showPet(); engine.rap(at:now) }
    @objc func spin() { showPet(); engine.wheel(reverse:false,at:now) }
    @objc func rest() { engine.rest(at:now) }
    @objc func stop() { engine.stop(at:now) }
    @objc func toggleFollow() { defaults.set(!(defaults.object(forKey:"followDesktop") as? Bool != false),forKey:"followDesktop"); engine.stop(at:now) }
    @objc func toggleQuiet() { engine.setQuiet(!engine.quiet,at:now) }
    func syncActivity() {
        danceTriggers.gptActive = activityTracker.count > 0 && activityEnabled
        if hidden { danceTriggers.updateHover(hit:false,withinHoldArea:false,eligible:false) }
        engine.setActivity(danceTriggers.active && !hidden,at:now)
    }
    @objc func toggleActivity() { defaults.set(!activityEnabled,forKey:"activityEnabled"); syncActivity() }
    @objc func toggleDemo() {
        demoActive.toggle()
        let t = Date().timeIntervalSince1970
        // A fresh turn avoids dedup tombstones when the demo is started again.
        if demoActive { demoTurn = UUID().uuidString }
        ActivityBridge.post(ActivityEvent(kind:demoActive ? .started : .finished,session:ActivityEvent.digest("dots-local-demo"),turn:ActivityEvent.digest(demoTurn),time:t))
    }
    private var demoTurn = ""
    @objc func resetActivity() { activityTracker.reset(); demoActive = false; syncActivity() }
    @objc func toggleSpeech() { petView.speechEnabled.toggle(); defaults.set(petView.speechEnabled,forKey:"speech") }
    @objc func toggleSound() { defaults.set(!defaults.bool(forKey:"sound"),forKey:"sound") }
    @objc func toggleReduced() { petView.reducedMotion.toggle(); defaults.set(petView.reducedMotion,forKey:"reducedMotion") }
    @objc func setSize(_ sender:NSMenuItem) { petView.petSize = CGFloat(sender.tag); defaults.set(sender.tag,forKey:"petSize"); resizePanel() }
    @objc func toggleHidden() { hidden.toggle(); engine.stop(at:now); if hidden { panel.orderOut(nil) } else { panel.orderFrontRegardless(); engine.resetClock(now) }; statusItem.menu = makeMenu() }
    func showPet() { if hidden { toggleHidden() } }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func workspaceSleep() { engine.stop(at:now); panel.orderOut(nil) }
    @objc func workspaceWake() { engine.resetClock(now); if !hidden { panel.orderFrontRegardless() } }
    @objc func screensChanged() { screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x:engine.position.x,y:engine.position.y)) }) ?? NSScreen.main; engine.stop(at:now); engine.place(clamp(engine.position)); positionPanel() }
    func applicationWillTerminate(_ notification:Notification) { monitor.stop(); activityBridge.stop(); timer?.invalidate() }

    @objc func showWelcome() {
        if let welcome { welcome.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); refreshPermissionLabel(); return }
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:500,height:510),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title = "Dots에 온 걸 환영해요"; window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedRed:0.98,green:0.97,blue:0.94,alpha:1)
        let root = NSView(frame:NSRect(x:0,y:0,width:500,height:510)); window.contentView = root
        func label(_ text:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ size:CGFloat,_ weight:NSFont.Weight = .regular) -> NSTextField {
            let l = NSTextField(wrappingLabelWithString:text); l.frame = NSRect(x:x,y:y,width:w,height:h); l.font = .systemFont(ofSize:size,weight:weight); l.textColor = NSColor(calibratedRed:0.28,green:0.23,blue:0.18,alpha:1); root.addSubview(l); return l
        }
        let art = NSImageView(frame:NSRect(x:24,y:374,width:108,height:108)); art.image = atlas.images.first; art.imageScaling = .scaleProportionallyUpOrDown; root.addSubview(art)
        _ = label("작은 우사기,\n너의 바탕화면에.",142,404,330,65,25,.bold)
        _ = label("말을 걸지 않아도 괜찮아요. 마우스로 함께 놀아요.",142,378,326,24,12)
        _ = label("클릭하면 빙글빙글",38,322,210,24,16,.semibold)
        _ = label("우사기를 톡 누르면 회전",38,295,210,24,12)
        _ = label("인어섬 랩 댄스",265,322,215,24,16,.semibold)
        _ = label("GPT 응답 중 댄스 · 훅 연결 후 자동 반응",265,295,215,32,11)
        _ = label("잡아서 옮기기",38,252,210,24,16,.semibold)
        _ = label("드래그하고 놓으면 말랑하게 착지",38,225,220,24,12)
        _ = label("빈 곳을 누르면 달려오기",265,252,220,24,16,.semibold)
        _ = label("바탕화면의 빈 공간에만 반응해요",265,225,220,24,12)
        permissionLabel = label("",38,163,425,43,12,.medium)
        _ = label("손쉬운 사용 권한은 바탕화면의 빈 곳과 파일 아이콘을 구분할 때만 사용해요. 화면 녹화·키보드 입력·인터넷 연결은 사용하지 않아요.",38,99,425,55,11)
        let permission = NSButton(title:"바탕화면 따라오기 설정",target:self,action:#selector(openPermission)); permission.bezelStyle = .rounded; permission.frame = NSRect(x:32,y:49,width:224,height:34); root.addSubview(permission)
        let play = NSButton(title:"우사기랑 놀기",target:self,action:#selector(closeWelcome)); play.bezelStyle = .rounded; play.frame = NSRect(x:320,y:49,width:146,height:34); root.addSubview(play)
        _ = label("우클릭 또는 메뉴 막대의 토끼 아이콘에서 설정·종료할 수 있어요.",38,14,425,22,10)
        welcome = window; refreshPermissionLabel(); window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func refreshPermissionLabel() {
        permissionLabel?.stringValue = monitor.detector.hasPermission ? "✓ 바탕화면 따라오기 준비 완료\n권한을 켠 뒤에도 반응이 없다면 Dots를 다시 실행해 주세요." : "바탕화면 따라오기: 손쉬운 사용 권한이 필요해요.\n클릭·회전·드래그는 지금 바로 사용할 수 있어요."
    }
    @objc func closeWelcome() { welcome?.close() }
    @objc func openPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
}

func resourceDirectory() -> URL {
    if let index = CommandLine.arguments.firstIndex(of:"--resources"), CommandLine.arguments.indices.contains(index+1) {
        return URL(fileURLWithPath:CommandLine.arguments[index+1])
    }
    return Bundle.main.resourceURL ?? URL(fileURLWithPath:"Resources")
}
