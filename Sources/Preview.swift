import AppKit
import ImageIO
import UniformTypeIdentifiers

// Diagnostic rendering uses the very same PetView/engine as the live app.
func renderPreviews(to output: URL) throws {
    _ = NSApplication.shared
    try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
    let atlas = try SpriteAtlas(resources:resourceDirectory())
    let engine = PetEngine(); engine.animations = atlas.manifest.animations
    let view = PetView(atlas:atlas,engine:engine)
    view.frame = NSRect(x:0,y:0,width:320,height:280); view.petSize = 200
    func capture(_ t: Double) -> CGImage {
        view.previewTime = t; view.frameIndex = engine.frame(at:t)
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:320,pixelsHigh:280,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:1280,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }
    func save(_ frames:[CGImage],_ name:String) {
        let dest = CGImageDestinationCreateWithURL(output.appendingPathComponent(name+".gif") as CFURL,UTType.gif.identifier as CFString,frames.count,nil)!
        CGImageDestinationSetProperties(dest,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for frame in frames { CGImageDestinationAddImage(dest,frame,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.08]] as CFDictionary) }
        precondition(CGImageDestinationFinalize(dest))
        let context = CGContext(data:nil,width:320*4,height:280,bitsPerComponent:8,bytesPerRow:320*4*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        for i in 0..<4 { context.draw(frames[i*(frames.count-1)/3],in:CGRect(x:i*320,y:0,width:320,height:280)) }
        let png = CGImageDestinationCreateWithURL(output.appendingPathComponent(name+"-frames.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(png,context.makeImage()!,nil); precondition(CGImageDestinationFinalize(png))
    }
    engine.resetClock(0); engine.rest(at:0)
    var rest = (0..<25).map { capture(Double($0)*0.08) }
    engine.click(at:2)
    rest += (0..<10).map { capture(2+Double($0)*0.08) }
    save(rest,"rest-wake")
    engine.stop(at:4); engine.start(.rap,at:5)
    save((0..<50).map { capture(5.5+Double($0)*0.08) },"rap")
    engine.start(.spin,at:10)
    save((0..<19).map { capture(10+Double($0)*0.08) },"spin")
    print("PASS: rendered rest/wake, rap, spin using native PetView")
}
