import Cocoa
import ScreenCaptureKit

// Only a tiny, in-memory sample is retained for the duration of each measurement.
@MainActor final class BackgroundColour {
    var cachedContent: SCShareableContent?
    var contentReadAt = Date.distantPast
    var busy = false
    var dark = false
    var luminance: Double?
    var status = "Waiting"
    func sample(window: NSWindow, body: CGRect, completion: @escaping (Bool) -> Void) {
        guard #available(macOS 14.0, *), !busy, window.isVisible else { return }
        guard CGPreflightScreenCaptureAccess() else { status = "Screen access needed";return }
        busy = true
        let frame = window.frame
        let screen = window.screen
        Task { @MainActor in
            defer { busy = false }
            do {
                let content: SCShareableContent
                if let cached=cachedContent,Date().timeIntervalSince(contentReadAt)<30 {
                    content=cached
                } else {
                    content=try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly:true)
                    cachedContent=content;contentReadAt=Date()
                }
                guard let screen = screen,
                      let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                      let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { return }
                let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
                let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.width = 16; config.height = 16; config.showsCursor = false
                let rect = CGRect(x: frame.minX + body.minX - screen.frame.minX,
                                  y: screen.frame.maxY - frame.maxY + body.minY,
                                  width: body.width, height: body.height)
                config.sourceRect = rect.intersection(CGRect(x: 0, y: 0, width: screen.frame.width, height: screen.frame.height))
                guard !config.sourceRect.isEmpty else { return }
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                var pixels = [UInt8](repeating: 0, count: 16*16*4)
                let success = pixels.withUnsafeMutableBytes { buffer -> Bool in
                    guard let ctx = CGContext(data: buffer.baseAddress, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                    ctx.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 16)); return true
                }
                guard success else { return }
                var brightness = 0.0
                for i in stride(from: 0, to: pixels.count, by: 4) {
                    brightness += (0.2126*Double(pixels[i]) + 0.7152*Double(pixels[i+1]) + 0.0722*Double(pixels[i+2]))/255
                }
                brightness /= 256
                luminance=brightness
                status = "Background \(Int(brightness*100))%"
                // Hysteresis prevents flickering over mixed backgrounds.
                if brightness > 0.60 { dark = true }
                else if brightness < 0.45 { dark = false }
                completion(dark)
            } catch { cachedContent=nil;status = error.localizedDescription }
        }
    }
}
