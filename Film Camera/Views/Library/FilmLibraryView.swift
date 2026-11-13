//
//  FilmLibraryView.swift
//  Film Camera
//

import SwiftUI

/// Browse the full film catalog, download films for offline use, and manage
/// the films that appear in the camera's film strip.
struct FilmLibraryView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case explore = "探索"
        case myFilms = "我的胶卷"
        var id: String { rawValue }
    }

    @Environment(FilmLibrary.self) private var library
    @Environment(CameraModel.self) private var camera
    @Environment(\.dismiss) private var dismiss

    @State private var scope: Scope = .explore
    @State private var category: String?
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @FocusState private var isSearchFocused: Bool
    @State private var confirmsDownloadAll = false

    var body: some View {
        NavigationStack {
            Group {
                switch scope {
                case .explore: explore
                case .myFilms: myFilms
                }
            }
            .navigationTitle("胶卷")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "柯达、富士、伊尔福…")
            .searchFocused($isSearchFocused)
            // Keep the navigation bar while searching; hiding it made the category
            // chips jump up and get clipped.
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("分类", selection: $scope) {
                        ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    switch scope {
                    case .myFilms:
                        EditButton()
                    case .explore:
                        Button("全部下载", systemImage: "arrow.down.circle") {
                            confirmsDownloadAll = true
                        }
                        .disabled(library.bulkDownload != nil || library.notYetDownloaded(filteredFilms).isEmpty)
                    }
                }
            }
            .confirmationDialog(downloadAllTitle, isPresented: $confirmsDownloadAll, titleVisibility: .visible) {
                Button("下载") { library.downloadAll(filteredFilms) }
            } message: {
                Text("下载后的胶卷可以离线使用，也会出现在相机的胶卷条里。")
            }
            .alert("下载失败", isPresented: errorBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(library.errorMessage ?? "")
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Explore

    private var filteredFilms: [Film] {
        library.films.filter { film in
            (category == nil || film.category == category) &&
            (searchText.isEmpty || film.displayName.localizedStandardContains(searchText)
                || film.displayCategory.localizedStandardContains(searchText))
        }
    }

    private var explore: some View {
        let films = filteredFilms
        let sections = Dictionary(grouping: films, by: \.category)
        let orderedCategories = library.categories.filter { sections[$0] != nil }

        return ScrollView {
            categoryChips
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 14)], spacing: 18, pinnedViews: []) {
                ForEach(orderedCategories, id: \.self) { key in
                    Section {
                        ForEach(sections[key] ?? []) { film in
                            FilmCard(film: film) { select(film) }
                        }
                    } header: {
                        Text(Film.prettyCategory(key))
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .safeAreaBar(edge: .bottom) {
            if let progress = library.bulkDownload {
                BulkDownloadBar(progress: progress) { library.cancelBulkDownload() }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: library.bulkDownload == nil)
        .overlay {
            if films.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .refreshable { await library.refreshCatalog() }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: "全部", value: nil)
                ForEach(library.categories, id: \.self) { key in
                    chip(title: Film.prettyCategory(key), value: key)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    @ViewBuilder
    private func chip(title: String, value: String?) -> some View {
        let isSelected = category == value
        let button = Button(title) {
            withAnimation(.snappy) { category = value }
        }
        .font(.subheadline.weight(.medium))
        if isSelected {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.glass)
        }
    }

    // MARK: - My Films

    private var myFilms: some View {
        let films = library.myFilms.filter {
            searchText.isEmpty || $0.displayName.localizedStandardContains(searchText)
        }
        return List {
            Section {
                ForEach(films) { film in
                    Button { select(film) } label: {
                        MyFilmRow(film: film, isSelected: camera.selectedFilmID == film.id)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("移除", systemImage: "trash", role: .destructive) { remove(film) }
                    }
                }
                .onDelete { offsets in offsets.map { films[$0] }.forEach(remove) }
                .onMove { library.moveMyFilms(from: $0, to: $1) }
            } footer: {
                Text("这里的胶卷会出现在相机下方的胶卷条中，并且可以离线使用。")
            }
        }
        .overlay {
            if library.myFilms.isEmpty {
                ContentUnavailableView {
                    Label("还没有胶卷", systemImage: "film.stack")
                } description: {
                    Text("去「探索」里下载胶卷，就能离线使用。")
                } actions: {
                    Button("去探索胶卷") { scope = .explore }
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }

    // MARK: - Actions

    private var downloadAllTitle: String {
        let films = library.notYetDownloaded(filteredFilms)
        let size = ByteCountFormatter.string(fromByteCount: Int64(films.count) * FilmLibrary.approximateBytesPerFilm, countStyle: .file)
        let scopeName = category.map { " \(Film.prettyCategory($0))" } ?? ""
        return films.count == 1
            ? "下载 1 卷\(scopeName)胶卷（\(size)）？"
            : "下载 \(films.count) 卷\(scopeName)胶卷（\(size)）？"
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            library.errorMessage != nil
        } set: { isPresented in
            if !isPresented { library.errorMessage = nil }
        }
    }

    private func select(_ film: Film) {
        Task {
            guard await library.download(film) else { return }
            await camera.selectFilm(film, lutURL: library.lutURL(for: film))
            // Dismissing the sheet while the search keyboard is still up can crash
            // UIKit's keyboard layout guide mid-transition; put the keyboard away first.
            if isSearchFocused || isSearchPresented {
                isSearchFocused = false
                isSearchPresented = false
                try? await Task.sleep(for: .milliseconds(400))
            }
            dismiss()
        }
    }

    private func remove(_ film: Film) {
        if camera.selectedFilmID == film.id {
            Task { await camera.selectFilm(nil, lutURL: nil) }
        }
        library.remove(film)
    }
}

// MARK: - Cells

private struct FilmCard: View {
    @Environment(FilmLibrary.self) private var library
    @Environment(CameraModel.self) private var camera
    let film: Film
    var onSelect: () -> Void

    var body: some View {
        let isDownloading = library.downloading.contains(film.id)
        let isOwned = library.isInMyFilms(film)
        let isSelected = camera.selectedFilmID == film.id

        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay { FilmThumbnail(url: library.thumbnailURL(for: film)) }
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color.filmPrimary : .clear, lineWidth: 2.5)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        badge(isDownloading: isDownloading, isOwned: isOwned)
                            .padding(6)
                    }
                Text(film.displayName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2, reservesSpace: true)
                    .foregroundStyle(isSelected ? Color.filmPrimary : .primary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
        .contextMenu {
            Button(isOwned ? "使用此胶卷" : "下载并使用", systemImage: isOwned ? "camera" : "arrow.down.circle", action: onSelect)
            if !isOwned {
                Button("下载", systemImage: "arrow.down.to.line") {
                    Task { await library.download(film) }
                }
            } else {
                Button("从「我的胶卷」移除", systemImage: "minus.circle", role: .destructive) {
                    if camera.selectedFilmID == film.id {
                        Task { await camera.selectFilm(nil, lutURL: nil) }
                    }
                    library.remove(film)
                }
            }
        }
        .accessibilityLabel(film.displayName)
        .accessibilityValue(isOwned ? "已下载" : "未下载")
    }

    @ViewBuilder
    private func badge(isDownloading: Bool, isOwned: Bool) -> some View {
        Group {
            if isDownloading {
                ProgressView().controlSize(.small)
            } else if isOwned {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.filmPrimary)
            } else {
                Image(systemName: "arrow.down")
                    .font(.caption.weight(.bold))
            }
        }
        .frame(width: 28, height: 28)
        .glassEffect(.regular, in: .circle)
        .transition(.scale.combined(with: .opacity))
    }
}

private struct MyFilmRow: View {
    @Environment(FilmLibrary.self) private var library
    let film: Film
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            FilmThumbnail(url: library.thumbnailURL(for: film))
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(film.displayName)
                    .font(.body.weight(.medium))
                Text(film.displayCategory)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.filmPrimary)
                    .font(.title3)
            }
        }
        .contentShape(.rect)
    }
}

private struct BulkDownloadBar: View {
    let progress: BulkDownloadProgress
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ProgressView(value: progress.fraction) {
                Text("正在下载胶卷")
                    .font(.subheadline.weight(.semibold))
            } currentValueLabel: {
                Text("\(progress.completed)/\(progress.total)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(progress.completed)))
            }
            Button("取消", systemImage: "xmark", action: onCancel)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .animation(.default, value: progress.completed)
    }
}
