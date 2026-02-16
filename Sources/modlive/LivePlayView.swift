import AppKit
import SwiftModCore
import SwiftModEngine

class LivePlayView: NSView {
    let module: Module
    let sequencer: LiveSequencer

    private var currentOctave: Int = 1     // 0-2 for MOD's 3 octaves
    private var currentInstrument: Int = 1 // 1-based

    // Single channel — track which key is currently sounding
    private var activeKey: UInt16? = nil

    // Controls
    private let effectPopup = NSPopUpButton()
    private let param1Label = NSTextField(labelWithString: "Param 1:")
    private let param1Field = NSTextField()
    private let param2Label = NSTextField(labelWithString: "Param 2:")
    private let param2Field = NSTextField()
    private let speedLabel = NSTextField(labelWithString: "Speed:")
    private let speedField = NSTextField()
    private let tempoLabel = NSTextField(labelWithString: "Tempo:")
    private let tempoField = NSTextField()

    // The keyboard area that receives key events
    let keyboardArea = KeyboardAreaView()
    var keyboardAreaView: NSView { keyboardArea }

    // Status display
    private let statusLabel = NSTextField(labelWithString: "")

    // Effect types with their parameter definitions
    private static let effectTypes: [(name: String, paramCount: Int, param1Name: String?, param2Name: String?, defaultP1: Int, defaultP2: Int)] = [
        ("None",           0, nil,       nil,       0,  0),
        ("Arpeggio",       2, "X (st):", "Y (st):", 4,  7),
        ("Vibrato",        2, "Speed:",  "Depth:",  4,  4),
        ("Tremolo",        2, "Speed:",  "Depth:",  4,  4),
        ("Slide Up",       1, "Speed:",  nil,       2,  0),
        ("Slide Down",     1, "Speed:",  nil,       2,  0),
        ("Volume Slide",   1, "Up/Dn:",  nil,       16, 0),
    ]

