import Cocoa

// 导入我们在 main.swift 里的辅助函数和样式
func formatSpeedAdaptive(_ bytesPerSec: Int) -> String {
    if bytesPerSec < 1024 {
        return "\(bytesPerSec) B/s"
    } else if bytesPerSec < 1024 * 1024 {
        let kb = Double(bytesPerSec) / 1024.0
        return String(format: "%.1f KB/s", kb)
    } else {
        let mb = Double(bytesPerSec) / (1024.0 * 1024.0)
        return String(format: "%.2f MB/s", mb)
    }
}

func formatTotalBytes(_ bytes: Int64) -> String {
    if bytes < 1024 * 1024 {
        return String(format: "%.1f KB", Double(bytes) / 1024.0)
    } else if bytes < 1024 * 1024 * 1024 {
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    } else {
        return String(format: "%.2f GB", Double(bytes) / (1024.0 * 1024.0 * 1024.0))
    }
}

// 目标图片尺寸 (1x: 340 x 520, 2x Retina: 680 x 1040)
let scale: CGFloat = 2.0
let widthPt: CGFloat = 350
let heightPt: CGFloat = 530
let pixelSize = NSSize(width: widthPt * scale, height: heightPt * scale)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pixelSize.width),
    pixelsHigh: Int(pixelSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
cg.scaleBy(x: scale, y: scale)

// 1. 背景渐变 (现代 macOS 桌面壁纸意境微光)
let bgColors = [
    NSColor(srgbRed: 0.10, green: 0.12, blue: 0.18, alpha: 1.0).cgColor,
    NSColor(srgbRed: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor
] as CFArray
if let bgGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 1.0]) {
    cg.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: heightPt), end: CGPoint(x: 0, y: 0), options: [])
}

// 装饰性环境柔光
let auraColor = NSColor(srgbRed: 0.20, green: 0.45, blue: 0.80, alpha: 0.22).cgColor
let auraColors = [auraColor, NSColor.clear.cgColor] as CFArray
if let auraGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: auraColors, locations: [0.0, 1.0]) {
    cg.drawRadialGradient(auraGrad, startCenter: CGPoint(x: 100, y: heightPt - 40), startRadius: 10, endCenter: CGPoint(x: 100, y: heightPt - 40), endRadius: 260, options: .drawsAfterEndLocation)
}

// 2. 顶部原生 macOS 菜单栏
let barHeight: CGFloat = 34
let barRect = NSRect(x: 0, y: heightPt - barHeight, width: widthPt, height: barHeight)
NSColor(white: 1.0, alpha: 0.08).setFill()
barRect.fill()

let barLine = NSBezierPath()
barLine.move(to: NSPoint(x: 0, y: heightPt - barHeight))
barLine.line(to: NSPoint(x: widthPt, y: heightPt - barHeight))
NSColor(white: 1.0, alpha: 0.15).setStroke()
barLine.lineWidth = 0.5
barLine.stroke()

// 菜单栏图标项激活态药丸胶囊
let itemW: CGFloat = 118
let itemH: CGFloat = 24
let itemX: CGFloat = 20
let itemY: CGFloat = heightPt - barHeight + 5
let itemPill = NSBezierPath(roundedRect: NSRect(x: itemX, y: itemY, width: itemW, height: itemH), xRadius: 5, yRadius: 5)
NSColor(white: 1.0, alpha: 0.18).setFill()
itemPill.fill()

// 状态小圆点 (Apple 原生温润绿)
let dotCX: CGFloat = itemX + 14
let dotCY: CGFloat = itemY + itemH / 2
let dotRadius: CGFloat = 4.2
let greenBase = NSColor(srgbRed: 0.19, green: 0.82, blue: 0.35, alpha: 1.0)
let greenGlow = NSColor(srgbRed: 0.19, green: 0.82, blue: 0.35, alpha: 0.4)

