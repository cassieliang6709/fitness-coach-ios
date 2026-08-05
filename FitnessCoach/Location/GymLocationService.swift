import CoreLocation
import Foundation
import MapKit

/// A POI the user can confirm as "where I trained". Resolution happens on the
/// device via MapKit; the coordinate is only ever stored locally.
struct GymPOI: Sendable, Hashable, Identifiable {
    /// Stable across visits: derived from the POI's own coordinate, which does
    /// not drift the way a GPS fix does.
    let id: String
    let name: String
    let address: String?
    let category: String?
    let latitude: Double
    let longitude: Double
    /// Meters from the converged device fix.
    let distanceFromDevice: CLLocationDistance

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        [name, address].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// Resolves gym POIs around a device coordinate. Abstracted so a Gaode/Maps
/// provider can replace MapKit later without touching the call sites.
protocol GymPOIResolving {
    func resolveGyms(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        query: String
    ) async -> [GymPOI]
}

/// MapKit-backed resolver. Prefers `fitnessCenter` POIs, then any gym-like
/// venue, each tagged with its distance from the device.
struct GymPOIResolver: GymPOIResolving {
    private let radiusMeters: CLLocationDistance

    init(radiusMeters: CLLocationDistance = 400) {
        self.radiusMeters = radiusMeters
    }

    func resolveGyms(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 400,
        query: String = "健身房 健身 健身工作室"
    ) async -> [GymPOI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        guard let response = try? await MKLocalSearch(request: request).start() else {
            return []
        }

        let device = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let items = response.mapItems
            .filter { $0.placemark.location != nil }
            .map { item in
                let distance = device.distance(from: item.placemark.location!)
                return (item, distance)
            }
            .filter { $0.1 <= radius }
            .sorted { $0.1 < $1.1 }

        // Fitness centers outrank generic gym-like POIs so a big box gym in
        // the same block doesn't shadow the smaller studio the user visits.
        func score(_ item: MKMapItem) -> Int {
            if item.pointOfInterestCategory == .fitnessCenter { return 0 }
            return 1
        }

        return
            items
            .sorted { score($0.0) < score($1.0) || (score($0.0) == score($1.0) && $0.1 < $1.1) }
            .map { item, distance in
                let placemark = item.placemark
                let latitude = placemark.coordinate.latitude
                let longitude = placemark.coordinate.longitude
                return GymPOI(
                    id: stableIdentity(
                        for: item,
                        address: address(for: placemark),
                        coordinate: placemark.coordinate
                    ),
                    name: item.name ?? "未命名健身房",
                    address: address(for: placemark),
                    category: item.pointOfInterestCategory?.rawValue,
                    latitude: latitude,
                    longitude: longitude,
                    distanceFromDevice: distance
                )
            }
    }

    private func address(for placemark: MKPlacemark) -> String {
        [placemark.subLocality, placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Prefer MapKit's own venue identity where it is available. The normalized
    /// name/address fallback is stable across GPS fixes, unlike the old 11 m
    /// coordinate rounding. Full coordinates are only an empty-metadata fallback
    /// and are not persisted as the user's device location.
    private func stableIdentity(
        for item: MKMapItem,
        address: String,
        coordinate: CLLocationCoordinate2D
    ) -> String {
        if #available(iOS 18.0, *), let identifier = item.identifier?.rawValue {
            return "mapkit-\(identifier)"
        }

        let normalized = [item.name, address]
            .compactMap {
                $0?.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            }
            .joined(separator: "|")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return String(format: "coordinate-%.6f-%.6f", coordinate.latitude, coordinate.longitude)
        }
        return "venue-\(fnv1a64(normalized.utf8))"
    }

    private func fnv1a64(_ bytes: String.UTF8View) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

/// One converged device location, before the user confirms a POI. `poi` is nil
/// until the picker resolves a candidate; the raw coordinate stays on-device.
struct GymLocationSnapshot: Sendable, Hashable, Identifiable {
    var id: String { "\(capturedAt.timeIntervalSinceReferenceDate)-\(latitude)-\(longitude)" }
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let placeName: String?
    let poi: GymPOI?
    let capturedAt: Date

