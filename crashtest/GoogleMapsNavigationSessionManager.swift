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
import Foundation
import GoogleNavigation

// Keep in sync with GoogleMapsNavigationSessionManager.kt
enum GoogleMapsNavigationSessionManagerError: Error {
    case initializeFailure
    case termsNotAccepted
    case termsResetNotAllowed
    case locationPermissionMissing
    case notAuthorized
    case sessionNotInitialized
    case noViewRegistry
    case viewNotFound
    case notSupported
}

class GoogleMapsNavigationSessionManager: NSObject {
    static let shared = GoogleMapsNavigationSessionManager()

    private var _session: GMSNavigationSession?

    func getNavigator() throws -> GMSNavigator {
        guard let _session else {
            throw GoogleMapsNavigationSessionManagerError.sessionNotInitialized
        }
        guard let navigator = _session.navigator
        else { throw GoogleMapsNavigationSessionManagerError.termsNotAccepted }
        return navigator
    }

    func getSession() throws -> GMSNavigationSession {
        guard let _session else {
            throw GoogleMapsNavigationSessionManagerError.sessionNotInitialized
        }
        return _session
    }

    // Create a navigation session and initializes listeners.
    // If navigator is already created, only re-initialize listeners.
    func createNavigationSession(_ abnormalTerminationReportingEnabled: Bool) throws {
        print("[SessionManager] Starting createNavigationSession")

        // Align API behavior with Android:
        // Check the terms and conditions before the location permission check below.
        print("[SessionManager] Checking terms acceptance")
        if !areTermsAccepted() {
            print("[SessionManager] ❌ Terms not accepted")
            throw GoogleMapsNavigationSessionManagerError.termsNotAccepted
        }
        print("[SessionManager] ✅ Terms accepted")

        // Enable or disable abnormal termination reporting.
        print(
            "[SessionManager] Setting abnormal termination reporting: \(abnormalTerminationReportingEnabled)"
        )
        GMSServices.setAbnormalTerminationReportingEnabled(abnormalTerminationReportingEnabled)

        // Align API behavior with Android:
        // Fail the session creation if the location permission hasn't been accepted.
        print("[SessionManager] Checking location permissions")
        let locationManager = CLLocationManager()
        let status = locationManager.authorizationStatus
        print("[SessionManager] Location permission status: \(status.rawValue)")
        if status != .authorizedAlways, status != .authorizedWhenInUse {
            print("[SessionManager] ❌ Location permission missing")
            throw GoogleMapsNavigationSessionManagerError.locationPermissionMissing
        }
        print("[SessionManager] ✅ Location permission granted")

        // Try to create a session.
        print("[SessionManager] Creating navigation session")
        if _session == nil {
            guard let session = GMSNavigationServices.createNavigationSession() else {
                // According API documentation the only reason a nil session is ever returned
                // is due to terms and conditions not having been accepted yet.
                //
                // At this point should not happen due to the earlier check.
                print("[SessionManager] ❌ Failed to create navigation session - terms not accepted")
                throw GoogleMapsNavigationSessionManagerError.termsNotAccepted
            }
            _session = session
            print("[SessionManager] ✅ Navigation session created")
        } else {
            print("[SessionManager] Reusing existing navigation session")
        }

        print("[SessionManager] Configuring session")
        _session?.isStarted = true
        _session?.navigator?.add(self)
        _session?.navigator?.stopGuidanceAtArrival = false

        // Disable time udpate callbacks.
        _session?.navigator?.timeUpdateThreshold = TimeInterval.infinity

        // Disable distance update callbacks.
        _session?.navigator?.distanceUpdateThreshold = CLLocationDistanceMax

        _session?.roadSnappedLocationProvider?.add(self)
        print("[SessionManager] ✅ Session configuration complete")
    }

    func isInitialized() -> Bool {
        _session?.navigator != nil
    }

