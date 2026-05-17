import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1200, height: 800))
    self.minSize = NSSize(width: 800, height: 600)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func close() {
    // 关闭窗口时隐藏而不是退出应用
    NSApp.hide(nil)
  }
}