    var displayName: String? {
        (poi?.displayName ?? placeName)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The database only needs an approximate map point. Keeping the original
    /// coordinate in this transient snapshot lets the picker render accurately,
    /// while storage uses an approximately 111 m grid.
    var coarseCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (latitude * 1_000).rounded() / 1_000,
            longitude: (longitude * 1_000).rounded() / 1_000
        )
    }
}

/// The result of a foreground location + POI lookup. Used by the photo flow to
/// time and render the picker.
struct GymLocationLookup: Sendable, Hashable {
    let snapshot: GymLocationSnapshot?
    let elapsedMilliseconds: Int
}

/// Single-shot GPS fix that converges to street-level precision before it is
/// exposed. The picker owns what the user finally confirms; this service only
/// hands over a best-effort coordinate to seed it.
@MainActor
final class GymLocationService: NSObject {
    static let shared = GymLocationService()

    /// Accuracy threshold that's good enough to stop sampling early.
    private static let goodAccuracy: CLLocationAccuracy = 40
    /// A raw fallback must be good enough for a user to recognize the map point.
    /// POI confirmation is preferred; this bound prevents poor indoor/cached
    /// fixes from becoming a long-lived venue record.
    private static let maximumFallbackAccuracy: CLLocationAccuracy = 100
    private static let maxSamples = 3
    private static let maxWait: Duration = .seconds(4)

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<GymLocationSnapshot?, Never>?
    private var samples: [CLLocation] = []
    private var requestStartedAt: Date?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func currentLocation() async -> GymLocationSnapshot? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }
        let status = manager.authorizationStatus
        let authorized: Bool
        if status == .notDetermined {
            authorized = await requestAuthorization()
        } else {
            authorized = status == .authorizedAlways || status == .authorizedWhenInUse
        }
        guard authorized else { return nil }
        return await converge()
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Keep sampling until the fix is stable enough to seed the map picker, or
    /// give up on a timeout. `requestLocation()` yields one frame; convergence
    /// needs several, so this drives continuous updates directly.
    private func converge() async -> GymLocationSnapshot? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            samples.removeAll()
            requestStartedAt = .now
            manager.startUpdatingLocation()
            Task { [weak self] in
                try? await Task.sleep(for: Self.maxWait)
                self?.finishConvergence()
            }
        }
    }

    private func finishConvergence() {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        requestStartedAt = nil
        manager.stopUpdatingLocation()
        // Keep the tightest fix seen, not the last one — the first frames from
        // a cold GPS start can be hundreds of meters off.
        guard let best = samples.min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }),
            best.horizontalAccuracy >= 0,
            best.horizontalAccuracy <= Self.maximumFallbackAccuracy
        else {
            continuation.resume(returning: nil)
            return
        }
        continuation.resume(
            returning: GymLocationSnapshot(
                latitude: best.coordinate.latitude,
                longitude: best.coordinate.longitude,
                horizontalAccuracy: best.horizontalAccuracy,
                placeName: nil,
                poi: nil,
                capturedAt: .now
            ))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        let status = manager.authorizationStatus
        continuation.resume(
            returning: status == .authorizedAlways || status == .authorizedWhenInUse)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let valid = locations.filter {
            $0.horizontalAccuracy >= 0
                && $0.timestamp >= (requestStartedAt ?? .distantFuture)
        }
        guard let last = valid.last else { return }
        samples.append(last)

        // Stop early on a genuinely tight fix; otherwise let the sample count
        // and the timeout bound how long the GPS runs.
        if last.horizontalAccuracy <= Self.goodAccuracy || samples.count >= Self.maxSamples {
            finishConvergence()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
        requestStartedAt = nil
        manager.stopUpdatingLocation()
    }
}

extension GymLocationService: @preconcurrency CLLocationManagerDelegate {}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
