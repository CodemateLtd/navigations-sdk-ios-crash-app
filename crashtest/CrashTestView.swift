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

import CoreLocation
import GoogleNavigation
import SwiftUI

struct CrashTestView: View {
    @State private var termsAccepted: Bool? = nil
    @State private var navigationSession: GMSNavigationSession?
    @State private var statusMessage = "Ready"
    @State private var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Navigation Crash Test")
                .font(.title)
                .padding()

            Text("Status: \(statusMessage)")
                .foregroundColor(.blue)
                .padding()

            VStack(spacing: 15) {
                if locationPermissionStatus == .notDetermined {
                    Button("Request Location Permission") {
                        locationManager.requestLocationPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if locationPermissionStatus == .denied || locationPermissionStatus == .restricted {
                    VStack {
                        Text("Location permission is required for navigation")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Button("Open Settings") {
                            openAppSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if termsAccepted == nil && locationPermissionStatus == .authorizedWhenInUse
                    || locationPermissionStatus == .authorizedAlways
                {
                    Button("Check Terms Acceptance") {
                        checkTermsAcceptance()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if termsAccepted == false
                    && (locationPermissionStatus == .authorizedWhenInUse
                        || locationPermissionStatus == .authorizedAlways)
                {
                    Button("Show Terms & Conditions Dialog") {
                        showTermsAndConditionsDialog()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if termsAccepted == true && navigationSession == nil
                    && (locationPermissionStatus == .authorizedWhenInUse
                        || locationPermissionStatus == .authorizedAlways)
                {
                    Button("Start Navigation & Guidance (Crash Test)") {
                        startNavigationAndGuidance()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if navigationSession != nil {
                    Button("Stop & Reset") {
                        reset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()

            Spacer()
        }
        .padding()
        .onAppear {
            locationPermissionStatus = locationManager.authorizationStatus
            checkTermsAcceptance()
        }
        .onReceive(locationManager.$authorizationStatus) { status in
            locationPermissionStatus = status
            updateStatusMessage()
        }
    }

    private func checkTermsAcceptance() {
        termsAccepted = GMSNavigationServices.areTermsAndConditionsAccepted()
        updateStatusMessage()
    }

    private func updateStatusMessage() {
        switch locationPermissionStatus {
        case .notDetermined:
            statusMessage = "Location permission not requested"
        case .denied, .restricted:
            statusMessage = "Location permission denied"
        case .authorizedWhenInUse, .authorizedAlways:
            if let termsAccepted = termsAccepted {
                statusMessage = termsAccepted ? "Ready to navigate" : "Terms not accepted"
            } else {
                statusMessage = "Checking terms acceptance..."
            }
        @unknown default:
            statusMessage = "Unknown location permission status"
        }
    }

    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    private func showTermsAndConditionsDialog() {
        let options = GMSNavigationTermsAndConditionsOptions(companyName: "Test Company")
        options.title = "Navigation Terms"
        
        GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(with: options) { accepted in
            DispatchQueue.main.async {
                self.termsAccepted = accepted
                self.statusMessage = accepted ? "Terms accepted" : "Terms not accepted"
            }
        }
    }

    // Simplified all-in-one method - reproduces crash
    private func startNavigationAndGuidance() {
        statusMessage = "Starting navigation..."
        
        // 1. Enable abnormal termination reporting
        GMSServices.setAbnormalTerminationReportingEnabled(true)
        
        // 2. Create navigation session
        let session = GMSNavigationServices.createNavigationSession()!
        navigationSession = session
        session.isStarted = true
        
        // 3. Set destination
        let destination = GMSNavigationWaypoint(
            location: CLLocationCoordinate2D(latitude: 37.791957, longitude: -122.412529),
            title: "Grace Cathedral"
        )!
        
        statusMessage = "Setting destination..."
        session.navigator!.setDestinations([destination]) { routeStatus in
            DispatchQueue.main.async {
                if routeStatus == .OK {
                    self.statusMessage = "Starting guidance..."
                    // 4. Start guidance - this is where crash occurs
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        session.navigator!.isGuidanceActive = true // This will crash
                        self.statusMessage = "✅ Guidance started!"
                    }
                } else {
                    self.statusMessage = "❌ Route error: \(routeStatus)"
                }
            }
        }
    }

    private func reset() {
        if let session = navigationSession {
            session.navigator?.clearDestinations()
            session.navigator?.isGuidanceActive = false
            session.isStarted = false
        }
        navigationSession = nil
        GMSNavigationServices.resetTermsAndConditionsAccepted()
        termsAccepted = nil
        statusMessage = "Reset complete"
    }
}

// MARK: - LocationManager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

#Preview {
    CrashTestView()
}
