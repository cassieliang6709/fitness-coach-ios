import SwiftUI

/// Poses from the IP sheet. Names map 1:1 to image sets in Assets.xcassets,
/// so dropping the artwork in replaces the vector fallback with no code change.
enum MascotPose: String, CaseIterable {
    case idle  // 01 idle standing
    case wave  // 02 waving hello
    case point  // 03 pointing forward
    case thumbsUp = "thumbs-up"  // 04 thumbs up
    case drink  // 05 drinking water
    case jogging  // 06 light jogging
    case stretch  // 07 warm-up stretch
    case dumbbell  // 08 holding dumbbell
    case listening  // 09 listening / coach mode
    case celebration  // 10 celebration / success

    var assetName: String { "mascot-\(rawValue)" }
}

/// The coach IP. Uses the real artwork when the matching image set has been
/// filled in; otherwise draws a vector stand-in of the same character so the
/// app is never missing a face.
struct Mascot: View {
    var pose: MascotPose = .idle
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let artwork = UIImage(named: pose.assetName) {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
            } else {
                VectorMascot(pose: pose, size: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Vector fallback

/// Shape-only rendition of the same character: white body, orange cap,
/// dot eyes. Detail is added progressively — at avatar sizes the belt bag and
/// pose accents would just read as smudges, so they only appear when large.
private struct VectorMascot: View {
    let pose: MascotPose
    let size: CGFloat

    private var ink: Color { Theme.mascotInk }
    private var showsDetail: Bool { size >= 56 }
    private var showsAccent: Bool { size >= 44 }

    var body: some View {
        ZStack {
            if showsDetail { feet }
            bodyBlob
            if showsDetail { belt }
            face
            cap
            if showsAccent { accent }
        }
        .frame(width: size, height: size)
    }

    // MARK: Body

    private var feet: some View {
        HStack(spacing: size * 0.1) {
            foot
            foot
        }
        .offset(y: size * 0.44)
    }

    private var foot: some View {
        Ellipse()
            .fill(.white)
            .overlay(Ellipse().strokeBorder(ink.opacity(0.7), lineWidth: size * 0.028))
            .frame(width: size * 0.19, height: size * 0.11)
    }

    private var bodyBlob: some View {
        Ellipse()
            .fill(.white)
            .overlay(Ellipse().strokeBorder(ink.opacity(0.7), lineWidth: size * 0.035))
            .frame(width: size * 0.76, height: size * 0.74)
            .offset(y: size * 0.1)
    }

    private var belt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
                .fill(ink)
                .frame(width: size * 0.62, height: size * 0.065)
                .rotationEffect(.degrees(-10))

            RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
                .fill(ink)
                .frame(width: size * 0.24, height: size * 0.13)
                .offset(x: -size * 0.03, y: size * 0.02)
        }
        .offset(y: size * 0.28)
    }

    // MARK: Face

    private var face: some View {
        ZStack {
            if showsDetail {
                HStack(spacing: size * 0.28) {
                    blush
                    blush
                }
                .offset(y: size * 0.1)
            }

            HStack(spacing: size * 0.15) {
                eye
                eye
            }
            .offset(y: size * 0.02)

            Ellipse()
                .fill(ink.opacity(0.8))
                .frame(width: size * 0.055, height: size * 0.038)
                .offset(y: size * 0.13)
        }
    }

    private var eye: some View {
        Ellipse()
            .fill(ink)
            .frame(width: size * 0.075, height: size * 0.095)
    }

    private var blush: some View {
        Ellipse()
            .fill(Theme.primary.opacity(0.22))
            .frame(width: size * 0.1, height: size * 0.055)
    }

    // MARK: Cap

    private var cap: some View {
        ZStack {
            // Crown: top half of a circle, flat edge resting on the head.
            Circle()
                .trim(from: 0.5, to: 1)
                .fill(Theme.primary)
                .frame(width: size * 0.72, height: size * 0.72)
                .offset(y: -size * 0.06)

            // Brim, swept to one side like the reference sheet.
            Capsule(style: .continuous)
                .fill(Theme.primary)
                .frame(width: size * 0.42, height: size * 0.09)
                .offset(x: size * 0.27, y: -size * 0.08)

            // Button on the crown.
            Capsule(style: .continuous)
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.07, height: size * 0.08)
                .offset(y: -size * 0.36)
        }
    }

    // MARK: Pose accents

    @ViewBuilder
    private var accent: some View {
        switch pose {
        case .celebration:
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundStyle(Theme.primary)
                .offset(x: size * 0.36, y: -size * 0.28)
        case .dumbbell:
            Image(systemName: "dumbbell.fill")
                .font(.system(size: size * 0.18))
                .foregroundStyle(ink)
                .offset(x: -size * 0.36, y: size * 0.1)
        case .jogging:
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.11))
                .foregroundStyle(Color(hex: 0x7FB8E8))
                .offset(x: size * 0.36, y: -size * 0.14)
        case .listening:
            Image(systemName: "music.note")
                .font(.system(size: size * 0.14, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .offset(x: size * 0.35, y: -size * 0.24)
        default:
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            ForEach(MascotPose.allCases, id: \.self) { pose in
                Mascot(pose: pose, size: 26)
            }
        }
        HStack(spacing: 16) {
            Mascot(pose: .dumbbell, size: 56)
            Mascot(pose: .jogging, size: 56)
            Mascot(pose: .celebration, size: 56)
            Mascot(pose: .listening, size: 56)
        }
    }
    .padding()
}
