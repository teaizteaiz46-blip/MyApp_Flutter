import UserNotifications

/// يضيف صورة الإشعار بالآيفون. Firebase يبعث رابط الصورة داخل fcm_options.image،
/// فهنا ننزّلها ونرفقها بالإشعار قبل ما يطلع. إذا فشل التنزيل، يطلع الإشعار بدون صورة.
class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttempt: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    let content = (request.content.mutableCopy() as? UNMutableNotificationContent)
    bestAttempt = content
    guard let content = content else {
      contentHandler(request.content)
      return
    }

    let info = request.content.userInfo
    let fcm = info["fcm_options"] as? [String: Any]
    let raw = (fcm?["image"] as? String) ?? (info["image"] as? String)
    guard let raw = raw, let url = URL(string: raw), url.scheme == "https" else {
      contentHandler(content)
      return
    }

    URLSession.shared.downloadTask(with: url) { location, response, _ in
      defer { contentHandler(content) }
      guard let location = location else { return }
      let ext: String
      switch (response as? HTTPURLResponse)?.mimeType ?? response?.mimeType ?? "" {
      case "image/png": ext = "png"
      case "image/gif": ext = "gif"
      case "image/webp": ext = "webp"
      default: ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
      }
      let file = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)
      do {
        try FileManager.default.moveItem(at: location, to: file)
        let attachment = try UNNotificationAttachment(identifier: "image", url: file, options: nil)
        content.attachments = [attachment]
      } catch {
        // بدون صورة
      }
    }.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    if let handler = contentHandler, let content = bestAttempt {
      handler(content)
    }
  }
}