    init(module: Module, sequencer: LiveSequencer) {
        self.module = module
        self.sequencer = sequencer
        super.init(frame: .zero)
        setupControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupControls() {
        // --- Effect dropdown ---
        effectPopup.removeAllItems()
        for et in LivePlayView.effectTypes {
            effectPopup.addItem(withTitle: et.name)
        }
        effectPopup.target = self
        effectPopup.action = #selector(effectChanged)

        // --- Parameter fields ---
        for field in [param1Field, param2Field] {
            field.stringValue = "0"
            field.alignment = .right
            field.formatter = IntFormatter(min: 0, max: 15)
        }
        // Set defaults for first non-None effect
        param1Field.stringValue = "0"
        param2Field.stringValue = "0"

        // --- Speed / Tempo ---
        speedField.stringValue = "\(sequencer.speed)"
        speedField.alignment = .right
        speedField.formatter = IntFormatter(min: 1, max: 31)
        speedField.target = self
        speedField.action = #selector(speedChanged)

        tempoField.stringValue = "\(sequencer.tempo)"
        tempoField.alignment = .right
        tempoField.formatter = IntFormatter(min: 32, max: 255)
        tempoField.target = self
        tempoField.action = #selector(tempoChanged)

        // --- Keyboard area ---
        keyboardArea.liveView = self

        // --- Status ---
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping

        // --- Layout with Auto Layout ---
        let controlsStack = NSStackView()
        controlsStack.orientation = .vertical
        controlsStack.alignment = .leading
        controlsStack.spacing = 8

        // Row 1: Effect + params
        let effectRow = NSStackView(views: [
            makeLabel("Effect:"), effectPopup,
            param1Label, param1Field,
            param2Label, param2Field,
        ])
        effectRow.spacing = 6
        param1Field.widthAnchor.constraint(equalToConstant: 40).isActive = true
        param2Field.widthAnchor.constraint(equalToConstant: 40).isActive = true
        effectPopup.widthAnchor.constraint(equalToConstant: 140).isActive = true

        // Row 2: Speed + Tempo
        let timingRow = NSStackView(views: [
            speedLabel, speedField,
            spacer(width: 20),
            tempoLabel, tempoField,
        ])
        timingRow.spacing = 6
        speedField.widthAnchor.constraint(equalToConstant: 40).isActive = true
        tempoField.widthAnchor.constraint(equalToConstant: 40).isActive = true

        // Row 3: Instrument + Octave info
        let infoLabel = NSTextField(labelWithString: "")
        infoLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        infoLabel.tag = 100 // for finding later

        controlsStack.addArrangedSubview(effectRow)
        controlsStack.addArrangedSubview(timingRow)
        controlsStack.addArrangedSubview(infoLabel)
        controlsStack.addArrangedSubview(statusLabel)

        // Main layout: controls at top, keyboard area fills the rest
        let mainStack = NSStackView(views: [controlsStack, keyboardArea])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            keyboardArea.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -24),
            keyboardArea.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])

        updateParamVisibility()
        updateInfoLabel()
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }

    private func spacer(width: CGFloat) -> NSView {
        let v = NSView()
        v.widthAnchor.constraint(equalToConstant: width).isActive = true
        return v
    }

    @objc private func effectChanged() {
        let idx = effectPopup.indexOfSelectedItem
        guard idx >= 0, idx < LivePlayView.effectTypes.count else { return }
        let et = LivePlayView.effectTypes[idx]
        param1Field.stringValue = "\(et.defaultP1)"
        param2Field.stringValue = "\(et.defaultP2)"
        updateParamVisibility()
    }

    @objc private func speedChanged() {
        if let val = Int(speedField.stringValue), val >= 1, val <= 31 {
            sequencer.speed = val
        }
    }

    @objc private func tempoChanged() {
        if let val = Int(tempoField.stringValue), val >= 32, val <= 255 {
            sequencer.setTempo(val)
        }
    }

    private func updateParamVisibility() {
        let idx = effectPopup.indexOfSelectedItem
        guard idx >= 0, idx < LivePlayView.effectTypes.count else { return }
        let et = LivePlayView.effectTypes[idx]

        param1Label.isHidden = et.paramCount < 1
        param1Field.isHidden = et.paramCount < 1
        param2Label.isHidden = et.paramCount < 2
        param2Field.isHidden = et.paramCount < 2

        if let name = et.param1Name {
            param1Label.stringValue = name
        }
        if let name = et.param2Name {
            param2Label.stringValue = name
        }
    }

    func updateInfoLabel() {
        guard let label = viewWithTag(100) as? NSTextField else { return }
        let instName: String
        if currentInstrument >= 1, currentInstrument <= module.instruments.count {
            let inst = module.instruments[currentInstrument - 1]
            let name = inst.name.isEmpty ? "(unnamed)" : inst.name
            instName = String(format: "%02d: %@", currentInstrument, name)
        } else {
            instName = "\(currentInstrument): ???"
        }
        label.stringValue = "Instrument [Up/Down]: \(instName)    Octave [Z/X]: \(currentOctave + 1)"
    }

    // Build the current Effect from dropdown + param fields
    func currentEffect() -> Effect? {
        let idx = effectPopup.indexOfSelectedItem
        guard idx > 0, idx < LivePlayView.effectTypes.count else { return nil }
        let p1 = Int(param1Field.stringValue) ?? 0
        let p2 = Int(param2Field.stringValue) ?? 0
        switch idx {
        case 1: return .arpeggio(x: p1, y: p2)
        case 2: return .vibrato(speed: p1, depth: p2)
        case 3: return .tremolo(speed: p1, depth: p2)
        case 4: return .slideUp(speed: p1)
        case 5: return .slideDown(speed: p1)
        case 6: return .volumeSlide(upDown: p1)
        default: return nil
        }
    }

    // Called by KeyboardAreaView
    func handleNoteKeyDown(_ keyCode: UInt16) {
        // Octave down (Z)
        if keyCode == KeyboardMapper.octaveDownKeyCode {
            currentOctave = max(0, currentOctave - 1)
            updateInfoLabel()
            keyboardArea.needsDisplay = true
            return
        }

        // Octave up (X)
        if keyCode == KeyboardMapper.octaveUpKeyCode {
            currentOctave = min(2, currentOctave + 1)
            updateInfoLabel()
            keyboardArea.needsDisplay = true
            return
        }

        // Instrument selection
        switch Int(keyCode) {
        case 126: // Up arrow
            currentInstrument = min(module.instruments.count, currentInstrument + 1)
            updateInfoLabel()
            return
        case 125: // Down arrow
            currentInstrument = max(1, currentInstrument - 1)
            updateInfoLabel()
            return
        default:
            break
        }

        // Get finetune for current instrument
        let finetune: Int
        if currentInstrument >= 1, currentInstrument <= module.instruments.count {
            finetune = module.instruments[currentInstrument - 1].samples.first?.finetune ?? 0
        } else {
            finetune = 0
        }
        let finetuneIndex = finetune < 0 ? finetune + 16 : finetune

        guard let period = KeyboardMapper.periodForKeyCode(keyCode, octave: currentOctave, finetune: finetuneIndex) else {
            return
        }

        activeKey = keyCode

        let effect = currentEffect()
        let event = NoteEvent(channel: 0, period: period, instrument: currentInstrument, effect: effect)
        sequencer.triggerNote(event)
        keyboardArea.isPlaying = true
        keyboardArea.needsDisplay = true
    }

    func handleNoteKeyUp(_ keyCode: UInt16) {
        // Only release if this is the key currently sounding
        guard keyCode == activeKey else { return }
        activeKey = nil
        sequencer.releaseNote(ReleaseEvent(channel: 0))
        keyboardArea.isPlaying = false
        keyboardArea.needsDisplay = true
    }
}

