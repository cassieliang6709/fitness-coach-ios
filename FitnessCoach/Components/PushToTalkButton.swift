import SwiftUI
import UIKit

/// Press and hold to talk, release to send, slide up to cancel.
///
/// The finger marks both ends of the turn, which is the whole point: a tapped
/// mic has to infer from silence when the user is done, and that inference is
/// what cut people off mid-thought. Holding removes the guess entirely.
///
/// The gesture lives here and the visual state is passed down, so the drawing
/// code stays free of recognizer lifecycle.
struct PushToTalkButton: View {
    @Bindable var thread: CoachThread
    /// Diameter of the solid dial. The coach pages use the gym-sized default;
    /// the home bar passes a tap-target-sized one so the tab bar still fits.
    var diameter: CGFloat = 66

    /// How far the finger has to travel up before releasing discards the turn.
    private let cancelDistance: CGFloat = 60

    private var holding: Bool { thread.isHolding }
    private var willCancel: Bool { thread.isCancelingHold }

    var body: some View {
        PushToTalkDial(holding: holding, willCancel: willCancel, diameter: diameter)
            .gesture(
                // `minimumDistance: 0` is what makes `onChanged` fire on touch
                // down rather than on the first movement.
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !holding { press() }
                        let shouldCancel = value.translation.height < -cancelDistance
                        if shouldCancel != willCancel {
                            thread.isCancelingHold = shouldCancel
                            Haptics.play(shouldCancel ? .warning : .light)
                        }
                    }
                    .onEnded { _ in release() }
            )
            // A raw gesture carries no button trait, so without this the
            // control disappears from VoiceOver's button rotor entirely.
            // Label kept as the old one so assistive tech — and the UI tests
            // that query it — still find it; the gesture is in the hint.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("开始语音")
            .accessibilityHint("按住录音，松开发送，上滑取消")
            // Deliberately not `.disabled` while the coach replies: disabling a
            // view mid-gesture cancels the gesture, and the press is already a
            // no-op in that state. The dial dims instead.
            .opacity(thread.isBusy && !holding ? 0.45 : 1)
    }

    private func press() {
        thread.isHolding = true
        thread.isCancelingHold = false
        Haptics.play(.light)
        thread.beginHold()
    }

    private func release() {
        let discard = willCancel
        // A press that ended before the permission dialog was answered has no
        // recording to end, but the flags still have to come down.
        thread.isHolding = false
        thread.isCancelingHold = false

        if discard {
            thread.cancelHold()
        } else {
            Haptics.play(.success)
            thread.endHold()
        }
    }
}

/// Pure visual. Knows nothing about speech — it renders two booleans.
private struct PushToTalkDial: View {
    let holding: Bool
    let willCancel: Bool
    let diameter: CGFloat

    @State private var breathing = false

    private var tint: Color { willCancel ? Theme.warning : Theme.primary }
    /// Rings sit outside the dial, so the touch area is larger than the paint.
    private var reach: CGFloat { diameter * 96 / 66 }

    var body: some View {
        ZStack {
            if holding {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: reach, height: reach)
                    .scaleEffect(breathing ? 1.08 : 0.92)
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: reach * 0.85, height: reach * 0.85)
                    .scaleEffect(breathing ? 1.05 : 0.95)
            }

            Circle()
                .fill(holding ? tint : Theme.primary)
                .frame(width: diameter, height: diameter)
                .scaleEffect(holding && breathing ? 1.03 : 1)

            Image(systemName: willCancel ? "xmark" : "mic.fill")
                .font(.system(size: diameter * 0.36, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: reach, height: reach)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.15), value: willCancel)
        .onChange(of: holding) { _, isHolding in
            if isHolding {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { breathing = false }
            }
        }
    }
}

/// The hint above the button. Slide-to-cancel is only discoverable if it's
/// spelled out while the finger is already down.
struct PushToTalkHint: View {
    let holding: Bool
    let willCancel: Bool
    let transcript: String

    var body: some View {
        if holding {
            VStack(spacing: 4) {
                Text(willCancel ? "松开取消" : "松开发送 · 上滑取消")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(willCancel ? Theme.warning : Theme.primary)

                if !transcript.isEmpty {
                    Text(transcript)
                        .font(Theme.body)
                        .foregroundStyle(Theme.mainText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .transition(.opacity)
        }
    }
}

enum Haptics {
    enum Kind { case light, warning, success }

    static func play(_ kind: Kind) {
        switch kind {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
