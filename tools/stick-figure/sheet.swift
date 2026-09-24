import AppKit
let args = CommandLine.arguments
let files = Array(args[2...])
let imgs = files.compactMap { NSImage(contentsOfFile: $0) }
let cols = min(4, imgs.count), rows = (imgs.count + cols - 1) / cols
let w: CGFloat = 300, h = w * imgs[0].size.height / imgs[0].size.width
let out = NSImage(size: NSSize(width: w * CGFloat(cols), height: h * CGFloat(rows)))
out.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: out.size.width, height: out.size.height).fill()
for (i, im) in imgs.enumerated() {
    im.draw(in: NSRect(x: CGFloat(i % cols) * w, y: CGFloat(rows - 1 - i / cols) * h, width: w, height: h))
}
out.unlockFocus()
let rep = NSBitmapImageRep(data: out.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
