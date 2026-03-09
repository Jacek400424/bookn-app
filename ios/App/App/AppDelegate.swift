import UIKit
import Capacitor
import UserNotifications
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var apnsToken: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        // Periodically try to inject token into WebView
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let token = self?.apnsToken else { return }
            self?.injectTokenIntoWebView(token: token)
        }
        
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
        
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.apnsToken = token
        print("APNs token received: \(token)")
        
        // Try to inject immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.injectTokenIntoWebView(token: token)
        }
    }
    
    func injectTokenIntoWebView(token: String) {
        DispatchQueue.main.async {
            guard let window = self.window,
                  let rootVC = window.rootViewController else { return }
            
            // Try to find the WKWebView in the view hierarchy
            if let webView = self.findWebView(in: rootVC.view) {
                let js = "window.nativeAPNsToken = '\(token)'; if(window.onAPNsToken) { window.onAPNsToken('\(token)'); }"
                webView.evaluateJavaScript(js) { result, error in
                    if let error = error {
                        print("JS injection error: \(error.localizedDescription)")
                    } else {
                        print("APNs token injected into WebView")
                    }
                }
            }
        }
    }
    
    func findWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        for subview in view.subviews {
            if let found = findWebView(in: subview) {
                return found
            }
        }
        return nil
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
        print("Push registration failed: \(error)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