// 呼吸发光
let gColors = [greenGlow.cgColor, greenGlow.withAlphaComponent(0).cgColor] as CFArray
if let gg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gColors, locations: [0.0, 1.0]) {
    cg.drawRadialGradient(gg, startCenter: CGPoint(x: dotCX, y: dotCY), startRadius: 0.5, endCenter: CGPoint(x: dotCX, y: dotCY), endRadius: 7.0, options: .drawsAfterEndLocation)
}
cg.setFillColor(NSColor(white: 0, alpha: 0.2).cgColor)
cg.fillEllipse(in: CGRect(x: dotCX - 4.8, y: dotCY - 4.8, width: 9.6, height: 9.6))

cg.saveGState()
cg.addEllipse(in: CGRect(x: dotCX - dotRadius, y: dotCY - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
cg.clip()
let cTop = greenBase.blended(withFraction: 0.3, of: .white)!.cgColor
let cBottom = greenBase.blended(withFraction: 0.2, of: .black)!.cgColor
let sc = [cTop, greenBase.cgColor, cBottom] as CFArray
if let sg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sc, locations: [0.0, 0.5, 1.0]) {
    cg.drawRadialGradient(sg, startCenter: CGPoint(x: dotCX, y: dotCY + 1), startRadius: 0.3, endCenter: CGPoint(x: dotCX, y: dotCY), endRadius: dotRadius, options: .drawsAfterEndLocation)
}
cg.restoreGState()

// 顶栏文字: 🇺🇸 0.47 MB/s
let topTitle = " 🇺🇸 0.47 MB/s"
let topAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor.white
]
(topTitle as NSString).draw(at: NSPoint(x: dotCX + 6, y: itemY + 4), withAttributes: topAttrs)

// 3. 弹出的 NSMenu 容器 (精细毛玻璃与投影)
let menuW: CGFloat = 286
let menuH: CGFloat = 368
let menuX: CGFloat = 20
let menuY: CGFloat = heightPt - barHeight - 10 - menuH

// 绘制拟真 macOS 窗口柔和投影
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor(white: 0, alpha: 0.55).cgColor)
let menuPath = NSBezierPath(roundedRect: NSRect(x: menuX, y: menuY, width: menuW, height: menuH), xRadius: 13, yRadius: 13)
NSColor(srgbRed: 0.16, green: 0.17, blue: 0.21, alpha: 0.94).setFill()
menuPath.fill()
cg.restoreGState()

// 菜单边框微光环
let menuBorder = NSColor(white: 1.0, alpha: 0.16)
menuBorder.setStroke()
menuPath.lineWidth = 0.5
menuPath.stroke()

// 4. 内部自定义状态卡片 (StatusCardView 渲染)
let cardW: CGFloat = menuW - 16
let cardH: CGFloat = 190
let cardX: CGFloat = menuX + 8
let cardY: CGFloat = menuY + menuH - cardH - 8

let cardPath = NSBezierPath(roundedRect: NSRect(x: cardX, y: cardY, width: cardW, height: cardH), xRadius: 11, yRadius: 11)
NSColor(white: 1.0, alpha: 0.065).setFill()
cardPath.fill()
let cardStroke = NSColor(white: 1.0, alpha: 0.12)
cardStroke.setStroke()
cardPath.lineWidth = 0.5
cardPath.stroke()

let innerLeft = cardX + 14
let innerRight = cardX + cardW - 14
let innerW = innerRight - innerLeft

// 卡片 Header: LED + "代理畅通" + "28ms · 极速"
let headerCY = cardY + cardH - 21
let cardDotCX = innerLeft + 5.5
let cardDotCY = headerCY

if let gg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gColors, locations: [0.0, 1.0]) {
    cg.drawRadialGradient(gg, startCenter: CGPoint(x: cardDotCX, y: cardDotCY), startRadius: 0.8, endCenter: CGPoint(x: cardDotCX, y: cardDotCY), endRadius: 8.5, options: .drawsAfterEndLocation)
}
cg.setFillColor(NSColor(white: 1.0, alpha: 0.14).cgColor)
cg.fillEllipse(in: CGRect(x: cardDotCX - 5.0, y: cardDotCY - 5.0, width: 10.0, height: 10.0))