    func cleanup() throws {
        if _session == nil {
            throw GoogleMapsNavigationSessionManagerError.sessionNotInitialized
        }
        _session?.locationSimulator?.stopSimulation()
        _session?.navigator?.clearDestinations()
        _session?.roadSnappedLocationProvider?.remove(self)
        _session?.navigator?.isGuidanceActive = false
        _session?.isStarted = false
        _session = nil
    }

    func showTermsAndConditionsDialog(
        title: String, companyName: String,
        shouldOnlyShowDriverAwarenessDisclaimer: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        GMSNavigationServices
            .shouldOnlyShowDriverAwarenesssDisclaimer = shouldOnlyShowDriverAwarenessDisclaimer
        GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(
            withTitle: title, companyName: companyName
        ) { termsAccepted in
            completion(termsAccepted)
        }
    }

    func areTermsAccepted() -> Bool {
        GMSNavigationServices.areTermsAndConditionsAccepted()
    }

    func resetTermsAccepted() throws {
        if _session != nil {
            throw GoogleMapsNavigationSessionManagerError.termsResetNotAllowed
        }

        GMSNavigationServices.resetTermsAndConditionsAccepted()
    }

    /// Navigation.
    func startGuidance() throws {
        print("[SessionManager] Starting guidance")
        try getNavigator().isGuidanceActive = true
        print("[SessionManager] ✅ Guidance started successfully")
    }

    func stopGuidance() throws {
        print("[SessionManager] Stopping guidance")
        try getNavigator().isGuidanceActive = false
        print("[SessionManager] ✅ Guidance stopped successfully")
    }

    func isGuidanceRunning() throws -> Bool {
        try getNavigator().isGuidanceActive
    }

    func setDestinations(
        destinations: [GMSNavigationWaypoint],
        completion: @escaping (GMSRouteStatus) -> Void
    ) {
        print("[SessionManager] Setting destinations")
        do {
            // Set destinations for navigator.
            print("[SessionManager] Setting \(destinations.count) destination(s)")
            try getNavigator()
                .setDestinations(destinations) { routeStatus in
                    print(
                        "[SessionManager] Route calculation completed with status: \(routeStatus)")
                    completion(routeStatus)
                }
        } catch {
            print("[SessionManager] ❌ Error setting destinations: \(error)")
        }
    }
}

extension GoogleMapsNavigationSessionManager: GMSRoadSnappedLocationProviderListener {
    func locationProvider(
        _ locationProvider: GMSRoadSnappedLocationProvider,
        didUpdate location: CLLocation
    ) {
        // Required for protocol compliance
    }
}

extension GoogleMapsNavigationSessionManager: GMSNavigatorListener {
    func navigator(
        _ navigator: GMSNavigator,
        didUpdate speedAlertSeverity: GMSNavigationSpeedAlertSeverity,
        speedingPercentage percentageAboveLimit: CGFloat
    ) {
        // Required for protocol compliance
    }

    func navigator(_ navigator: GMSNavigator, didArriveAt waypoint: GMSNavigationWaypoint) {
        // Required for protocol compliance
    }

    func navigatorDidChangeRoute(_ navigator: GMSNavigator) {
        // Required for protocol compliance
    }

    func navigator(_ navigator: GMSNavigator, didUpdateRemainingTime time: TimeInterval) {
        // Required for protocol compliance
    }

    func navigator(
        _ navigator: GMSNavigator,
        didUpdateRemainingDistance distance: CLLocationDistance
    ) {
        // Required for protocol compliance
    }

    func navigator(
        _ navigator: GMSNavigator,
        didUpdate navInfo: GMSNavigationNavInfo
    ) {
        // Required for protocol compliance
    }

    func navigatorWillPresentPrompt(_ navigator: GMSNavigator) {
        // Required for protocol compliance
    }

    func navigatorDidDismissPrompt(_ navigator: GMSNavigator) {
        // Required for protocol compliance
    }
}
