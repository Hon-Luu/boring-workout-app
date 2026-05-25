import SwiftUI
import AVFoundation

// MARK: - QR Payload

private struct QRRoutinePayload: Decodable {
    let bw_version: Int
    let name: String
    let exercises: [QRExercisePayload]
}

private struct QRExercisePayload: Decodable {
    let name: String
    let sets: Int
    let reps: Int
}

// MARK: - Scanner View (sheet)

struct QRRoutineScannerView: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var scanResult: ScanState = .scanning
    @State private var importedRoutine: WorkoutTemplate? = nil

    enum ScanState {
        case scanning, processing, success(WorkoutTemplate), error(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HONTheme.background.ignoresSafeArea()

                switch scanResult {
                case .scanning, .processing:
                    CameraPreviewView { code in
                        handleScan(code)
                    }
                    .ignoresSafeArea()

                    scanOverlay

                case .success(let routine):
                    successView(routine)

                case .error(let msg):
                    errorView(msg)
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(HONTheme.textPrimary)
                }
            }
        }
    }

    // MARK: Overlay

    private var scanOverlay: some View {
        VStack {
            Spacer()
            Text("Point your camera at the QR code\ngenerated on the H.O.N website")
                .font(.callout)
                .foregroundStyle(HONTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
        }
    }

    // MARK: Success

    private func successView(_ routine: WorkoutTemplate) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(HONTheme.positive)

            VStack(spacing: 6) {
                Text("Routine Imported!")
                    .font(.title2).bold()
                    .foregroundStyle(HONTheme.textPrimary)
                Text("\"\(routine.name)\"")
                    .font(.title3)
                    .foregroundStyle(HONTheme.textPrimary.opacity(0.8))
                Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(HONTheme.textPrimary.opacity(0.6))
            }

            VStack(spacing: 12) {
                ForEach(routine.exercises) { ex in
                    HStack {
                        Text(ex.exercise.name)
                            .foregroundStyle(HONTheme.textPrimary)
                        Spacer()
                        Text("\(ex.targetSets)×\(ex.targetReps)")
                            .foregroundStyle(HONTheme.textPrimary.opacity(0.6))
                            .font(.subheadline.monospacedDigit())
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
            .background(HONTheme.textPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)

            Button("Done") { dismiss() }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(HONTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
        }
        .padding(.top, 32)
    }

    // MARK: Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(HONTheme.warning)

            Text("Import Failed")
                .font(.title2).bold()
                .foregroundStyle(HONTheme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(HONTheme.textPrimary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 12) {
                Button("Try Again") { scanResult = .scanning }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(HONTheme.textPrimary.opacity(0.15))
                    .foregroundStyle(HONTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Cancel") { dismiss() }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(HONTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Parse

    private func handleScan(_ rawCode: String) {
        guard case .scanning = scanResult else { return }
        scanResult = .processing

        guard let data = rawCode.data(using: .utf8),
              let payload = try? JSONDecoder().decode(QRRoutinePayload.self, from: data),
              payload.bw_version == 1
        else {
            scanResult = .error("This QR code doesn't appear to be an H.O.N routine. Make sure you scanned the right code.")
            return
        }

        let templateExercises: [TemplateExercise] = payload.exercises.map { qe in
            let matched = store.exercises.first {
                $0.name.localizedCaseInsensitiveCompare(qe.name) == .orderedSame
            } ?? store.exercises.first {
                $0.name.localizedCaseInsensitiveContains(qe.name) ||
                qe.name.localizedCaseInsensitiveContains($0.name)
            } ?? Exercise(
                id: UUID(),
                name: qe.name,
                bodyRegion: .chest,
                equipment: .barbell,
                isCompound: true,
                movementPattern: .horizontalPush
            )
            return TemplateExercise(
                exercise: matched,
                targetSets: max(1, qe.sets),
                targetReps: max(1, qe.reps)
            )
        }

        var routine = WorkoutTemplate()
        routine.name = payload.name
        routine.exercises = templateExercises
        store.addOrUpdateRoutine(routine)

        scanResult = .success(routine)
    }
}

// MARK: - AVFoundation Camera Preview

private struct CameraPreviewView: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeUIView(context: Context) -> CameraView {
        let view = CameraView()
        view.onScan = onScan
        view.startSession()
        return view
    }

    func updateUIView(_ uiView: CameraView, context: Context) {}

    static func dismantleUIView(_ uiView: CameraView, coordinator: ()) {
        uiView.stopSession()
    }
}

final class CameraView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func startSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        // Viewfinder bracket overlay
        let cutout = UIView(frame: CGRect(x: 0, y: 0, width: 240, height: 240))
        cutout.center = CGPoint(x: bounds.midX, y: bounds.midY)
        cutout.layer.borderColor = UIColor(red: 0.941, green: 0.929, blue: 0.910, alpha: 1).cgColor
        cutout.layer.borderWidth = 2
        cutout.layer.cornerRadius = 16
        addSubview(cutout)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        session.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let str = obj.stringValue else { return }
        onScan?(str)
    }
}