cg.saveGState()
cg.addEllipse(in: CGRect(x: cardDotCX - 4.5, y: cardDotCY - 4.5, width: 9.0, height: 9.0))
cg.clip()
if let sg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sc, locations: [0.0, 0.5, 1.0]) {
    cg.drawRadialGradient(sg, startCenter: CGPoint(x: cardDotCX, y: cardDotCY + 1.1), startRadius: 0.3, endCenter: CGPoint(x: cardDotCX, y: cardDotCY), endRadius: 4.5, options: .drawsAfterEndLocation)
}
cg.restoreGState()

let cTitle = "代理畅通"
let cTitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13.5, weight: .semibold),
    .foregroundColor: NSColor.white
]
(cTitle as NSString).draw(at: NSPoint(x: innerLeft + 18, y: headerCY - 8), withAttributes: cTitleAttrs)

// 延迟药丸
let pillStr = "28ms · 极速"
let pillAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold),
    .foregroundColor: NSColor(srgbRed: 0.38, green: 0.92, blue: 0.58, alpha: 0.98)
]
let pSize = (pillStr as NSString).size(withAttributes: pillAttrs)
let pillW = pSize.width + 16, pillH = pSize.height + 7
let pillX = innerRight - pillW, pillY = headerCY - pillH / 2
NSColor.systemGreen.withAlphaComponent(0.20).setFill()
NSBezierPath(roundedRect: NSRect(x: pillX, y: pillY, width: pillW, height: pillH), xRadius: pillH / 2, yRadius: pillH / 2).fill()
(pillStr as NSString).draw(at: NSPoint(x: pillX + 8, y: pillY + 3.5), withAttributes: pillAttrs)

// 分隔线
let cDiv = NSBezierPath()
cDiv.move(to: NSPoint(x: innerLeft, y: cardY + cardH - 41))
cDiv.line(to: NSPoint(x: innerRight, y: cardY + cardH - 41))
NSColor(white: 1.0, alpha: 0.09).setStroke()
cDiv.lineWidth = 0.5
cDiv.stroke()

// 三行键值对
func drawCardRow(y: CGFloat, label: String, val: String, valColor: NSColor) {
    let lAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
        .foregroundColor: NSColor(white: 1.0, alpha: 0.48)
    ]
    (label as NSString).draw(at: NSPoint(x: innerLeft, y: y), withAttributes: lAttrs)

    let para = NSMutableParagraphStyle()
    para.alignment = .right
    let vAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium),
        .foregroundColor: valColor,
        .paragraphStyle: para
    ]
    (val as NSString).draw(in: NSRect(x: innerLeft + 40, y: y, width: innerW - 40, height: 16), withAttributes: vAttrs)
}

let vWhite = NSColor(white: 1.0, alpha: 0.90)
let vMuted = NSColor(white: 1.0, alpha: 0.65)
drawCardRow(y: cardY + cardH - 64, label: "地区", val: "🇺🇸 美国 · 141.98.41.73", valColor: vWhite)
drawCardRow(y: cardY + cardH - 84, label: "节点", val: "DIRECT", valColor: vWhite)
drawCardRow(y: cardY + cardH - 104, label: "端口", val: "7897 · 每 1s 检测", valColor: vMuted)

// 底部双数据块
let tileGap: CGFloat = 8
let tileW = (innerW - tileGap) / 2
let tileH: CGFloat = 50
let tileY = cardY + 11

func drawTile(x: CGFloat, arrow: String, speed: String, total: String, arrowColor: NSColor) {
    let tPath = NSBezierPath(roundedRect: NSRect(x: x, y: tileY, width: tileW, height: tileH), xRadius: 8, yRadius: 8)
    NSColor(white: 1.0, alpha: 0.05).setFill()
    tPath.fill()
    NSColor(white: 1.0, alpha: 0.08).setStroke()
    tPath.lineWidth = 0.5
    tPath.stroke()

    let aAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11.5, weight: .bold), .foregroundColor: arrowColor]
    let sAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .semibold), .foregroundColor: vWhite]
    let s = NSMutableAttributedString(string: "\(arrow) ", attributes: aAttrs)
    s.append(NSAttributedString(string: speed, attributes: sAttrs))
    s.draw(at: NSPoint(x: x + 10, y: tileY + 26))

    let totAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 10.0, weight: .regular), .foregroundColor: NSColor(white: 1.0, alpha: 0.5)]
    ("累计 \(total)" as NSString).draw(at: NSPoint(x: x + 10, y: tileY + 9), withAttributes: totAttrs)
}

