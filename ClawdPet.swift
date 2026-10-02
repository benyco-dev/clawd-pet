// Clawd desktop pets for macOS: walk on window tops and the Dock line, drag to move,
// right-click to dismiss one. A touch of ~/.clawd-pet/done makes a random pet say "done".
// Build: swiftc -O -swift-version 5 ClawdPet.swift -o clawd-pet
// Run:   ./clawd-pet clawd white black
import AppKit

// MARK: - Sprites

struct Sprite {
    let px: CGFloat
    let flip: Bool  // sprite faces right; mirror when walking left
    let body: [String]
    let legs: [[String]]
    let sit: [String]?
    let drag: [String]
    let colors: [Character: NSColor]
    let say: String
}

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
}

// Big head, small body. H = eye highlight, D = lower eye row, B = blush.
let kitten = [
    ".......K......K.",
    "......KPK....KPK",
    ".K....KWPKKKKPWK",
    "KWK...KWWWWWWWWK",
    "KWK...KWHEWWHEWK",
    "KWK...KWDDWWDDWK",
    ".KWKKKKBWWPPWWBK",
    "..KWWWWWWWWWWWK.",
    "..KWWWWWWWWWWWK.",
]
let kittenLegs = [
    ["..KWKWK..KWKWK..", "..KKKKK..KKKKK.."],
    [".KWK.KWKWK.KWK..", ".KKK.KKKKK.KKK.."],
]
let kittenSit = [
    "................",
    "................",
    ".......K......K.",
    "......KPK....KPK",
    "......KWPKKKKPWK",
    "...KKKKWWWWWWWWK",
    "..KWWWKWHEWWHEWK",
    "..KWWWKWDDWWDDWK",
    ".KWWWWKBWWPPWWBK",
    "KKKKWWWWWWWWWWK.",
    "KWWWKKKKKKKKKKK.",
]
// Picked up: "!" (X), ring eyes with pupils (S), open mouth (M).
let kittenDrag = [
    "....X..K......K.",
    "....X.KPK....KPK",
    ".K..X.KWPKKKKPWK",
    "KWK...KWWWWWWWWK",
    "KWK.X.KDDDWWDDDK",
    "KWK...KDSDWWDSDK",
    ".KWKKKKDDDPPDDDK",
    "..KWWWWWWWMMWWK.",
    "..KWWWWWWWWWWWK.",
    "..KWKWK..KWKWK..",
    "..KKKKK..KKKKK..",
]
let blinkMap: [Character: Character] = ["H": "W", "E": "W", "D": "K"]

let sprites: [String: Sprite] = [
    "clawd": Sprite(
        px: 10, flip: false,
        body: ["..#########..", "..##o###o##..", "#############", "..#########..", "...#.#.#.#..."],
        legs: [["...#...#....."], [".....#...#..."]],
        sit: nil,
        drag: ["#.#########.#", "#.##o###o##.#", "#############", "..#########..", "...#.#.#.#...", "...#.#.#.#..."],
        colors: ["#": rgb(217, 119, 87), "o": rgb(0, 0, 0)],
        say: "작업 완료!"),
    "white": Sprite(
        px: 6, flip: true, body: kitten, legs: kittenLegs, sit: kittenSit, drag: kittenDrag,
        colors: ["K": rgb(70, 70, 70), "W": rgb(252, 252, 252), "E": rgb(40, 40, 40), "D": rgb(40, 40, 40),
                 "H": rgb(255, 255, 255), "P": rgb(245, 150, 175), "B": rgb(255, 195, 210),
                 "X": rgb(230, 60, 60), "S": rgb(255, 255, 255), "M": rgb(90, 40, 45)],
        say: "작업 완료냥!"),
    "black": Sprite(
        px: 6, flip: true, body: kitten, legs: kittenLegs, sit: kittenSit, drag: kittenDrag,
        colors: ["K": rgb(10, 10, 10), "W": rgb(45, 45, 45), "E": rgb(250, 205, 40), "D": rgb(250, 205, 40),
                 "H": rgb(255, 255, 255), "P": rgb(230, 130, 155), "B": rgb(150, 70, 90),
                 "X": rgb(230, 60, 60), "S": rgb(10, 10, 10), "M": rgb(170, 60, 80)],
        say: "작업 완료냥!"),
]

// MARK: - Screen and windows (all in CG coordinates: origin top-left of the main display, y down)

