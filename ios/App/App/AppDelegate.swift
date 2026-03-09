import UIKit
import Capacitor
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?
    var fcmToken: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { token, error in
            if let error = error {
                NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
                print("❌ FCM token error: \(error)")
            } else if let token = token {
                NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: token)
                self.fcmToken = token
                print("✅ FCM token obtained: \(token.prefix(20))...")
                self.passTokenToWebpage(token: token)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
        print("❌ Push registration failed: \(error)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔄 FCM token refreshed")
        if let token = fcmToken {
            self.fcmToken = token
            NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: token)
            self.passTokenToWebpage(token: token)
        }
    }

    // Inject the token into the webpage — the JS handles saving it to Firestore
    // using the authenticated Firebase session (no auth issues this way)
    func passTokenToWebpage(token: String) {
        DispatchQueue.main.async {
            guard let rootVC = self.window?.rootViewController else {
                print("⚠️ No root view controller yet, will retry in 2s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.passTokenToWebpage(token: token)
                }
                return
            }
            
            let js = "if(typeof window.saveFCMToken==='function'){window.saveFCMToken('\(token)');}else{window.__pendingFCMToken='\(token)';console.log('📲 FCM token queued (saveFCMToken not ready yet)');}";
            
            self.evaluateJavaScript(js, in: rootVC)
        }
    }
    
    func evaluateJavaScript(_ js: String, in viewController: UIViewController) {
        // Try the view controller's view hierarchy for a WKWebView
        if let webView = findWebView(in: viewController.view) {
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("⚠️ JS eval error: \(error.localizedDescription)")
                } else {
                    print("✅ FCM token passed to webpage JS")
                }
            }
            return
        }
        
        // Check child view controllers (Capacitor nests the webview)
        for child in viewController.children {
            evaluateJavaScript(js, in: child)
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

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
