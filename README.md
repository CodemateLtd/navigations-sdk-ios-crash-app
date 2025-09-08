# Google Maps Navigation SDK Crash Test

This app demonstrates a crash issue that occurs when starting navigation guidance with the Google Maps Navigation SDK.

## Setup

1. Copy `Keys.plist.sample` as `Keys.plist` and add your proper Google Maps API key
2. Start iOS simulator and configure it:
   - Set device language to **English** or **Finnish** (Settings > General > Language & Region > iPhone Language)
   - Set location to "Apple" (Features > Location > Apple)
   - **Important:** The crash appears to be language-dependent and may not occur with all languages (e.g., Japanese works fine, but English and Finnish both reproduce the crash)
   - Note: Unit settings (metric vs imperial) do not affect the crash

## Reproducing the Crash

1. Start the application in Xcode
2. Give location permissions and accept Terms of Service
3. Press "Start Navigation & Guidance (Crash Test)" button
4. App crashes when guidance is started

**Note:** If the crash doesn't occur on first try, restart the application and try again. If the crash still doesn't happen, try changing the simulator's language settings as the crash appears to be dependent on specific localization settings (English and Finnish are known to reproduce the crash, while Japanese does not).

## Expected Crash Example

When the crash occurs, you should see a stack trace similar to this:

```
	0   CoreFoundation                      0x00000001804c97d4 __exceptionPreprocess + 172
	1   libobjc.A.dylib                     0x00000001800937cc objc_exception_throw + 72
	2   Foundation                          0x0000000180f28fa4 _NSDescriptionWithLocaleFunc + 0
	3   Foundation                          0x0000000180f223b0 +[NSString stringWithFormat:] + 64
	4   crashtest.debug.dylib               0x000000010839f450 -[GMSx_SpeechFixedDistanceFormatRule formatMeters:roadName:] + 132
```

**Language Dependency:** This crash appears to be related to localization/formatting issues in the Navigation SDK. It occurs consistently with English and Finnish language settings but may not reproduce with other languages (e.g., Japanese). Unit settings (metric vs imperial) do not affect the crash occurrence.

## Expected Behavior

The app should crash during the guidance start process, demonstrating the underlying issue with the Navigation SDK.