var mainH: CGFloat { NSScreen.screens[0].frame.height }

// Usable area of the main display (below the menu bar, above the Dock).
var area: CGRect {
    let v = NSScreen.screens[0].visibleFrame
    return CGRect(x: v.minX, y: mainH - v.maxY, width: v.width, height: v.height)
}

func toNS(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat) -> NSPoint { NSPoint(x: x, y: mainH - y - h) }

struct Win { let id: Int; let rect: CGRect }

// Normal app windows on screen, front to back. Bounds need no Screen Recording permission.
func visibleWindows() -> [Win] {
    let me = Int(getpid())
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return [] }
    return list.compactMap { w in
        guard (w[kCGWindowLayer as String] as? Int) == 0,
              (w[kCGWindowOwnerPID as String] as? Int) != me,
              (w[kCGWindowAlpha as String] as? Double ?? 1) > 0,
              let n = w[kCGWindowNumber as String] as? Int,
              let b = w[kCGWindowBounds as String],
              let r = CGRect(dictionaryRepresentation: b as! CFDictionary),
              r.width > 50, r.height > 50 else { return nil }
        return Win(id: n, rect: r)
    }
}

// Highest visible window top edge at column x, at or below feet (tol: how far above feet still counts).
func findFloor(_ wins: [Win], x: CGFloat, feet: CGFloat, fallback: CGFloat, tol: CGFloat) -> (CGFloat, Int?) {
    var best = fallback
    var hit: Int? = nil
    for (i, w) in wins.enumerated() {
        let r = w.rect
        if x < r.minX || x >= r.maxX || r.minY < feet - tol || r.minY >= best { continue }
        let hidden = wins[..<i].contains { o in
            x >= o.rect.minX && x < o.rect.maxX && r.minY >= o.rect.minY && r.minY < o.rect.maxY
        }
        if !hidden { best = r.minY; hit = w.id }
    }
    return (best, hit)
}

// MARK: - Pet

final class PetView: NSView {
    weak var pet: Pet?
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        bounds.fill(using: .copy)  // wipe the last frame (sit/stand change shape)
        pet?.draw()
    }
    override func mouseDown(with e: NSEvent) { pet?.grab(e) }
    override func mouseDragged(with e: NSEvent) { pet?.dragTo() }
    override func mouseUp(with e: NSEvent) { pet?.drop() }
    override func rightMouseDown(with e: NSEvent) { pet?.close() }
}

final class Pet {
    let sp: Sprite
    let panel: NSPanel
    let view = PetView()
    let bubble: NSPanel
    let label: NSTextField
    let box: NSView
    var onClose: (() -> Void)?
    var queue: [(due: Date, text: String)] = []  // lines to say, from the director

    var x: CGFloat, y: CGFloat  // top-left, CG coordinates
    var dx: CGFloat
    var vy: CGFloat = 0
    var t = 0, blink = 0, rest = 0, say = 0
    var drag = false
    var grabOffset = CGPoint.zero
    var on: Int? = nil            // window we stand on
    var onL: CGFloat = 0, onT: CGFloat = 0
    var perch: CGFloat? = nil     // stand this far below the top of window `on` (its top is off-screen)

    var w: CGFloat { panel.frame.width }
    var h: CGFloat { panel.frame.height }

    init(_ sp: Sprite) {
        self.sp = sp
        let size = NSSize(width: CGFloat(sp.body[0].count) * sp.px,
                          height: CGFloat(sp.body.count + sp.legs[0].count) * sp.px)
        let a = area
        x = CGFloat.random(in: a.minX...(a.maxX - size.width))
        y = a.maxY - size.height
        dx = Bool.random() ? 4 : -4
        panel = Pet.makePanel(size)

        let l = NSTextField(labelWithString: sp.say)
        l.font = .boldSystemFont(ofSize: 13)
        l.textColor = .black
        l.frame.origin = NSPoint(x: 8, y: 4)
        let b = Pet.makePanel(NSSize(width: 10, height: 10))
        b.ignoresMouseEvents = true
        b.hasShadow = true
        let bx = NSView(frame: .zero)
        bx.wantsLayer = true
        bx.layer?.backgroundColor = NSColor.white.cgColor
        bx.layer?.borderColor = NSColor.black.cgColor
        bx.layer?.borderWidth = 1
        bx.layer?.cornerRadius = 6
        bx.addSubview(l)
        b.contentView = bx
        label = l
        box = bx
        bubble = b

        panel.contentView = view
        view.pet = self
        place()
        panel.orderFrontRegardless()
    }

