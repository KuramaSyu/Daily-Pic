import SwiftUI
import os
import UniformTypeIdentifiers

protocol ImageSelectionStrategy {
    func selectImage(from images: [NamedBingImage]) -> NamedBingImage?
}

// Strategy for selecting any random image
struct AnyRandomImageStrategy: ImageSelectionStrategy {
    func selectImage(from images: [NamedBingImage]) -> NamedBingImage? {
        return images.randomElement()
    }
}

// Strategy for selecting only favorite images
struct FavoriteRandomImageStrategy: ImageSelectionStrategy {
    let favorites: Set<NamedBingImage>
    
    func selectImage(from images: [NamedBingImage]) -> NamedBingImage? {
        let favoriteImages = images.filter { favorites.contains($0) }
        return favoriteImages.randomElement()
    }
}

// Iterator that supports different strategies
class StrategyBasedImageIterator: IteratorProtocol {
    private var items: [NamedBingImage]
    private var strategy: ImageSelectionStrategy
    private var currentIndex: Int?
    
    init(items: [NamedBingImage], strategy: ImageSelectionStrategy) {
        self.items = items
        self.strategy = strategy
        self.currentIndex = items.isEmpty ? nil : -1
    }
    
    func setItems(_ items: [NamedBingImage], track_index: Bool = false) {
        if items == self.items {
            print("images are same")
            return }
        print("images are different")
        let current_url = self.current()?.url
        self.items = items
        if track_index == true && current_url != nil {
            setIndexByUrl(current_url!);
        } else {
            self.currentIndex = items.isEmpty ? nil : -1
        }
    }
    
    func getItems() -> [NamedBingImage] {
        return self.items
    }
    
    func current() -> NamedBingImage? {
        guard let currentIndex = currentIndex else { return nil }
        if currentIndex >= items.count {
            return last()
        }
        return items[currentIndex]
    }
    func next() -> NamedBingImage? {
        guard let currentIndex = currentIndex else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < items.count else { return nil }
        self.currentIndex = nextIndex
        return items[nextIndex]
    }
    
    func previous() -> NamedBingImage? {
        guard let currentIndex = currentIndex, currentIndex > 0 else { return nil }
        self.currentIndex = currentIndex - 1
        return items[self.currentIndex!]
    }
    
    func first() -> NamedBingImage? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = 0
        return items[self.currentIndex!]
    }
    
    func last() -> NamedBingImage? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = items.count - 1
        return items[self.currentIndex!]
    }
    
    func random() -> NamedBingImage? {
        let image = strategy.selectImage(from: items)
        guard let image = image else {return nil}
        if let index = items.firstIndex(of: image) {
            self.currentIndex = index
        }
        return image
    }
    
    func setStrategy(_ newStrategy: ImageSelectionStrategy) {
        self.strategy = newStrategy
    }
    
    func getStrategy() -> ImageSelectionStrategy {
        return strategy
    }
    
    func isLast() -> Bool {
        guard !items.isEmpty else { return false }

        return currentIndex! >= (items.count - 1)
    }
    
    func isFirst() -> Bool {
        guard !items.isEmpty else { return true }
        return currentIndex! <= 0
    }
    
    func setIndexByUrl(_ current_image_url: URL) {
        var index_of_previous_image: Int? = nil
        for (index, image) in items.enumerated() {
            if image.url == current_image_url {
                index_of_previous_image = index
                print("New index of previous image: \(index)")
                break
            }
        }
        if let index = index_of_previous_image {
            currentIndex = index
        }
    }

}
