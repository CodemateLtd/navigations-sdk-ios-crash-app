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
    @State private var sessionInitialized = false
    @State private var routeCalculated = false
    @State private var guidanceRunning = false
    @State private var statusMessage = "Ready"
    @State private var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @StateObject private var locationManager = LocationManager()
    @State private var shouldContinueWithGuidance = false

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

                if termsAccepted == true && !sessionInitialized
                    && (locationPermissionStatus == .authorizedWhenInUse
                        || locationPermissionStatus == .authorizedAlways)
                {
                    Button("Initialize Navigation Session") {
                        initializeNavigationSession()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if routeCalculated && !guidanceRunning {
                    Button("Start Guidance") {
                        continueWithGuidanceIfReady()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if guidanceRunning {
                    Button("Stop Guidance") {
                        stopGuidance()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Initialize Navigation and Guidance") {
                    initializeNavigationAndGuidance()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 20)
                .disabled(
                    locationPermissionStatus != .authorizedWhenInUse
                        && locationPermissionStatus != .authorizedAlways)

                Button("Reset/Cleanup") {
                    reset()
                }
                .buttonStyle(.bordered)
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
        let accepted = GoogleMapsNavigationSessionManager.shared.areTermsAccepted()
        termsAccepted = accepted
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
        GoogleMapsNavigationSessionManager.shared.showTermsAndConditionsDialog(
            title: "Navigation Terms",
            companyName: "Test Company",
            shouldOnlyShowDriverAwarenessDisclaimer: false
        ) { accepted in
            DispatchQueue.main.async {
                self.termsAccepted = accepted
                self.statusMessage = accepted ? "Terms accepted" : "Terms not accepted"
            }
        }
    }

    private func initializeNavigationSession() {
        do {
            try GoogleMapsNavigationSessionManager.shared.createNavigationSession(true)
            sessionInitialized = true
            statusMessage = "Session initialized"
        } catch GoogleMapsNavigationSessionManagerError.locationPermissionMissing {
            statusMessage = "Location permission missing"
        } catch GoogleMapsNavigationSessionManagerError.termsNotAccepted {
            statusMessage = "Terms not accepted"
        } catch {
            statusMessage = "Initialization failed: \(error)"
        }
    }

    private func setDestinations() {
        // Grace Cathedral coordinates from the example
        let destination = GMSNavigationWaypoint(
            location: CLLocationCoordinate2D(latitude: 37.791957, longitude: -122.412529),
            title: "Grace Cathedral"
        )!

        GoogleMapsNavigationSessionManager.shared.setDestinations(
            destinations: [destination]
        ) { routeStatus in
            DispatchQueue.main.async {
                switch routeStatus {
                case .OK:
                    self.routeCalculated = true
                    self.statusMessage = "Route calculated"

                    // Continue with guidance if this was called from initializeNavigationAndGuidance
                    if self.shouldContinueWithGuidance {
                        self.shouldContinueWithGuidance = false
                        self.continueWithGuidanceIfReady()
                    }
                case .internalError:
                    self.statusMessage = "Internal error - try updating SDK"
                case .noRouteFound:
                    self.statusMessage = "No route found to destination"
                case .networkError:
                    self.statusMessage = "Network error"
                case .quotaExceeded:
                    self.statusMessage = "API quota exceeded"
                case .apiKeyNotAuthorized:
                    self.statusMessage = "API key not authorized"
                case .canceled:
                    self.statusMessage = "Route calculation canceled"
                case .duplicateWaypointsError:
                    self.statusMessage = "Duplicate waypoints in request"
                case .noWaypointsError:
                    self.statusMessage = "No waypoints provided"
                case .locationUnavailable:
                    self.statusMessage = "Location unavailable"
                case .waypointError:
                    self.statusMessage = "Waypoint error - invalid Place ID"
                case .travelModeUnsupported:
                    self.statusMessage = "Travel mode not supported"
                @unknown default:
                    self.statusMessage = "Unknown route error: \(routeStatus)"
                }
            }
        }
    }

    private func stopGuidance() {
        do {
            try GoogleMapsNavigationSessionManager.shared.stopGuidance()
            guidanceRunning = try GoogleMapsNavigationSessionManager.shared.isGuidanceRunning()
            statusMessage = !guidanceRunning ? "Guidance stopped" : "Failed to stop guidance"
        } catch {
            statusMessage = "Failed to stop guidance: \(error)"
        }
    }

    // Initialize navigation and guidance in sequence - reproduces crash
    private func initializeNavigationAndGuidance() {
        // Check location permission first
        guard
            locationPermissionStatus == .authorizedWhenInUse
                || locationPermissionStatus == .authorizedAlways
        else {
            statusMessage = "Location permission required"
            return
        }

        statusMessage = "Starting initialization sequence"

        // Step 1: Check terms
        if !GoogleMapsNavigationSessionManager.shared.areTermsAccepted() {
            statusMessage = "Terms not accepted"
            return
        }

        // Step 2: Initialize session
        do {
            try GoogleMapsNavigationSessionManager.shared.createNavigationSession(true)
            sessionInitialized = true
            statusMessage = "Session initialized, setting destinations"

            // Step 3: Set destinations using the existing method with proper error handling
            shouldContinueWithGuidance = true
            setDestinations()

            // The setDestinations method will update routeCalculated state
            // We'll continue guidance in a separate check after route calculation

        } catch {
            statusMessage = "Session initialization failed: \(error)"
        }
    }

    // Helper method to continue with guidance after route calculation
    private func continueWithGuidanceIfReady() {
        guard routeCalculated && !guidanceRunning else { return }

        statusMessage = "Route calculated, starting guidance"

        // Start guidance immediately - this is where crash typically occurs
        do {
            try GoogleMapsNavigationSessionManager.shared.startGuidance()
            let isRunning = try GoogleMapsNavigationSessionManager.shared.isGuidanceRunning()
            guidanceRunning = isRunning
            statusMessage = isRunning ? "Guidance started successfully" : "Guidance failed to start"
        } catch {
            statusMessage = "❌ CRASH OR ERROR starting guidance: \(error)"
        }
    }

    private func reset() {
        do {
            try GoogleMapsNavigationSessionManager.shared.cleanup()
        } catch {
            print("[CrashTestView] ❌ Cleanup error: \(error)")
        }

        // Reset terms acceptance using the SDK method
        do {
            try GoogleMapsNavigationSessionManager.shared.resetTermsAccepted()
        } catch {
            print("[CrashTestView] ❌ Terms reset error: \(error)")
        }

        termsAccepted = nil
        sessionInitialized = false
        routeCalculated = false
        guidanceRunning = false
        shouldContinueWithGuidance = false
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
