package com.booknbuddy.app;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;
import com.google.firebase.messaging.FirebaseMessaging;

public class MainActivity extends BridgeActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        registerFCMToken();
    }

    @Override
    public void onResume() {
        super.onResume();
        registerFCMToken();
    }

    private void registerFCMToken() {
        FirebaseMessaging.getInstance().getToken()
            .addOnSuccessListener(token -> {
                if (token != null && !token.isEmpty()) {
                    android.util.Log.d("FCM", "Android FCM token: " + token.substring(0, 20) + "...");
                    passTokenToWebpage(token);
                }
            })
            .addOnFailureListener(e -> {
                android.util.Log.e("FCM", "Failed to get FCM token: " + e.getMessage());
            });
    }

    private void passTokenToWebpage(String token) {
        new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(() -> {
            try {
                String js = "if(typeof window.saveFCMToken==='function'){" +
                            "  window.saveFCMToken('" + token + "');" +
                            "} else {" +
                            "  window.__pendingFCMToken='" + token + "';" +
                            "  console.log('Android FCM token queued');" +
                            "}";
                getBridge().getWebView().evaluateJavascript(js, null);
                android.util.Log.d("FCM", "Token injected into WebView");
            } catch (Exception e) {
                android.util.Log.e("FCM", "Error injecting token: " + e.getMessage());
            }
        }, 2000);
    }
}
