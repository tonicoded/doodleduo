//
//  LiveDoodleSheet.swift
//  doodleduo
//
//  Created by Codex on 22/11/2025.
//

import SwiftUI
import Combine
import PencilKit

/// Encapsulates the PencilKit canvas so ActivityView can present a clean doodle experience.
struct LiveDoodleSheet: View {
    let partnerName: String
    let accentColor: Color
    let onSend: @Sendable (PKDrawing) async -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var canvasController = DoodleCanvasController()
    @State private var drawing = PKDrawing()
    @State private var isSending = false
    @State private var statusMessage = "connected"
    
    private var canSend: Bool {
        !drawing.bounds.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [CozyPalette.softLavender.opacity(0.3), CozyPalette.lightBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                VStack(spacing: 20) {
                    doodleHeader
                    canvas
                    canvasControls
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Live doodle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var doodleHeader: some View {
        VStack(spacing: 6) {
            Text("Sketch together")
                .font(.title2.weight(.semibold))
            Text("Anything you draw is shared live with \(partnerName).")
                .font(.callout)
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text(statusMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
    
    private var canvas: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white)
            DoodleCanvasView(
                drawing: $drawing,
                controller: canvasController,
                onBeginDrawing: notifyDrawingBegan
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            sendOverlayButton
        }
        .padding(.horizontal, 4)
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        .frame(minHeight: 360)
    }
    
    private var canvasControls: some View {
        HStack(spacing: 16) {
            Button {
                drawing = canvasController.undoLastStroke()
                feedback(action: .impact)
                refreshStatus(with: "undo")
            } label: {
                Label("Undo", systemImage: "arrow.uturn.left")
            }
            .buttonStyle(.bordered)
            .disabled(drawing.bounds.isEmpty)
            
            Button(role: .destructive) {
                drawing = canvasController.clearDrawing()
                refreshStatus(with: "cleared")
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(drawing.bounds.isEmpty)
            
            Spacer()
        }
        .font(.callout)
    }
    
    
    private var sendOverlayButton: some View {
        Button {
            Task { await sendDrawing() }
        } label: {
            HStack(spacing: 6) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                Text(isSending ? "Sending" : "Send")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(accentColor))
            .foregroundColor(.white)
        }
        .disabled(!canSend || isSending)
        .padding(16)
    }
    
    private func notifyDrawingBegan() {
        refreshStatus(with: "drawing…")
    }
    
    private func refreshStatus(with action: String) {
        statusMessage = "\(action) · just now"
    }
    
    private func sendDrawing() async {
        guard canSend, !isSending else { return }
        isSending = true
        await onSend(drawing)
        isSending = false
        drawing = canvasController.clearDrawing()
        refreshStatus(with: "sent")
    }
    
    private func feedback(action: FeedbackAction) {
        switch action {
        case .impact:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private enum FeedbackAction {
        case impact
        case success
    }
}

final class DoodleCanvasController: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    fileprivate weak var canvasView: PKCanvasView?
    
    @discardableResult
    func clearDrawing() -> PKDrawing {
        let empty = PKDrawing()
        canvasView?.drawing = empty
        objectWillChange.send()
        return empty
    }
    
    @discardableResult
    func undoLastStroke() -> PKDrawing {
        canvasView?.undoManager?.undo()
        objectWillChange.send()
        return canvasView?.drawing ?? PKDrawing()
    }
    
    func apply(drawing: PKDrawing) {
        canvasView?.drawing = drawing
        objectWillChange.send()
    }
}

struct DoodleCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @ObservedObject var controller: DoodleCanvasController
    var onBeginDrawing: (() -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.alwaysBounceVertical = false
        canvas.drawingPolicy = .anyInput
        canvas.isOpaque = false
        canvas.backgroundColor = UIColor.clear
        canvas.drawing = drawing
        controller.canvasView = canvas
        context.coordinator.attachToolPicker(to: canvas)
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        controller.canvasView = uiView
        context.coordinator.attachToolPicker(to: uiView)
    }
    
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let parent: DoodleCanvasView
        private let toolPicker = PKToolPicker()
        
        init(parent: DoodleCanvasView) {
            self.parent = parent
        }
        
        func attachToolPicker(to canvas: PKCanvasView) {
            toolPicker.addObserver(canvas)
            toolPicker.setVisible(true, forFirstResponder: canvas)
            DispatchQueue.main.async {
                canvas.becomeFirstResponder()
            }
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onBeginDrawing?()
        }
    }
}