    static func makePanel(_ size: NSSize) -> NSPanel {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        return p
    }

    func place() { panel.setFrameOrigin(toNS(x, y, h)) }

    func draw() {
        let rows: [String]
        if drag { rows = sp.drag }
        else if rest > 0, let s = sp.sit { rows = s }
        else { rows = sp.body + sp.legs[(t / 3) % sp.legs.count] }
        let cols = rows[0].count
        let mirror = sp.flip && dx < 0
        for (r, row) in rows.enumerated() {
            for (c, ch0) in row.enumerated() {
                var ch = ch0
                if blink > 0, let b = blinkMap[ch] { ch = b }
                guard let color = sp.colors[ch] else { continue }
                color.setFill()
                let cc = mirror ? cols - 1 - c : c
                NSRect(x: CGFloat(cc) * sp.px, y: CGFloat(r) * sp.px, width: sp.px, height: sp.px).fill()
            }
        }
    }

    static func sayTicks(_ text: String) -> Int { 30 + 2 * text.count }  // 80 ms ticks

    func speak(_ text: String) {
        label.stringValue = text
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 16, height: label.frame.height + 8)
        bubble.setContentSize(size)
        box.frame = NSRect(origin: .zero, size: size)
        say = Pet.sayTicks(text)
        bubble.orderFrontRegardless()
        if !drag { rest = max(rest, say) }  // stop to talk
    }

    func announce() {
        speak(sp.say)
        if !drag { rest = 0; y -= 1; vy = -10 }  // happy hop
    }

    func tick(_ wins: [Win]) {
        let a = area
        if let q = queue.first, q.due <= Date() { queue.removeFirst(); speak(q.text) }
        if say > 0 {
            say -= 1
            let bw = bubble.frame.width, bh = bubble.frame.height
            let bx = max(a.minX, min(a.maxX - bw, x + (w - bw) / 2))
            bubble.setFrameOrigin(toNS(bx, y - bh - 4, bh))
            if say == 0 { bubble.orderOut(nil) }
        }
        if drag { return }
        if blink > 0 { blink -= 1 } else if Int.random(in: 0..<50) == 0 { blink = 2 }

        // ride along if the window we stand on moved
        var cur = wins.first { $0.id == on }
        if let c = cur { x += c.rect.minX - onL; y += c.rect.minY - onT }
        let cx = x + w / 2

        // standing on a window: keep its top (or the perch height) as the floor even if other windows
        // cover it, until the window closes/minimizes or we leave its sides
        var floor: CGFloat? = nil
        var hit = on
        if on != nil {
            if let c = cur, cx >= c.rect.minX, cx < c.rect.maxX { floor = c.rect.minY + (perch ?? 0) }
            else { on = nil; perch = nil; hit = nil }
        }
        if floor == nil {
            let r = findFloor(wins, x: cx, feet: y + h, fallback: a.maxY, tol: 4)
            floor = r.0
            hit = r.1
        }
        let f = floor!

        if y + h < f {
            // falling (or hopping)
            vy = min(vy + 2, 40)
            y = min(y + vy, f - h)
        } else {
            vy = 0
            y = f - h
            on = hit
            cur = wins.first { $0.id == on }
            if let c = cur { onL = c.rect.minX; onT = c.rect.minY }
            if rest > 0 {
                rest -= 1
            } else if Int.random(in: 0..<150) == 0 {
                rest = Int.random(in: 40..<100)  // sit 3-8 s
            } else {
                t += 1
                x += dx
                // turn around at the edges of the window we're on, and of the screen
                var minX = a.minX, maxX = a.maxX
                if let c = cur, c.rect.width > w { minX = max(minX, c.rect.minX); maxX = min(maxX, c.rect.maxX) }
                if x < minX { dx = abs(dx); x = minX } else if x + w > maxX { dx = -abs(dx); x = maxX - w }
            }
        }
        place()
        view.needsDisplay = true
    }

    func grab(_ e: NSEvent) {
        drag = true; on = nil; perch = nil; rest = 0; blink = 0
        let p = e.locationInWindow  // bottom-left origin
        grabOffset = CGPoint(x: p.x, y: h - p.y)
        view.needsDisplay = true
    }

    func dragTo() {
        let m = NSEvent.mouseLocation
        x = m.x - grabOffset.x
        y = (mainH - m.y) - grabOffset.y
        place()
    }

    func drop() {
        drag = false
        vy = 0
        let wins = visibleWindows()
        let cx = x + w / 2, feet = y + h
        let (f, _) = findFloor(wins, x: cx, feet: feet, fallback: area.maxY, tol: h)
        if f <= feet {
            // feet on/overlapping a title bar: stand on its top edge
            y = f - h
            place()
        } else if let win = wins.first(where: { $0.rect.contains(CGPoint(x: cx, y: feet - 1)) }) {
            // dropped over a window's body: climb onto its top edge (kept on-screen for maximized windows)
            on = win.id; onL = win.rect.minX; onT = win.rect.minY
            let p = max(0, area.minY + h - win.rect.minY)
            perch = p
            y = win.rect.minY + p - h
            place()
        }
        view.needsDisplay = true
    }

    func close() {
        bubble.orderOut(nil)
        panel.orderOut(nil)
        onClose?()
    }
}

