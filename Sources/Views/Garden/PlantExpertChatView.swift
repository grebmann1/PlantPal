import SwiftUI
import UIKit

struct PlantExpertChatView: View {
    let plant: Plant
    let careGuide: CareGuide?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var messages: [PlantExpertChatMessage] = []
    @State private var draft = ""
    @State private var pendingImageData: Data?
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showPhotoSource = false
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @FocusState private var composerFocused: Bool

    private var plantContext: String {
        PlantExpertContext.build(plant: plant, careGuide: careGuide)
    }

    private var welcomeText: String {
        String(
            localized: "Ask anything about watering, light, or \(plant.nickname)’s health. You can also attach a photo."
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Rectangle().fill(theme.separator).frame(height: 1)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            seededWelcome
                                .id("welcome")

                            ForEach(messages) { message in
                                bubble(message)
                                    .id(message.id)
                            }

                            if isSending {
                                typingRow
                                    .id("typing")
                            }

                            if let errorMessage {
                                errorBanner(errorMessage)
                                    .id("error")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: isSending) { _, sending in
                        if sending { scrollToBottom(proxy) }
                    }
                }

                Rectangle().fill(theme.separator).frame(height: 1)
                if let pendingImageData, let uiImage = UIImage(data: pendingImageData) {
                    pendingAttachmentBar(uiImage)
                }
                composer
            }
            .background(theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog("Add a photo", isPresented: $showPhotoSource, titleVisibility: .visible) {
                Button("Take photo") { showCameraPicker = true }
                Button("Choose from library") { showLibraryPicker = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Attach a plant photo so the expert can see what you see.")
            }
            .fullScreenCover(isPresented: $showCameraPicker) {
                ImagePicker(
                    sourceType: .camera,
                    onImage: attach,
                    onDismiss: { showCameraPicker = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibraryPicker) {
                ImagePicker(
                    sourceType: .photoLibrary,
                    onImage: attach,
                    onDismiss: { showLibraryPicker = false }
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FIELD CONSULT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(theme.textTertiary)

            Text("Plant Expert")
                .font(theme.title2Font)
                .foregroundStyle(theme.primary)

            Text(plant.nickname)
                .font(theme.subheadFont)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var seededWelcome: some View {
        HStack(alignment: .top, spacing: 10) {
            expertMark
            Text(welcomeText)
                .font(theme.bodyFont)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(theme.surfaceSunken)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(theme.primary.opacity(0.55))
                .frame(width: 3)
        }
    }

    private func bubble(_ message: PlantExpertChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 36) } else { expertMark }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                if let data = message.imageJPEGData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.radius.md)
                                .stroke(theme.separator, lineWidth: 1)
                        }
                }

                if !message.content.isEmpty {
                    Text(message.content)
                        .font(theme.bodyFont)
                        .foregroundStyle(isUser ? theme.onPrimary : theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isUser ? theme.primary : theme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.radius.md)
                                .stroke(isUser ? Color.clear : theme.separator, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))
                }
            }

            if !isUser { Spacer(minLength: 36) }
        }
    }

    private var expertMark: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.primary)
            .frame(width: 26, height: 26)
            .background(theme.primary.opacity(0.12))
            .clipShape(Circle())
    }

    private var typingRow: some View {
        HStack(spacing: 10) {
            expertMark
            ProgressView()
                .tint(theme.primary)
            Text("Consulting…")
                .font(theme.footnoteFont)
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(theme.footnoteFont)
            .foregroundStyle(theme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(theme.error.opacity(0.10))
            .overlay(alignment: .leading) {
                Rectangle().fill(theme.error).frame(width: 3)
            }
    }

    private func pendingAttachmentBar(_ image: UIImage) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Photo attached")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("Will be sent with your next message")
                    .font(theme.footnoteFont)
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            Button {
                pendingImageData = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(theme.textTertiary)
            }
            .accessibilityLabel("Remove photo")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.surfaceSunken)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                showPhotoSource = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 36, height: 36)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(Circle())
            }
            .disabled(isSending)
            .accessibilityLabel("Attach photo")

            TextField("Ask about this plant…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.surfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.md))

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.onPrimary)
                    .frame(width: 36, height: 36)
                    .background(canSend ? theme.primary : theme.primary.opacity(0.35))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.background)
    }

    private var canSend: Bool {
        guard !isSending else { return false }
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || pendingImageData != nil
    }

    private func attach(_ image: UIImage) {
        let prepared = ImageCompressor.prepareForAI(image)
        guard !prepared.isEmpty else { return }
        pendingImageData = prepared
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData = pendingImageData
        guard (!text.isEmpty || imageData != nil), !isSending else { return }

        draft = ""
        pendingImageData = nil
        errorMessage = nil
        let userMessage = PlantExpertChatMessage(
            role: .user,
            content: text.isEmpty
                ? String(localized: "Please look at this plant photo.")
                : text,
            imageJPEGData: imageData
        )
        messages.append(userMessage)
        isSending = true
        defer { isSending = false }

        do {
            let result = try await AIProxyService.plantExpert(
                messages: messages,
                plantContext: plantContext
            )
            let reply = result.reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reply.isEmpty else {
                errorMessage = String(localized: "The expert returned an empty reply. Try again.")
                return
            }
            messages.append(PlantExpertChatMessage(role: .assistant, content: reply))
        } catch let error as AIProxyError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                if isSending {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                } else if errorMessage != nil {
                    proxy.scrollTo("error", anchor: .bottom)
                }
            }
        }
    }
}
