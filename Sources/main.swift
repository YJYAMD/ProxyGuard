import Cocoa
import Foundation
import SystemConfiguration

// ──────────────────────────────────────────────
// MARK: - Indicator Style & Speed Format Enums
// ──────────────────────────────────────────────
enum IndicatorStyle: Int {
    case glowSphere = 0     // 🔮 霓虹晶体呼吸灯
    case capsule = 1        // 💊 灵动高科技胶囊
    case precisionRing = 2  // 🎯 精密极客光环
    case minimalGem = 3     // 💎 微光珠宝圆点
}

enum SpeedFormat: Int {
    case mbs = 0            // 0.00 MB/s (默认，精确 MB/s)
    case mbsCompact = 1     // 0.00 M/s
    case adaptive = 2       // 动态自适应 (KB/s · MB/s)
}

enum SpeedMetric: Int {
    case total = 0          // 上行 + 下行 (总速率)
    case download = 1       // 仅下载速率
}

// ──────────────────────────────────────────────
// MARK: - Country & Flag Helpers
// ──────────────────────────────────────────────
func countryInfo(from code: String) -> (flag: String, name: String) {
    let mapping: [String: String] = [
        "US": "美国", "JP": "日本", "HK": "中国香港", "TW": "中国台湾",
        "SG": "新加坡", "KR": "韩国", "GB": "英国", "DE": "德国",
        "CA": "加拿大", "AU": "澳大利亚", "FR": "法国", "MY": "马来西亚",
        "RU": "俄罗斯", "IN": "印度", "TH": "泰国", "VN": "越南",
        "NL": "荷兰", "CH": "瑞士", "SE": "瑞典", "IT": "意大利",
        "ES": "西班牙", "BR": "巴西", "AR": "阿根廷", "TR": "土耳其",
        "CN": "中国大陆"
    ]
    let upper = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let name = mapping[upper] ?? (upper.isEmpty ? "未知国家" : upper)
    let flag = flagEmoji(for: upper)
    return (flag, name)
}

func flagEmoji(for countryCode: String) -> String {
    let base: UInt32 = 127397
    var s = ""
    for v in countryCode.uppercased().unicodeScalars {
        if v.value >= 65 && v.value <= 90 {
            if let scalar = UnicodeScalar(base + v.value) {
                s.append(String(scalar))
            }
        }
    }
    return s.isEmpty ? "🌐" : s
}

// ──────────────────────────────────────────────
// MARK: - Traffic Monitor (mihomo Unix Socket API)
// ──────────────────────────────────────────────
class TrafficMonitor {
    var upBytesPerSec: Int = 0
    var downBytesPerSec: Int = 0
    var upTotal: Int64 = 0
    var downTotal: Int64 = 0
    var isRunning: Bool = false

    private var process: Process?
    private var pipe: Pipe?
    private var buffer: Data = Data()
    var onUpdate: ((Int, Int, Int64, Int64) -> Void)?

    let socketPath = "/tmp/verge/verge-mihomo.sock"

    func start() {
        guard !isRunning else { return }
        isRunning = true
        launchCurl()
    }

    func stop() {
        isRunning = false
        process?.terminate()
        process = nil
    }

    private func launchCurl() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        proc.arguments = ["--unix-socket", socketPath, "http://localhost/traffic", "-s", "-N"]

        let p = Pipe()
        proc.standardOutput = p
        proc.standardError = FileHandle.nullDevice

        p.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            self.buffer.append(data)
            self.processBuffer()
        }

        proc.terminationHandler = { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.launchCurl()
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.pipe = p
        } catch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.launchCurl()
            }
        }
    }

    private func processBuffer() {
        guard let str = String(data: buffer, encoding: .utf8) else { return }
        let lines = str.components(separatedBy: "\n")

        if str.hasSuffix("\n") {
            buffer = Data()
        } else {
            buffer = lines.last?.data(using: .utf8) ?? Data()
        }

        let completeLines = str.hasSuffix("\n") ? lines : Array(lines.dropLast())

        for line in completeLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let up = json["up"] as? Int ?? 0
            let down = json["down"] as? Int ?? 0
            let uT = json["upTotal"] as? Int64 ?? (json["upTotal"] as? Int).map { Int64($0) } ?? 0
            let dT = json["downTotal"] as? Int64 ?? (json["downTotal"] as? Int).map { Int64($0) } ?? 0

            DispatchQueue.main.async { [weak self] in
                self?.upBytesPerSec = up
                self?.downBytesPerSec = down
                self?.upTotal = uT
                self?.downTotal = dT
                self?.onUpdate?(up, down, uT, dT)
            }
        }
    }
}

// ──────────────────────────────────────────────
// MARK: - Format Helpers
// ──────────────────────────────────────────────
func formatSpeedInMBs(_ bytesPerSec: Int) -> String {
    let mb = Double(bytesPerSec) / (1024.0 * 1024.0)
    if mb < 10.0 {
        return String(format: "%.2f MB/s", mb)
    } else if mb < 100.0 {
        return String(format: "%.1f MB/s", mb)
    } else {
        return String(format: "%.0f MB/s", mb)
    }
}

func formatSpeedInMbsCompact(_ bytesPerSec: Int) -> String {
    let mb = Double(bytesPerSec) / (1024.0 * 1024.0)
    if mb < 10.0 {
        return String(format: "%.2f M/s", mb)
    } else if mb < 100.0 {
        return String(format: "%.1f M/s", mb)
    } else {
        return String(format: "%.0f M/s", mb)
    }
}

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

