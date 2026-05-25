import DGis
import Foundation

@objc(DGisSdkHolder)
public final class DGisSdkHolder: NSObject {
  @objc public static let shared = DGisSdkHolder()

  private let lock = NSLock()
  private var container: DGis.Container?
  private var initializedApiKey: String?

  private override init() {
    super.init()
  }

  @objc public var isInitialized: Bool {
    lock.lock()
    defer { lock.unlock() }
    return container != nil
  }

  @objc public func initialize(_ apiKey: String, logLevel: String?) throws {
    lock.lock()
    defer { lock.unlock() }

    if let initializedApiKey {
      if initializedApiKey == apiKey {
        return
      }

      throw NSError(
        domain: "DgisMaps",
        code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "2GIS SDK is already initialized with another key"]
      )
    }

    let level: DGis.LogLevel
    switch logLevel {
    case "verbose":
      level = .verbose
    case "warning":
      level = .warning
    case "error":
      level = .error
    case "off":
      level = .off
    default:
      level = .info
    }

    container = DGis.Container(
      keySource: Self.resolveKeySource(apiKey: apiKey),
      logOptions: LogOptions(systemLevel: level),
      httpOptions: HttpOptions(),
      personalDataCollectionOptions: PersonalDataCollectionOptions(
        personalDataCollectionConsent: .granted
      )
    )
    initializedApiKey = apiKey
  }

  private static func resolveKeySource(apiKey: String) -> KeySource {
    // Mobile SDK validates the signed binary dgissdk.key, not the API string —
    // KeyFromString is left only as a dev-time fallback so init() doesn't throw
    // synchronously, but the vendor will reject it with "File with key info is
    // invalid". A consumer who hits this warning needs to add dgissdk.key to
    // the app target's Copy Bundle Resources phase.
    if let path = Bundle.main.path(forResource: "dgissdk", ofType: "key") {
      return .fromFile(KeyFromFile(path: path))
    }
    NSLog("[DGisSdkHolder] WARNING: dgissdk.key missing from app bundle — falling back to KeyFromString which the Mobile SDK will reject.")
    return .fromString(KeyFromString(contents: apiKey))
  }

  public func sdkOrNil() -> DGis.Container? {
    lock.lock()
    defer { lock.unlock() }
    return container
  }

  public func requireSdk() throws -> DGis.Container {
    lock.lock()
    defer { lock.unlock() }

    guard let container else {
      throw NSError(
        domain: "DgisMaps",
        code: 1000,
        userInfo: [NSLocalizedDescriptionKey: "2GIS SDK is not initialized. Call DgisMapsModule.initialize(...) before mounting DgisMapsView."]
      )
    }

    return container
  }
}
