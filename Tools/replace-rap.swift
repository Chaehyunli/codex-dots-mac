import AppKit
import ImageIO
import UniformTypeIdentifiers

// Mechanical crop/alignment/packing only. The twelve new poses are ImageGen art.
// Usage: replace-rap old.webp rap-keyposes-v3.png output-directory
let args = CommandLine.arguments
precondition(args.count == 4)
let out = URL(fileURLWithPath:args[3],isDirectory:true)
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
func load(_ path:String) -> CGImage {
    let s = CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil)!
    return CGImageSourceCreateImageAtIndex(s,0,nil)!
}
let original = load(args[1]), source = load(args[2])
let space = CGColorSpaceCreateDeviceRGB()
func canvas(_ w:Int,_ h:Int) -> CGContext {
    CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
}
var pixels = [UInt8](repeating:0,count:source.width*source.height*4)
pixels.withUnsafeMutableBytes { bytes in
    let c = CGContext(data:bytes.baseAddress,width:source.width,height:source.height,bitsPerComponent:8,bytesPerRow:source.width*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(source,in:CGRect(x:0,y:0,width:source.width,height:source.height))
}
var visited = [Bool](repeating:false,count:source.width*source.height)
var bodies:[(CGRect,Int)] = []
for seed in visited.indices {
    if visited[seed] || pixels[seed*4+3] <= 100 { continue }
    visited[seed] = true
    var queue = [seed], head = 0
    var x0=seed%source.width, x1=x0, y0=seed/source.width, y1=y0
    while head < queue.count {
        let p=queue[head]; head += 1
        let x=p%source.width, y=p/source.width
        x0=min(x0,x); x1=max(x1,x); y0=min(y0,y); y1=max(y1,y)
        for dy in -1...1 { for dx in -1...1 {
            let nx=x+dx, ny=y+dy
            if nx<0 || ny<0 || nx>=source.width || ny>=source.height { continue }
            let n=ny*source.width+nx
            if !visited[n] && pixels[n*4+3]>100 { visited[n]=true; queue.append(n) }
        }}
    }
    if queue.count>1500 { bodies.append((CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1),queue.count)) }
}
bodies=Array(bodies.sorted {$0.1>$1.1}.prefix(12)).sorted {$0.0.midY<$1.0.midY}
precondition(bodies.count==12,"Expected twelve isolated character bodies")
var boxes:[CGRect]=[]
for row in 0..<3 { boxes += bodies[row*4..<row*4+4].map {$0.0}.sorted {$0.midX<$1.midX} }
let scale = 200/(boxes.map {$0.height}.max()!)
let shiftX:[Double] = [0,8,14,0,-8,-14,0,0,0,0,0,0]
let shiftY:[Double] = [0,-2,-5,0,-2,-5,0,-6,8,18,-6,0]
var keys:[CGImage]=[]
for i in 0..<12 {
    let box=boxes[i].insetBy(dx:-2,dy:-2).intersection(CGRect(x:0,y:0,width:source.width,height:source.height))
    let image=source.cropping(to:box)!, c=canvas(256,256)
    c.interpolationQuality = .high
    let w=Double(image.width)*scale, h=Double(image.height)*scale
    precondition(32+shiftY[i]+h<256,"Ear clipping")
    c.draw(image,in:CGRect(x:128-w/2+shiftX[i],y:32+shiftY[i],width:w,height:h))
    keys.append(c.makeImage()!)
}
let atlas=canvas(original.width,original.height)
atlas.draw(original,in:CGRect(x:0,y:0,width:original.width,height:original.height))
func rect(_ index:Int) -> CGRect { CGRect(x:index%12*256,y:original.height-(index/12+1)*256,width:256,height:256) }
let core = (0..<12).flatMap { [$0,$0] }
for frame in 36..<96 {
    let r=rect(frame)
    atlas.clear(r)
    let image:CGImage
    if frame<38 || frame>=94 {
        image=original.cropping(to:CGRect(x:0,y:0,width:256,height:256))!
    } else {
        let key = frame<42 || frame>=90 ? 0 : core[(frame-42)%24]
        image=keys[key]
    }
    atlas.draw(image,in:r)
}
func save(_ image:CGImage,_ name:String) {
    let d=CGImageDestinationCreateWithURL(out.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(d,image,nil)
    let ok=CGImageDestinationFinalize(d); precondition(ok)
}
save(atlas.makeImage()!,"spritesheet.png")
let preview=canvas(1024,768)
preview.setFillColor(CGColor(red:0.96,green:0.95,blue:0.91,alpha:1)); preview.fill(CGRect(x:0,y:0,width:1024,height:768))
for i in 0..<12 { preview.draw(keys[i],in:CGRect(x:i%4*256,y:768-(i/4+1)*256,width:256,height:256)) }
save(preview.makeImage()!,"rap-keyposes-preview.png")
let gif=CGImageDestinationCreateWithURL(out.appendingPathComponent("rap-loop-preview.gif") as CFURL,UTType.gif.identifier as CFString,24,nil)!
CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for key in core {
    let c=canvas(384,384)
    c.setFillColor(CGColor(red:0.96,green:0.95,blue:0.91,alpha:1)); c.fill(CGRect(x:0,y:0,width:384,height:384))
    c.setFillColor(CGColor(gray:0,alpha:0.08)); c.fillEllipse(in:CGRect(x:131,y:88,width:122,height:9))
    c.draw(keys[key],in:CGRect(x:64,y:64,width:256,height:256))
    CGImageDestinationAddImage(gif,c.makeImage()!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/12]] as CFDictionary)
}
let ok=CGImageDestinationFinalize(gif); precondition(ok)
print("Replaced ONLY rap cells 36...95; 12 front-facing poses, 24 playback frames per 2-second core loop.")