// Separate view for the keyboard area so it can be first responder
// while leaving text fields editable
class KeyboardAreaView: NSView {
    weak var liveView: LivePlayView?
    var isPlaying: Bool = false
    private var displayTimer: Timer?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && displayTimer == nil {
            displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.needsDisplay = true
                }
            }
        }
    }

    override func removeFromSuperview() {
        displayTimer?.invalidate()
        displayTimer = nil
        super.removeFromSuperview()
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        liveView?.handleNoteKeyDown(event.keyCode)
    }

    override func keyUp(with event: NSEvent) {
        liveView?.handleNoteKeyUp(event.keyCode)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.1, alpha: 1).setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        path.fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.green,
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.green.withAlphaComponent(0.5),
        ]
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.green.withAlphaComponent(0.7),
        ]

        var y = bounds.height - 24
        let x: CGFloat = 16
        let lineHeight: CGFloat = 18

        NSAttributedString(string: "Click here to play — keyboard layout:", attributes: headerAttrs)
            .draw(at: NSPoint(x: x, y: y))
        y -= lineHeight * 1.3

        NSAttributedString(string: " W  E     T  Y  U     O  P", attributes: dimAttrs)
            .draw(at: NSPoint(x: x, y: y))
        y -= lineHeight
        NSAttributedString(string: " C# D#    F# G# A#    C# D#", attributes: dimAttrs)
            .draw(at: NSPoint(x: x, y: y))
        y -= lineHeight
        NSAttributedString(string: "A  S  D  F  G  H  J  K  L  ;  '", attributes: attrs)
            .draw(at: NSPoint(x: x, y: y))
        y -= lineHeight
        NSAttributedString(string: "C  D  E  F  G  A  B  C  D  E  F", attributes: attrs)
            .draw(at: NSPoint(x: x, y: y))
        y -= lineHeight * 1.3

        NSAttributedString(string: "Z = octave down   X = octave up   Up/Down = instrument", attributes: dimAttrs)
            .draw(at: NSPoint(x: x, y: y))
        y -= lineHeight * 1.5

        if isPlaying, let seq = liveView?.sequencer {
            let ch = seq.channels[0]
            let status = String(format: "Playing   Row: %d   Tick: %d/%d", ch.channelRow, ch.channelTick, seq.speed)
            NSAttributedString(string: status, attributes: attrs)
                .draw(at: NSPoint(x: x, y: y))
        } else {
            NSAttributedString(string: "Silent", attributes: dimAttrs)
                .draw(at: NSPoint(x: x, y: y))
        }
    }
}

// Simple integer formatter for text fields
class IntFormatter: NumberFormatter, @unchecked Sendable {
    let minVal: Int
    let maxVal: Int

    init(min: Int, max: Int) {
        self.minVal = min
        self.maxVal = max
        super.init()
        self.minimum = NSNumber(value: min)
        self.maximum = NSNumber(value: max)
        self.allowsFloats = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func isPartialStringValid(
        _ partialString: String,
        newEditingString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        if partialString.isEmpty { return true }
        guard let val = Int(partialString) else { return false }
        return val >= 0 && val <= maxVal
    }
}
