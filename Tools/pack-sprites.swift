import AppKit
import ImageIO
import UniformTypeIdentifiers

// Mechanical extraction, alignment and atlas packaging only; artwork is ImageGen.
let input = URL(fileURLWithPath:CommandLine.arguments[1])
let out = URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
let source = CGImageSourceCreateWithURL(input as CFURL,nil)!
let sheet = CGImageSourceCreateImageAtIndex(source,0,nil)!
let colorSpace = CGColorSpaceCreateDeviceRGB()
var pixels = [UInt8](repeating:0,count:sheet.width*sheet.height*4)
pixels.withUnsafeMutableBytes { buffer in
    let context = CGContext(data:buffer.baseAddress,width:sheet.width,height:sheet.height,bitsPerComponent:8,bytesPerRow:sheet.width*4,space:colorSpace,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(sheet,in:CGRect(x:0,y:0,width:sheet.width,height:sheet.height))
}
var visited = [Bool](repeating:false,count:sheet.width*sheet.height)
var components: [(CGRect,Int)] = []
for seed in visited.indices {
    if visited[seed] || pixels[seed*4+3] <= 100 { continue }
    visited[seed] = true
    var queue = [seed], head = 0
    var x0 = seed%sheet.width, x1 = x0, y0 = seed/sheet.width, y1 = y0
    while head < queue.count {
        let p = queue[head]; head += 1
        let x = p%sheet.width, y = p/sheet.width
        x0 = min(x0,x); x1 = max(x1,x); y0 = min(y0,y); y1 = max(y1,y)
        for dy in -1...1 { for dx in -1...1 {
            let nx = x+dx, ny = y+dy
            if nx < 0 || ny < 0 || nx >= sheet.width || ny >= sheet.height { continue }
            let n = ny*sheet.width+nx
            if !visited[n] && pixels[n*4+3] > 100 { visited[n] = true; queue.append(n) }
        }}
    }
    if queue.count > 600 { components.append((CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1),queue.count)) }
}
components = Array(components.sorted { $0.1 > $1.1 }.prefix(64)).sorted { $0.0.midY < $1.0.midY }
guard components.count == 64 else { fatalError("Expected 64 isolated bodies, found \(components.count)") }
var boxes: [CGRect] = []
for row in 0..<8 { boxes += components[(row*8)..<(row*8+8)].map { $0.0 }.sorted { $0.midX < $1.midX } }
let normalHeight = boxes.prefix(8).map { $0.height }.sorted()[4]
let unit = normalHeight*1.05
var keys: [CGImage] = []
for index in 0..<64 {
    let crop = boxes[index].insetBy(dx:-1,dy:-1).intersection(CGRect(x:0,y:0,width:sheet.width,height:sheet.height))
    let cell = sheet.cropping(to:crop)!
    var bytes = [UInt8](repeating:0,count:cell.width*cell.height*4)
    bytes.withUnsafeMutableBytes { buffer in
        let c = CGContext(data:buffer.baseAddress,width:cell.width,height:cell.height,bitsPerComponent:8,bytesPerRow:cell.width*4,space:colorSpace,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(cell,in:CGRect(x:0,y:0,width:cell.width,height:cell.height))
    }
    var minX = cell.width, minY = cell.height, maxX = 0, maxY = 0
    for yy in 0..<cell.height { for xx in 0..<cell.width {
        if bytes[(yy*cell.width+xx)*4+3] > 100 {
            minX = min(minX,xx); minY = min(minY,yy); maxX = max(maxX,xx); maxY = max(maxY,yy)
        }
    }}
    let normalized = CGContext(data:nil,width:256,height:256,bitsPerComponent:8,bytesPerRow:256*4,space:colorSpace,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    normalized.interpolationQuality = .high
    let boundWidth = Double(maxX-minX+1), boundHeight = Double(maxY-minY+1)
    let scale = min(216/unit,220/max(boundWidth,boundHeight))
    // All original cell pixels remain; only geometry is aligned to a common baseline.
    let w = Double(cell.width)*scale, h = Double(cell.height)*scale
    let dx = 128-(Double(minX)+boundWidth/2)*scale
    let dy: Double
    if index/8 == 4 {
        dy = 128-(Double(cell.height-1-maxY)+boundHeight/2)*scale
    } else {
        dy = 32-Double(cell.height-1-maxY)*scale
    }
    normalized.draw(cell,in:CGRect(x:dx,y:dy,width:w,height:h))
    keys.append(normalized.makeImage()!)
}

func repeatFrames(_ frames:[Int],_ times:Int) -> [Int] { frames.flatMap { Array(repeating:$0,count:times) } }
var mapping = Array(repeating:0,count:160)
func place(_ start:Int,_ frames:[Int]) { for (n,f) in frames.enumerated() { mapping[start+n] = f } }
place(0,[0,1,0,2,0,3,0,4])
place(8,Array(8...15)); place(16,Array(8...15))
place(24,[0,3,4,56,57,8]); place(30,[56,57,58,58,59,0])
let intro = [0,0,16,16,17,17]
// Approved original frontal poses only: no turntable/back view in the rap loop.
let core = repeatFrames([17,18,19,20,21,20,17,18,19,20,21,20,17,18,19,20,21,20,17,18,19,20,21,20],2)
let outro = [23,22,17,17,0,0]
place(36,intro+core+outro)
place(96,[40,41,42,40,43,41,40,0])
place(104,[44,45,46,47,45,46])
place(110,[60,60,61,62,63,0])
// Rest/get-up reuse the original neutral/blink artwork. Swift rotates the
// unchanged sprite smoothly; no new ear/face drawing and no prone sleep art.
place(116,[0,0,0,0,2,0,0,0])
place(124,[0,0,0,0,0,0])
place(130,[3,3,0,0,4,4])
place(136,[16,16,32,32]+repeatFrames(Array(32...39),2)+[39,39,17,0])
let width = 12*256, height = 14*256
let atlas = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:colorSpace,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
for index in mapping.indices {
    let rect = CGRect(x:(index%12)*256,y:height-(index/12+1)*256,width:256,height:256)
    atlas.saveGState()
    if (16...23).contains(index) {
        atlas.translateBy(x:rect.maxX,y:rect.minY); atlas.scaleBy(x:-1,y:1)
        atlas.draw(keys[mapping[index]],in:CGRect(x:0,y:0,width:256,height:256))
    } else { atlas.draw(keys[mapping[index]],in:rect) }
    atlas.restoreGState()
}
func save(_ image:CGImage,_ url:URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(dest,image,nil)
    let success = CGImageDestinationFinalize(dest)
    precondition(success,"PNG export failed")
}
save(atlas.makeImage()!,out.appendingPathComponent("spritesheet.png"))
save(keys[0],out.appendingPathComponent("icon.png"))

let preview = CGContext(data:nil,width:12*128,height:14*128,bitsPerComponent:8,bytesPerRow:12*128*4,space:colorSpace,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
preview.setFillColor(NSColor(calibratedRed:0.94,green:0.93,blue:0.89,alpha:1).cgColor)
preview.fill(CGRect(x:0,y:0,width:12*128,height:14*128))
preview.draw(atlas.makeImage()!,in:CGRect(x:0,y:0,width:12*128,height:14*128))
save(preview.makeImage()!,out.appendingPathComponent("atlas-preview.png"))
print("Packed 160 playback frames from 64 generated key poses into 3072x3584. Left run is mirrored; repeated timing frames are intentional.")