func formatSpeedForDisplay(_ bytesPerSec: Int, format: SpeedFormat) -> String {
    switch format {
    case .mbs:
        return formatSpeedInMBs(bytesPerSec)
    case .mbsCompact:
        return formatSpeedInMbsCompact(bytesPerSec)
    case .adaptive:
        return formatSpeedAdaptive(bytesPerSec)
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

// ──────────────────────────────────────────────
// MARK: - Custom Status Card Header View
// ──────────────────────────────────────────────
class StatusCardView: NSView {
    var connected: Bool = true
    var latencyMs: Int = 0
    var errorText: String = ""
    var proxyHost: String = "127.0.0.1"
    var proxyPort: Int = 7897
    var lastCheckStr: String = "--:--:--"
    var checkIntervalSec: Int = 1

    // Country & Node info
    var countryFlag: String = ""
    var countryName: String = ""
    var exitIP: String = ""
    var nodeName: String = ""

    // Traffic data
    var upSpeed: Int = 0
    var downSpeed: Int = 0
    var upTotal: Int64 = 0
    var downTotal: Int64 = 0

    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 186

    override var intrinsicContentSize: NSSize {
        return NSSize(width: cardWidth, height: cardHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // ── Card Container ──
        let cardRect = NSRect(x: 10, y: 6, width: cardWidth - 20, height: cardHeight - 12)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 12, yRadius: 12)

        if isDark {
            NSColor(white: 1.0, alpha: 0.07).setFill()
        } else {
            NSColor(white: 0.0, alpha: 0.04).setFill()
        }
        cardPath.fill()

        let strokeColor = isDark ? NSColor(white: 1.0, alpha: 0.12) : NSColor(white: 0.0, alpha: 0.08)
        strokeColor.setStroke()
        cardPath.lineWidth = 0.5
        cardPath.stroke()

        // ── Left Accent Strip ──
        let accentColor = connected
            ? NSColor(srgbRed: 0.05, green: 0.88, blue: 0.52, alpha: 1.0)
            : NSColor(srgbRed: 1.00, green: 0.22, blue: 0.38, alpha: 1.0)

        let stripRect = NSRect(x: 10, y: 6, width: 4, height: cardHeight - 12)
        let stripPath = NSBezierPath(roundedRect: stripRect, xRadius: 2, yRadius: 2)
        accentColor.setFill()
        stripPath.fill()

        // ── Status Dot ──
        let dotCX: CGFloat = 34
        let dotCY: CGFloat = cardHeight - 34

        let glowColor = accentColor.withAlphaComponent(connected ? 0.40 : 0.50)
        let glowColors = [glowColor.cgColor, glowColor.withAlphaComponent(0.0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: dotCX, y: dotCY), startRadius: 1.5, endCenter: CGPoint(x: dotCX, y: dotCY), endRadius: 10.0, options: .drawsAfterEndLocation)
        }
        ctx.setFillColor(NSColor(white: 0.0, alpha: 0.15).cgColor)
        ctx.fillEllipse(in: CGRect(x: dotCX - 5.5, y: dotCY - 5.5, width: 11.0, height: 11.0))

        let dotR = CGRect(x: dotCX - 5.0, y: dotCY - 5.0, width: 10.0, height: 10.0)
        ctx.saveGState()
        ctx.addEllipse(in: dotR)
        ctx.clip()
        let cc = [accentColor.blended(withFraction: 0.40, of: .white)!.cgColor, accentColor.cgColor, accentColor.blended(withFraction: 0.28, of: .black)!.cgColor] as CFArray
        if let cg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cc, locations: [0.0, 0.45, 1.0]) {
            ctx.drawLinearGradient(cg, start: CGPoint(x: dotCX, y: dotCY + 5), end: CGPoint(x: dotCX, y: dotCY - 5), options: [])
        }
        ctx.restoreGState()

        ctx.setFillColor(NSColor(white: 1.0, alpha: 0.70).cgColor)
        ctx.fillEllipse(in: CGRect(x: dotCX - 2.8, y: dotCY + 1.0, width: 5.6, height: 2.6))

        // ── Title ──
        let titleStr = connected ? "代理连接畅通" : "代理连接已断开"
        let titleColor = connected
            ? (isDark ? NSColor(srgbRed: 0.35, green: 1.0, blue: 0.65, alpha: 1.0) : NSColor(srgbRed: 0.02, green: 0.65, blue: 0.38, alpha: 1.0))
            : (isDark ? NSColor(srgbRed: 1.0, green: 0.48, blue: 0.48, alpha: 1.0) : NSColor(srgbRed: 0.90, green: 0.15, blue: 0.22, alpha: 1.0))
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: titleColor]
        (titleStr as NSString).draw(at: NSPoint(x: 48, y: cardHeight - 38), withAttributes: titleAttrs)

        // ── Right-side KPI Pill ──
        if connected {
            let tier: String
            let pillBg: NSColor
            let pillFg: NSColor
            if latencyMs < 80 {
                tier = "极速"; pillBg = NSColor(srgbRed: 0.05, green: 0.88, blue: 0.52, alpha: isDark ? 0.20 : 0.16)
                pillFg = isDark ? NSColor(srgbRed: 0.40, green: 1.0, blue: 0.68, alpha: 0.95) : NSColor(srgbRed: 0.02, green: 0.65, blue: 0.36, alpha: 0.95)
            } else if latencyMs < 200 {
                tier = "良好"; pillBg = NSColor(srgbRed: 0.0, green: 0.70, blue: 1.0, alpha: isDark ? 0.20 : 0.16)
                pillFg = isDark ? NSColor(srgbRed: 0.35, green: 0.80, blue: 1.0, alpha: 0.95) : NSColor(srgbRed: 0.0, green: 0.50, blue: 0.85, alpha: 0.95)
            } else {
                tier = "偏高"; pillBg = NSColor(srgbRed: 1.0, green: 0.70, blue: 0.0, alpha: isDark ? 0.20 : 0.16)
                pillFg = isDark ? NSColor(srgbRed: 1.0, green: 0.80, blue: 0.25, alpha: 0.95) : NSColor(srgbRed: 0.80, green: 0.55, blue: 0.0, alpha: 0.95)
            }
            let pillText = "\(latencyMs)ms · \(tier)"
            let pillAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold), .foregroundColor: pillFg]
            let pillSize = (pillText as NSString).size(withAttributes: pillAttrs)
            let pH: CGFloat = 8, pV: CGFloat = 4
            let pW = pillSize.width + pH * 2, pHt = pillSize.height + pV * 2
            let pX = cardRect.maxX - pW - 8, pY = cardHeight - 44
            NSBezierPath(roundedRect: NSRect(x: pX, y: pY, width: pW, height: pHt), xRadius: pHt / 2, yRadius: pHt / 2).fill(with: pillBg)
            (pillText as NSString).draw(at: NSPoint(x: pX + pH, y: pY + pV), withAttributes: pillAttrs)
        } else {
            let wBg = isDark ? NSColor(srgbRed: 1.0, green: 0.22, blue: 0.38, alpha: 0.22) : NSColor(srgbRed: 1.0, green: 0.22, blue: 0.38, alpha: 0.16)
            let wFg = isDark ? NSColor(srgbRed: 1.0, green: 0.45, blue: 0.50, alpha: 0.95) : NSColor(srgbRed: 0.90, green: 0.15, blue: 0.22, alpha: 0.95)
            let wText = "已断开"
            let wAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: wFg]
            let wSize = (wText as NSString).size(withAttributes: wAttrs)
            let wPH: CGFloat = 8, wPV: CGFloat = 4
            let wW = wSize.width + wPH * 2, wH = wSize.height + wPV * 2
            let wX = cardRect.maxX - wW - 8, wY = cardHeight - 44
            NSBezierPath(roundedRect: NSRect(x: wX, y: wY, width: wW, height: wH), xRadius: wH / 2, yRadius: wH / 2).fill(with: wBg)
            (wText as NSString).draw(at: NSPoint(x: wX + wPH, y: wY + wPV), withAttributes: wAttrs)
        }

        // ── Detail Rows (Structured Information) ──
        let detailColor = isDark ? NSColor(white: 1.0, alpha: 0.65) : NSColor(white: 0.0, alpha: 0.60)
        let monoAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: detailColor]

        let row1Y: CGFloat = cardHeight - 56
        let row2Y: CGFloat = cardHeight - 72
        let row3Y: CGFloat = cardHeight - 88
        let row4Y: CGFloat = cardHeight - 104

        // Row 1: 国家与地区
        let flag = countryFlag.isEmpty ? "🌐" : countryFlag
        let name = countryName.isEmpty ? "正在识别国家..." : countryName
        let ipSuffix = exitIP.isEmpty ? "" : " · \(exitIP)"
        let countryLine = "地区  \(flag) \(name)\(ipSuffix)"
        (countryLine as NSString).draw(at: NSPoint(x: 24, y: row1Y), withAttributes: monoAttrs)

        // Row 2: 节点名称
        let nodeDisplay = nodeName.isEmpty ? "\(proxyHost):\(proxyPort)" : nodeName
        let nodeLine = "节点  \(nodeDisplay)"
        (nodeLine as NSString).draw(at: NSPoint(x: 24, y: row2Y), withAttributes: monoAttrs)

        // Row 3: 延迟与端口
        let latLabel = connected ? "延迟  \(latencyMs) ms  ·  端口 \(proxyPort)" : "延迟  超时  ·  端口 \(proxyPort)"
        (latLabel as NSString).draw(at: NSPoint(x: 24, y: row3Y), withAttributes: monoAttrs)

        // Row 4: 上次检测时间
        let timeLabel = "检测  \(lastCheckStr)  ·  每 \(checkIntervalSec)s"
        (timeLabel as NSString).draw(at: NSPoint(x: 24, y: row4Y), withAttributes: monoAttrs)

        // ── Traffic Section (2 Clean, Non-overlapping Rows) ──
        let dividerY: CGFloat = cardHeight - 116
        let divPath = NSBezierPath()
        divPath.move(to: NSPoint(x: cardRect.minX + 8, y: dividerY))
        divPath.line(to: NSPoint(x: cardRect.maxX - 8, y: dividerY))
        (isDark ? NSColor(white: 1.0, alpha: 0.10) : NSColor(white: 0.0, alpha: 0.08)).setStroke()
        divPath.lineWidth = 0.5
        divPath.stroke()

        // Traffic Row 1: 实时速率
        let speedRowY: CGFloat = cardHeight - 134
        let upArrowColor = NSColor(srgbRed: 1.0, green: 0.60, blue: 0.20, alpha: isDark ? 0.90 : 0.85)
        let upAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: upArrowColor]
        ("↑ " + formatSpeedAdaptive(upSpeed) as NSString).draw(at: NSPoint(x: 24, y: speedRowY), withAttributes: upAttrs)

        let dnArrowColor = NSColor(srgbRed: 0.30, green: 0.70, blue: 1.0, alpha: isDark ? 0.90 : 0.85)
        let dnAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: dnArrowColor]
        ("↓ " + formatSpeedAdaptive(downSpeed) as NSString).draw(at: NSPoint(x: 145, y: speedRowY), withAttributes: dnAttrs)

        // Traffic Row 2: 累计统计
        let totalRowY: CGFloat = cardHeight - 152
        let totalStr = "累计  ↑\(formatTotalBytes(upTotal))   ↓\(formatTotalBytes(downTotal))"
        let totalAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular), .foregroundColor: detailColor.withAlphaComponent(0.75)]
        (totalStr as NSString).draw(at: NSPoint(x: 24, y: totalRowY), withAttributes: totalAttrs)

        // ── Error detail ──
        if !connected && !errorText.isEmpty {
            let errColor = isDark ? NSColor(srgbRed: 1.0, green: 0.50, blue: 0.50, alpha: 0.85) : NSColor(srgbRed: 0.85, green: 0.15, blue: 0.15, alpha: 0.85)
            let errAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .regular), .foregroundColor: errColor]
            (errorText as NSString).draw(at: NSPoint(x: 24, y: 12), withAttributes: errAttrs)
        }
    }

    func update(connected: Bool, latency: Int, error: String, host: String, port: Int, checkTime: String, interval: Int,
                countryFlag: String, countryName: String, exitIP: String, nodeName: String,
                upSpeed: Int, downSpeed: Int, upTotal: Int64, downTotal: Int64) {
        self.connected = connected
        self.latencyMs = latency
        self.errorText = error
        self.proxyHost = host
        self.proxyPort = port
        self.lastCheckStr = checkTime
        self.checkIntervalSec = interval
        self.countryFlag = countryFlag
        self.countryName = countryName
        self.exitIP = exitIP
        self.nodeName = nodeName
        self.upSpeed = upSpeed
        self.downSpeed = downSpeed
        self.upTotal = upTotal
        self.downTotal = downTotal
        self.needsDisplay = true
    }
}

extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        self.fill()
    }
}

// ──────────────────────────────────────────────
// MARK: - Main App Delegate
// ──────────────────────────────────────────────
class ProxyMonitorApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var pulseTimer: Timer?
    var trafficMonitor = TrafficMonitor()

    // Status tracking
    var isConnected: Bool = true
    var consecutiveFailures: Int = 0
    var lastCheckTime: Date?
    var lastLatencyMs: Int = 0
    var lastErrorDetail: String = ""
    var checkInterval: TimeInterval = 1.0
    var isChecking: Bool = false
    var currentStyle: IndicatorStyle = .glowSphere
    var soundEnabled: Bool = true

    // Country & Node info
    var currentCountryFlag: String = ""
    var currentCountryName: String = ""
    var currentExitIP: String = ""
    var currentNodeName: String = ""
    var showFlagInMenuBar: Bool = true

    // Speed display options
    var speedFormat: SpeedFormat = .mbs
    var speedMetric: SpeedMetric = .total

    // Traffic data
    var currentUpSpeed: Int = 0
    var currentDownSpeed: Int = 0
    var totalUp: Int64 = 0
    var totalDown: Int64 = 0

    // Pulse animation state
    var pulsePhase: Int = 0

    // Cached icons
    var greenImage: NSImage!
    var redImageBright: NSImage!
    var redImageDim: NSImage!

    // Custom header
    var statusCardView: StatusCardView!
    var statusCardMenuItem: NSMenuItem!

    // Menu items
    var autoLaunchMenuItem: NSMenuItem!
    var soundMenuItem: NSMenuItem!
    var showFlagMenuItem: NSMenuItem!
    var speedFormatMenuItems: [NSMenuItem] = []
    var speedMetricMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        rebuildIcons()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "ProxyGuardStatusItem"

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.image = greenImage
            updateTrafficDisplay()
        }

        setupMenu()

        // Fetch active node name once on startup
        refreshActiveNodeName()

        // Start traffic monitor
        trafficMonitor.onUpdate = { [weak self] up, down, uT, dT in
            guard let self = self else { return }
            self.currentUpSpeed = up
            self.currentDownSpeed = down
            self.totalUp = uT
            self.totalDown = dT
            self.updateTrafficDisplay()
        }
        trafficMonitor.start()

        checkProxy(isRetry: false)
        scheduleTimer()
    }

    func updateTrafficDisplay() {
        guard let button = statusItem.button else { return }

        let bytesPerSec = (speedMetric == .total) ? (currentUpSpeed + currentDownSpeed) : currentDownSpeed
        let speedStr = formatSpeedForDisplay(bytesPerSec, format: speedFormat)

        let flagPart = (showFlagInMenuBar && !currentCountryFlag.isEmpty) ? "\(currentCountryFlag) " : ""
        let displayText = " \(flagPart)\(speedStr)"

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let speedColor = isDark ? NSColor(white: 1.0, alpha: 0.82) : NSColor(white: 0.0, alpha: 0.70)

        let attrStr = NSAttributedString(string: displayText, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.0, weight: .medium),
            .foregroundColor: speedColor,
            .baselineOffset: 0.5
        ])
        button.attributedTitle = attrStr

        // Detailed hover tooltip
        let flag = currentCountryFlag.isEmpty ? "🌐" : currentCountryFlag
        let name = currentCountryName.isEmpty ? "代理节点" : currentCountryName
        let ip = currentExitIP.isEmpty ? "" : " (\(currentExitIP))"
        let node = currentNodeName.isEmpty ? "" : "\n节点: \(currentNodeName)"
        let tipUp = formatSpeedAdaptive(currentUpSpeed)
        let tipDn = formatSpeedAdaptive(currentDownSpeed)
        let tipTotal = "↑\(formatTotalBytes(totalUp))  ↓\(formatTotalBytes(totalDown))"
        button.toolTip = "ProxyGuard · \(flag) \(name)\(ip)\(node)\n实时: ↑\(tipUp)  ↓\(tipDn)\n累计: \(tipTotal)"
    }

    // ── Active Node Fetcher from Mihomo API ──
    func refreshActiveNodeName() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            p.arguments = ["--unix-socket", "/tmp/verge/verge-mihomo.sock", "http://localhost/proxies/GLOBAL", "-s", "--max-time", "1"]
            let pipe = Pipe()
            p.standardOutput = pipe
            do {
                try p.run()
                p.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let now = json["now"] as? String {
                    DispatchQueue.main.async {
                        self?.currentNodeName = now
                        self?.updateTrafficDisplay()
                    }
                }
            } catch {}
        }
    }

    // ── Icon Rendering ──
    func rebuildIcons() {
        greenImage = renderIndicator(connected: true, style: currentStyle, dimmed: false)
        redImageBright = renderIndicator(connected: false, style: currentStyle, dimmed: false)
        redImageDim = renderIndicator(connected: false, style: currentStyle, dimmed: true)
    }

    func renderIndicator(connected: Bool, style: IndicatorStyle, dimmed: Bool) -> NSImage {
        let width: CGFloat = (style == .capsule) ? 22.0 : ((style == .minimalGem) ? 16.0 : 18.0)
        let height: CGFloat = 18.0
        let size = NSSize(width: width, height: height)

        let baseColor: NSColor
        let glowColor: NSColor

        if connected {
            baseColor = NSColor(srgbRed: 0.05, green: 0.88, blue: 0.52, alpha: 1.0)
            glowColor = NSColor(srgbRed: 0.05, green: 0.88, blue: 0.52, alpha: 0.45)
        } else {
            let alpha: CGFloat = dimmed ? 0.38 : 1.0
            baseColor = NSColor(srgbRed: 1.00, green: 0.22, blue: 0.38, alpha: alpha)
            glowColor = NSColor(srgbRed: 1.00, green: 0.22, blue: 0.38, alpha: dimmed ? 0.12 : 0.50)
        }

        let img = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let cx = width / 2.0, cy = height / 2.0

            switch style {
            case .glowSphere:
                let gc = [glowColor.cgColor, glowColor.withAlphaComponent(0.0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gc, locations: [0.0, 1.0]) {
                    ctx.drawRadialGradient(g, startCenter: CGPoint(x: cx, y: cy), startRadius: 1.8, endCenter: CGPoint(x: cx, y: cy), endRadius: 8.5, options: .drawsAfterEndLocation)
                }
                ctx.setFillColor(NSColor(white: 0.0, alpha: 0.16).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - 4.8, y: cy - 4.8, width: 9.6, height: 9.6))
                let sr = CGRect(x: cx - 4.2, y: cy - 4.2, width: 8.4, height: 8.4)
                ctx.saveGState(); ctx.addEllipse(in: sr); ctx.clip()
                let sc = [baseColor.blended(withFraction: 0.40, of: .white)!.cgColor, baseColor.cgColor, baseColor.blended(withFraction: 0.28, of: .black)!.cgColor] as CFArray
                if let sg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sc, locations: [0.0, 0.45, 1.0]) {
                    ctx.drawLinearGradient(sg, start: CGPoint(x: cx, y: sr.maxY), end: CGPoint(x: cx, y: sr.minY), options: [])
                }
                ctx.restoreGState()
                ctx.setFillColor(NSColor(white: 1.0, alpha: dimmed ? 0.25 : 0.70).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - 2.8, y: cy + 0.6, width: 5.6, height: 2.6))

            case .capsule:
                let cw: CGFloat = 16.0, ch: CGFloat = 6.4
                let capX = (width - cw) / 2.0, capY = (height - ch) / 2.0
                let halo = NSBezierPath(roundedRect: NSRect(x: capX - 1.5, y: capY - 1.5, width: cw + 3, height: ch + 3), xRadius: 4.5, yRadius: 4.5)
                glowColor.setFill(); halo.fill()
                let bodyPath = NSBezierPath(roundedRect: NSRect(x: capX, y: capY, width: cw, height: ch), xRadius: 3.2, yRadius: 3.2)
                ctx.saveGState(); bodyPath.addClip()
                let ccap = [baseColor.blended(withFraction: 0.35, of: .white)!.cgColor, baseColor.cgColor] as CFArray
                if let cg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: ccap, locations: [0.0, 1.0]) {
                    ctx.drawLinearGradient(cg, start: CGPoint(x: cx, y: capY + ch), end: CGPoint(x: cx, y: capY), options: [])
                }
                ctx.restoreGState()
                ctx.setFillColor(NSColor(white: 1.0, alpha: dimmed ? 0.20 : 0.45).cgColor)
                NSBezierPath(roundedRect: NSRect(x: capX + 2, y: capY + ch - 2.2, width: cw - 4, height: 1.4), xRadius: 0.7, yRadius: 0.7).fill()

            case .precisionRing:
                ctx.setStrokeColor(baseColor.withAlphaComponent(dimmed ? 0.30 : 0.75).cgColor)
                ctx.setLineWidth(1.3)
                ctx.strokeEllipse(in: CGRect(x: cx - 5.5, y: cy - 5.5, width: 11, height: 11))
                ctx.setFillColor(baseColor.cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5))

            case .minimalGem:
                let r: CGFloat = 3.6
                let gc = [glowColor.cgColor, glowColor.withAlphaComponent(0.0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gc, locations: [0.0, 1.0]) {
                    ctx.drawRadialGradient(g, startCenter: CGPoint(x: cx, y: cy), startRadius: 1.0, endCenter: CGPoint(x: cx, y: cy), endRadius: 6.0, options: .drawsAfterEndLocation)
                }
                ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.25).cgColor); ctx.setLineWidth(0.6)
                ctx.strokeEllipse(in: CGRect(x: cx - r - 0.5, y: cy - r - 0.5, width: (r + 0.5) * 2, height: (r + 0.5) * 2))
                ctx.setFillColor(baseColor.cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                ctx.setFillColor(NSColor(white: 1.0, alpha: dimmed ? 0.20 : 0.75).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: cy + 0.8, width: 3.0, height: 1.5))
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    // ── Pulse Animation ──
    func startPulse() {
        pulsePhase = 0; pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            guard let self = self, !self.isConnected, let button = self.statusItem.button else { return }
            self.pulsePhase = (self.pulsePhase + 1) % 2
            button.image = (self.pulsePhase == 0) ? self.redImageBright : self.redImageDim
        }
    }

    func stopPulse() { pulseTimer?.invalidate(); pulseTimer = nil }

    // ── Menu Setup ──
    func setupMenu() {
        let menu = NSMenu()
        menu.minimumWidth = 280

        statusCardView = StatusCardView()
        statusCardView.frame = NSRect(x: 0, y: 0, width: 280, height: 186)
        statusCardMenuItem = NSMenuItem()
        statusCardMenuItem.view = statusCardView
        menu.addItem(statusCardMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeMenuItem(title: "立即重新检测", symbol: "arrow.clockwise", action: #selector(checkNowClicked), key: "r"))
        menu.addItem(makeMenuItem(title: "复制节点与代理信息", symbol: "doc.on.doc", action: #selector(copyProxyClicked)))

        menu.addItem(NSMenuItem.separator())

        // Speed format submenu
        let speedMenu = NSMenu()
        let fmtMbs = NSMenuItem(title: "0.00 MB/s (标准 MB/s，推荐)", action: #selector(setSpeedFormatClicked(_:)), keyEquivalent: "")
        fmtMbs.tag = 0; fmtMbs.target = self; fmtMbs.state = (speedFormat == .mbs) ? .on : .off
        let fmtMbsC = NSMenuItem(title: "0.00 M/s (紧凑)", action: #selector(setSpeedFormatClicked(_:)), keyEquivalent: "")
        fmtMbsC.tag = 1; fmtMbsC.target = self; fmtMbsC.state = (speedFormat == .mbsCompact) ? .on : .off
        let fmtAdapt = NSMenuItem(title: "自动单位 (B/s · KB/s · MB/s)", action: #selector(setSpeedFormatClicked(_:)), keyEquivalent: "")
        fmtAdapt.tag = 2; fmtAdapt.target = self; fmtAdapt.state = (speedFormat == .adaptive) ? .on : .off
        speedMenu.addItem(fmtMbs)
        speedMenu.addItem(fmtMbsC)
        speedMenu.addItem(fmtAdapt)
        speedFormatMenuItems = [fmtMbs, fmtMbsC, fmtAdapt]

        speedMenu.addItem(NSMenuItem.separator())

        let metTotal = NSMenuItem(title: "统计: 总速率 (上传 + 下载)", action: #selector(setSpeedMetricClicked(_:)), keyEquivalent: "")
        metTotal.tag = 0; metTotal.target = self; metTotal.state = (speedMetric == .total) ? .on : .off
        let metDown = NSMenuItem(title: "统计: 仅下载速率", action: #selector(setSpeedMetricClicked(_:)), keyEquivalent: "")
        metDown.tag = 1; metDown.target = self; metDown.state = (speedMetric == .download) ? .on : .off
        speedMenu.addItem(metTotal)
        speedMenu.addItem(metDown)
        speedMetricMenuItems = [metTotal, metDown]

        let speedParent = makeMenuItem(title: "速率显示设置", symbol: "gauge.with.dots.needle.bottom.50percent", action: nil)
        speedParent.submenu = speedMenu
        menu.addItem(speedParent)

        // Show Flag in Menu Bar toggle
        showFlagMenuItem = makeMenuItem(title: "在顶部显示国家旗帜", symbol: "flag", action: #selector(toggleShowFlagClicked))
        showFlagMenuItem.state = showFlagInMenuBar ? .on : .off
        menu.addItem(showFlagMenuItem)

        // Interval submenu
        let intervalMenu = NSMenu()
        for sec in [1, 2, 3, 5, 10] {
            let label = sec == 1 ? "1 秒  (极速实时，推荐)" : "\(sec) 秒"
            let item = NSMenuItem(title: label, action: #selector(setIntervalClicked(_:)), keyEquivalent: "")
            item.tag = sec; item.target = self; item.state = (sec == 1) ? .on : .off
            intervalMenu.addItem(item)
        }
        let intParent = makeMenuItem(title: "检测频率", symbol: "timer", action: nil)
        intParent.submenu = intervalMenu
        menu.addItem(intParent)

        // Style submenu
        let styleMenu = NSMenu()
        for (i, name) in ["🔮  霓虹晶体呼吸灯", "💊  灵动高科技胶囊", "🎯  精密极客光环", "💎  微光珠宝圆点"].enumerated() {
            let item = NSMenuItem(title: name, action: #selector(setStyleClicked(_:)), keyEquivalent: "")
            item.tag = i; item.target = self; item.state = (i == 0) ? .on : .off
            styleMenu.addItem(item)
        }
        let styleParent = makeMenuItem(title: "图标视觉样式", symbol: "paintpalette", action: nil)
        styleParent.submenu = styleMenu
        menu.addItem(styleParent)

        soundMenuItem = makeMenuItem(title: "断开声音提示", symbol: "speaker.wave.2", action: #selector(toggleSoundClicked))
        soundMenuItem.state = .on
        menu.addItem(soundMenuItem)

        menu.addItem(NSMenuItem.separator())

        autoLaunchMenuItem = makeMenuItem(title: "开机自动启动", symbol: "play.circle", action: #selector(toggleAutoLaunch))
        updateAutoLaunchState()
        menu.addItem(autoLaunchMenuItem)

        menu.addItem(makeMenuItem(title: "退出 ProxyGuard", symbol: "xmark.circle", action: #selector(quitClicked), key: "q"))

        statusItem.menu = menu
    }

    func makeMenuItem(title: String, symbol: String, action: Selector?, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            item.image = img.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
        }
        return item
    }

    func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkProxy(isRetry: false)
        }
    }

    @objc func toggleShowFlagClicked() {
        showFlagInMenuBar.toggle()
        showFlagMenuItem.state = showFlagInMenuBar ? .on : .off
        updateTrafficDisplay()
    }

    @objc func setSpeedFormatClicked(_ sender: NSMenuItem) {
        if let fmt = SpeedFormat(rawValue: sender.tag) {
            speedFormat = fmt
            for item in speedFormatMenuItems {
                item.state = (item.tag == sender.tag) ? .on : .off
            }
            updateTrafficDisplay()
        }
    }

    @objc func setSpeedMetricClicked(_ sender: NSMenuItem) {
        if let met = SpeedMetric(rawValue: sender.tag) {
            speedMetric = met
            for item in speedMetricMenuItems {
                item.state = (item.tag == sender.tag) ? .on : .off
            }
            updateTrafficDisplay()
        }
    }

    @objc func setIntervalClicked(_ sender: NSMenuItem) {
        checkInterval = TimeInterval(sender.tag)
        if let p = sender.menu { for i in p.items { i.state = (i == sender) ? .on : .off } }
        scheduleTimer(); checkProxy(isRetry: false)
    }

    @objc func setStyleClicked(_ sender: NSMenuItem) {
        if let s = IndicatorStyle(rawValue: sender.tag) {
            currentStyle = s; rebuildIcons()
            if let button = statusItem.button { button.image = isConnected ? greenImage : redImageBright }
            if !isConnected { startPulse() }
            if let p = sender.menu { for i in p.items { i.state = (i == sender) ? .on : .off } }
        }
    }

    @objc func toggleSoundClicked() { soundEnabled.toggle(); soundMenuItem.state = soundEnabled ? .on : .off }

    @objc func copyProxyClicked() {
        let p = getSystemProxy()
        let flag = currentCountryFlag.isEmpty ? "" : "\(currentCountryFlag) "
        let name = currentCountryName.isEmpty ? "" : "\(currentCountryName) "
        let ip = currentExitIP.isEmpty ? "" : "(\(currentExitIP))"
        let node = currentNodeName.isEmpty ? "" : " 节点: \(currentNodeName)"
        let text = "\(flag)\(name)\(ip)\(node) 代理端口: \(p.host):\(p.port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        sendNotification(title: "已复制节点信息", message: text, sound: nil)
    }

    @objc func checkNowClicked() {
        refreshActiveNodeName()
        checkProxy(isRetry: false)
    }

    @objc func quitClicked() { trafficMonitor.stop(); NSApplication.shared.terminate(self) }

    // ── Auto Launch ──
    let plistPath = ("~/Library/LaunchAgents/com.yjy.proxyguard.plist" as NSString).expandingTildeInPath

    func isAutoLaunchEnabled() -> Bool { FileManager.default.fileExists(atPath: plistPath) }
    func updateAutoLaunchState() { autoLaunchMenuItem.state = isAutoLaunchEnabled() ? .on : .off }

    @objc func toggleAutoLaunch() {
        if isAutoLaunchEnabled() {
            try? FileManager.default.removeItem(atPath: plistPath)
        } else {
            let exec = Bundle.main.executablePath ?? "/Applications/ProxyGuard.app/Contents/MacOS/ProxyGuard"
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
                <key>Label</key><string>com.yjy.proxyguard</string>
                <key>ProgramArguments</key><array><string>\(exec)</string></array>
                <key>RunAtLoad</key><true/><key>KeepAlive</key><false/>
            </dict></plist>
            """
            try? plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
        }
        updateAutoLaunchState()
    }

    // ── Proxy Detection ──
    func getSystemProxy() -> (host: String, port: Int) {
        if let s = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] {
            return (s[kCFNetworkProxiesHTTPProxy as String] as? String ?? "127.0.0.1",
                    s[kCFNetworkProxiesHTTPPort as String] as? Int ?? 7897)
        }
        return ("127.0.0.1", 7897)
    }

    func checkProxy(isRetry: Bool) {
        if isChecking && !isRetry { return }
        isChecking = true
        let proxy = getSystemProxy()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0; config.timeoutIntervalForResource = 2.0
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as String: 1, kCFNetworkProxiesHTTPPort as String: proxy.port,
            kCFNetworkProxiesHTTPProxy as String: proxy.host, kCFNetworkProxiesHTTPSEnable as String: 1,
            kCFNetworkProxiesHTTPSPort as String: proxy.port, kCFNetworkProxiesHTTPSProxy as String: proxy.host
        ]
        let session = URLSession(configuration: config)
        let t0 = Date()
        let traceUrl = URL(string: "https://www.cloudflare.com/cdn-cgi/trace")!

        session.dataTask(with: traceUrl) { [weak self] data, resp, err in
            guard let self = self else { return }
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            var ok = false; var detail = ""
            var loc = ""
            var ip = ""

            if let http = resp as? HTTPURLResponse, http.statusCode == 200, let data = data,
               let str = String(data: data, encoding: .utf8) {
                ok = true
                for line in str.components(separatedBy: "\n") {
                    if line.hasPrefix("loc=") { loc = String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines) }
                    if line.hasPrefix("ip=") { ip = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines) }
                }
            } else if let err = err {
                let ns = err as NSError
                if ns.domain == "kCFErrorDomainCFNetwork" && ns.code == 310 { detail = "代理客户端未启动或端口不通" }
                else if ns.code == NSURLErrorTimedOut { detail = "代理节点连接超时" }
                else { detail = err.localizedDescription }
            } else if let http = resp as? HTTPURLResponse { detail = "状态码 \(http.statusCode)" }

            DispatchQueue.main.async {
                self.isChecking = false
                if !ok && !isRetry {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.checkProxy(isRetry: true) }
                } else {
                    if ok && !loc.isEmpty {
                        let cInfo = countryInfo(from: loc)
                        self.currentCountryFlag = cInfo.flag
                        self.currentCountryName = cInfo.name
                        self.currentExitIP = ip
                    }
                    self.handleResult(ok: ok, latency: ms, error: detail, proxy: proxy)
                }
            }
        }.resume()

        // Periodically refresh active node name from mihomo API
        if Int(Date().timeIntervalSince1970) % 5 == 0 {
            refreshActiveNodeName()
        }
    }

    func handleResult(ok: Bool, latency: Int, error: String, proxy: (host: String, port: Int)) {
        lastCheckTime = Date(); lastLatencyMs = latency; lastErrorDetail = error
        let df = DateFormatter(); df.dateFormat = "HH:mm:ss"
        let timeStr = df.string(from: Date())
        guard let button = statusItem.button else { return }

        if ok {
            consecutiveFailures = 0
            if !isConnected {
                isConnected = true; stopPulse()
                let flag = currentCountryFlag.isEmpty ? "" : "\(currentCountryFlag) "
                let name = currentCountryName.isEmpty ? "" : "\(currentCountryName) · "
                sendNotification(title: "✅ 代理已恢复正常", message: "\(flag)\(name)延迟 \(latency)ms", sound: soundEnabled ? "Ping" : nil)
            }
            button.image = greenImage
        } else {
            consecutiveFailures += 1
            if isConnected {
                isConnected = false; startPulse()
                sendNotification(title: "⚠️ 代理连接已断开", message: error, sound: soundEnabled ? "Basso" : nil)
            }
        }
        updateTrafficDisplay()

        statusCardView.update(
            connected: isConnected, latency: lastLatencyMs, error: lastErrorDetail,
            host: proxy.host, port: proxy.port, checkTime: timeStr, interval: Int(checkInterval),
            countryFlag: currentCountryFlag, countryName: currentCountryName, exitIP: currentExitIP, nodeName: currentNodeName,
            upSpeed: currentUpSpeed, downSpeed: currentDownSpeed, upTotal: totalUp, downTotal: totalDown
        )
    }

    func sendNotification(title: String, message: String, sound: String?) {
        var script = "display notification \"\(message)\" with title \"\(title)\""
        if let s = sound { script += " sound name \"\(s)\"" }
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }
}

// ── Entry Point ──
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = ProxyMonitorApp()
app.delegate = delegate
app.run()
