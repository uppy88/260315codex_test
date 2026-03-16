import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @State private var handMagicController = HandMagicController()

    var body: some View {
        RealityView { content in
            content.add(handMagicController.rootEntity)
            await handMagicController.startSession()
        } update: { _ in
            handMagicController.updateEmittersIfNeeded()
        }
        .overlay(alignment: .top) {
            Text("右手を開くと雪の結晶 / 左手を開くと流れ星")
                .font(.headline)
                .padding(12)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 18)
        }
        .task {
            await handMagicController.processHandUpdates()
        }
    }
}

@Observable
@MainActor
final class HandMagicController {
    let rootEntity = Entity()

    private let arSession = ARKitSession()
    private let handTracking = HandTrackingProvider()

    private let rightHandMagic = MagicEmitterEntity(style: .snowflake)
    private let leftHandMagic = MagicEmitterEntity(style: .shootingStar)

    private(set) var rightPalmOpen = false
    private(set) var leftPalmOpen = false

    init() {
        rootEntity.addChild(rightHandMagic)
        rootEntity.addChild(leftHandMagic)
    }

    func startSession() async {
        guard HandTrackingProvider.isSupported else {
            print("Hand tracking is not available on this device.")
            return
        }

        do {
            try await arSession.run([handTracking])
        } catch {
            print("Failed to run ARKit session: \(error.localizedDescription)")
        }
    }

    func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            guard let skeleton = update.anchor.handSkeleton else { continue }

            let wristTransform = update.anchor.originFromAnchorTransform * skeleton.joint(.wrist).anchorFromJointTransform

            let indexTip = worldPosition(for: .indexFingerTip, skeleton: skeleton, anchor: update.anchor)
            let middleTip = worldPosition(for: .middleFingerTip, skeleton: skeleton, anchor: update.anchor)
            let ringTip = worldPosition(for: .ringFingerTip, skeleton: skeleton, anchor: update.anchor)
            let littleTip = worldPosition(for: .littleFingerTip, skeleton: skeleton, anchor: update.anchor)
            let thumbTip = worldPosition(for: .thumbTip, skeleton: skeleton, anchor: update.anchor)

            let wristPos = SIMD3<Float>(wristTransform.columns.3.x, wristTransform.columns.3.y, wristTransform.columns.3.z)
            let openness = averageDistance(from: wristPos, to: [indexTip, middleTip, ringTip, littleTip, thumbTip])
            let isOpen = openness > 0.085

            if update.anchor.chirality == .right {
                rightPalmOpen = isOpen
                rightHandMagic.setWorldPosition(indexTip)
                rightHandMagic.setEnabled(isOpen)
            } else {
                leftPalmOpen = isOpen
                leftHandMagic.setWorldPosition(indexTip)
                leftHandMagic.setEnabled(isOpen)
            }
        }
    }

    func updateEmittersIfNeeded() {
        rightHandMagic.tickAnimation()
        leftHandMagic.tickAnimation()
    }

    private func worldPosition(
        for jointName: HandSkeleton.JointName,
        skeleton: HandSkeleton,
        anchor: HandAnchor
    ) -> SIMD3<Float> {
        let jointTransform = anchor.originFromAnchorTransform * skeleton.joint(jointName).anchorFromJointTransform
        return SIMD3<Float>(jointTransform.columns.3.x, jointTransform.columns.3.y, jointTransform.columns.3.z)
    }

    private func averageDistance(from origin: SIMD3<Float>, to points: [SIMD3<Float>]) -> Float {
        guard !points.isEmpty else { return 0 }
        let total = points.reduce(Float.zero) { partial, point in
            partial + simd_distance(origin, point)
        }
        return total / Float(points.count)
    }
}

@MainActor
final class MagicEmitterEntity: Entity {
    enum Style {
        case snowflake
        case shootingStar

        var tint: UIColor {
            switch self {
            case .snowflake: return .systemTeal
            case .shootingStar: return .systemYellow
            }
        }
    }

    private let emitter = ParticleEmitterComponent.Presets.magic
    private let trail = ModelEntity(mesh: .generateSphere(radius: 0.01))
    private let style: Style
    private var wobble: Float = 0

    init(style: Style) {
        self.style = style
        super.init()

        trail.model?.materials = [SimpleMaterial(color: style.tint, isMetallic: true)]
        addChild(trail)

        var configuredEmitter = emitter
        configuredEmitter.mainEmitter.color = .single(style.tint)
        configuredEmitter.mainEmitter.birthRate = 180
        configuredEmitter.emissionDirection = .outward
        configuredEmitter.speed = 0.14

        components.set(configuredEmitter)
        isEnabled = false
    }

    required init() {
        fatalError("init() has not been implemented")
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func setWorldPosition(_ position: SIMD3<Float>) {
        setPosition(position, relativeTo: nil)
    }

    func tickAnimation() {
        guard isEnabled else { return }
        wobble += 0.04

        switch style {
        case .snowflake:
            trail.position.y = 0.008 * sin(wobble)
        case .shootingStar:
            trail.position.x = 0.012 * cos(wobble)
            trail.position.z = 0.012 * sin(wobble)
        }
    }
}
