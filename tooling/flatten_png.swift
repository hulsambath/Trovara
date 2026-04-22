import AppKit

func parseHexColor(_ hex: String) -> NSColor? {
  var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  if s.hasPrefix("#") { s.removeFirst() }
  guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
  let r = CGFloat((v >> 16) & 0xFF) / 255.0
  let g = CGFloat((v >> 8) & 0xFF) / 255.0
  let b = CGFloat(v & 0xFF) / 255.0
  return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
}

func fail(_ message: String) -> Never {
  fputs("error: \(message)\n", stderr)
  exit(1)
}

let args = CommandLine.arguments
guard args.count == 4 else {
  fail("usage: flatten_png <input.png> <output.png> <#RRGGBB>")
}

let inputPath = args[1]
let outputPath = args[2]
let hex = args[3]

guard let bg = parseHexColor(hex) else {
  fail("invalid color: \(hex)")
}

guard let img = NSImage(contentsOfFile: inputPath) else {
  fail("failed to read image: \(inputPath)")
}

var rect = NSRect(origin: .zero, size: img.size)
guard let cg = img.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
  fail("failed to decode image: \(inputPath)")
}

let w = cg.width
let h = cg.height
let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
// App icons must be fully opaque; ensure output has no alpha channel.
let alphaInfo = CGImageAlphaInfo.noneSkipLast
let bmpInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: alphaInfo.rawValue))
guard let ctx = CGContext(
  data: nil,
  width: w,
  height: h,
  bitsPerComponent: 8,
  bytesPerRow: 0,
  space: cs,
  bitmapInfo: bmpInfo.rawValue
) else {
  fail("failed to create CGContext")
}

ctx.setFillColor(bg.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

guard let outCg = ctx.makeImage() else {
  fail("failed to render output image")
}

let rep = NSBitmapImageRep(cgImage: outCg)
guard let pngData = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
  fail("failed to encode PNG")
}

do {
  try pngData.write(to: URL(fileURLWithPath: outputPath), options: Data.WritingOptions.atomic)
} catch {
  fail("failed to write output: \(outputPath) (\(error))")
}
