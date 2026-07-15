import AppKit
import Foundation

enum AboutPanel {
    static let xProfileURL = URL(string: "https://x.com/brandon_ai")!
    static let xHandle = "@brandon_ai"

    static func show() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 3

        let credits = NSMutableAttributedString()

        let byline = NSAttributedString(
            string: "by Brandon Charleson\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph,
            ]
        )
        credits.append(byline)

        let link = NSAttributedString(
            string: "𝕏 \(xHandle)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .link: xProfileURL,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .paragraphStyle: paragraph,
            ]
        )
        credits.append(link)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "3"

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "CleanLock",
            .applicationVersion: version,
            .version: build,
            .credits: credits,
            .applicationIcon: NSApp.applicationIconImage as Any,
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
