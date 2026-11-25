import SwiftUI
import UIKit

enum iOSSidebarSection: String, CaseIterable, Identifiable {
    case library = "Library"
    case playlists = "Playlists"
    case podcasts = "Podcasts"
    case navidrome = "Navidrome"
    case sync = "Sync & Servers"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .library: return "music.note.house.fill"
        case .playlists: return "music.note.list"
        case .podcasts: return "mic.fill"
        case .navidrome: return "antenna.radiowaves.left.and.right"
        case .sync: return "arrow.triangle.2.circlepath"
        }
    }
}

struct RootTabView: View {
    @Environment(iOSEchoStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showNowPlayingSheet = false
    @State private var selectedSection: iOSSidebarSection = .library
    @State private var isKeyboardVisible = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                // Full-width iPad Layout with pinned bottom tab bar + floating Hi-Fi player bar
                ZStack {
                    switch selectedSection {
                    case .library: OfflineLibraryTab()
                    case .playlists: PlaylistsTab()
                    case .podcasts: PodcastsTab()
                    case .navidrome: NavidromeTab()
                    case .sync: SyncAndSettingsTab()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: isKeyboardVisible ? 0 : 6) {
                        if let current = store.player.currentItem {
                            FloatingMiniPlayerBar(item: current) {
                                showNowPlayingSheet = true
                            }
                            .frame(maxWidth: 680)
                            .padding(.horizontal, 16)
                            .padding(.bottom, isKeyboardVisible ? 6 : 0)
                        }

                        // Compact Pinned Bottom Tab Bar for iPad (hidden while keyboard is up so player sits flush above keyboard)
                        if !isKeyboardVisible {
                            HStack(spacing: 0) {
                                ForEach(iOSSidebarSection.allCases) { sec in
                                    let isSelected = selectedSection == sec
                                    Button {
                                        selectedSection = sec
                                    } label: {
                                        VStack(spacing: 2) {
                                            Image(systemName: sec.icon)
                                                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                                            Text(sec == .sync ? "Sync" : sec.rawValue)
                                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                        }
                                        .foregroundStyle(isSelected ? EchoiOSTheme.neoMint : EchoiOSTheme.textMuted)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: 720)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.top, 2)
                            .padding(.bottom, 1)
                            .background(
                                EchoiOSTheme.surface.opacity(0.96)
                                    .ignoresSafeArea(edges: .bottom)
                            )
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(EchoiOSTheme.border)
                                    .frame(height: 0.75)
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: isKeyboardVisible)
                }
                .tint(EchoiOSTheme.neoMint)
            } else {
                // Native iPhone Compact TabView + floating mini player bar
                ZStack(alignment: .bottom) {
                    TabView {
                        OfflineLibraryTab()
                            .tabItem { Label("Library", systemImage: "music.note.house.fill") }

                        PlaylistsTab()
                            .tabItem { Label("Playlists", systemImage: "music.note.list") }

                        PodcastsTab()
                            .tabItem { Label("Podcasts", systemImage: "mic.fill") }

                        NavidromeTab()
                            .tabItem { Label("Navidrome", systemImage: "antenna.radiowaves.left.and.right") }

                        SyncAndSettingsTab()
                            .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
                    }
                    .tint(EchoiOSTheme.neoMint)

                    if let current = store.player.currentItem {
                        FloatingMiniPlayerBar(item: current) {
                            showNowPlayingSheet = true
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, isKeyboardVisible ? 6 : 56)
                        .animation(.easeOut(duration: 0.2), value: isKeyboardVisible)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .sheet(isPresented: $showNowPlayingSheet) {
            NowPlayingSheetView()
        }
    }
}

// MARK: - Tab 1: Offline Synced Library + Mac Full Library Search/Add + Lidarr Order

enum LibrarySearchScope: String, CaseIterable, Identifiable {
    case onDevice = "On Device"
    case macLibrary = "Mac Library"
    case lidarr = "Lidarr"
    var id: String { rawValue }
}

struct OfflineLibraryTab: View {
    @Environment(iOSEchoStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var searchText = ""
    @State private var scope: LibrarySearchScope = .onDevice

    private var filteredAlbums: [SyncedAlbumGroup] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.albums }
        return store.albums.filter { $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q) }
    }

    private var filteredTracks: [SyncedTrack] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return store.tracks.filter {
            $0.title.lowercased().contains(q)
                || $0.artist.lowercased().contains(q)
                || $0.album.lowercased().contains(q)
        }
    }

    private var searchPlaceholder: String {
        switch scope {
        case .onDevice: return "Filter offline albums & tracks..."
        case .macLibrary: return "Search full Mac library to add tracks/albums..."
        case .lidarr: return "Search Lidarr to order new albums or tracks..."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Always-visible Unified Search Bar + Scope Picker (On Device / Mac Library / Lidarr)
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: scope == .lidarr ? "arrow.down.circle.fill" : (scope == .macLibrary ? "desktopcomputer" : "magnifyingglass"))
                                .font(.system(size: sizeClass == .regular ? 16 : 14, weight: .semibold))
                                .foregroundStyle(scope == .lidarr ? EchoiOSTheme.hiResGold : (scope == .macLibrary ? EchoiOSTheme.neoCyan : EchoiOSTheme.neoMint))

                            TextField(searchPlaceholder, text: $searchText)
                                .font(.system(size: sizeClass == .regular ? 17 : 15))
                                .foregroundStyle(EchoiOSTheme.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                                .onSubmit {
                                    triggerScopedSearch(immediate: true)
                                }
                                .onChange(of: searchText) { _, _ in
                                    triggerScopedSearch(immediate: false)
                                }

                            if (scope == .macLibrary && store.isSearchingMacLibrary) || (scope == .lidarr && store.isSearchingLidarr) {
                                ProgressView().tint(EchoiOSTheme.neoCyan).scaleEffect(0.75)
                            } else if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    store.scheduleMacLibrarySearch(query: "", immediate: true)
                                    store.scheduleLidarrSearch(query: "", immediate: true)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: sizeClass == .regular ? 18 : 15))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, sizeClass == .regular ? 11 : 10)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard)
                                .strokeBorder(searchText.isEmpty ? EchoiOSTheme.borderStrong : EchoiOSTheme.neoMint.opacity(0.6), lineWidth: 1)
                        )

                        Picker("Search Scope", selection: $scope) {
                            ForEach(LibrarySearchScope.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: scope) { _, _ in
                            triggerScopedSearch(immediate: true)
                        }
                    }
                    .padding(.horizontal, 16)

                    if scope == .macLibrary {
                        macLibrarySearchSection
                    } else if scope == .lidarr {
                        lidarrSearchSection
                    } else if store.tracks.isEmpty {
                        @Bindable var bindable = store
                        VStack(spacing: 14) {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .font(.system(size: 42))
                                .foregroundStyle(EchoiOSTheme.neoMint)
                            Text("Ready for Automatic Wi-Fi Sync")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(EchoiOSTheme.textPrimary)

                            if let mac = store.discoveredMacs.first {
                                HStack(spacing: 6) {
                                    Circle().fill(EchoiOSTheme.neoMint).frame(width: 8, height: 8)
                                    Text("Found \(mac.name) · \(mac.baseURLString)")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(EchoiOSTheme.neoMint)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(EchoiOSTheme.neoMint.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                            }

                            Text("Enter the 6-digit Pairing PIN shown in My Echo on your Mac (under iPhone → Wi-Fi Auto-Sync) to pull your marked tracks & playlists over local Wi-Fi.")
                                .font(.system(size: 13))
                                .foregroundStyle(EchoiOSTheme.textSecondary)
                                .multilineTextAlignment(.center)

                            VStack(spacing: 10) {
                                TextField("6-Digit Pairing PIN", text: $bindable.pairingPIN)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .padding(10)
                                    .background(EchoiOSTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                    .frame(maxWidth: 220)
                                    .onChange(of: store.pairingPIN) { _, newValue in
                                        store.saveWiFiSyncSettings()
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if trimmed.count == 6 && !store.macServerURL.isEmpty && !store.isSyncing {
                                            Task { await store.syncNow() }
                                        }
                                    }

                                if store.isSyncing {
                                    VStack(spacing: 6) {
                                        ProgressView(value: store.syncProgressFraction)
                                            .tint(EchoiOSTheme.neoMint)
                                            .frame(maxWidth: 260)
                                        Text("\(store.syncStatusText)\(store.syncCurrentItem.isEmpty ? "" : " · \(store.syncCurrentItem)")")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(EchoiOSTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                } else {
                                    Button {
                                        Task { await store.syncNow() }
                                    } label: {
                                        Label("Pair & Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 14, weight: .bold))
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 10)
                                            .background(EchoiOSTheme.neoMint)
                                            .foregroundStyle(.black)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                }

                                if let err = store.syncError {
                                    Text(err)
                                        .font(.system(size: 12))
                                        .foregroundStyle(EchoiOSTheme.dangerCoral)
                                        .multilineTextAlignment(.center)
                                    if err.contains("Local Network"),
                                       let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                        Button("Open iPhone Settings") {
                                            UIApplication.shared.open(settingsURL)
                                        }
                                        .font(.system(size: 12.5, weight: .bold))
                                        .foregroundStyle(EchoiOSTheme.neoCyan)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .padding(.horizontal, 16)
                    } else {
                        // Offline Summary Strip
                        HStack(spacing: 8) {
                            statBadge("\(store.albums.count) Albums", color: EchoiOSTheme.neoMint)
                            statBadge("\(store.tracks.count) Offline Tracks", color: EchoiOSTheme.neoCyan)
                            if !store.navidromeOfflineTracks.isEmpty {
                                statBadge("\(store.navidromeOfflineTracks.count) ND Saved", color: EchoiOSTheme.hiResGold)
                            }
                            Spacer()
                            if store.isSyncing {
                                ProgressView().tint(EchoiOSTheme.neoMint)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Matching offline single tracks when filtering On Device
                        if !filteredTracks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("OFFLINE TRACKS (\(filteredTracks.count))")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.neoMint)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    TrackListColumnHeader(leadingLabel: "ART", showFormat: true)
                                    Divider().overlay(EchoiOSTheme.border)
                                    ForEach(Array(filteredTracks.prefix(25).enumerated()), id: \.element.id) { idx, track in
                                        let isCurrent = store.player.currentItem?.id == track.id
                                        StyledTrackRow(
                                            indexNumber: nil,
                                            title: track.title,
                                            subtitle: "\(track.artist) · \(track.effectiveAlbum)",
                                            duration: track.duration,
                                            formatPrimary: track.formatPrimaryLabel,
                                            formatDetail: track.formatDetailLabel,
                                            isHiRes: track.isHiRes,
                                            isLossless: track.isLossless,
                                            localArtworkURL: store.artworkFileURL(for: track.artworkHash),
                                            remoteArtworkURL: nil,
                                            isCurrent: isCurrent,
                                            isPlaying: isCurrent && store.player.isPlaying,
                                            accentColor: EchoiOSTheme.neoMint,
                                            isAlternateRow: idx % 2 == 1
                                        ) {
                                            store.playLocalTracks(filteredTracks, startingAt: idx)
                                        }
                                        if idx < min(25, filteredTracks.count) - 1 {
                                            Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 64)
                                        }
                                    }
                                }
                                .background(EchoiOSTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                                .padding(.horizontal, 16)
                            }
                        }

                        // Albums Grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 16) {
                            ForEach(filteredAlbums) { album in
                                NavigationLink(value: album) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        LocalArtworkImage(url: store.artworkFileURL(for: album.artworkHash))
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                        Text(album.title)
                                            .font(.system(size: 13.5, weight: .bold))
                                            .foregroundStyle(EchoiOSTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(album.artist)
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(EchoiOSTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    .padding(10)
                                    .background(EchoiOSTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .background(EchoiOSTheme.canvas)
            .navigationTitle("My Echo")
            .refreshable {
                await store.syncNow()
            }
            .navigationDestination(for: SyncedAlbumGroup.self) { album in
                OfflineAlbumDetailView(album: album)
            }
        }
    }

    private func triggerScopedSearch(immediate: Bool) {
        switch scope {
        case .onDevice: break
        case .macLibrary: store.scheduleMacLibrarySearch(query: searchText, immediate: immediate)
        case .lidarr: store.scheduleLidarrSearch(query: searchText, immediate: immediate)
        }
    }

    @ViewBuilder
    private var macLibrarySearchSection: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let err = store.macSearchError {
            Text(err)
                .font(.system(size: 12.5))
                .foregroundStyle(EchoiOSTheme.dangerCoral)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EchoiOSTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                .padding(.horizontal, 16)
        }

        if trimmed.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 32))
                    .foregroundStyle(EchoiOSTheme.neoCyan)
                Text("Search Your Entire Mac Library")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(EchoiOSTheme.textPrimary)
                Text("Type an artist, album, or song above to search all tracks on your Mac — tap + on any single track or full album to add it to this device's offline sync immediately.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(EchoiOSTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(EchoiOSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
            .padding(.horizontal, 16)
        } else {
            if !store.macSearchAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("MAC ALBUMS (\(store.macSearchAlbums.count))")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoiOSTheme.neoCyan)
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                        ForEach(store.macSearchAlbums) { album in
                            let busy = store.togglingMacSyncIDs.contains(album.albumKey)
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    RemoteArtworkImage(url: store.macArtworkURL(for: album.artworkHash))
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))

                                    Button {
                                        Task { await store.toggleMacSyncAlbum(album) }
                                    } label: {
                                        Group {
                                            if busy {
                                                ProgressView().tint(.black).scaleEffect(0.75)
                                            } else {
                                                Image(systemName: album.isSelectedForSync ? "checkmark" : "plus")
                                                    .font(.system(size: 13, weight: .black))
                                            }
                                        }
                                        .frame(width: 30, height: 30)
                                        .background(album.isSelectedForSync ? EchoiOSTheme.neoMint : EchoiOSTheme.neoCyan)
                                        .foregroundStyle(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                        .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(6)
                                }

                                Text(album.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(EchoiOSTheme.textPrimary)
                                    .lineLimit(1)
                                Text("\(album.artist) · \(album.trackCount) tracks")
                                    .font(.system(size: 11))
                                    .foregroundStyle(EchoiOSTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .background(EchoiOSTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                            .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(album.isSelectedForSync ? EchoiOSTheme.neoMint.opacity(0.6) : EchoiOSTheme.border, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if !store.macSearchTracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MAC SINGLE TRACKS (\(store.macSearchTracks.count))")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoiOSTheme.neoMint)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        ForEach(Array(store.macSearchTracks.enumerated()), id: \.element.id) { idx, track in
                            let busy = store.togglingMacSyncIDs.contains(track.id)
                            HStack(spacing: 10) {
                                RemoteArtworkImage(url: store.macArtworkURL(for: track.artworkHash))
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                        .lineLimit(1)
                                    Text("\(track.artist) · \(track.album)")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(EchoiOSTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 6)

                                TwoFactorFormatPill(
                                    primary: track.formatPrimaryLabel,
                                    detail: track.formatDetailLabel,
                                    isHiRes: track.isHiRes,
                                    isLossless: track.isLossless
                                )

                                Button {
                                    Task { await store.toggleMacSyncTrack(track) }
                                } label: {
                                    Group {
                                        if busy {
                                            ProgressView().tint(EchoiOSTheme.neoMint).scaleEffect(0.75)
                                        } else {
                                            Image(systemName: track.isSelectedForSync ? "checkmark" : "plus")
                                                .font(.system(size: 12, weight: .black))
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                                    .background(track.isSelectedForSync ? EchoiOSTheme.neoMint : EchoiOSTheme.surfaceElevated)
                                    .foregroundStyle(track.isSelectedForSync ? .black : EchoiOSTheme.neoMint)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall).strokeBorder(EchoiOSTheme.neoMint.opacity(0.6), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(idx % 2 == 1 ? Color.white.opacity(0.025) : Color.clear)

                            if idx < store.macSearchTracks.count - 1 {
                                Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 62)
                            }
                        }
                    }
                    .background(EchoiOSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                    .padding(.horizontal, 16)
                }
            }

            if !store.isSearchingMacLibrary && store.macSearchAlbums.isEmpty && store.macSearchTracks.isEmpty && store.macSearchError == nil {
                Text("No matches on Mac for '\(trimmed)'.")
                    .font(.system(size: 13))
                    .foregroundStyle(EchoiOSTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
        }
    }

    @ViewBuilder
    private var lidarrSearchSection: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let msg = store.lidarrFeedbackMessage {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(EchoiOSTheme.neoMint)
                Text(msg).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(EchoiOSTheme.neoMint)
                Spacer()
            }
            .padding(12)
            .background(EchoiOSTheme.neoMint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
            .padding(.horizontal, 16)
        }

        if let err = store.lidarrError {
            Text(err)
                .font(.system(size: 12.5))
                .foregroundStyle(EchoiOSTheme.dangerCoral)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EchoiOSTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                .padding(.horizontal, 16)
        }

        if trimmed.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(EchoiOSTheme.hiResGold)
                Text("Order Missing Music via Lidarr")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(EchoiOSTheme.textPrimary)
                Text("Search any album or single track to order it directly into your Lidarr download queue via My Echo on Mac.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(EchoiOSTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(EchoiOSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
            .padding(.horizontal, 16)
        } else {
            if !store.lidarrSearchAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("LIDARR ALBUMS (\(store.lidarrSearchAlbums.count))")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoiOSTheme.hiResGold)
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                        ForEach(store.lidarrSearchAlbums) { album in
                            let isOrdered = store.orderedLidarrIDs.contains(album.id) || album.monitored
                            let isBusy = store.orderingLidarrIDs.contains(album.id)
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    RemoteArtworkImage(url: album.coverURL.flatMap(URL.init(string:)))
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))

                                    Button {
                                        Task { await store.orderLidarrAlbum(album) }
                                    } label: {
                                        Group {
                                            if isBusy {
                                                ProgressView().tint(.black).scaleEffect(0.75)
                                            } else if album.inLibrary {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.system(size: 13))
                                            } else {
                                                Image(systemName: isOrdered ? "checkmark" : "arrow.down")
                                                    .font(.system(size: 12, weight: .black))
                                            }
                                        }
                                        .frame(width: 30, height: 30)
                                        .background(album.inLibrary || isOrdered ? EchoiOSTheme.neoMint : EchoiOSTheme.hiResGold)
                                        .foregroundStyle(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                        .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBusy || album.inLibrary)
                                    .padding(6)
                                }

                                Text(album.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(EchoiOSTheme.textPrimary)
                                    .lineLimit(1)
                                Text("\(album.artistName)\(album.releaseYear.map { " · \($0)" } ?? "")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(EchoiOSTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .background(EchoiOSTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                            .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(isOrdered ? EchoiOSTheme.neoMint.opacity(0.5) : EchoiOSTheme.border, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if !store.lidarrSearchTracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ORDER BY TRACK (\(store.lidarrSearchTracks.count))")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoiOSTheme.hiResGold)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        ForEach(Array(store.lidarrSearchTracks.enumerated()), id: \.element.id) { idx, track in
                            let isOrdered = store.orderedLidarrIDs.contains(track.id)
                            let isBusy = store.orderingLidarrIDs.contains(track.id)
                            HStack(spacing: 10) {
                                RemoteArtworkImage(url: track.coverURL.flatMap(URL.init(string:)))
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                        .lineLimit(1)
                                    Text("\(track.artistName) · \(track.albumTitle)")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(EchoiOSTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 6)

                                Button {
                                    Task { await store.orderLidarrTrack(track) }
                                } label: {
                                    Group {
                                        if isBusy {
                                            ProgressView().tint(.black).scaleEffect(0.75)
                                        } else {
                                            Text(isOrdered ? "QUEUED" : "ORDER")
                                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                        }
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(isOrdered ? EchoiOSTheme.neoMint : EchoiOSTheme.hiResGold)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                }
                                .buttonStyle(.plain)
                                .disabled(isBusy || isOrdered)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(idx % 2 == 1 ? Color.white.opacity(0.025) : Color.clear)

                            if idx < store.lidarrSearchTracks.count - 1 {
                                Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 62)
                            }
                        }
                    }
                    .background(EchoiOSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func statBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
    }
}

struct OfflineAlbumDetailView: View {
    @Environment(iOSEchoStore.self) private var store
    let album: SyncedAlbumGroup
    @State private var showLightbox = false

    private var totalDuration: TimeInterval {
        album.tracks.reduce(0) { $0 + $1.duration }
    }

    private var albumEditorial: SyncedAlbumEditorial? {
        store.albumEditorial(for: album.title)
    }

    private var audioQualitySummary: String {
        let formats = Array(Set(album.tracks.map(\.formatPrimaryLabel))).sorted()
        let detail = album.tracks.compactMap(\.formatDetailLabel).first
        if let detail { return "\(formats.joined(separator: "/")) · \(detail)" }
        return formats.joined(separator: "/")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Hero Header Card
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [EchoiOSTheme.neoMint.opacity(0.18), EchoiOSTheme.neoCyan.opacity(0.08), EchoiOSTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard)
                            .strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1)
                    )

                    HStack(spacing: 16) {
                        Button {
                            showLightbox = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                LocalArtworkImage(url: store.artworkFileURL(for: album.artworkHash))
                                    .frame(width: 118, height: 118)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.neoMint.opacity(0.45), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(EchoiOSTheme.neoMint)
                                    .frame(width: 22, height: 22)
                                    .background(Color.black.opacity(0.72))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(5)
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("OFFLINE HI-FI ALBUM")
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(EchoiOSTheme.neoMint)

                            Text(album.title)
                                .font(.system(size: 19, weight: .black))
                                .foregroundStyle(EchoiOSTheme.textPrimary)
                                .lineLimit(2)

                            Text(album.artist)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(EchoiOSTheme.neoCyan)
                                .lineLimit(1)

                            Text("\(album.year.map { "\($0) · " } ?? "")\(album.tracks.count) TRACKS · \(iOSFormatters.duration(totalDuration))")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(EchoiOSTheme.textMuted)

                            HStack(spacing: 8) {
                                Button {
                                    store.player.isShuffled = false
                                    store.playLocalTracks(album.tracks, startingAt: 0)
                                } label: {
                                    Label("Play", systemImage: "play.fill")
                                        .font(.system(size: 12.5, weight: .black))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(EchoiOSTheme.neoMint)
                                        .foregroundStyle(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    store.player.isShuffled = true
                                    store.playLocalTracks(album.tracks, startingAt: Int.random(in: 0..<max(1, album.tracks.count)))
                                } label: {
                                    Label("Shuffle", systemImage: "shuffle")
                                        .font(.system(size: 12.5, weight: .bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(EchoiOSTheme.surfaceElevated)
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                }
                .padding(.horizontal, 16)

                // Compact synced Album & Artist Notes teaser (tap to open full Lightbox)
                if let info = albumEditorial, info.hasDisplayableContent {
                    Button {
                        showLightbox = true
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("ALBUM & ARTIST NOTES")
                                    .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                    .tracking(1.0)
                                    .foregroundStyle(EchoiOSTheme.neoMint)
                                Spacer()
                                if let label = info.label {
                                    Text(label)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                        .lineLimit(1)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(EchoiOSTheme.neoMint)
                            }
                            if let summary = info.albumSummary ?? info.artistSummary {
                                Text(summary)
                                    .font(.system(size: 12))
                                    .foregroundStyle(EchoiOSTheme.textSecondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.neoMint.opacity(0.32), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                // Framed Studio Track Deck
                VStack(spacing: 0) {
                    TrackListColumnHeader(leadingLabel: "#", showFormat: true)
                    Divider().overlay(EchoiOSTheme.border)

                    ForEach(Array(album.tracks.enumerated()), id: \.element.id) { idx, track in
                        let isCurrent = store.player.currentItem?.id == track.id
                        StyledTrackRow(
                            indexNumber: track.trackNumber ?? (idx + 1),
                            title: track.title,
                            subtitle: track.artist,
                            duration: track.duration,
                            formatPrimary: track.formatPrimaryLabel,
                            formatDetail: track.formatDetailLabel,
                            isHiRes: track.isHiRes,
                            isLossless: track.isLossless,
                            localArtworkURL: nil,
                            remoteArtworkURL: nil,
                            isCurrent: isCurrent,
                            isPlaying: isCurrent && store.player.isPlaying,
                            accentColor: EchoiOSTheme.neoMint,
                            isAlternateRow: idx % 2 == 1
                        ) {
                            store.playLocalTracks(album.tracks, startingAt: idx)
                        }

                        if idx < album.tracks.count - 1 {
                            Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 44)
                        }
                    }
                }
                .background(EchoiOSTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(EchoiOSTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLightbox) {
            iOSAlbumLightboxSheet(
                albumTitle: album.title,
                artistName: album.artist,
                year: album.year,
                trackCount: album.tracks.count,
                totalDuration: totalDuration,
                audioQuality: audioQualitySummary,
                localArtworkURL: store.artworkFileURL(for: album.artworkHash),
                remoteArtworkURL: nil
            )
            .environment(store)
        }
    }
}

// MARK: - Tab 2: Synced Playlists

struct PlaylistsTab: View {
    @Environment(iOSEchoStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.playlists.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 36))
                                .foregroundStyle(EchoiOSTheme.neoMint)
                            Text("No Synced Playlists Yet")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(EchoiOSTheme.textPrimary)
                            Text("Mark playlists for your iPhone destination in My Echo on Mac — they sync automatically over Wi-Fi.")
                                .font(.system(size: 13))
                                .foregroundStyle(EchoiOSTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.border, lineWidth: 1))
                    } else {
                        let map = Dictionary(uniqueKeysWithValues: store.tracks.map { ($0.id, $0) })
                        ForEach(store.playlists) { pl in
                            let plTracks = pl.trackIDs.compactMap { map[$0] }
                            let totalDur = plTracks.reduce(0) { $0 + $1.duration }
                            let losslessCount = plTracks.filter(\.isLossless).count
                            NavigationLink {
                                OfflinePlaylistDetailView(playlist: pl, tracks: plTracks)
                            } label: {
                                HStack(spacing: 14) {
                                    LocalArtworkImage(url: store.artworkFileURL(for: plTracks.first?.artworkHash))
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pl.name)
                                            .font(.system(size: 15.5, weight: .bold))
                                            .foregroundStyle(EchoiOSTheme.textPrimary)
                                            .lineLimit(1)

                                        HStack(spacing: 6) {
                                            Text("\(plTracks.count) TRACKS")
                                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                                .foregroundStyle(EchoiOSTheme.neoMint)
                                            Text("· \(iOSFormatters.duration(totalDur))")
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(EchoiOSTheme.textMuted)
                                            if losslessCount > 0 {
                                                Text("· \(losslessCount) LOSSLESS")
                                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(EchoiOSTheme.neoCyan)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                }
                                .padding(12)
                                .background(EchoiOSTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(EchoiOSTheme.canvas)
            .navigationTitle("Playlists")
        }
    }
}

struct OfflinePlaylistDetailView: View {
    @Environment(iOSEchoStore.self) private var store
    let playlist: SyncedPlaylist
    let tracks: [SyncedTrack]

    private var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Playlist Hero Card
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [EchoiOSTheme.neoMint.opacity(0.18), EchoiOSTheme.neoCyan.opacity(0.08), EchoiOSTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))

                    HStack(spacing: 16) {
                        LocalArtworkImage(url: store.artworkFileURL(for: tracks.first?.artworkHash))
                            .frame(width: 108, height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                            .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                            .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("OFFLINE PLAYLIST")
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(EchoiOSTheme.neoMint)

                            Text(playlist.name)
                                .font(.system(size: 19, weight: .black))
                                .foregroundStyle(EchoiOSTheme.textPrimary)
                                .lineLimit(2)

                            Text("\(tracks.count) TRACKS · \(iOSFormatters.duration(totalDuration))")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(EchoiOSTheme.textMuted)

                            HStack(spacing: 8) {
                                Button {
                                    store.player.isShuffled = false
                                    store.playLocalTracks(tracks, startingAt: 0)
                                } label: {
                                    Label("Play", systemImage: "play.fill")
                                        .font(.system(size: 12.5, weight: .black))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(EchoiOSTheme.neoMint)
                                        .foregroundStyle(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                }
                                .buttonStyle(.plain)
                                .disabled(tracks.isEmpty)

                                Button {
                                    store.player.isShuffled = true
                                    store.playLocalTracks(tracks, startingAt: Int.random(in: 0..<max(1, tracks.count)))
                                } label: {
                                    Label("Shuffle", systemImage: "shuffle")
                                        .font(.system(size: 12.5, weight: .bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(EchoiOSTheme.surfaceElevated)
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(tracks.isEmpty)
                            }
                            .padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                }
                .padding(.horizontal, 16)

                // Framed Playlist Track Deck (with Album Art Thumbnails)
                VStack(spacing: 0) {
                    TrackListColumnHeader(leadingLabel: "ART", showFormat: true)
                    Divider().overlay(EchoiOSTheme.border)

                    ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                        let isCurrent = store.player.currentItem?.id == track.id
                        StyledTrackRow(
                            indexNumber: nil,
                            title: track.title,
                            subtitle: "\(track.artist) · \(track.effectiveAlbum)",
                            duration: track.duration,
                            formatPrimary: track.formatPrimaryLabel,
                            formatDetail: track.formatDetailLabel,
                            isHiRes: track.isHiRes,
                            isLossless: track.isLossless,
                            localArtworkURL: store.artworkFileURL(for: track.artworkHash),
                            remoteArtworkURL: nil,
                            isCurrent: isCurrent,
                            isPlaying: isCurrent && store.player.isPlaying,
                            accentColor: EchoiOSTheme.neoMint,
                            isAlternateRow: idx % 2 == 1
                        ) {
                            store.playLocalTracks(tracks, startingAt: idx)
                        }

                        if idx < tracks.count - 1 {
                            Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 64)
                        }
                    }
                }
                .background(EchoiOSTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(EchoiOSTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared Hi-Fi Studio Track List Components

struct TrackListColumnHeader: View {
    let leadingLabel: String
    let showFormat: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(leadingLabel)
                .frame(width: leadingLabel == "ART" ? 42 : 26, alignment: .center)
            Text("TRACK")
            Spacer()
            if showFormat {
                Text("FORMAT")
                    .frame(width: 56, alignment: .center)
            }
            Text("TIME")
                .frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(EchoiOSTheme.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.22))
    }
}

struct StyledTrackRow: View {
    let indexNumber: Int?
    let title: String
    let subtitle: String
    let duration: TimeInterval
    let formatPrimary: String?
    let formatDetail: String?
    let isHiRes: Bool
    let isLossless: Bool
    let localArtworkURL: URL?
    let remoteArtworkURL: URL?
    let isCurrent: Bool
    let isPlaying: Bool
    let accentColor: Color
    let isAlternateRow: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if localArtworkURL != nil || remoteArtworkURL != nil || indexNumber == nil {
                    ZStack {
                        Group {
                            if let localArtworkURL {
                                LocalArtworkImage(url: localArtworkURL)
                            } else {
                                RemoteArtworkImage(url: remoteArtworkURL)
                            }
                        }
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall)
                                .strokeBorder(isCurrent ? accentColor : EchoiOSTheme.border, lineWidth: isCurrent ? 1.5 : 0.75)
                        )

                        if isCurrent {
                            RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall)
                                .fill(Color.black.opacity(0.55))
                                .frame(width: 42, height: 42)
                            Image(systemName: isPlaying ? "waveform" : "pause.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(accentColor)
                        }
                    }
                } else if let num = indexNumber {
                    Group {
                        if isCurrent {
                            Image(systemName: isPlaying ? "waveform" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(accentColor)
                        } else {
                            Text(String(format: "%02d", num))
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(EchoiOSTheme.textMuted)
                        }
                    }
                    .frame(width: 26, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    Text(title)
                        .font(.system(size: 14, weight: isCurrent ? .bold : .semibold))
                        .foregroundStyle(isCurrent ? accentColor : EchoiOSTheme.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(EchoiOSTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if let formatPrimary {
                    TwoFactorFormatPill(
                        primary: formatPrimary,
                        detail: formatDetail,
                        isHiRes: isHiRes,
                        isLossless: isLossless
                    )
                    .frame(width: 56, alignment: .center)
                }

                Text(iOSFormatters.duration(duration))
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? accentColor.opacity(0.9) : EchoiOSTheme.textMuted)
                    .frame(width: 38, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9.5)
            .background(
                ZStack(alignment: .leading) {
                    if isCurrent {
                        LinearGradient(
                            colors: [accentColor.opacity(0.18), accentColor.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 3)
                    } else if isAlternateRow {
                        Color.white.opacity(0.025)
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab 3: Podcasts (Synced Feeds + Search + Offline/Online Directory + Mac Sync-Back)

struct PodcastsTab: View {
    @Environment(iOSEchoStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var trimmedQuery: String {
        store.podcastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredSubscribedShows: [iOSPodcastShow] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return store.podcastShows }
        return store.podcastShows.filter { show in
            show.title.lowercased().contains(q)
                || show.author.lowercased().contains(q)
                || show.description.lowercased().contains(q)
        }
    }

    private var matchingSubscribedEpisodes: [(show: iOSPodcastShow, episode: iOSPodcastEpisode)] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        var matches: [(show: iOSPodcastShow, episode: iOSPodcastEpisode)] = []
        for show in store.podcastShows {
            for ep in show.episodes {
                if ep.title.lowercased().contains(q)
                    || ep.summary.lowercased().contains(q)
                    || show.title.lowercased().contains(q) {
                    matches.append((show, ep))
                }
            }
        }
        return matches.sorted { ($0.episode.publishedAt ?? .distantPast) > ($1.episode.publishedAt ?? .distantPast) }
    }

    var body: some View {
        @Bindable var bindable = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Always-visible Podcast Search Bar + Offline / Online Switch
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: store.podcastSearchIsOnline ? "globe" : "magnifyingglass")
                                .font(.system(size: sizeClass == .regular ? 16 : 14, weight: .semibold))
                                .foregroundStyle(store.podcastSearchIsOnline ? EchoiOSTheme.neoCyan : EchoiOSTheme.neoMint)

                            TextField(
                                store.podcastSearchIsOnline
                                    ? "Search podcasts, hosts, or genres (e.g. True Crime, Tech)..."
                                    : "Search subscribed podcasts & episodes...",
                                text: $bindable.podcastSearchQuery
                            )
                            .font(.system(size: sizeClass == .regular ? 17 : 15))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit {
                                if store.podcastSearchIsOnline {
                                    store.schedulePodcastDirectorySearch(immediate: true)
                                }
                            }
                            .onChange(of: store.podcastSearchQuery) { _, _ in
                                if store.podcastSearchIsOnline {
                                    store.schedulePodcastDirectorySearch(immediate: false)
                                }
                            }

                            if store.podcastSearchIsOnline && store.isSearchingPodcastDirectory {
                                ProgressView()
                                    .tint(EchoiOSTheme.neoCyan)
                                    .scaleEffect(0.75)
                            } else if !store.podcastSearchQuery.isEmpty {
                                Button {
                                    store.podcastSearchQuery = ""
                                    if store.podcastSearchIsOnline {
                                        store.schedulePodcastDirectorySearch(immediate: true)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: sizeClass == .regular ? 18 : 15))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, sizeClass == .regular ? 11 : 10)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard)
                                .strokeBorder(
                                    trimmedQuery.isEmpty
                                        ? EchoiOSTheme.borderStrong
                                        : (store.podcastSearchIsOnline ? EchoiOSTheme.neoCyan.opacity(0.65) : EchoiOSTheme.neoMint.opacity(0.65)),
                                    lineWidth: 1
                                )
                        )

                        // Offline (Subscribed Only) vs Online (Directories -> Sync Back to Mac) Switch
                        Picker("Podcast Search Mode", selection: $bindable.podcastSearchIsOnline) {
                            Text("Offline · Subscribed").tag(false)
                            Text("Online · Directories").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: store.podcastSearchIsOnline) { _, isOnline in
                            if isOnline {
                                store.schedulePodcastDirectorySearch(immediate: true)
                            }
                        }

                        // Directory Pills + Genre/Category Chips when Online
                        if store.podcastSearchIsOnline {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(iOSPodcastDirectory.allCases) { dir in
                                        let isSelected = store.podcastDirectory == dir
                                        Button {
                                            store.podcastDirectory = dir
                                            store.schedulePodcastDirectorySearch(immediate: true)
                                        } label: {
                                            Text(dir.rawValue)
                                                .font(.system(size: 11.5, weight: .bold))
                                                .foregroundStyle(isSelected ? .black : EchoiOSTheme.textSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(isSelected ? EchoiOSTheme.neoCyan : EchoiOSTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl)
                                                        .strokeBorder(isSelected ? EchoiOSTheme.neoCyan : EchoiOSTheme.borderStrong, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 7) {
                                    ForEach(iOSPodcastCategory.allCases) { cat in
                                        let isActive = store.podcastCategory == cat
                                        Button {
                                            store.selectPodcastCategory(cat)
                                        } label: {
                                            Text(cat.rawValue)
                                                .font(.system(size: 11, weight: isActive ? .black : .semibold))
                                                .foregroundStyle(isActive ? EchoiOSTheme.neoMint : EchoiOSTheme.textSecondary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5.5)
                                                .background(isActive ? EchoiOSTheme.neoMint.opacity(0.18) : EchoiOSTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall)
                                                        .strokeBorder(isActive ? EchoiOSTheme.neoMint.opacity(0.65) : EchoiOSTheme.border, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Pending Mac Sync-Back Banner (when podcasts were subscribed while Mac was offline)
                    if !store.pendingMacPodcastSubscriptions.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(EchoiOSTheme.hiResGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(store.pendingMacPodcastSubscriptions.count) podcast\(store.pendingMacPodcastSubscriptions.count == 1 ? "" : "s") queued for Mac")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(EchoiOSTheme.textPrimary)
                                Text("Will be added back to My Echo on Mac on next sync.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(EchoiOSTheme.textSecondary)
                            }
                            Spacer(minLength: 6)
                            Button {
                                Task { await store.syncNow() }
                            } label: {
                                Text("Sync")
                                    .font(.system(size: 11, weight: .black))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(EchoiOSTheme.hiResGold)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isSyncing)
                        }
                        .padding(12)
                        .background(EchoiOSTheme.hiResGold.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.hiResGold.opacity(0.45), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    if let status = store.podcastStatusText {
                        HStack(spacing: 8) {
                            if store.isRefreshingPodcasts || store.isSearchingPodcastDirectory {
                                ProgressView().tint(EchoiOSTheme.neoMint).scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(EchoiOSTheme.neoMint)
                            }
                            Text(status)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(EchoiOSTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }

                    if let err = store.podcastError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(EchoiOSTheme.dangerCoral)
                            .padding(.horizontal, 16)
                    }

                    if store.podcastSearchIsOnline {
                        onlinePodcastDiscoverySection
                    } else {
                        offlineSubscribedPodcastsSection
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .background(EchoiOSTheme.canvas)
            .navigationTitle("Podcasts")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refreshAllPodcastFeeds(downloadNew: false) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshingPodcasts || store.podcastShows.isEmpty)

                    Button {
                        Task { await store.refreshAllPodcastFeeds(downloadNew: true) }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .disabled(store.isRefreshingPodcasts || store.podcastShows.isEmpty)
                }
            }
            .refreshable {
                if store.podcastSearchIsOnline {
                    store.schedulePodcastDirectorySearch(immediate: true)
                } else {
                    await store.refreshAllPodcastFeeds(downloadNew: false)
                }
            }
            .navigationDestination(for: String.self) { showID in
                PodcastShowDetailView(showID: showID)
            }
        }
    }

    // MARK: - Offline Mode (Subscribed Podcasts & Episodes Only)

    @ViewBuilder
    private var offlineSubscribedPodcastsSection: some View {
        if store.podcastShows.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(EchoiOSTheme.neoCyan)
                Text("Podcast Feeds & Offline Episodes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(EchoiOSTheme.textPrimary)
                Text("Sync with My Echo on your Mac to pull subscribed feeds, or switch to Online above to search directories and add new podcasts (they sync back to Mac automatically).")
                    .font(.system(size: 13))
                    .foregroundStyle(EchoiOSTheme.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button {
                        Task { await store.syncNow() }
                    } label: {
                        Label("Sync from Mac", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(EchoiOSTheme.neoMint)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.podcastSearchIsOnline = true
                        store.schedulePodcastDirectorySearch(immediate: true)
                    } label: {
                        Label("Browse Online", systemImage: "globe")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(EchoiOSTheme.surfaceElevated)
                            .foregroundStyle(EchoiOSTheme.neoCyan)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                            .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(EchoiOSTheme.neoCyan.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(EchoiOSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
            .padding(.horizontal, 16)
        } else {
            let matchedEps = matchingSubscribedEpisodes
            if !trimmedQuery.isEmpty && !matchedEps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MATCHING EPISODES (\(matchedEps.count))")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoiOSTheme.neoMint)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        ForEach(Array(matchedEps.prefix(20).enumerated()), id: \.element.episode.id) { idx, pair in
                            let ep = pair.episode
                            let show = pair.show
                            let isCurrent = store.player.currentItem?.id == ep.id
                            let isPlaying = isCurrent && store.player.isPlaying

                            Button {
                                Task { await store.playPodcastEpisode(ep, in: show) }
                            } label: {
                                HStack(spacing: 10) {
                                    PodcastArtworkView(
                                        localURL: store.artworkFileURL(for: ep.artworkHash ?? show.artworkHash),
                                        remoteURL: show.artworkURL.flatMap(URL.init(string:))
                                    )
                                    .frame(width: 42, height: 42)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall)
                                            .strokeBorder(isCurrent ? EchoiOSTheme.neoMint : EchoiOSTheme.border, lineWidth: isCurrent ? 1.5 : 0.75)
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ep.title)
                                            .font(.system(size: 13.5, weight: isCurrent ? .bold : .semibold))
                                            .foregroundStyle(isCurrent ? EchoiOSTheme.neoMint : EchoiOSTheme.textPrimary)
                                            .lineLimit(1)
                                        Text("\(show.title)\(ep.duration > 0 ? " · \(iOSFormatters.duration(ep.duration))" : "")")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(EchoiOSTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 6)

                                    if isPlaying {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(EchoiOSTheme.neoMint)
                                    } else if ep.downloadOrigin != .none {
                                        Text("OFFLINE")
                                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(EchoiOSTheme.neoMint.opacity(0.16))
                                            .foregroundStyle(EchoiOSTheme.neoMint)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                    } else {
                                        Text("STREAM")
                                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(EchoiOSTheme.surfaceElevated)
                                            .foregroundStyle(EchoiOSTheme.textMuted)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(idx % 2 == 1 ? Color.white.opacity(0.025) : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if idx < min(20, matchedEps.count) - 1 {
                                Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 64)
                            }
                        }
                    }
                    .background(EchoiOSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                    .padding(.horizontal, 16)
                }
            }

            if !filteredSubscribedShows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if !trimmedQuery.isEmpty {
                        Text("SUBSCRIBED SHOWS (\(filteredSubscribedShows.count))")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoiOSTheme.neoCyan)
                            .padding(.horizontal, 16)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 16) {
                        ForEach(filteredSubscribedShows) { show in
                            NavigationLink(value: show.id) {
                                let dlCount = show.episodes.filter { $0.downloadOrigin != .none }.count
                                VStack(alignment: .leading, spacing: 8) {
                                    PodcastArtworkView(
                                        localURL: store.artworkFileURL(for: show.artworkHash),
                                        remoteURL: show.artworkURL.flatMap(URL.init(string:))
                                    )
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))

                                    Text(show.title)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(show.author)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(EchoiOSTheme.textSecondary)
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        Text("\(dlCount) offline")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(dlCount > 0 ? EchoiOSTheme.neoMint : EchoiOSTheme.textMuted)
                                        if !show.episodes.isEmpty {
                                            Text("· \(show.episodes.count) eps")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(EchoiOSTheme.textMuted)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(EchoiOSTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else if matchedEps.isEmpty && !trimmedQuery.isEmpty {
                VStack(spacing: 12) {
                    Text("No subscribed podcasts or episodes match '\(trimmedQuery)'.")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(EchoiOSTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        store.podcastSearchIsOnline = true
                        store.schedulePodcastDirectorySearch(immediate: true)
                    } label: {
                        Label("Search Online Directories for '\(trimmedQuery)'", systemImage: "globe")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(EchoiOSTheme.neoCyan)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(EchoiOSTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Online Mode (Large Directory Result Cards + Compact Subscribed Shows Below)

    @ViewBuilder
    private var onlinePodcastDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(
                    trimmedQuery.isEmpty
                        ? (store.podcastCategory.map { "\($0.rawValue.uppercased()) PODCASTS (\(store.podcastDirectoryResults.count))" } ?? "FEATURED PODCASTS")
                        : "RESULTS\(store.podcastCategory.flatMap { ($0 != .featured && $0 != .topCharts) ? " · \($0.rawValue.uppercased())" : nil } ?? "") (\(store.podcastDirectoryResults.count))"
                )
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoiOSTheme.neoCyan)
                Spacer()
                Text("ADDS TO MAC")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(EchoiOSTheme.neoMint.opacity(0.14))
                    .foregroundStyle(EchoiOSTheme.neoMint)
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
            }
            .padding(.horizontal, 16)

            if store.isSearchingPodcastDirectory && store.podcastDirectoryResults.isEmpty {
                VStack(spacing: 10) {
                    ProgressView().tint(EchoiOSTheme.neoCyan)
                    Text("Searching podcast directories...")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(EchoiOSTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            } else if store.podcastDirectoryResults.isEmpty {
                Text("No online podcast results for '\(trimmedQuery)'.")
                    .font(.system(size: 13))
                    .foregroundStyle(EchoiOSTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                    ForEach(store.podcastDirectoryResults) { result in
                        let norm = iOSEchoStore.normalizedFeedURL(result.feedURL)
                        let isSubscribed = store.isPodcastSubscribed(feedURL: result.feedURL)
                        let isBusy = store.subscribingPodcastFeedURLs.contains(norm)

                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                RemoteArtworkImage(url: result.artworkURL.flatMap(URL.init(string:)))
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))

                                // Top-left Directory Badge
                                HStack {
                                    Text(result.directorySource)
                                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.72))
                                        .foregroundStyle(EchoiOSTheme.neoCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                    Spacer()
                                }
                                .padding(6)

                                // Top-right Subscribe / Subscribed Button
                                Button {
                                    Task { await store.subscribeToPodcastFromiOS(result) }
                                } label: {
                                    Group {
                                        if isBusy {
                                            ProgressView().tint(.black).scaleEffect(0.75)
                                        } else {
                                            Image(systemName: isSubscribed ? "checkmark" : "plus")
                                                .font(.system(size: 13, weight: .black))
                                        }
                                    }
                                    .frame(width: 30, height: 30)
                                    .background(isSubscribed ? EchoiOSTheme.neoMint : EchoiOSTheme.neoCyan)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                    .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                                }
                                .buttonStyle(.plain)
                                .disabled(isBusy || isSubscribed)
                                .padding(6)
                            }

                            Text(result.title)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(EchoiOSTheme.textPrimary)
                                .lineLimit(2)

                            Text(result.author)
                                .font(.system(size: 11.5))
                                .foregroundStyle(EchoiOSTheme.textSecondary)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                if let genre = result.genre, !genre.isEmpty {
                                    Text(genre)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                        .lineLimit(1)
                                }
                                if let count = result.episodeCount, count > 0 {
                                    Text("· \(count) eps")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                }
                            }
                        }
                        .padding(10)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard)
                                .strokeBorder(isSubscribed ? EchoiOSTheme.neoMint.opacity(0.6) : EchoiOSTheme.border, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        // Compact Subscribed Shows section underneath while browsing Online results
        if !store.podcastShows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("SUBSCRIBED SHOWS (\(store.podcastShows.count))")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoiOSTheme.neoMint)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(Array(store.podcastShows.enumerated()), id: \.element.id) { idx, show in
                        let dlCount = show.episodes.filter { $0.downloadOrigin != .none }.count
                        NavigationLink(value: show.id) {
                            HStack(spacing: 10) {
                                PodcastArtworkView(
                                    localURL: store.artworkFileURL(for: show.artworkHash),
                                    remoteURL: show.artworkURL.flatMap(URL.init(string:))
                                )
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(show.title)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                        .lineLimit(1)
                                    Text("\(show.author) · \(dlCount) offline")
                                        .font(.system(size: 11))
                                        .foregroundStyle(EchoiOSTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(EchoiOSTheme.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(idx % 2 == 1 ? Color.white.opacity(0.025) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if idx < store.podcastShows.count - 1 {
                            Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 66)
                        }
                    }
                }
                .background(EchoiOSTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)
        }
    }
}

struct PodcastShowDetailView: View {
    @Environment(iOSEchoStore.self) private var store
    let showID: String

    private var show: iOSPodcastShow? {
        store.podcastShows.first(where: { $0.id == showID })
    }

    var body: some View {
        ScrollView {
            if let show {
                let offlineCount = show.episodes.filter { $0.downloadOrigin != .none }.count
                VStack(alignment: .leading, spacing: 18) {
                    // Ambient Hero Header Card (matches Music Album & Playlist Hero)
                    ZStack(alignment: .leading) {
                        LinearGradient(
                            colors: [EchoiOSTheme.neoCyan.opacity(0.18), EchoiOSTheme.neoMint.opacity(0.08), EchoiOSTheme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))

                        HStack(spacing: 16) {
                            PodcastArtworkView(
                                localURL: store.artworkFileURL(for: show.artworkHash),
                                remoteURL: show.artworkURL.flatMap(URL.init(string:))
                            )
                            .frame(width: 116, height: 116)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                            .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                            .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("PODCAST FEED")
                                    .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                    .tracking(1.0)
                                    .foregroundStyle(EchoiOSTheme.neoCyan)

                                Text(show.title)
                                    .font(.system(size: 19, weight: .black))
                                    .foregroundStyle(EchoiOSTheme.textPrimary)
                                    .lineLimit(2)

                                Text(show.author)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(EchoiOSTheme.textSecondary)
                                    .lineLimit(1)

                                Text("\(offlineCount) OFFLINE · \(show.episodes.count) EPISODES")
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.textMuted)

                                HStack(spacing: 8) {
                                    Button {
                                        Task { await store.refreshPodcastShow(show, downloadNew: true) }
                                    } label: {
                                        Label("Pull New", systemImage: "arrow.down.circle.fill")
                                            .font(.system(size: 12.5, weight: .black))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(EchoiOSTheme.neoMint)
                                            .foregroundStyle(.black)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(store.isRefreshingPodcasts || show.feedURL.isEmpty)

                                    Button {
                                        Task { await store.refreshPodcastShow(show, downloadNew: false) }
                                    } label: {
                                        Label("Refresh", systemImage: "arrow.clockwise")
                                            .font(.system(size: 12.5, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(EchoiOSTheme.surfaceElevated)
                                            .foregroundStyle(EchoiOSTheme.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                            .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(store.isRefreshingPodcasts || show.feedURL.isEmpty)
                                }
                                .padding(.top, 2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                    }
                    .padding(.horizontal, 16)

                    if show.episodes.isEmpty {
                        VStack(spacing: 10) {
                            Text("No episodes loaded yet.")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(EchoiOSTheme.textSecondary)
                            Text("Tap Refresh to pull the latest episodes directly from this podcast's RSS feed.")
                                .font(.system(size: 12))
                                .foregroundStyle(EchoiOSTheme.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                        .padding(.horizontal, 16)
                    } else {
                        // Framed Studio Episode Deck (matches Music Track Deck)
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                Text("#")
                                    .frame(width: 34, alignment: .center)
                                Text("EPISODE")
                                Spacer()
                                Text("STATUS")
                                    .frame(width: 56, alignment: .center)
                                Text("TIME")
                                    .frame(width: 56, alignment: .trailing)
                            }
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(EchoiOSTheme.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.22))

                            Divider().overlay(EchoiOSTheme.border)

                            let totalEpisodes = show.episodes.count
                            ForEach(Array(show.episodes.enumerated()), id: \.element.id) { idx, ep in
                                let episodeNumber = totalEpisodes - idx
                                let isCurrent = store.player.currentItem?.id == ep.id
                                let isPlaying = isCurrent && store.player.isPlaying
                                let rowAccent = ep.downloadOrigin != .none ? EchoiOSTheme.neoMint : EchoiOSTheme.neoCyan

                                HStack(spacing: 10) {
                                    Button {
                                        Task { await store.playPodcastEpisode(ep, in: show) }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Group {
                                                if isCurrent {
                                                    Image(systemName: isPlaying ? "waveform" : "play.fill")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundStyle(rowAccent)
                                                } else {
                                                    Text(String(format: "%02d", episodeNumber))
                                                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                                        .monospacedDigit()
                                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.85)
                                                }
                                            }
                                            .frame(width: 34, alignment: .center)

                                            VStack(alignment: .leading, spacing: 2.5) {
                                                Text(ep.title)
                                                    .font(.system(size: 13.5, weight: isCurrent ? .bold : .semibold))
                                                    .foregroundStyle(isCurrent ? rowAccent : EchoiOSTheme.textPrimary)
                                                    .lineLimit(2)

                                                if let pub = ep.publishedAt {
                                                    Text(pub.formatted(date: .abbreviated, time: .omitted))
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(EchoiOSTheme.textSecondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer(minLength: 4)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    // Compact 2-factor Status / Download Pill (matches Music Format Pill width)
                                    Group {
                                        if store.downloadingEpisodeIDs.contains(ep.id) {
                                            ProgressView()
                                                .tint(EchoiOSTheme.neoCyan)
                                                .scaleEffect(0.8)
                                        } else if ep.downloadOrigin == .syncedFromMac {
                                            Menu {
                                                Button(role: .destructive) {
                                                    Task { await store.deletePodcastEpisodeDownload(ep) }
                                                } label: {
                                                    Label("Remove Local Download", systemImage: "trash")
                                                }
                                            } label: {
                                                TwoFactorFormatPill(
                                                    primary: "SYNC",
                                                    detail: ep.fileExtension.uppercased(),
                                                    isHiRes: false,
                                                    isLossless: true
                                                )
                                            }
                                        } else if ep.downloadOrigin == .downloadedOnDevice {
                                            Menu {
                                                Button(role: .destructive) {
                                                    Task { await store.deletePodcastEpisodeDownload(ep) }
                                                } label: {
                                                    Label("Remove Local Download", systemImage: "trash")
                                                }
                                            } label: {
                                                VStack(spacing: 1) {
                                                    Text("LOCAL")
                                                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                                    Text(ep.fileExtension.uppercased())
                                                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                                                        .opacity(0.85)
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(EchoiOSTheme.neoCyan.opacity(0.16))
                                                .foregroundStyle(EchoiOSTheme.neoCyan)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                            }
                                        } else {
                                            Button {
                                                Task { await store.downloadPodcastEpisode(ep) }
                                            } label: {
                                                VStack(spacing: 1) {
                                                    Image(systemName: "arrow.down.circle.fill")
                                                        .font(.system(size: 11))
                                                    Text("GET")
                                                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(EchoiOSTheme.surfaceElevated)
                                                .foregroundStyle(EchoiOSTheme.neoCyan)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall).strokeBorder(EchoiOSTheme.neoCyan.opacity(0.35), lineWidth: 0.75))
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(ep.audioURL.isEmpty)
                                        }
                                    }
                                    .frame(width: 56, alignment: .center)

                                    Text(ep.duration > 0 ? iOSFormatters.duration(ep.duration) : "—")
                                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .foregroundStyle(isCurrent ? rowAccent.opacity(0.9) : EchoiOSTheme.textMuted)
                                        .frame(width: 56, alignment: .trailing)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9.5)
                                .background(
                                    ZStack(alignment: .leading) {
                                        if isCurrent {
                                            LinearGradient(
                                                colors: [rowAccent.opacity(0.18), rowAccent.opacity(0.05)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                            Rectangle()
                                                .fill(rowAccent)
                                                .frame(width: 3)
                                        } else if idx % 2 == 1 {
                                            Color.white.opacity(0.025)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )

                                if idx < show.episodes.count - 1 {
                                    Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 44)
                                }
                            }
                        }
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
        }
        .background(EchoiOSTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let show, show.episodes.isEmpty, !show.feedURL.isEmpty {
                await store.refreshPodcastShow(show, downloadNew: false)
            }
        }
    }
}

struct PodcastArtworkView: View {
    let localURL: URL?
    let remoteURL: URL?

    var body: some View {
        if let localURL {
            LocalArtworkImage(url: localURL)
        } else {
            RemoteArtworkImage(url: remoteURL)
        }
    }
}

// MARK: - Tab 4: Navidrome Streaming On The Go (Tailscale)

struct NavidromeTab: View {
    @Environment(iOSEchoStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var loginURL = ""
    @State private var loginUser = ""
    @State private var loginPass = ""
    @State private var newAddrLabel = ""
    @State private var newAddrURL = ""
    @State private var showEditLogin = false

    var body: some View {
        @Bindable var bindable = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !store.navidromeConfig.isConfigured || showEditLogin {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 24))
                                    .foregroundStyle(EchoiOSTheme.neoCyan)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Navidrome Servers & Login")
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                    Text("Save LAN + Tailscale addresses and switch with one tap")
                                        .font(.system(size: 12))
                                        .foregroundStyle(EchoiOSTheme.textSecondary)
                                }
                            }

                            // Saved Server Addresses Picker
                            if !store.navidromeConfig.savedAddresses.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("SAVED ADDRESSES")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                    ForEach(store.navidromeConfig.savedAddresses) { addr in
                                        let isActive = loginURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                            .lowercased() == addr.url.lowercased()
                                        HStack(spacing: 8) {
                                            Button {
                                                loginURL = addr.url
                                                if store.navidromeConfig.isConfigured {
                                                    store.switchNavidromeAddress(addr)
                                                }
                                            } label: {
                                                HStack(spacing: 8) {
                                                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(isActive ? EchoiOSTheme.neoCyan : EchoiOSTheme.textMuted)
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(addr.label)
                                                            .font(.system(size: 13, weight: .bold))
                                                            .foregroundStyle(EchoiOSTheme.textPrimary)
                                                        Text(addr.url)
                                                            .font(.system(size: 11, design: .monospaced))
                                                            .foregroundStyle(EchoiOSTheme.textSecondary)
                                                            .lineLimit(1)
                                                    }
                                                    Spacer()
                                                }
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)

                                            if store.navidromeConfig.savedAddresses.count > 1 {
                                                Button {
                                                    store.removeNavidromeAddress(id: addr.id)
                                                    loginURL = store.navidromeConfig.serverURL
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(9)
                                        .background(isActive ? EchoiOSTheme.neoCyan.opacity(0.12) : EchoiOSTheme.surfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(isActive ? EchoiOSTheme.neoCyan.opacity(0.6) : EchoiOSTheme.border, lineWidth: 1))
                                    }
                                }
                            }

                            // Add Another Address (e.g. Home LAN + Tailscale)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ADD ADDRESS")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.textMuted)
                                HStack(spacing: 8) {
                                    TextField("Label (e.g. Home LAN)", text: $newAddrLabel)
                                        .padding(9)
                                        .background(EchoiOSTheme.surfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .frame(maxWidth: 135)
                                    TextField("http://192.168.0.x:4533", text: $newAddrURL)
                                        .keyboardType(.URL)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .padding(9)
                                        .background(EchoiOSTheme.surfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                    Button {
                                        let trimmedURL = newAddrURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !trimmedURL.isEmpty else { return }
                                        store.addNavidromeAddress(label: newAddrLabel, url: trimmedURL, selectImmediately: true)
                                        loginURL = store.navidromeConfig.serverURL
                                        newAddrLabel = ""
                                        newAddrURL = ""
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .black))
                                            .frame(width: 36, height: 36)
                                            .background(EchoiOSTheme.neoCyan)
                                            .foregroundStyle(.black)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(newAddrURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("CREDENTIALS")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.textMuted)

                                TextField("Active Server URL", text: $loginURL)
                                    .keyboardType(.URL)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .padding(10)
                                    .background(EchoiOSTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))

                                TextField("Navidrome Username", text: $loginUser)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .padding(10)
                                    .background(EchoiOSTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))

                                SecureField("Navidrome Password", text: $loginPass)
                                    .padding(10)
                                    .background(EchoiOSTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))

                                HStack(spacing: 10) {
                                    Button {
                                        var cfg = store.navidromeConfig
                                        cfg.isEnabled = true
                                        cfg.serverURL = loginURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                        cfg.username = loginUser.trimmingCharacters(in: .whitespacesAndNewlines)
                                        cfg.password = loginPass
                                        store.saveNavidromeConfig(cfg)
                                        Task {
                                            await store.testNavidromeConnection()
                                            if store.navidromeError == nil {
                                                showEditLogin = false
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            if store.isTestingNavidrome || store.isLoadingNavidrome {
                                                ProgressView().tint(.black)
                                            } else {
                                                Image(systemName: "bolt.fill")
                                            }
                                            Text(store.isTestingNavidrome ? "Connecting..." : "Connect & Load Library")
                                                .font(.system(size: 14, weight: .black))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(EchoiOSTheme.neoCyan)
                                        .foregroundStyle(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(loginURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loginUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loginPass.isEmpty || store.isTestingNavidrome)

                                    if showEditLogin {
                                        Button("Done") {
                                            showEditLogin = false
                                        }
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(EchoiOSTheme.textSecondary)
                                        .padding(.horizontal, 10)
                                    }
                                }
                            }

                            if let status = store.navidromeStatusText {
                                Text(status)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.neoMint)
                            }
                            if let err = store.navidromeError {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundStyle(EchoiOSTheme.dangerCoral)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                        .padding(.horizontal, 16)
                    } else {
                        // 1-Tap Saved Address Switcher Strip (LAN <-> Tailscale without re-entering)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.navidromeConfig.savedAddresses) { addr in
                                    let isActive = store.navidromeConfig.serverURL
                                        .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                                        .lowercased() == addr.url.lowercased()
                                    Button {
                                        if !isActive {
                                            loginURL = addr.url
                                            store.switchNavidromeAddress(addr)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(isActive ? EchoiOSTheme.neoCyan : EchoiOSTheme.textMuted.opacity(0.4))
                                                .frame(width: 7, height: 7)
                                            Text(addr.label)
                                                .font(.system(size: 11.5, weight: .bold))
                                                .foregroundStyle(isActive ? EchoiOSTheme.neoCyan : EchoiOSTheme.textSecondary)
                                        }
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6.5)
                                        .background(isActive ? EchoiOSTheme.neoCyan.opacity(0.16) : EchoiOSTheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl)
                                                .strokeBorder(isActive ? EchoiOSTheme.neoCyan : EchoiOSTheme.borderStrong, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    showEditLogin = true
                                } label: {
                                    Label("Add / Edit", systemImage: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6.5)
                                        .background(EchoiOSTheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(EchoiOSTheme.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                        }

                        // Always-visible Live Search Bar
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: sizeClass == .regular ? 16 : 14, weight: .semibold))
                                .foregroundStyle(store.navidromeSearchQuery.isEmpty ? EchoiOSTheme.textMuted : EchoiOSTheme.neoCyan)

                            TextField("Search artists, albums, tracks, playlists...", text: $bindable.navidromeSearchQuery)
                                .font(.system(size: sizeClass == .regular ? 17 : 15))
                                .foregroundStyle(EchoiOSTheme.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                                .onSubmit {
                                    store.scheduleNavidromeSearch(immediate: true)
                                }
                                .onChange(of: store.navidromeSearchQuery) { _, _ in
                                    store.scheduleNavidromeSearch(immediate: false)
                                }

                            if store.isSearchingNavidrome {
                                ProgressView()
                                    .tint(EchoiOSTheme.neoCyan)
                                    .scaleEffect(0.75)
                            } else if !store.navidromeSearchQuery.isEmpty {
                                Button {
                                    store.navidromeSearchQuery = ""
                                    store.scheduleNavidromeSearch(immediate: true)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: sizeClass == .regular ? 18 : 15))
                                        .foregroundStyle(EchoiOSTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, sizeClass == .regular ? 11 : 10)
                        .background(EchoiOSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard)
                                .strokeBorder(store.navidromeSearchQuery.isEmpty ? EchoiOSTheme.borderStrong : EchoiOSTheme.neoCyan.opacity(0.65), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                        let isSearching = !store.navidromeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                        if !isSearching {
                            // Category switcher when browsing home
                            Picker("Browse", selection: $bindable.navidromeAlbumListType) {
                                Text("Newest").tag("newest")
                                Text("Recent").tag("recent")
                                Text("Most Played").tag("frequent")
                                Text("A–Z").tag("alphabeticalByName")
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)
                            .onChange(of: store.navidromeAlbumListType) { _, _ in
                                Task { await store.refreshNavidromeHome() }
                            }
                        }

                        if let err = store.navidromeError {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(err)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(EchoiOSTheme.dangerCoral)
                                HStack(spacing: 10) {
                                    Button {
                                        if isSearching {
                                            store.scheduleNavidromeSearch(immediate: true)
                                        } else {
                                            Task { await store.refreshNavidromeHome() }
                                        }
                                    } label: {
                                        Label("Retry", systemImage: "arrow.clockwise")
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(EchoiOSTheme.neoCyan)
                                            .foregroundStyle(.black)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        showEditLogin = true
                                    } label: {
                                        Label("Edit Server", systemImage: "slider.horizontal.3")
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(EchoiOSTheme.surfaceElevated)
                                            .foregroundStyle(EchoiOSTheme.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(EchoiOSTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                            .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.dangerCoral.opacity(0.45), lineWidth: 1))
                            .padding(.horizontal, 16)
                        }

                        if (store.isLoadingNavidrome && !isSearching && store.navidromeAlbums.isEmpty)
                            || (store.isSearchingNavidrome && store.navidromeSearchArtists.isEmpty && store.navidromeSearchAlbums.isEmpty && store.navidromeSearchSongs.isEmpty) {
                            VStack(spacing: 12) {
                                ProgressView().tint(EchoiOSTheme.neoCyan)
                                Text(isSearching ? "Searching Navidrome..." : "Loading from \(store.navidromeConfig.serverURL)...")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(36)
                        }

                        // Matching Artists (during search)
                        if isSearching && !store.navidromeSearchArtists.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ARTISTS (\(store.navidromeSearchArtists.count))")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.neoCyan)
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(store.navidromeSearchArtists) { artist in
                                            NavigationLink(value: artist) {
                                                HStack(spacing: 10) {
                                                    RemoteArtworkImage(url: NavidromeClient.coverArtURL(coverArtID: artist.coverArt, size: 160, config: store.navidromeConfig))
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(Circle())
                                                        .overlay(Circle().strokeBorder(EchoiOSTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(artist.name)
                                                            .font(.system(size: 13, weight: .bold))
                                                            .foregroundStyle(EchoiOSTheme.textPrimary)
                                                            .lineLimit(1)
                                                        Text("\(artist.albumCount) album\(artist.albumCount == 1 ? "" : "s")")
                                                            .font(.system(size: 10.5, design: .monospaced))
                                                            .foregroundStyle(EchoiOSTheme.textMuted)
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(EchoiOSTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Matching Playlists (or Home Playlists strip)
                        if !store.matchingNavidromePlaylists.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PLAYLISTS (\(store.matchingNavidromePlaylists.count))")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.neoMint)
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(store.matchingNavidromePlaylists) { pl in
                                            NavigationLink(value: pl) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "music.note.list")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundStyle(EchoiOSTheme.neoMint)
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(pl.name)
                                                            .font(.system(size: 12.5, weight: .bold))
                                                            .foregroundStyle(EchoiOSTheme.textPrimary)
                                                            .lineLimit(1)
                                                        Text("\(pl.songCount) tracks")
                                                            .font(.system(size: 10, design: .monospaced))
                                                            .foregroundStyle(EchoiOSTheme.textMuted)
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(EchoiOSTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.border, lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Matching Tracks (Styled Hi-Fi Deck)
                        if isSearching && !store.navidromeSearchSongs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("TRACKS (\(store.navidromeSearchSongs.count))")
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoiOSTheme.neoCyan)
                                    Spacer()
                                    Button {
                                        store.playNavidromeSongs(store.navidromeSearchSongs, startingAt: 0)
                                    } label: {
                                        Label("Play All", systemImage: "play.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(EchoiOSTheme.neoCyan)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    TrackListColumnHeader(leadingLabel: "ART", showFormat: true)
                                    Divider().overlay(EchoiOSTheme.border)

                                    ForEach(Array(store.navidromeSearchSongs.enumerated()), id: \.element.id) { idx, song in
                                        let isCurrent = store.player.currentItem?.id == "nd-\(song.id)"
                                        let primary = (song.suffix ?? "STREAM").uppercased()
                                        let detail = song.bitRate.map { "\($0)k" }
                                        let isLossless = ["FLAC", "ALAC", "WAV"].contains(primary)

                                        HStack(spacing: 0) {
                                            StyledTrackRow(
                                                indexNumber: nil,
                                                title: song.title,
                                                subtitle: "\(song.artist) · \(song.album)",
                                                duration: TimeInterval(song.duration),
                                                formatPrimary: primary,
                                                formatDetail: detail,
                                                isHiRes: false,
                                                isLossless: isLossless,
                                                localArtworkURL: nil,
                                                remoteArtworkURL: NavidromeClient.coverArtURL(coverArtID: song.coverArt, size: 160, config: store.navidromeConfig),
                                                isCurrent: isCurrent,
                                                isPlaying: isCurrent && store.player.isPlaying,
                                                accentColor: EchoiOSTheme.neoCyan,
                                                isAlternateRow: idx % 2 == 1
                                            ) {
                                                store.playNavidromeSongs(store.navidromeSearchSongs, startingAt: idx)
                                            }
                                            NavidromeOfflineSongButton(song: song)
                                                .padding(.trailing, 10)
                                        }

                                        if idx < store.navidromeSearchSongs.count - 1 {
                                            Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 64)
                                        }
                                    }
                                }
                                .background(EchoiOSTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                                .padding(.horizontal, 16)
                            }
                        }

                        // Albums Grid (Home or Search Results)
                        let shownAlbums = isSearching ? store.navidromeSearchAlbums : store.navidromeAlbums
                        if !shownAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                if isSearching {
                                    Text("ALBUMS (\(shownAlbums.count))")
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoiOSTheme.neoCyan)
                                        .padding(.horizontal, 16)
                                }

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 16) {
                                    ForEach(shownAlbums) { album in
                                        NavigationLink(value: album) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                RemoteArtworkImage(url: NavidromeClient.coverArtURL(coverArtID: album.coverArt, size: 400, config: store.navidromeConfig))
                                                    .aspectRatio(1, contentMode: .fit)
                                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                                Text(album.name)
                                                    .font(.system(size: 13.5, weight: .bold))
                                                    .foregroundStyle(EchoiOSTheme.textPrimary)
                                                    .lineLimit(1)
                                                Text(album.artist)
                                                    .font(.system(size: 11.5))
                                                    .foregroundStyle(EchoiOSTheme.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            .padding(10)
                                            .background(EchoiOSTheme.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                            .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.border, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        } else if !store.isLoadingNavidrome && !store.isSearchingNavidrome && store.navidromeError == nil
                                    && store.navidromeSearchArtists.isEmpty && store.navidromeSearchSongs.isEmpty && store.matchingNavidromePlaylists.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: isSearching ? "magnifyingglass" : "music.note.house")
                                    .font(.system(size: 32))
                                    .foregroundStyle(EchoiOSTheme.neoCyan)
                                Text(isSearching ? "No Results for '\(store.navidromeSearchQuery)'" : "No Albums Loaded Yet")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(EchoiOSTheme.textPrimary)
                                if !isSearching {
                                    Button {
                                        Task { await store.refreshNavidromeHome() }
                                    } label: {
                                        Label("Reload from Navidrome", systemImage: "arrow.clockwise")
                                            .font(.system(size: 13, weight: .bold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(EchoiOSTheme.neoCyan)
                                            .foregroundStyle(.black)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(28)
                            .background(EchoiOSTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(EchoiOSTheme.canvas)
            .navigationTitle("Navidrome")
            .toolbar {
                if store.navidromeConfig.isConfigured {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            Task { await store.refreshNavidromeHome() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(store.isLoadingNavidrome)

                        Button {
                            showEditLogin.toggle()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .refreshable {
                await store.refreshNavidromeHome()
            }
            .onAppear {
                loginURL = store.navidromeConfig.serverURL.isEmpty ? iOSEchoStore.presetUnraidTailscaleNavidromeURL : store.navidromeConfig.serverURL
                loginUser = store.navidromeConfig.username
                loginPass = store.navidromeConfig.password
            }
            .task {
                if store.navidromeConfig.isConfigured && store.navidromeAlbums.isEmpty && !store.isLoadingNavidrome {
                    await store.refreshNavidromeHome()
                }
            }
            .navigationDestination(for: NavidromeAlbum.self) { album in
                NavidromeAlbumDetailView(album: album)
            }
            .navigationDestination(for: NavidromeArtist.self) { artist in
                NavidromeArtistDetailView(artist: artist)
            }
            .navigationDestination(for: NavidromePlaylist.self) { playlist in
                NavidromePlaylistDetailView(playlist: playlist)
            }
        }
    }
}

struct NavidromeArtistDetailView: View {
    @Environment(iOSEchoStore.self) private var store
    let artist: NavidromeArtist
    @State private var albums: [NavidromeAlbum] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    RemoteArtworkImage(url: NavidromeClient.coverArtURL(coverArtID: artist.coverArt, size: 300, config: store.navidromeConfig))
                        .frame(width: 74, height: 74)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(EchoiOSTheme.neoCyan.opacity(0.55), lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NAVIDROME ARTIST")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .foregroundStyle(EchoiOSTheme.neoCyan)
                        Text(artist.name)
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                        Text("\(albums.isEmpty ? artist.albumCount : albums.count) albums")
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(EchoiOSTheme.textMuted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                if isLoading {
                    ProgressView().tint(EchoiOSTheme.neoCyan).frame(maxWidth: .infinity).padding(32)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 16) {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                VStack(alignment: .leading, spacing: 8) {
                                    RemoteArtworkImage(url: NavidromeClient.coverArtURL(coverArtID: album.coverArt, size: 400, config: store.navidromeConfig))
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                    Text(album.name)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                        .lineLimit(1)
                                    if let y = album.year {
                                        Text("\(String(y)) · \(album.songCount) tracks")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(EchoiOSTheme.textMuted)
                                    }
                                }
                                .padding(10)
                                .background(EchoiOSTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(EchoiOSTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            albums = (try? await store.navidromeClient.fetchArtistAlbums(artistID: artist.id, config: store.navidromeConfig)) ?? []
            isLoading = false
        }
    }
}

struct NavidromePlaylistDetailView: View {
    @Environment(iOSEchoStore.self) private var store
    let playlist: NavidromePlaylist
    @State private var songs: [NavidromeSong] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("NAVIDROME PLAYLIST")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .foregroundStyle(EchoiOSTheme.neoMint)
                        Text(playlist.name)
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                        Text("\(songs.isEmpty ? playlist.songCount : songs.count) tracks")
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(EchoiOSTheme.textMuted)
                    }
                    Spacer()
                    Button {
                        store.playNavidromeSongs(songs, startingAt: 0)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.system(size: 12.5, weight: .black))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(EchoiOSTheme.neoCyan)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                    }
                    .buttonStyle(.plain)
                    .disabled(songs.isEmpty)
                }
                .padding(.horizontal, 16)

                if isLoading {
                    ProgressView().tint(EchoiOSTheme.neoCyan).frame(maxWidth: .infinity).padding(32)
                } else {
                    VStack(spacing: 0) {
                        TrackListColumnHeader(leadingLabel: "ART", showFormat: true)
                        Divider().overlay(EchoiOSTheme.border)
                        ForEach(Array(songs.enumerated()), id: \.offset) { idx, song in
                            let isCurrent = store.player.currentItem?.id == "nd-\(song.id)"
                            let primary = (song.suffix ?? "STREAM").uppercased()
                            let detail = song.bitRate.map { "\($0)k" }
                            let isLossless = ["FLAC", "ALAC", "WAV"].contains(primary)
                            StyledTrackRow(
                                indexNumber: nil,
                                title: song.title,
                                subtitle: "\(song.artist) · \(song.album)",
                                duration: TimeInterval(song.duration),
                                formatPrimary: primary,
                                formatDetail: detail,
                                isHiRes: false,
                                isLossless: isLossless,
                                localArtworkURL: nil,
                                remoteArtworkURL: NavidromeClient.coverArtURL(coverArtID: song.coverArt, size: 160, config: store.navidromeConfig),
                                isCurrent: isCurrent,
                                isPlaying: isCurrent && store.player.isPlaying,
                                accentColor: EchoiOSTheme.neoCyan,
                                isAlternateRow: idx % 2 == 1
                            ) {
                                store.playNavidromeSongs(songs, startingAt: idx)
                            }
                            if idx < songs.count - 1 {
                                Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 64)
                            }
                        }
                    }
                    .background(EchoiOSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(EchoiOSTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            songs = (try? await store.navidromeClient.fetchPlaylistSongs(playlistID: playlist.id, config: store.navidromeConfig)) ?? []
            isLoading = false
        }
    }
}

struct NavidromeOfflineSongButton: View {
    @Environment(iOSEchoStore.self) private var store
    let song: NavidromeSong

    var body: some View {
        let isOffline = store.isNavidromeSongOffline(song.id)
        let isDownloading = store.downloadingNavidromeIDs.contains(song.id)

        if isDownloading {
            ProgressView()
                .tint(EchoiOSTheme.neoCyan)
                .scaleEffect(0.75)
                .frame(width: 26, height: 26)
        } else if isOffline {
            Menu {
                Button(role: .destructive) {
                    Task { await store.removeNavidromeOfflineSong(song.id) }
                } label: {
                    Label("Remove Offline Download", systemImage: "trash")
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(EchoiOSTheme.neoMint)
                    .frame(width: 26, height: 26)
            }
        } else {
            Button {
                Task { await store.downloadNavidromeSongOffline(song) }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(EchoiOSTheme.neoCyan)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
    }
}

struct NavidromeAlbumDetailView: View {
    @Environment(iOSEchoStore.self) private var store
    let album: NavidromeAlbum
    @State private var songs: [NavidromeSong] = []
    @State private var isLoading = true
    @State private var showLightbox = false

    private var totalDuration: TimeInterval {
        TimeInterval(songs.reduce(0) { $0 + $1.duration })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [EchoiOSTheme.neoCyan.opacity(0.20), EchoiOSTheme.neoMint.opacity(0.06), EchoiOSTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))

                    HStack(spacing: 16) {
                        Button {
                            showLightbox = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                RemoteArtworkImage(url: NavidromeClient.coverArtURL(coverArtID: album.coverArt, size: 500, config: store.navidromeConfig))
                                    .frame(width: 116, height: 116)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(EchoiOSTheme.neoCyan)
                                    .frame(width: 22, height: 22)
                                    .background(Color.black.opacity(0.72))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(5)
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("NAVIDROME · STREAM")
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(EchoiOSTheme.neoCyan)

                            Text(album.name)
                                .font(.system(size: 19, weight: .black))
                                .foregroundStyle(EchoiOSTheme.textPrimary)
                                .lineLimit(2)

                            Text(album.artist)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(EchoiOSTheme.textSecondary)
                                .lineLimit(1)

                            if !songs.isEmpty {
                                Text("\(album.year.map { "\($0) · " } ?? "")\(songs.count) TRACKS · \(iOSFormatters.duration(totalDuration))")
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.textMuted)
                            }

                            HStack(spacing: 8) {
                                Button {
                                    store.player.isShuffled = false
                                    store.playNavidromeSongs(songs, startingAt: 0)
                                } label: {
                                    Label("Stream", systemImage: "play.fill")
                                        .font(.system(size: 12.5, weight: .black))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(EchoiOSTheme.neoCyan)
                                        .foregroundStyle(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                }
                                .buttonStyle(.plain)
                                .disabled(songs.isEmpty)

                                Button {
                                    store.player.isShuffled = true
                                    store.playNavidromeSongs(songs, startingAt: Int.random(in: 0..<max(1, songs.count)))
                                } label: {
                                    Label("Shuffle", systemImage: "shuffle")
                                        .font(.system(size: 12.5, weight: .bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(EchoiOSTheme.surfaceElevated)
                                        .foregroundStyle(EchoiOSTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(songs.isEmpty)

                                let allSaved = !songs.isEmpty && songs.allSatisfy { store.isNavidromeSongOffline($0.id) }
                                Button {
                                    Task { await store.downloadNavidromeAlbumOffline(songs: songs) }
                                } label: {
                                    Image(systemName: allSaved ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .frame(width: 34, height: 34)
                                        .background(allSaved ? EchoiOSTheme.neoMint.opacity(0.22) : EchoiOSTheme.surfaceElevated)
                                        .foregroundStyle(allSaved ? EchoiOSTheme.neoMint : EchoiOSTheme.neoCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(allSaved ? EchoiOSTheme.neoMint.opacity(0.6) : EchoiOSTheme.neoCyan.opacity(0.5), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(songs.isEmpty || allSaved)
                            }
                            .padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                }
                .padding(.horizontal, 16)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(32)
                } else {
                    VStack(spacing: 0) {
                        TrackListColumnHeader(leadingLabel: "#", showFormat: true)
                        Divider().overlay(EchoiOSTheme.border)

                        ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                            let isCurrent = store.player.currentItem?.id == "nd-\(song.id)"
                            let primary = (song.suffix ?? "STREAM").uppercased()
                            let detail = song.bitRate.map { "\($0)k" }
                            let isLossless = ["FLAC", "ALAC", "WAV"].contains(primary)

                            HStack(spacing: 0) {
                                StyledTrackRow(
                                    indexNumber: song.track ?? (idx + 1),
                                    title: song.title,
                                    subtitle: song.artist,
                                    duration: TimeInterval(song.duration),
                                    formatPrimary: primary,
                                    formatDetail: detail,
                                    isHiRes: false,
                                    isLossless: isLossless,
                                    localArtworkURL: nil,
                                    remoteArtworkURL: nil,
                                    isCurrent: isCurrent,
                                    isPlaying: isCurrent && store.player.isPlaying,
                                    accentColor: EchoiOSTheme.neoCyan,
                                    isAlternateRow: idx % 2 == 1
                                ) {
                                    store.playNavidromeSongs(songs, startingAt: idx)
                                }
                                NavidromeOfflineSongButton(song: song)
                                    .padding(.trailing, 10)
                            }

                            if idx < songs.count - 1 {
                                Divider().overlay(EchoiOSTheme.border.opacity(0.65)).padding(.leading, 44)
                            }
                        }
                    }
                    .background(EchoiOSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(EchoiOSTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLightbox) {
            let quality = songs.first.map { s in
                let p = (s.suffix ?? "STREAM").uppercased()
                return s.bitRate.map { "\(p) · \($0)k" } ?? p
            }
            iOSAlbumLightboxSheet(
                albumTitle: album.name,
                artistName: album.artist,
                year: album.year,
                trackCount: songs.isEmpty ? album.songCount : songs.count,
                totalDuration: totalDuration > 0 ? totalDuration : nil,
                audioQuality: quality,
                localArtworkURL: nil,
                remoteArtworkURL: NavidromeClient.coverArtURL(coverArtID: album.coverArt, size: 800, config: store.navidromeConfig)
            )
            .environment(store)
        }
        .task {
            isLoading = true
            songs = (try? await store.navidromeClient.fetchAlbumSongs(albumID: album.id, config: store.navidromeConfig)) ?? []
            isLoading = false
        }
    }
}

// MARK: - Tab 4: Automatic Wi-Fi Sync + Navidrome Tailscale Settings + Crossfade

struct SyncAndSettingsTab: View {
    @Environment(iOSEchoStore.self) private var store
    @State private var ndURL = ""
    @State private var ndUser = ""
    @State private var ndPass = ""
    @State private var showMacSettings = false
    @State private var showNavidromeSettings = false
    @State private var showSyncDetails = false

    var body: some View {
        @Bindable var bindable = store
        NavigationStack {
            Form {
                // 1. Primary Quick Controls: Manual Sync Now + Switches Only
                Section {
                    if store.isSyncing {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: store.syncProgressFraction)
                                .tint(EchoiOSTheme.neoMint)
                            Text("\(store.syncStatusText)\(store.syncCurrentItem.isEmpty ? "" : " · \(store.syncCurrentItem)")")
                                .font(.system(size: 12))
                                .foregroundStyle(EchoiOSTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            Task { await store.syncNow() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Sync Now")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(EchoiOSTheme.neoMint.opacity(0.18))
                            .foregroundStyle(EchoiOSTheme.neoMint)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl, style: .continuous)
                                    .strokeBorder(EchoiOSTheme.neoMint.opacity(0.65), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    }

                    if let err = store.syncError {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundStyle(EchoiOSTheme.dangerCoral)
                            if err.contains("Local Network"),
                               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                Button("Open Settings (Local Network)") {
                                    UIApplication.shared.open(settingsURL)
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(EchoiOSTheme.neoCyan)
                            }
                        }
                    }

                    Toggle("Auto-Sync on Home Wi-Fi", isOn: $bindable.autoSyncEnabled)
                        .tint(EchoiOSTheme.neoMint)
                        .onChange(of: store.autoSyncEnabled) { _, _ in store.saveWiFiSyncSettings() }

                    Toggle("Auto-Download New Podcast Episodes", isOn: $bindable.autoDownloadNewPodcasts)
                        .tint(EchoiOSTheme.neoMint)
                        .onChange(of: store.autoDownloadNewPodcasts) { _, _ in store.saveWiFiSyncSettings() }

                    Toggle("Equal-Power Crossfade (Offline)", isOn: Binding(
                        get: { store.player.crossfadeEnabled },
                        set: {
                            store.player.crossfadeEnabled = $0
                            store.saveCrossfadeSettings()
                        }
                    ))
                    .tint(EchoiOSTheme.neoMint)
                }
                .listRowBackground(EchoiOSTheme.surface)

                // 2. Collapsed Settings & Related Details
                Section("Settings") {
                    DisclosureGroup(isExpanded: $showMacSettings) {
                        if !store.discoveredMacs.isEmpty {
                            ForEach(store.discoveredMacs) { mac in
                                Button {
                                    store.selectDiscoveredMac(mac)
                                } label: {
                                    HStack {
                                        Image(systemName: "desktopcomputer")
                                            .foregroundStyle(EchoiOSTheme.neoMint)
                                        VStack(alignment: .leading) {
                                            Text(mac.name)
                                                .foregroundStyle(EchoiOSTheme.textPrimary)
                                                .font(.system(size: 14, weight: .bold))
                                            Text(mac.baseURLString)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(EchoiOSTheme.textMuted)
                                        }
                                        Spacer()
                                        if store.macServerURL == mac.baseURLString {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(EchoiOSTheme.neoMint)
                                        }
                                    }
                                }
                            }
                        }

                        TextField("Mac Wi-Fi URL (e.g. http://192.168.0.50:48721)", text: $bindable.macServerURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: store.macServerURL) { _, _ in store.saveWiFiSyncSettings() }

                        TextField("Mac Tailscale Fallback (e.g. http://100.86.21.27:48721)", text: $bindable.macTailscaleURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: store.macTailscaleURL) { _, _ in store.saveWiFiSyncSettings() }

                        HStack(spacing: 8) {
                            Button {
                                store.macServerURL = iOSEchoStore.presetMacTailscaleURL
                                store.macTailscaleURL = iOSEchoStore.presetMacTailscaleURL
                                store.saveWiFiSyncSettings()
                            } label: {
                                Text("Preset: Mac Tailscale (100.86.21.27)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(EchoiOSTheme.neoCyan.opacity(0.16))
                                    .foregroundStyle(EchoiOSTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                            }
                            .buttonStyle(.plain)
                        }

                        TextField("6-Digit Pairing PIN (from My Echo Mac)", text: $bindable.pairingPIN)
                            .keyboardType(.numberPad)
                            .onChange(of: store.pairingPIN) { _, newValue in
                                store.saveWiFiSyncSettings()
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.count == 6 && !store.macServerURL.isEmpty && !store.isSyncing {
                                    Task { await store.syncNow() }
                                }
                            }
                    } label: {
                        Label("Mac Connection & Pairing", systemImage: "desktopcomputer")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                    }
                    .tint(EchoiOSTheme.neoMint)

                    DisclosureGroup(isExpanded: $showNavidromeSettings) {
                        ForEach(store.navidromeConfig.savedAddresses) { addr in
                            let isActive = store.navidromeConfig.serverURL
                                .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                                .lowercased() == addr.url.lowercased()
                            HStack {
                                Button {
                                    ndURL = addr.url
                                    store.switchNavidromeAddress(addr)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isActive ? EchoiOSTheme.neoCyan : EchoiOSTheme.textMuted)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(addr.label)
                                                .font(.system(size: 13.5, weight: .bold))
                                                .foregroundStyle(EchoiOSTheme.textPrimary)
                                            Text(addr.url)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(EchoiOSTheme.textSecondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)

                                if store.navidromeConfig.savedAddresses.count > 1 {
                                    Button {
                                        store.removeNavidromeAddress(id: addr.id)
                                        ndURL = store.navidromeConfig.serverURL
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundStyle(EchoiOSTheme.textMuted)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        TextField("Add / Edit Server URL (e.g. http://192.168.0.x:4533)", text: $ndURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("Username", text: $ndUser)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        SecureField("Password", text: $ndPass)

                        Picker("Streaming Quality", selection: Binding(
                            get: { store.navidromeConfig.streamQuality },
                            set: { q in
                                var cfg = store.navidromeConfig
                                cfg.streamQuality = q
                                store.saveNavidromeConfig(cfg)
                            }
                        )) {
                            ForEach(NavidromeStreamQuality.allCases) { q in
                                Text(q.displayName).tag(q)
                            }
                        }

                        Button {
                            var cfg = store.navidromeConfig
                            cfg.isEnabled = true
                            cfg.serverURL = ndURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            cfg.username = ndUser.trimmingCharacters(in: .whitespacesAndNewlines)
                            cfg.password = ndPass
                            store.saveNavidromeConfig(cfg)
                            Task { await store.testNavidromeConnection() }
                        } label: {
                            HStack {
                                Label(store.isTestingNavidrome ? "Connecting..." : "Save & Test Navidrome", systemImage: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(EchoiOSTheme.neoCyan)
                                Spacer()
                                if store.isTestingNavidrome { ProgressView() }
                            }
                        }

                        if let status = store.navidromeStatusText {
                            Text(status)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EchoiOSTheme.neoMint)
                        }
                        if let err = store.navidromeError {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundStyle(EchoiOSTheme.dangerCoral)
                        }
                    } label: {
                        Label("Navidrome Streaming", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                    }
                    .tint(EchoiOSTheme.neoMint)

                    DisclosureGroup(isExpanded: $showSyncDetails) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(store.syncStatusText)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(store.syncError != nil ? EchoiOSTheme.dangerCoral : EchoiOSTheme.neoMint)
                        }

                        if let last = store.lastSyncedAt {
                            HStack {
                                Text("Last Synced")
                                Spacer()
                                Text(last.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(EchoiOSTheme.textSecondary)
                            }
                        }

                        HStack {
                            Text("Offline Storage Used")
                            Spacer()
                            Text(iOSFormatters.bytes(store.localStorageBytes))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(EchoiOSTheme.neoCyan)
                        }

                        if store.player.crossfadeEnabled {
                            HStack {
                                Text("Crossfade: \(Int(store.player.crossfadeDuration.rounded()))s")
                                Slider(
                                    value: Binding(
                                        get: { store.player.crossfadeDuration },
                                        set: {
                                            store.player.crossfadeDuration = $0.rounded()
                                            store.saveCrossfadeSettings()
                                        }
                                    ),
                                    in: 1...12,
                                    step: 1
                                )
                                .tint(EchoiOSTheme.neoMint)
                            }
                        }
                    } label: {
                        Label("Sync Status, Storage & Crossfade", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                    }
                    .tint(EchoiOSTheme.neoMint)
                }
                .listRowBackground(EchoiOSTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(EchoiOSTheme.canvas)
            .navigationTitle("Sync")
            .onAppear {
                ndURL = store.navidromeConfig.serverURL
                ndUser = store.navidromeConfig.username
                ndPass = store.navidromeConfig.password
            }
        }
    }
}

// MARK: - Persistent Mini Player Bar & Full Now Playing Sheet

struct FloatingMiniPlayerBar: View {
    @Environment(iOSEchoStore.self) private var store
    let item: PlayableItem
    let onTapOpen: () -> Void
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0

    var body: some View {
        let player = store.player
        let total = max(1, player.duration)
        let elapsed = min(total, max(0, isScrubbing ? scrubTime : player.currentTime))
        let remaining = max(0, player.duration - elapsed)
        let progress = player.duration > 0 ? min(1, max(0, elapsed / total)) : 0
        let accent = item.isStreaming ? EchoiOSTheme.neoCyan : EchoiOSTheme.neoMint

        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Group {
                    if let local = item.localArtworkURL {
                        LocalArtworkImage(url: local)
                    } else {
                        RemoteArtworkImage(url: item.remoteArtworkURL)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                            .lineLimit(1)
                        if item.isStreaming {
                            Text("TS")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(EchoiOSTheme.neoCyan.opacity(0.22))
                                .foregroundStyle(EchoiOSTheme.neoCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    Text(item.artist)
                        .font(.system(size: 11.5))
                        .foregroundStyle(EchoiOSTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTapOpen)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Button {
                    player.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(EchoiOSTheme.textPrimary)
                        .frame(width: 30, height: 34)
                }
                .buttonStyle(.plain)
            }

            // Interactive Timeline + Time Played vs Time Left
            HStack(spacing: 8) {
                Text(iOSFormatters.duration(elapsed))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .frame(minWidth: 34, alignment: .leading)

                GeometryReader { geo in
                    let width = max(1, geo.size.width)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 4)
                        Capsule()
                            .fill(accent)
                            .frame(width: max(4, width * progress), height: 4)
                        Circle()
                            .fill(accent)
                            .frame(width: isScrubbing ? 11 : 7, height: isScrubbing ? 11 : 7)
                            .offset(x: max(0, min(width - 7, width * progress - 3.5)))
                    }
                    .frame(height: 16)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isScrubbing = true
                                let frac = min(1, max(0, value.location.x / width))
                                scrubTime = frac * player.duration
                            }
                            .onEnded { value in
                                let frac = min(1, max(0, value.location.x / width))
                                let target = frac * player.duration
                                player.seek(to: target)
                                isScrubbing = false
                            }
                    )
                }
                .frame(height: 16)

                Text("-\(iOSFormatters.duration(remaining))")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(EchoiOSTheme.textMuted)
                    .frame(minWidth: 38, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 6)
        .background(EchoiOSTheme.surfaceElevated.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(accent.opacity(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
    }
}

struct NowPlayingSheetView: View {
    @Environment(iOSEchoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isScrubbing = false
    @State private var scrubVal: Double = 0
    @State private var showLightbox = false

    var body: some View {
        let player = store.player
        VStack(spacing: 22) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            if let item = player.currentItem {
                Button {
                    showLightbox = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let local = item.localArtworkURL {
                                LocalArtworkImage(url: local)
                            } else {
                                RemoteArtworkImage(url: item.remoteArtworkURL)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 310)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.neoMint.opacity(0.35), lineWidth: 1))
                        .shadow(color: .black.opacity(0.6), radius: 20, y: 8)

                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(EchoiOSTheme.neoMint)
                            .padding(8)
                            .background(Color.black.opacity(0.68))
                            .clipShape(Circle())
                            .padding(10)
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showLightbox) {
                    let matchingAlbum = store.albums.first { $0.title.caseInsensitiveCompare(item.album) == .orderedSame }
                    let qualityStr = item.formatDetail.map { "\(item.formatPrimary) · \($0)" } ?? item.formatPrimary
                    iOSAlbumLightboxSheet(
                        albumTitle: item.album.isEmpty ? item.title : item.album,
                        artistName: item.artist,
                        year: matchingAlbum?.year,
                        trackCount: matchingAlbum?.tracks.count,
                        totalDuration: matchingAlbum?.tracks.reduce(0) { $0 + $1.duration },
                        audioQuality: qualityStr,
                        localArtworkURL: item.localArtworkURL,
                        remoteArtworkURL: item.remoteArtworkURL
                    )
                    .environment(store)
                }

                VStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(EchoiOSTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(item.artist) · \(item.album)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(EchoiOSTheme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        TwoFactorFormatPill(
                            primary: item.formatPrimary,
                            detail: item.formatDetail,
                            isHiRes: item.isHiRes,
                            isLossless: item.isLossless
                        )
                        let badgeText: String = {
                            switch item.source {
                            case .localFile: return "OFFLINE LOCAL"
                            case .navidromeStream: return "TAILSCALE STREAM"
                            case .podcastStream: return "PODCAST STREAM"
                            }
                        }()
                        Text(badgeText)
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background((item.isStreaming ? EchoiOSTheme.neoCyan : EchoiOSTheme.neoMint).opacity(0.18))
                            .foregroundStyle(item.isStreaming ? EchoiOSTheme.neoCyan : EchoiOSTheme.neoMint)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(.top, 4)
                }

                VStack(spacing: 6) {
                    let played = isScrubbing ? scrubVal : player.currentTime
                    let remaining = max(0, player.duration - played)

                    Slider(
                        value: Binding(
                            get: { played },
                            set: { isScrubbing = true; scrubVal = $0 }
                        ),
                        in: 0...max(1, player.duration),
                        onEditingChanged: { editing in
                            if !editing {
                                player.seek(to: scrubVal)
                                isScrubbing = false
                            }
                        }
                    )
                    .tint(item.isStreaming ? EchoiOSTheme.neoCyan : EchoiOSTheme.neoMint)

                    HStack {
                        Text(iOSFormatters.duration(played))
                            .foregroundStyle(item.isStreaming ? EchoiOSTheme.neoCyan : EchoiOSTheme.neoMint)
                        Spacer()
                        Text(iOSFormatters.duration(player.duration))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(EchoiOSTheme.textMuted.opacity(0.7))
                        Spacer()
                        Text("-\(iOSFormatters.duration(remaining))")
                            .foregroundStyle(EchoiOSTheme.textSecondary)
                    }
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                }
                .padding(.horizontal, 24)

                HStack(spacing: 34) {
                    Button { player.isShuffled.toggle() } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18))
                            .foregroundStyle(player.isShuffled ? EchoiOSTheme.neoMint : EchoiOSTheme.textSecondary)
                    }
                    Button { player.previousTrack() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                    }
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .frame(width: 62, height: 62)
                            .background(EchoiOSTheme.neoMint)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
                    }
                    Button { player.nextTrack() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(EchoiOSTheme.textPrimary)
                    }
                    Button { player.cycleRepeatMode() } label: {
                        Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.system(size: 18))
                            .foregroundStyle(player.repeatMode != .off ? EchoiOSTheme.neoMint : EchoiOSTheme.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .background(EchoiOSTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - Shared iOS Visual Components

struct TwoFactorFormatPill: View {
    let primary: String
    let detail: String?
    let isHiRes: Bool
    let isLossless: Bool

    var body: some View {
        let color: Color = isHiRes ? EchoiOSTheme.hiResGold : (isLossless ? EchoiOSTheme.neoCyan : EchoiOSTheme.textSecondary)
        VStack(spacing: 0.5) {
            Text(primary)
                .font(.system(size: 9.5, weight: .black, design: .monospaced))
            if let detail {
                Text(detail)
                    .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.82))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.14))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall).strokeBorder(color.opacity(0.45), lineWidth: 0.8))
    }
}

struct LocalArtworkImage: View {
    let url: URL?
    var body: some View {
        Group {
            if let url, let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    EchoiOSTheme.surfaceElevated
                    Image(systemName: "waveform")
                        .font(.system(size: 24))
                        .foregroundStyle(EchoiOSTheme.neoMint.opacity(0.5))
                }
            }
        }
    }
}

struct RemoteArtworkImage: View {
    let url: URL?
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            EchoiOSTheme.surfaceElevated
                            Image(systemName: "waveform").foregroundStyle(EchoiOSTheme.neoCyan.opacity(0.5))
                        }
                    }
                }
            } else {
                ZStack {
                    EchoiOSTheme.surfaceElevated
                    Image(systemName: "waveform").foregroundStyle(EchoiOSTheme.neoCyan.opacity(0.5))
                }
            }
        }
    }
}

// MARK: - iOS / iPadOS Album Artwork & Editorial Lightbox Sheet

struct iOSAlbumLightboxSheet: View {
    @Environment(iOSEchoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let albumTitle: String
    let artistName: String
    let year: Int?
    let trackCount: Int?
    let totalDuration: TimeInterval?
    let audioQuality: String?
    let localArtworkURL: URL?
    let remoteArtworkURL: URL?

    private var albumInfo: SyncedAlbumEditorial? {
        store.albumEditorial(for: albumTitle)
    }

    private var artistInfo: SyncedArtistEditorial? {
        let primary = artistName.components(separatedBy: CharacterSet(charactersIn: ",;&")).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? artistName
        return store.artistEditorial(for: primary)
    }

    private var isFetching: Bool {
        store.fetchingEditorialKeys.contains(albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private var artworkResolutionText: String? {
        guard let url = localArtworkURL,
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        let w = Int(img.size.width * img.scale)
        let h = Int(img.size.height * img.scale)
        guard w > 0, h > 0 else { return nil }
        return "\(w) × \(h) px"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Large Artwork Showcase
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let local = localArtworkURL {
                                LocalArtworkImage(url: local)
                            } else {
                                RemoteArtworkImage(url: remoteArtworkURL)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 420)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard, style: .continuous)
                                .strokeBorder(EchoiOSTheme.neoMint.opacity(0.50), lineWidth: 1.2)
                        )
                        .shadow(color: .black.opacity(0.65), radius: 22, y: 10)

                        if let res = artworkResolutionText {
                            Text(res)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(EchoiOSTheme.neoMint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.78))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(EchoiOSTheme.neoMint.opacity(0.45), lineWidth: 0.8))
                                .padding(10)
                        }
                    }

                    // Album Title + Artist Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ALBUM & ARTIST INFO")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.3)
                            .foregroundStyle(EchoiOSTheme.neoMint)

                        Text(albumTitle)
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(EchoiOSTheme.textPrimary)

                        HStack(spacing: 8) {
                            if let picStr = albumInfo?.artistImageURL ?? artistInfo?.imageURL,
                               let picURL = URL(string: picStr) {
                                AsyncImage(url: picURL) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 24, height: 24)
                                            .clipShape(Circle())
                                            .overlay(Circle().strokeBorder(EchoiOSTheme.neoMint.opacity(0.55), lineWidth: 1))
                                    }
                                }
                            }
                            Text(artistName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(EchoiOSTheme.neoMint)
                        }
                    }

                    // Structured Metadata Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        lightboxMetaTile(
                            label: "RELEASE",
                            value: albumInfo?.releaseDate ?? year.map(String.init) ?? "Unknown",
                            icon: "calendar"
                        )
                        if let tc = trackCount {
                            let durStr = totalDuration.map { " · \(iOSFormatters.duration($0))" } ?? ""
                            lightboxMetaTile(
                                label: "TRACKS",
                                value: "\(tc) tracks\(durStr)",
                                icon: "music.note.list"
                            )
                        }
                        if let q = audioQuality, !q.isEmpty {
                            lightboxMetaTile(label: "AUDIO QUALITY", value: q, icon: "waveform")
                        }
                        if let label = albumInfo?.label {
                            lightboxMetaTile(label: "RECORD LABEL", value: label, icon: "opticaldisc")
                        }
                        if let fans = albumInfo?.artistFans ?? artistInfo?.fans {
                            lightboxMetaTile(label: "ARTIST FANS", value: Self.compactCount(fans), icon: "heart.fill")
                        }
                        if let count = albumInfo?.artistAlbumCount ?? artistInfo?.albumCount {
                            lightboxMetaTile(label: "RELEASES", value: "\(count) releases", icon: "square.stack.fill")
                        }
                    }

                    // Genres
                    if let genres = albumInfo?.genres, !genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(genres.prefix(5), id: \.self) { g in
                                    Text(g)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(EchoiOSTheme.neoMint)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(EchoiOSTheme.neoMint.opacity(0.14))
                                        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall))
                                        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusSmall).strokeBorder(EchoiOSTheme.neoMint.opacity(0.4), lineWidth: 0.9))
                                }
                            }
                        }
                    }

                    // Album Summary
                    if let albumSummary = albumInfo?.albumSummary {
                        lightboxInfoBox(title: "ABOUT THIS ALBUM", text: albumSummary)
                    }

                    // Artist Bio
                    if let artistSummary = albumInfo?.artistSummary ?? artistInfo?.summary {
                        lightboxInfoBox(title: "ABOUT \(artistName.uppercased())", text: artistSummary)
                    } else if isFetching {
                        HStack(spacing: 8) {
                            ProgressView().tint(EchoiOSTheme.neoMint)
                            Text("Loading album & artist info...")
                                .font(.system(size: 12.5))
                                .foregroundStyle(EchoiOSTheme.textMuted)
                        }
                        .padding(.vertical, 6)
                    }

                    if let fetched = albumInfo?.fetchedAt ?? artistInfo?.fetchedAt {
                        Text("Cached locally · Updated \(fetched.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(EchoiOSTheme.textMuted)
                    }
                }
                .padding(18)
            }
            .background(EchoiOSTheme.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await store.ensureEditorialLoaded(albumTitle: albumTitle, artist: artistName, force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(EchoiOSTheme.neoMint)
                    }
                    .disabled(isFetching)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(EchoiOSTheme.neoMint)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await store.ensureEditorialLoaded(albumTitle: albumTitle, artist: artistName)
        }
    }

    private func lightboxMetaTile(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(EchoiOSTheme.neoMint)
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(EchoiOSTheme.textMuted)
            }
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(EchoiOSTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(EchoiOSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl))
        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusControl).strokeBorder(EchoiOSTheme.border, lineWidth: 1))
    }

    private func lightboxInfoBox(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(EchoiOSTheme.neoMint)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(EchoiOSTheme.textSecondary)
                .lineSpacing(3.5)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EchoiOSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: EchoiOSTheme.radiusCard).strokeBorder(EchoiOSTheme.borderStrong, lineWidth: 1))
    }

    private static func compactCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000.0) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000.0) }
        return "\(n)"
    }
}
