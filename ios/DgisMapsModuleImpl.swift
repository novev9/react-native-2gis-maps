import CoreLocation
import Foundation
import React
import UIKit

@objc(DgisMapsModuleImpl)
public final class DgisMapsModuleImpl: NSObject, CLLocationManagerDelegate {
  @objc public static let shared = DgisMapsModuleImpl()

  private let locationManager = CLLocationManager()
  private var permissionResolve: RCTPromiseResolveBlock?

  private override init() {
    super.init()
    locationManager.delegate = self
  }

  @objc public func initialize(
    _ options: NSDictionary,
    resolve: RCTPromiseResolveBlock,
    reject: RCTPromiseRejectBlock
  ) {
    guard let apiKey = options["apiKey"] as? String, !apiKey.isEmpty else {
      reject("E_DGIS_INVALID_API_KEY", "apiKey is required", nil)
      return
    }

    do {
      try DGisSdkHolder.shared.initialize(apiKey, logLevel: options["logLevel"] as? String)
      resolve(true)
    } catch {
      reject("E_DGIS_INIT_FAILED", error.localizedDescription, error)
    }
  }

  @objc public var isInitialized: Bool {
    DGisSdkHolder.shared.isInitialized
  }

  @objc public func flyTo(
    viewTag: NSNumber,
    latitude: NSNumber,
    longitude: NSNumber,
    zoom: NSNumber,
    tilt: NSNumber,
    bearing: NSNumber,
    durationMs: NSNumber,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    DispatchQueue.main.async {
      guard let view = self.findView(tag: viewTag) else {
        reject("E_DGIS_VIEW_NOT_FOUND", "Could not find DgisMapsView for tag \(viewTag)", nil)
        return
      }

      view.flyTo(latitude, lng: longitude, zoom: zoom, tilt: tilt, bearing: bearing, duration: durationMs)
      resolve(true)
    }
  }

  @objc public func centerOnUserLocation(
    viewTag: NSNumber,
    durationMs: NSNumber,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    DispatchQueue.main.async {
      guard let view = self.findView(tag: viewTag) else {
        reject("E_DGIS_VIEW_NOT_FOUND", "Could not find DgisMapsView for tag \(viewTag)", nil)
        return
      }

      view.centerOnUserLocation(durationMs)
      resolve(true)
    }
  }

  @objc public func requestLocationPermission(resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      let status = CLLocationManager.authorizationStatus()
      if status == .authorizedAlways || status == .authorizedWhenInUse {
        resolve(true)
        return
      }

      if status == .denied || status == .restricted {
        resolve(false)
        return
      }

      self.permissionResolve = resolve
      self.locationManager.requestWhenInUseAuthorization()
    }
  }

  @objc public var hasLocationPermission: Bool {
    let status = CLLocationManager.authorizationStatus()
    return status == .authorizedAlways || status == .authorizedWhenInUse
  }

  public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let resolve = permissionResolve else {
      return
    }

    permissionResolve = nil
    resolve(hasLocationPermission)
  }

  private func findView(tag: NSNumber) -> DgisMapsViewImpl? {
    // Fabric's wrapper doesn't expose `reactTag`, so we can't propagate the
    // JS-side tag to the impl. Single-map flows: pick any live impl from the
    // global registry. Multi-map will need per-view dispatch (likely via
    // Fabric commands instead of imperative module methods).
    let live = DgisMapsViewImpl.registry.allObjects
    if let any = live.first {
      if live.count > 1 {
        // Per-tag dispatch isn't wired (Fabric hides reactTag on the wrapper),
        // so we pick the first impl. Multiple simultaneous DGisMap instances
        // will route to a non-deterministic one — switch to Fabric commands
        // before shipping multi-map support.
        NSLog("[DgisMaps] WARNING: %d DgisMapsViewImpl registered; tag %@ ignored, routed to first.", live.count, tag)
      }
      return any
    }

    // Fallback: walk the UIKit tree from the key window. Kept for any path
    // where the registry wasn't populated (shouldn't happen in normal mount).
    guard let root = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow }) else {
      return nil
    }

    return findView(in: root, tag: tag.intValue)
  }

  private func findView(in view: UIView, tag: Int) -> DgisMapsViewImpl? {
    if view.reactTag?.intValue == tag {
      // The Fabric wrapper (DgisMapsView) owns the tag; the actual impl is one
      // of its descendants (Fabric may wrap contentView in a private host view).
      // Walk the whole subtree under the tagged view instead of only the direct
      // subviews — otherwise flyTo / centerOnUserLocation reject with NOT_FOUND.
      if let impl = view as? DgisMapsViewImpl {
        return impl
      }
      return findImplInDescendants(of: view)
    }

    for child in view.subviews {
      if let found = findView(in: child, tag: tag) {
        return found
      }
    }

    return nil
  }

  private func findImplInDescendants(of view: UIView) -> DgisMapsViewImpl? {
    for child in view.subviews {
      if let impl = child as? DgisMapsViewImpl {
        return impl
      }
      if let nested = findImplInDescendants(of: child) {
        return nested
      }
    }
    return nil
  }
}
