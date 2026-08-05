import MapKit
import SwiftUI

/// The map confirmation sheet presented after a gym photo is recognized. The
/// device's converged location seeds the map, gym POIs around it are pinned,
/// and the user confirms one (or falls back to the raw current location). No
/// keyboard unless the user explicitly opens search.
@MainActor
struct GymLocationPicker: View {
    let snapshot: GymLocationSnapshot
    let onConfirm: (GymLocationSnapshot) -> Void
    let onDismiss: () -> Void

    /// Top POI around the device, auto-highlighted as the default choice.
    @State private var pois: [GymPOI] = []
    @State private var selectedPOI: GymPOI?
    @State private var isSearchOpen = false
    @State private var searchText = ""
    @State private var isResolving = true
    @State private var searchWork: Task<Void, Never>?

    private let resolver = GymPOIResolver()

    private var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude)
    }

    /// The camera frame centered on the device, wide enough to show nearby gyms.
    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                map
                bottomCard
            }
            .navigationTitle("确认训练地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { onDismiss() }
                        .font(Theme.caption)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    searchButton
                }
            }
            .searchable(text: $searchText, isPresented: $isSearchOpen, prompt: "搜索健身房")
            .onChange(of: searchText) { _, newValue in
                runSearch(newValue)
            }
            .task { await load() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Map

    private var map: some View {
        Map(initialPosition: .region(region)) {
            // Device location pin — the fallback the user can pick directly.
            Annotation("", coordinate: center) {
                currentLocationBadge
            }

            ForEach(pois) { poi in
                Annotation("", coordinate: poi.coordinate) {
                    poiMarker(for: poi)
                        .onTapGesture {
                            selectedPOI = poi
                        }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .top) {
            if isResolving {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在查找附近健身房…")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.mainText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule(style: .continuous).fill(Theme.surface))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                .padding(.top, 8)
            }
        }
    }

    private var currentLocationBadge: some View {
        Circle()
            .fill(Theme.primary)
            .frame(width: 16, height: 16)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(radius: 3)
    }

    private func poiMarker(for poi: GymPOI) -> some View {
        let isSelected = selectedPOI?.id == poi.id
        return ZStack {
            Capsule(style: .continuous)
                .fill(isSelected ? Theme.primary : Theme.surface)
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            HStack(spacing: 4) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Theme.primary)
                Text(poi.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Theme.mainText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
        }
    }

    // MARK: - Bottom card

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selected = selectedPOI {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.name)
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)
                    if let address = selected.address, !address.isEmpty {
                        Text(address)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Text("距离约 \(Format.meters(selected.distanceFromDevice))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.primary)
                }
            } else {
                Text(isResolving ? "正在查找附近健身房…" : "未找到附近的健身房，可确认当前定位。")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            PrimaryButton(
                title: selectedPOI != nil ? "确认 \(selectedPOI!.name)" : "确认当前定位"
            ) {
                confirm(selectedPOI)
            }
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 16)
        .background(Theme.background)
    }

    // MARK: - Toolbar

    private var searchButton: some View {
        Button {
            isSearchOpen.toggle()
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primary)
        }
        .accessibilityLabel("搜索健身房")
    }

    // MARK: - Actions

    private func load() async {
        isResolving = true
        let resolved = await resolver.resolveGyms(near: center)
        pois = resolved
        selectedPOI = pois.first
        isResolving = false
    }

    private func runSearch(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isResolving = true
        searchWork?.cancel()
        searchWork = Task {
            // Debounce keystrokes: only the last search wins.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let resolved = await resolver.resolveGyms(near: center, query: query)
            if isSearchOpen {
                pois = resolved
                selectedPOI = pois.first
            }
            isResolving = false
        }
    }

    private func confirm(_ poi: GymPOI?) {
        var confirmed = snapshot
        if let poi {
            confirmed = GymLocationSnapshot(
                latitude: poi.latitude,
                longitude: poi.longitude,
                horizontalAccuracy: 0,
                placeName: poi.displayName,
                poi: poi,
                capturedAt: snapshot.capturedAt
            )
        }
        onConfirm(confirmed)
    }
}
