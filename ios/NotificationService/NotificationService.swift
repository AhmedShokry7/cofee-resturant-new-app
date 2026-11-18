import Foundation
import UniformTypeIdentifiers
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private var downloadTask: URLSessionDataTask?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

    guard
      let content = bestAttemptContent,
      let imageURL = imageURL(from: request.content.userInfo)
    else {
      finish()
      return
    }

    var urlRequest = URLRequest(url: imageURL)
    urlRequest.timeoutInterval = 20
    downloadTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, _ in
      guard
        let self,
        let data,
        let response = response as? HTTPURLResponse,
        (200..<300).contains(response.statusCode),
        let attachment = self.makeAttachment(data: data, response: response, sourceURL: imageURL)
      else {
        self?.finish()
        return
      }
      content.attachments = [attachment]
      self.finish()
    }
    downloadTask?.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    downloadTask?.cancel()
    finish()
  }

  private func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
    let fcmOptions = userInfo["fcm_options"] as? [String: Any]
    let aps = userInfo["aps"] as? [String: Any]
    let alert = aps?["alert"] as? [String: Any]
    let raw = fcmOptions?["image"] as? String
      ?? userInfo["image"] as? String
      ?? alert?["image"] as? String
    guard let raw, let url = URL(string: raw), url.scheme == "https" else { return nil }
    return url
  }

  private func makeAttachment(
    data: Data,
    response: HTTPURLResponse,
    sourceURL: URL
  ) -> UNNotificationAttachment? {
    guard !data.isEmpty else { return nil }
    let mimeType = response.value(forHTTPHeaderField: "Content-Type")?
      .split(separator: ";", maxSplits: 1)
      .first
      .map(String.init)
    let ext = sourceURL.pathExtension.isEmpty
      ? mimeType.flatMap { UTType(mimeType: $0)?.preferredFilenameExtension } ?? "jpg"
      : sourceURL.pathExtension
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(ext)
    do {
      try data.write(to: fileURL, options: .atomic)
      return try UNNotificationAttachment(identifier: "campaign-image", url: fileURL)
    } catch {
      try? FileManager.default.removeItem(at: fileURL)
      return nil
    }
  }

  private func finish() {
    guard let contentHandler, let content = bestAttemptContent else { return }
    self.contentHandler = nil
    contentHandler(content)
  }
}
