// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import GoogleNavigation
import SwiftUI

@main
struct crashtestApp: App {

    init() {
        // Initialize Google Maps with API key
        // Make sure to add your API key to Info.plist under GMSApiKey
        if let path = Bundle.main.path(forResource: "Keys", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: path),
            let apiKey = plist["GMSApiKey"] as? String
        {
            GMSServices.provideAPIKey(apiKey)
        } else {
            print("Warning: No Google Maps API key found in Keys.plist")
        }
    }

    var body: some Scene {
        WindowGroup {
            CrashTestView()
        }
    }
}
