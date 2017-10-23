//
//  HighlightTextView.swift
//  Rocket.Chat
//
//  Created by Artur Rymarz on 21.10.2017.
//  Copyright © 2017 Rocket.Chat. All rights reserved.
//

import Foundation

private enum Regex: String {
    case hashtag = "(?<!\\S)#[\\p{L}0-9_]+"
}

class HighlightTextView: UITextView {

    weak var labelTextTapGesture: UITapGestureRecognizer?
    var rectsHighlight: [CGRect: String]?

    override var attributedText: NSAttributedString! {
        didSet {
            setNeedsDisplay()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        fillRectHighlights()
        insertGesturesIfNeeded()
    }

    fileprivate func fillRectHighlights() {
        rectsHighlight = [:]

        for range in text.matches(of: Regex.hashtag.rawValue) {
            let startOffset = text.distance(from: text.startIndex, to: range.lowerBound)
            let rangeLength = text.distance(from: range.lowerBound, to: range.upperBound)

            guard
                let start = position(from: beginningOfDocument, offset: startOffset),
                let end = position(from: start, offset: rangeLength),

                let textRange = textRange(from: start, to: end) else {
                    continue
            }

            let rect = firstRect(for: textRange)
            rectsHighlight?[rect] = text(in: textRange)
        }
    }

    func insertGesturesIfNeeded() {
        if labelTextTapGesture == nil {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleHighlightsTapGestureCell(recognizer:)))
            gesture.delegate = self
            addGestureRecognizer(gesture)
            labelTextTapGesture = gesture
         }
    }

    override func draw(_ rect: CGRect) {
        guard let string = attributedText else {
            return
        }

        let framesetter: CTFramesetter = CTFramesetterCreateWithAttributedString(string)
        let path: CGMutablePath = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: bounds.size.width - 16, height: bounds.size.height))
        let totalframe: CTFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)

        guard let context: CGContext = UIGraphicsGetCurrentContext() else {
            return
        }

        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

//        CTFrameDraw(totalframe, context)

        let lines = CTFrameGetLines(totalframe) as NSArray

        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(totalframe, CFRangeMake(0, 0), &origins)

        for index in 0..<lines.count {
            // swiftlint:disable force_cast
            let line = lines[index] as! CTLine
            // swiftlint:enable force_cast

            let glyphRuns = CTLineGetGlyphRuns(line) as NSArray

            for i in 0..<glyphRuns.count {
                // swiftlint:disable force_cast
                let run = glyphRuns[i] as! CTRun
                // swiftlint:enable force_cast

                let attributes = CTRunGetAttributes(run) as NSDictionary

                //"highlightText"
                if let color: UIColor = attributes.object(forKey: "highlightColor") as? UIColor {
                    var runBounds: CGRect = .zero
                    var ascent: CGFloat = 0
                    var descent: CGFloat = 0

                    runBounds.size.width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil)) + 6
                    runBounds.size.height = ascent + descent

                    let xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
                    runBounds.origin.x = origins[index].x + xOffset + 2
                    runBounds.origin.y = origins[index].y - 4

                    let path = UIBezierPath(roundedRect: runBounds, cornerRadius: 5)

                    let highlightColor = color.cgColor
                    context.setFillColor(highlightColor)
                    context.setStrokeColor(highlightColor)
                    context.addPath(path.cgPath)
                    context.drawPath(using: .fillStroke)
                }
            }
        }
    }

    @objc func handleHighlightsTapGestureCell(recognizer: UIGestureRecognizer) {
        guard let recognizer = recognizer as? UITapGestureRecognizer else { return }

        let point = recognizer.location(in: self)

        guard let first = rectsHighlight?.first(where: { $0.key.contains(point) }) else { return }

        print(first)

        // TODO
    }
}

extension HighlightTextView: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

}

extension CGRect: Hashable {
    public var hashValue: Int {
        return NSStringFromCGRect(self).hashValue
    }
}

extension String {
    fileprivate func matches(of regex: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = self.startIndex
        while let range = self.range(of: regex, options: .regularExpression, range: start..<self.endIndex) {

            ranges.append(range)
            start = range.upperBound
        }

        return ranges
    }
}