// MARK: - App

struct Slot { let from: Int, to: Int; var lines: [String] }

// "A: text" / "B: text" -> (role, text)
func parseChatLine(_ line: String) -> (role: String, text: String)? {
    let t = line.trimmingCharacters(in: .whitespaces)
    guard let colon = t.firstIndex(of: ":") else { return nil }
    let role = t[..<colon].trimmingCharacters(in: .whitespaces)
    let text = t[t.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    return (role == "A" || role == "B") && !text.isEmpty ? (role, text) : nil
}

final class App: NSObject {
    var pets: [Pet] = []
    let signalPath = NSHomeDirectory() + "/.clawd-pet/done"
    let greetPath = NSHomeDirectory() + "/.clawd-pet/greeted"
    var sigTime: Date?
    var n = 0

    // Talking: lines to you by time of day, and chats between pets (from ~/.clawd-pet/lines.txt)
    var slots: [Slot] = []
    var chats: [[(role: String, text: String)]] = []
    var greeted = ""
    var busyUntil = Date() + 15  // let pets land first
    var nextChat = Date() + Double.random(in: 30...60)
    var nextRemark = Date() + Double.random(in: 120...180)

    // [h-h] = lines to you in that hour range (first = greeting); any other [..] = chats (A:/B:, blank line between)
    func loadLines() {
        guard let s = try? String(contentsOfFile: NSHomeDirectory() + "/.clawd-pet/lines.txt", encoding: .utf8) else { return }
        var mode = ""
        var chat: [(role: String, text: String)] = []
        for raw in s.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n") {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") {
                if !chat.isEmpty { chats.append(chat); chat = [] }
                continue
            }
            if t.hasPrefix("[") && t.hasSuffix("]") {
                let r = t.dropFirst().dropLast().split(separator: "-")
                if r.count == 2, let a = Int(r[0]), let b = Int(r[1]) {
                    slots.append(Slot(from: a, to: b, lines: [])); mode = "slot"
                } else { mode = "chat" }
            } else if mode == "slot" {
                slots[slots.count - 1].lines.append(t)
            } else if mode == "chat", let line = parseChatLine(t) {
                chat.append(line)
            }
        }
        if !chat.isEmpty { chats.append(chat) }
    }

    // MARK: AI chats about today's trends: ai.sh drops ai-*.txt files (A:/B: lines, blank line between chats)

    let dir = NSHomeDirectory() + "/.clawd-pet"
    var nextGen = Date.distantPast

    func aiFiles() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [])
            .filter { $0.hasPrefix("ai-") && $0.hasSuffix(".txt") && Int($0.dropFirst(3).dropLast(4)) != nil }  // not ai-prompt.txt
            .sorted().map { dir + "/" + $0 }
    }

    func aiBlocks(_ path: String) -> [String] {
        let s = ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").replacingOccurrences(of: "\r", with: "")
        return s.components(separatedBy: "\n")
            .split(whereSeparator: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map { $0.joined(separator: "\n") }
    }

    // Take (and remove) the oldest AI chat.
    func takeAiChat() -> [(role: String, text: String)]? {
        guard let f = aiFiles().first else { return nil }
        var blocks = aiBlocks(f)
        let first = blocks.isEmpty ? "" : blocks.removeFirst()
        if blocks.isEmpty { try? FileManager.default.removeItem(atPath: f) }
        else { try? (blocks.joined(separator: "\n\n") + "\n").write(toFile: f, atomically: true, encoding: .utf8) }
        let chat = first.components(separatedBy: "\n").compactMap(parseChatLine)
        return chat.isEmpty ? nil : chat
    }

    // Keep a few AI chats in stock; generating takes ~1 min in the background.
    func refillAi() {
        let now = Date()
        let script = dir + "/ai.sh"
        guard now > nextGen, FileManager.default.fileExists(atPath: script) else { return }
        if let m = (try? FileManager.default.attributesOfItem(atPath: dir + "/ai-running"))?[.modificationDate] as? Date,
           now.timeIntervalSince(m) < 300 { return }
        if aiFiles().reduce(0, { $0 + aiBlocks($1).count }) >= 3 { return }
        nextGen = now + 600  // at most one Claude call per 10 min
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script]
        try? p.run()
    }

    // Queue lines on pets, spoken one after another.
    func emit(_ items: [(Pet, String)]) {
        let now = Date()
        var off: TimeInterval = 0
        for (p, text) in items {
            p.queue.append((now + off, text))
            off += Double(Pet.sayTicks(text)) * 0.08 + 0.4
        }
        busyUntil = now + off + 2
    }

    // Chat partners face each other and stay put until the chat is over.
    func faceOff(_ a: Pet, _ b: Pet, seconds: TimeInterval) {
        for (me, other) in [(a, b), (b, a)] {
            me.dx = abs(me.dx) * (other.x + other.w / 2 >= me.x + me.w / 2 ? 1 : -1)
            if !me.drag { me.rest = max(me.rest, Int(seconds / 0.08) + 5) }
        }
    }

    func direct() {
        let now = Date()
        refillAi()
        if now < busyUntil || pets.isEmpty { return }
        let h = Calendar.current.component(.hour, from: now)
        if let slot = slots.first(where: { $0.from < $0.to ? (h >= $0.from && h < $0.to) : (h >= $0.from || h < $0.to) }),
           !slot.lines.isEmpty {
            // greet once when a time slot starts (or when pets start during it)
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd"
            let day = slot.from > slot.to && h < slot.to ? now - 86400 : now  // overnight slot started yesterday
            let key = "\(f.string(from: day))-\(slot.from)"
            if greeted != key {
                greeted = key
                try? key.write(toFile: greetPath, atomically: true, encoding: .utf8)
                emit([(pets.randomElement()!, slot.lines[0])])
                return
            }
            if now > nextRemark {
                nextRemark = now + Double.random(in: 180...300)
                emit([(pets.randomElement()!, slot.lines.randomElement()!)])
                return
            }
        }
        if pets.count >= 2, now > nextChat {
            // half the time an AI chat about today's trends, otherwise one from the lines file
            var chat = Bool.random() ? takeAiChat() : nil
            if chat == nil { chat = chats.randomElement() }
            guard let c = chat else { return }
            nextChat = now + Double.random(in: 60...120)
            let pair = pets.shuffled()
            emit(c.map { ($0.role == "A" ? pair[0] : pair[1], $0.text) })
            faceOff(pair[0], pair[1], seconds: busyUntil.timeIntervalSinceNow - 2)
        }
    }

    func mtime() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: signalPath))?[.modificationDate] as? Date
    }

    func start(_ names: [String]) {
        for n in names {
            let p = Pet(sprites[n]!)
            p.onClose = { [unowned self, unowned p] in
                self.pets.removeAll { $0 === p }
                if self.pets.isEmpty { NSApp.terminate(nil) }
            }
            pets.append(p)
        }
        sigTime = mtime()  // ignore signals from before startup
        loadLines()
        greeted = ((try? String(contentsOfFile: greetPath, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let timer = Timer(timeInterval: 0.08, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc func tick() {
        let m = mtime()
        if m != sigTime {
            sigTime = m
            if m != nil { pets.randomElement()?.announce() }
        }
        n += 1
        if n % 12 == 0 { direct() }
        let wins = visibleWindows()
        for p in pets { p.tick(wins) }
    }
}

var names = CommandLine.arguments.dropFirst().filter { sprites[$0] != nil }
if names.isEmpty { names = ["clawd"] }
let nsApp = NSApplication.shared
nsApp.setActivationPolicy(.accessory)  // no Dock icon, never steals focus
let controller = App()
controller.start(Array(names))
nsApp.run()
