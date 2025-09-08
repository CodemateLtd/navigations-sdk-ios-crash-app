# Google Maps Navigation SDK Crash Test

This app demonstrates a crash issue that occurs when starting navigation guidance with the Google Maps Navigation SDK.

## Setup

1. Copy `Keys.plist.sample` as `Keys.plist` and add your proper Google Maps API key
2. Start iOS simulator and set location to "Apple" (Features > Location > Apple)

## Reproducing the Crash

1. Start the application in Xcode
2. Give location permissions and accept Terms of Service
3. Press "Initialize Navigation and Guidance" button
4. App crashes when guidance is started

**Note:** If the crash doesn't occur on first try, restart the application and try again.

## Expected Crash Example

When the crash occurs, you should see a stack trace similar to this:

```
	0   CoreFoundation                      0x00000001804c97d4 __exceptionPreprocess + 172
	1   libobjc.A.dylib                     0x00000001800937cc objc_exception_throw + 72
	2   Foundation                          0x0000000180f28fa4 _NSDescriptionWithLocaleFunc + 0
	3   Foundation                          0x0000000180f223b0 +[NSString stringWithFormat:] + 64
	4   crashtest.debug.dylib               0x000000010839f450 -[GMSx_SpeechFixedDistanceFormatRule formatMeters:roadName:] + 132
```

## Expected Behavior

The app should crash during the guidance start process, demonstrating the underlying issue with the Navigation SDK.
