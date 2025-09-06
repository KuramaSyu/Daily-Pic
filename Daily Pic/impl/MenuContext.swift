import SwiftUI

struct MenuContent<VM: GalleryViewModelProtocol, IM: ImageTrackerProtocol>: View {
    @Namespace var mainNamespace
    @Environment(\.resetFocus) var resetFocus
    @ObservedObject var vm: VM
    @Binding var api: WallpaperApiEnum
    let menuIcon: NSImage
    let imageTracker: IM

    var body: some View {
        ZStack {
            VStack {
                Text(getTitleText())
                    .font(.headline)
                    .padding(.top, 15)
                if let title = vm.currentImage?.getTitle() {
                    Text(title).font(.subheadline)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        SettingsWindowController.shared.showSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .padding(6)
                    }
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(6)
                Spacer()
            }
        }

        if let nextImage = vm.revealNextImage {
            RevealNextImageView(revealNextImage: nextImage, vm: self.vm)
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.8), value: (vm.revealNextImage != nil))
        }

        VStack {
            if let currentImage = vm.currentImage {
                DropdownWithToggles(
                    image: currentImage,
                    imageManager: vm
                )
                if let loaded = currentImage.loadNSImage() {
                    Image(nsImage: loaded)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .shadow(radius: 3)
                        .onTapGesture { openInViewer(url: currentImage.url) }
                }
            } else {
                VStack(alignment: .center) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud")
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 50, minHeight: 50)
                        .padding(.top, 10)
                    Text("No image available.").font(.headline).padding(10)
                    Text("Downloading images from last 7 days...").font(.headline).padding(10)
                }
                .scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200, alignment: .center)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }

            ImageNavigation(imageManager: vm).scaledToFit()
            ApiSelection(selectedApi: $api).scaledToFit()
            QuickActions(imageManager: vm, imageTracker: imageTracker)
                .layoutPriority(2)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 15)
        .frame(width: 350, height: 450)
        .focusScope(mainNamespace)
        .onAppear {
            Task { try await imageTracker.downloadMissingImages(from: nil, reloadImages: true) }
        }
        .focusEffectDisabled(true)
    }

    private func getTitleText() -> String {
        let wrap = { (date: String) in "Picture of \(date)" }
        guard let image = vm.currentImage else {
            return wrap(DateParser.prettyDate(for: Date()))
        }
        return image.getSubtitle()
    }

    private func openInViewer(url: URL) { NSWorkspace.shared.open(url) }
}