let upColor = NSColor(srgbRed: 1.0, green: 0.64, blue: 0.26, alpha: 0.95)
let dnColor = NSColor(srgbRed: 0.36, green: 0.74, blue: 1.0, alpha: 0.95)
drawTile(x: innerLeft, arrow: "↑", speed: "128.4 KB/s", total: "1.19 GB", arrowColor: upColor)
drawTile(x: innerLeft + tileW + tileGap, arrow: "↓", speed: "3.42 MB/s", total: "5.49 GB", arrowColor: dnColor)

// 5. 菜单项渲染 (紧凑优雅)
var currentMenuY = cardY - 6

func drawMenuSep(y: CGFloat) {
    let sep = NSBezierPath()
    sep.move(to: NSPoint(x: menuX + 12, y: y))
    sep.line(to: NSPoint(x: menuX + menuW - 12, y: y))
    NSColor(white: 1.0, alpha: 0.10).setStroke()
    sep.lineWidth = 0.5
    sep.stroke()
}

func drawMenuItemRow(y: CGFloat, symbol: String, title: String, shortcut: String? = nil, hasSubmenu: Bool = false) {
    let rowH: CGFloat = 27
    let rowY = y - rowH

    // 图标 (SF Symbol)
    if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
        let conf = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .medium)
        if let tinted = img.withSymbolConfiguration(conf) {
            let imgR = NSRect(x: menuX + 16, y: rowY + 5.5, width: 16, height: 16)
            tinted.draw(in: imgR, from: .zero, operation: .sourceOver, fraction: 0.88)
        }
    }

    // 标题
    let tAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12.5, weight: .regular),
        .foregroundColor: NSColor(white: 1.0, alpha: 0.92)
    ]
    (title as NSString).draw(at: NSPoint(x: menuX + 38, y: rowY + 6), withAttributes: tAttrs)

    // 快捷键或右箭头
    if let sc = shortcut {
        let scAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.40)
        ]
        let para = NSMutableParagraphStyle()
        para.alignment = .right
        var full = scAttrs
        full[.paragraphStyle] = para
        (sc as NSString).draw(in: NSRect(x: menuX + menuW - 60, y: rowY + 6, width: 44, height: 16), withAttributes: full)
    } else if hasSubmenu {
        let arrowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.35)
        ]
        let para = NSMutableParagraphStyle()
        para.alignment = .right
        var full = arrowAttrs
        full[.paragraphStyle] = para
        ("›" as NSString).draw(in: NSRect(x: menuX + menuW - 36, y: rowY + 6, width: 20, height: 16), withAttributes: full)
    }
}

// 分隔线 1
drawMenuSep(y: currentMenuY)
currentMenuY -= 4

// 菜单项: 立即刷新状态
drawMenuItemRow(y: currentMenuY, symbol: "arrow.clockwise", title: "立即刷新状态", shortcut: "⌘R")
currentMenuY -= 27

// 菜单项: 复制连接信息
drawMenuItemRow(y: currentMenuY, symbol: "doc.on.doc", title: "复制连接信息")
currentMenuY -= 27

// 分隔线 2
currentMenuY -= 3
drawMenuSep(y: currentMenuY)
currentMenuY -= 4

// 菜单项: 偏好设置 ›
drawMenuItemRow(y: currentMenuY, symbol: "slider.horizontal.3", title: "偏好设置", hasSubmenu: true)
currentMenuY -= 27

// 分隔线 3
currentMenuY -= 3
drawMenuSep(y: currentMenuY)
currentMenuY -= 4

// 菜单项: 退出 VPN监控
drawMenuItemRow(y: currentMenuY, symbol: "power", title: "退出 VPN监控", shortcut: "⌘Q")

NSGraphicsContext.restoreGraphicsState()

// 保存为 PNG 文件
if let pngData = rep.representation(using: .png, properties: [:]) {
    let outPath = "/Users/yjy/.gemini/antigravity/scratch/proxy-guard/assets/preview.png"
    try! pngData.write(to: URL(fileURLWithPath: outPath))
    print("Successfully generated: \(outPath)")
}
