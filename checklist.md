I'll expand the checklist to include Firebase configuration steps for Android:

1. Install Required Tools:
   - [ ] Install Android Studio for M1 Mac (if not already installed)
     - Download from: https://developer.android.com/studio
     - Choose the Apple Silicon (ARM) version
   - [ ] Install the Android SDK through Android Studio
     - Open Android Studio → Tools → SDK Manager
     - Install Android SDK Platform 34 (or latest)
     - Install Android SDK Build-Tools
     - Install Android Emulator

2. Configure Android Studio:
   - [ ] Open Android SDK Manager (Tools → SDK Manager)
   - [ ] Under "SDK Tools" tab, ensure these are installed:
     - Android SDK Build-Tools
     - Android Emulator
     - Android SDK Platform-Tools
     - Android SDK Tools
     - ARM (v8a) System Image for your target API level

3. Create an Android Virtual Device (AVD):
   - [ ] Open AVD Manager (Tools → AVD Manager)
   - [ ] Click "Create Virtual Device"
   - [ ] Select a device definition (e.g., Pixel 7)
   - [ ] Select a system image (make sure to choose an ARM-based image)
     - Look for images with "arm64-v8a" architecture
   - [ ] Complete the AVD creation with default settings

4. Firebase Configuration:
   - [ ] Register Android App in Firebase Console:
     - Go to Firebase Console → Project Settings
     - Add Android App
     - Use package name from `android/app/build.gradle` (usually `com.example.reelai`)
     - Download `google-services.json`
   
   - [ ] Add Firebase Files:
     - Place `google-services.json` in `android/app/`
     - Add to `.gitignore` if not already there
   
   - [ ] Update Android Gradle Files:
     - In `android/build.gradle`, add:
       ```gradle
       buildscript {
           dependencies {
               classpath 'com.google.gms:google-services:4.4.0'
           }
       }
       ```
     - In `android/app/build.gradle`, add:
       ```gradle
       apply plugin: 'com.google.gms.google-services'
       ```
   
   - [ ] Update Multidex Support:
     - In `android/app/build.gradle`, add:
       ```gradle
       android {
           defaultConfig {
               multiDexEnabled true
           }
       }
       ```

5. Configure Project:
   - [ ] Check your `android/app/build.gradle` for correct SDK versions:
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

6. Environment Setup:
   - [ ] Add Android SDK path to your shell profile (~/.zshrc):
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

7. Firebase Authentication Setup:
   - [ ] Enable required auth providers in Firebase Console:
     - Email/Password
     - Google Sign-In
   - [ ] Configure SHA-1 and SHA-256 certificates:
     ```bash
     cd android
     ./gradlew signingReport
     ```
   - [ ] Add the SHA fingerprints to Firebase Console

8. Firebase Cloud Messaging (FCM):
   - [ ] Enable FCM in Firebase Console
   - [ ] Add FCM configuration to `AndroidManifest.xml`:
     ```xml
     <manifest>
         <application>
             <meta-data
                 android:name="com.google.firebase.messaging.default_notification_channel_id"
                 android:value="high_importance_channel" />
         </application>
     </manifest>
     ```

9. Run the App:
   - [ ] Start the Android emulator from AVD Manager
   - [ ] In your project directory, run:
```bash
flutter doctor # Verify everything is set up correctly
flutter clean  # Clean the project
flutter pub get # Get dependencies
flutter run    # Run the app
```

Common Issues to Watch For:
1. If you see Gradle build errors:
   - Run `cd android && ./gradlew clean` then try again
2. If the emulator is slow:
   - Enable "Hardware acceleration" in the AVD settings
3. If you see ARM architecture compatibility issues:
   - Make sure you're using ARM-based system images in your AVD
4. If Firebase initialization fails:
   - Double-check `google-services.json` placement
   - Verify package name matches in Firebase Console
   - Check SHA fingerprints are correctly added
5. If authentication fails:
   - Verify SHA keys are correctly added to Firebase Console
   - Check if the OAuth consent screen is configured (for Google Sign-In)

Would you like me to help you start with any specific step from this checklist? We can begin by checking your current Firebase configuration and make any necessary adjustments.
