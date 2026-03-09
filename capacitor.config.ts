import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.booknbuddy.app',
  appName: "Book'n",
  webDir: 'www',
  server: {
    url: 'https://app.booknbuddy.com/login.html',
    cleartext: false,
    allowNavigation: ['app.booknbuddy.com', '*.booknbuddy.com', '*.stripe.com', '*.firebaseapp.com', '*.googleapis.com']
  },
  ios: {
    contentInset: 'automatic',
    backgroundColor: '#0a1628',
    preferredContentMode: 'mobile',
    scheme: 'BooknApp',
    allowsLinkPreview: false
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 2000,
      launchAutoHide: true,
      backgroundColor: '#0a1628',
      showSpinner: false,
      splashFullScreen: true,
      splashImmersive: true
    },
    StatusBar: {
      style: 'LIGHT',
      backgroundColor: '#0a1628'
    },
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert']
    }
  }
};

export default config;
