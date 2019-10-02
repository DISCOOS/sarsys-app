import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    // Hide your app’s key window when your app will resign active.
    func applicationWillResignActive(application:UIApplication) {
      self.window.isHidden = true;
    }
        
    // Show your app’s key window when your app becomes active again.
    func applicationDidBecomeActive(application:UIApplication) {
      self.window.isHidden = false;
    }

    
}



