import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    let preferredLanguage = Locale.preferredLanguages.first ?? "en"
    self.title = preferredLanguage.hasPrefix("zh") ? "墨阅" : "Moyue"

    updateApplicationIcon()
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(systemAppearanceDidChange(_:)),
      name: Notification.Name("AppleInterfaceThemeChangedNotification"),
      object: nil
    )
  }

  deinit {
    DistributedNotificationCenter.default().removeObserver(self)
  }

  @objc private func systemAppearanceDidChange(_ notification: Notification) {
    updateApplicationIcon()
  }

  private func updateApplicationIcon() {
    let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
    let imageName: NSImage.Name
    if appearance == .darkAqua {
      imageName = NSImage.Name("RuntimeAppIconDark")
    } else {
      imageName = NSImage.Name("RuntimeAppIconDay")
    }
    NSApp.applicationIconImage = NSImage(named: imageName)
  }
}
