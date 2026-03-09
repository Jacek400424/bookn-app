import WebKit
import UIKit
import Capacitor
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import WebKit

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
                print("FCM token error: \(error)")
            } else if let token = token {
                NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: token)
                self.fcmToken = token
                print("FCM token: \(token)")
                self.saveFCMTokenToFirestore(token: token)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
        print("Push registration failed: \(error)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM token refreshed: \(fcmToken ?? "nil")")
        if let token = fcmToken {
            self.fcmToken = token
            NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: token)
            saveFCMTokenToFirestore(token: token)
        }
    }
    
    func saveFCMTokenToFirestore(token: String) {
        // Save token to UserDefaults so we can retry later
        UserDefaults.standard.set(token, forKey: "fcmToken")
        
        // Try to get the current user UID from the WebView cookies
        // We'll poll for it since the user may not be logged in yet
        pollForUserAndSaveToken(token: token, attempts: 0)
    }
    
    func pollForUserAndSaveToken(token: String, attempts: Int) {
        guard attempts < 60 else { return } // Try for 5 minutes
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            // Try to get UID from WebView by evaluating JavaScript
            guard let window = self.window,
                  let rootVC = window.rootViewController else {
                self.pollForUserAndSaveToken(token: token, attempts: attempts + 1)
                return
            }
            
            self.findWebView(in: rootVC.view)?.evaluateJavaScript(
                "try { firebase.auth().currentUser ? firebase.auth().currentUser.uid : null } catch(e) { null }"
            ) { result, error in
                if let uid = result as? String {
                    print("Found user UID: \(uid), saving FCM token")
                    self.saveTokenToFirestoreREST(uid: uid, token: token)
                } else {
                    // Try alternate method - check if auth state is in the page
                    self.findWebView(in: rootVC.view)?.evaluateJavaScript(
                        "try { document.cookie.match(/firebaseUser=([^;]+)/)?.[1] || null } catch(e) { null }"
                    ) { result2, error2 in
                        if result2 == nil || result2 is NSNull {
                            self.pollForUserAndSaveToken(token: token, attempts: attempts + 1)
                        }
                    }
                }
            }
        }
    }
    
    func saveTokenToFirestoreREST(uid: String, token: String) {
        let projectId = "calendar-b7a60"
        let urlString = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/users/\(uid)?updateMask.fieldPaths=apnsToken&updateMask.fieldPaths=fcmTokens"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "apnsToken": ["stringValue": token],
                "fcmTokens": ["arrayValue": ["values": [["stringValue": token]]]]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to save token to Firestore: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("Firestore save response: \(httpResponse.statusCode)")
                if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                    print("Response: \(responseStr.prefix(200))")
                }
            }
        }.resume()
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
