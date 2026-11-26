import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import UIKit

class SceneDelegate: RCTDefaultReactNativeFactoryDelegate, UIWindowSceneDelegate {
  var window: UIWindow?
  var reactNativeFactory: RCTReactNativeFactory?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }

    dependencyProvider = RCTAppDependencyProvider()
    reactNativeFactory = RCTReactNativeFactory(delegate: self)
    window = UIWindow(windowScene: windowScene)
    
    #if DEBUG
    let devMenuConfiguration = RCTDevMenuConfiguration(
      devMenuEnabled: true,
      shakeGestureEnabled: true,
      keyboardShortcutsEnabled: true
    )
    reactNativeFactory?.devMenuConfiguration = devMenuConfiguration
    #endif
    
    reactNativeFactory?.startReactNative(
      withModuleName: "CylDeallocExample",
      in: window,
      connectionOptions: connectionOptions
    )

   
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    RCTLinkingManager.scene(scene, openURLContexts: URLContexts)
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    RCTLinkingManager.scene(scene, continue: userActivity)
  }

  override func bundleURL() -> URL? {
    #if DEBUG
    let settings = RCTBundleURLProvider.sharedSettings()
    // An explicit `RCT_jsLocation` default wins; otherwise honour a Metro port given to this run or build.
    if settings.jsLocation == nil, let port = Self.metroPort() {
      return RCTBundleURLProvider.jsBundleURL(
        forBundleRoot: "index",
        packagerHost: "localhost:\(port)",
        packagerScheme: settings.packagerScheme,
        enableDev: settings.enableDev,
        enableMinification: settings.enableMinification,
        inlineSourceMap: settings.inlineSourceMap,
        modulesOnly: false,
        runModule: true
      )
    }
    return settings.jsBundleURL(forBundleRoot: "index")
    #else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
    #endif
  }

  #if DEBUG
  /// `RCT_METRO_PORT` is a compile-time macro of React-Core, so a prebuilt React-Core keeps 8081 whatever the build says.
  /// Read the port at run time instead: the launch environment (`SIMCTL_CHILD_RCT_METRO_PORT=8088 xcrun simctl launch …`)
  /// first, then the `RCTMetroPort` Info.plist key, which Xcode fills from the `RCT_METRO_PORT` build setting or variable.
  private static func metroPort() -> Int? {
    let candidates = [
      ProcessInfo.processInfo.environment["RCT_METRO_PORT"],
      Bundle.main.object(forInfoDictionaryKey: "RCTMetroPort") as? String,
    ]
    for case let value? in candidates {
      if let port = Int(value.trimmingCharacters(in: .whitespaces)), (1...65535).contains(port) {
        return port
      }
    }
    return nil
  }
  #endif
}
