import UIKit
import Capacitor
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import FirebaseAuth
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
        
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user, let token = self.fcmToken {
                print("User signed in: \(user.uid), saving FCM token")
                self.saveTokenToFirestore(uid: user.uid, token: token)
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
                // If user is already signed in, save immediately
                if let user = Auth.auth().currentUser {
                    self.saveTokenToFirestore(uid: user.uid, token: token)
                }
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
            if let user = Auth.auth().currentUser {
                saveTokenToFirestore(uid: user.uid, token: token)
            }
        }
    }
    
    func saveTokenToFirestore(uid: String, token: String) {
        let projectId = "calendar-b7a60"
        let urlString = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/users/\(uid)?updateMask.fieldPaths=apnsToken&updateMask.fieldPaths=fcmToken"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "apnsToken": ["stringValue": token],
                "fcmToken": ["stringValue": token]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to save token: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("Firestore response: \(httpResponse.statusCode)")
            }
        }.resume()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
