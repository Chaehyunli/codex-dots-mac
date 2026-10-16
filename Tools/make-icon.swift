import Foundation
let png = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
func be(_ n: Int) -> Data { var v = UInt32(n).bigEndian; return withUnsafeBytes(of: &v) { Data($0) } }
var bytes = Data("icns".utf8)
bytes.append(be(png.count + 16))
bytes.append(Data("ic08".utf8))
bytes.append(be(png.count + 8))
bytes.append(png)
try bytes.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
