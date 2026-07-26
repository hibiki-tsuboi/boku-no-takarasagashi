//
//  AppRootView.swift
//  BokuNoTakarasagashi
//

import LocalAuthentication
import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query(sort: \TreasureHunt.updatedAt, order: .reverse)
    private var hunts: [TreasureHunt]

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var destination = AppDestination.title
    @State private var playingHunt: TreasureHunt?
    @State private var isShowingOpeningVideo: Bool
    @State private var hasResolvedInitialSession = false
    @State private var parentAccessIsAuthorized = false
    @State private var isAuthenticatingParent = false
    @State private var parentAccessError: String?
    @StateObject private var musicCoordinator = BackgroundMusicCoordinator()
    @StateObject private var privacyShieldController =
        AppPrivacyShieldWindowController()

    init(automaticallyShowsOpening: Bool = true) {
        _isShowingOpeningVideo = State(
            initialValue: automaticallyShowsOpening
        )
    }

    var body: some View {
        ZStack {
            if hasResolvedInitialSession {
                destinationContent
                    .id(destination)
                    .transition(.opacity)
                    .allowsHitTesting(!isShowingOpeningVideo)
                    .accessibilityHidden(isShowingOpeningVideo)

                if isShowingOpeningVideo {
                    OpeningVideoView(onFinished: finishOpeningVideo)
                        .transition(.opacity)
                        .zIndex(10)
                }

                if destination == .parent, !parentAccessIsAuthorized {
                    privacyShield
                        .zIndex(20)
                }
            } else {
                TreasureBackgroundArtwork(style: .adventureSelection)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.32),
            value: destination
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.32),
            value: isShowingOpeningVideo
        )
        .environmentObject(musicCoordinator)
        .onAppear {
            resumeLockedSessionIfNeeded()
            hasResolvedInitialSession = true
            updateMusic()
            updatePrivacyShield()
        }
        .onChange(of: backgroundMusicTrack) {
            updateMusic()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, destination != .parent {
                resumeLockedSessionIfNeeded()
            }
            if newPhase == .background, destination == .parent {
                parentAccessIsAuthorized = false
                parentAccessError = nil
            }
            updatePrivacyShield()
            if newPhase == .active,
               destination == .parent,
               !parentAccessIsAuthorized {
                requestParentAccess()
            }
            updateMusic()
        }
        .onChange(of: destination) {
            updatePrivacyShield()
        }
        .onChange(of: parentAccessIsAuthorized) {
            updatePrivacyShield()
        }
        .onChange(of: isAuthenticatingParent) {
            updatePrivacyShield()
        }
        .onChange(of: parentAccessError) {
            updatePrivacyShield()
        }
        .onChange(of: playingHunt?.id) {
            updateMusic()
        }
        .onChange(of: lockedHunt?.id) { _, lockedHuntID in
            if lockedHuntID != nil, destination != .parent {
                resumeLockedSessionIfNeeded()
            }
        }
        .fullScreenCover(
            item: $playingHunt,
            onDismiss: resumeLockedSessionIfNeeded
        ) { hunt in
            PlaySessionView(hunt: hunt)
                .environmentObject(musicCoordinator)
        }
        .alert("おうちの人を確認できませんでした", isPresented: parentAccessErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(parentAccessError ?? "もう一度ためしてください。")
        }
        .onDisappear {
            privacyShieldController.hide()
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch destination {
        case .title:
            TitleScreenView(
                resumableHunt: resumableHunt,
                onStart: { show(.adventures) },
                onResume: { playingHunt = $0 },
                onOpenParent: requestParentAccess
            )

        case .adventures:
            AdventureSelectionView(
                hunts: hunts,
                onPlay: { playingHunt = $0 },
                onOpenParent: requestParentAccess,
                onShowTitle: { show(.title) }
            )

        case .parent:
            ContentView(onShowTitle: closeParentDashboard)
                .allowsHitTesting(parentAccessIsAuthorized)
                .accessibilityHidden(!parentAccessIsAuthorized)
        }
    }

    private var privacyShield: some View {
        TreasureBackgroundArtwork(style: .security)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                    Text("おうちの人専用")
                        .font(.title2.bold())
                }
                .foregroundStyle(TreasureTheme.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("おうちの人専用画面はロックされています")
    }

    private var resumableHunt: TreasureHunt? {
        lockedHunt ?? hunts.first { $0.playState == .inProgress }
    }

    private var lockedHunt: TreasureHunt? {
        hunts.first(where: \.isChildModeLocked)
    }

    private var backgroundMusicTrack: BackgroundMusicTrack? {
        guard hasResolvedInitialSession,
              !isShowingOpeningVideo,
              playingHunt == nil else {
            return nil
        }

        switch destination {
        case .title:
            return .title
        case .adventures:
            return .adventureMenu
        case .parent:
            return .parentMenu
        }
    }

    private func updateMusic() {
        musicCoordinator.setBaseTrack(backgroundMusicTrack)
        musicCoordinator.setSceneActive(scenePhase == .active)
    }

    private func resumeLockedSessionIfNeeded() {
        guard playingHunt == nil,
              let lockedHunt else {
            return
        }
        isShowingOpeningVideo = false
        playingHunt = lockedHunt
    }

    private var parentAccessErrorIsPresented: Binding<Bool> {
        Binding(
            get: {
                parentAccessError != nil
                    && !(destination == .parent && !parentAccessIsAuthorized)
            },
            set: { isPresented in
                if !isPresented {
                    parentAccessError = nil
                }
            }
        )
    }

    private func requestParentAccess() {
        guard !isAuthenticatingParent else { return }
        isAuthenticatingParent = true
        parentAccessError = nil

        Task {
            defer {
                isAuthenticatingParent = false
            }

            do {
                try await ParentAccessAuthenticator.authenticate()
                parentAccessIsAuthorized = true
                if destination != .parent {
                    show(.parent)
                }
            } catch let error as LAError where error.code == .userCancel
                || error.code == .appCancel
                || error.code == .systemCancel {
                return
            } catch {
                parentAccessError = error.localizedDescription
            }
        }
    }

    private func closeParentDashboard() {
        parentAccessIsAuthorized = false
        parentAccessError = nil
        if destination == .parent {
            show(.title)
        }
    }

    private var privacyShieldMode: AppPrivacyShieldMode? {
        if scenePhase != .active {
            return .background
        }
        if destination == .parent, !parentAccessIsAuthorized {
            return .parentLocked(
                isAuthenticating: isAuthenticatingParent,
                errorMessage: parentAccessError
            )
        }
        return nil
    }

    private func updatePrivacyShield() {
        privacyShieldController.update(
            mode: privacyShieldMode,
            onUnlock: requestParentAccess,
            onExit: closeParentDashboard
        )
    }

    private func show(_ newDestination: AppDestination) {
        withAnimation(
            reduceMotion ? nil : .easeInOut(duration: 0.28)
        ) {
            destination = newDestination
        }
    }

    private func finishOpeningVideo() {
        withAnimation(
            reduceMotion ? nil : .easeInOut(duration: 0.32)
        ) {
            isShowingOpeningVideo = false
        }
    }
}

private enum AppDestination: Hashable {
    case title
    case adventures
    case parent
}

#Preview {
    AppRootView(automaticallyShowsOpening: false)
        .modelContainer(
            for: [TreasureHunt.self, TreasureStage.self, AdventureRecord.self],
            inMemory: true
        )
}
