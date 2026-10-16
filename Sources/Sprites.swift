import AppKit
import ImageIO

final class SpriteAtlas {
    let manifest: AtlasManifest
    let images: [NSImage]
    private let masks: [[UInt8]]
    init(resources: URL, makeAppKitImages: Bool = true) throws {
        manifest = try JSONDecoder().decode(AtlasManifest.self,from:Data(contentsOf:resources.appendingPathComponent("animations.json")))
        let url = resources.appendingPathComponent(manifest.image)
        guard let source = CGImageSourceCreateWithURL(url as CFURL,nil),
              let sheet = CGImageSourceCreateImageAtIndex(source,0,nil) else {
            throw NSError(domain:"Dots",code:1,userInfo:[NSLocalizedDescriptionKey:"spritesheet.webp을 읽을 수 없어요."])
        }
        guard sheet.width == manifest.columns*manifest.cellSize, sheet.height == manifest.rows*manifest.cellSize else {
            throw NSError(domain:"Dots",code:2,userInfo:[NSLocalizedDescriptionKey:"스프라이트 크기와 프레임 정보가 맞지 않아요."])
        }
        var sprites: [NSImage] = [], alpha: [[UInt8]] = []
        let cell = manifest.cellSize
        for index in 0..<manifest.frameCount {
            let rect = CGRect(x:(index%manifest.columns)*cell,y:(index/manifest.columns)*cell,width:cell,height:cell)
            guard let frame = sheet.cropping(to:rect) else { continue }
            if makeAppKitImages { sprites.append(NSImage(cgImage:frame,size:NSSize(width:cell,height:cell))) }
            var pixels = [UInt8](repeating:0,count:cell*cell*4)
            pixels.withUnsafeMutableBytes { bytes in
                if let context = CGContext(data:bytes.baseAddress,width:cell,height:cell,bitsPerComponent:8,bytesPerRow:cell*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) {
                    context.draw(frame,in:CGRect(x:0,y:0,width:cell,height:cell))
                }
            }
            let mask = stride(from:3,to:pixels.count,by:4).map { pixels[$0] > 30 ? UInt8(1) : UInt8(0) }
            alpha.append(mask)
        }
        images = sprites; masks = alpha
    }
    func hit(frame: Int, normalizedX x: Double, normalizedY y: Double) -> Bool {
        guard x >= 0, x < 1, y >= 0, y < 1, masks.indices.contains(frame) else { return false }
        let cell = manifest.cellSize
        return masks[frame][min(cell-1,Int((1-y)*Double(cell)))*cell + min(cell-1,Int(x*Double(cell)))] > 0
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    let atlas: SpriteAtlas
    let engine: PetEngine
    var petSize: CGFloat = 144
    var frameIndex = 0
    var reducedMotion = false
    var speechEnabled = false
    var menuRequested: ((NSEvent) -> Void)?
    var onPressed: (() -> Void)?
    var onDragged: ((NSPoint) -> Void)?
    var onReleased: (() -> Void)?
    var downPoint: NSPoint?
    var dragOffset: NSPoint = .zero
    private(set) var dragging = false
    var previewTime: Double?
    var now: Double { previewTime ?? ProcessInfo.processInfo.systemUptime }

    init(atlas: SpriteAtlas,engine: PetEngine) {
        self.atlas = atlas; self.engine = engine
        super.init(frame:.zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("우사기 — 클릭: 빙글빙글, 드래그: 이동")
        toolTip = "커서를 올리면 랩 댄스 · 클릭하면 빙글빙글 · 드래그로 이동 · 우클릭 설정"
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    var spriteRect: NSRect { NSRect(x:(bounds.width-petSize)/2,y:24,width:petSize,height:petSize) }
    var footOffset: CGFloat { 24+petSize*0.125 }
    private func poseTransform() -> AffineTransform {
        let r = spriteRect
        let amount = reducedMotion ? ([Motion.rest,.sleep].contains(engine.motion) ? 1.0 : 0.0) : engine.reclineAmount(at:now)
        var transform = AffineTransform()
        transform.translate(x:r.midX,y:r.midY)
        transform.rotate(byDegrees:CGFloat(40*amount))
        transform.translate(x:-r.midX,y:-r.midY)
        return transform
    }
    func containsSprite(_ local: NSPoint) -> Bool {
        let r = spriteRect
        guard let inverse = poseTransform().inverted() else { return false }
        let point = inverse.transform(local)
        return atlas.hit(frame:frameIndex,normalizedX:(point.x-r.minX)/r.width,normalizedY:(point.y-r.minY)/r.height)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill(using:.copy)
        let t = now-engine.startedAt
        let r = spriteRect
        let active = engine.motion == .rap || engine.motion == .spin
        if active && !reducedMotion {
            let stage = NSBezierPath(ovalIn:NSRect(x:r.minX-8,y:17,width:r.width+16,height:23))
            NSColor(calibratedRed:0.12,green:0.67,blue:0.72,alpha:0.20).setFill(); stage.fill()
            if engine.motion == .rap {
                for i in 0..<19 {
                    let height = 3+abs(sin(t*8+Double(i)*1.43))*13
                    NSColor(calibratedRed:0.95,green:0.40,blue:0.65,alpha:0.72).setFill()
                    NSBezierPath(roundedRect:NSRect(x:r.midX-66+Double(i)*7,y:18,width:3,height:height),xRadius:1.5,yRadius:1.5).fill()
                }
            }
        }
        if engine.motion != .drag {
            NSColor.black.withAlphaComponent(0.10).setFill()
            NSBezierPath(ovalIn:NSRect(x:r.midX-petSize*0.23,y:footOffset-4,width:petSize*0.46,height:8)).fill()
        }
        var drawn = r
        if !reducedMotion && engine.motion == .idle { drawn.origin.y += sin(t*2)*0.6 }
        if atlas.images.indices.contains(frameIndex) {
            NSGraphicsContext.saveGraphicsState()
            (poseTransform() as NSAffineTransform).concat()
            atlas.images[frameIndex].draw(in:drawn,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
            NSGraphicsContext.restoreGraphicsState()
        }
        if engine.motion == .pet || engine.highlightUntil > now {
            drawSymbol(engine.motion == .pet ? "♥" : "✦",at:NSPoint(x:r.maxX-20,y:r.maxY-48),size:18,color:.systemPink)
        }
        // Long inactivity keeps the same open-eyed, blinking reclined rest.
        if speechEnabled && active {
            let phrase = engine.motion == .spin ? "캬우!" : (t < 1.5 ? "우이야-" : (t < 3.5 ? "캬우-" : "으야!"))
            let attributes: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:12,weight:.bold),.foregroundColor:NSColor(calibratedRed:0.30,green:0.20,blue:0.14,alpha:1)]
            let text = NSAttributedString(string:phrase,attributes:attributes)
            let w = text.size().width+20
            NSColor(calibratedWhite:1,alpha:0.94).setFill()
            let bubble = NSRect(x:r.midX-w/2,y:r.maxY+2,width:w,height:25)
            NSBezierPath(roundedRect:bubble,xRadius:12,yRadius:12).fill()
            text.draw(at:NSPoint(x:bubble.minX+10,y:bubble.minY+5))
        }
    }
    private func drawSymbol(_ text: String,at point:NSPoint,size:CGFloat,color:NSColor) {
        (text as NSString).draw(at:point,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:color])
    }
    override func mouseDown(with event:NSEvent) {
        guard containsSprite(convert(event.locationInWindow,from:nil)) else { return }
        downPoint = NSEvent.mouseLocation; dragging = false
        dragOffset = NSPoint(x:engine.position.x-(downPoint?.x ?? 0),y:engine.position.y-(downPoint?.y ?? 0))
        onPressed?()
    }
    override func mouseDragged(with event:NSEvent) {
        guard let start = downPoint else { return }
        let p = NSEvent.mouseLocation
        if !dragging && hypot(p.x-start.x,p.y-start.y) >= 6 {
            dragging = true; engine.beginDrag(at:now)
        }
        if dragging { onDragged?(NSPoint(x:p.x+dragOffset.x,y:p.y+dragOffset.y)) }
    }
    override func mouseUp(with event:NSEvent) {
        guard downPoint != nil else { return }
        if dragging { engine.endDrag(at:now) } else { engine.click(at:now) }
        downPoint = nil; dragging = false; onReleased?()
    }
    override func rightMouseDown(with event:NSEvent) { menuRequested?(event) }
    override func scrollWheel(with event:NSEvent) {
        // Rotation is now an explicit click. Scrolling never triggers an animation.
    }
    override func accessibilityPerformPress() -> Bool { engine.click(at:now); return true }
}
