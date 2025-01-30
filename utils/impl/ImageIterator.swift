import SwiftUI
import os
import UniformTypeIdentifiers

protocol ImageSelectionStrategy {
    func selectImage(from images: [NamedImage]) -> NamedImage?
}

// Strategy for selecting any random image
struct AnyRandomImageStrategy: ImageSelectionStrategy {
    func selectImage(from images: [NamedImage]) -> NamedImage? {
        return images.randomElement()
    }
}

// Strategy for selecting only favorite images
struct FavoriteRandomImageStrategy: ImageSelectionStrategy {
    let favorites: Set<NamedImage>
    
    func selectImage(from images: [NamedImage]) -> NamedImage? {
        let favoriteImages = images.filter { favorites.contains($0) }
        return favoriteImages.randomElement()
    }
}

// Iterator that supports different strategies
class StrategyBasedImageIterator: IteratorProtocol {
    private var items: [NamedImage]
    private var strategy: ImageSelectionStrategy
    private var currentIndex: Int?
    
    init(items: [NamedImage], strategy: ImageSelectionStrategy) {
        self.items = items
        self.strategy = strategy
        self.currentIndex = items.isEmpty ? nil : -1
    }
    
    func setItems(_ items: [NamedImage]) {
        if items == self.items {
            print("images are same")
            return }
        print("images are different")
        self.items = items
        self.currentIndex = items.isEmpty ? nil : -1
    }
    func current() -> NamedImage? {
        guard let currentIndex = currentIndex else { return nil }
        return items[currentIndex]
    }
    func next() -> NamedImage? {
        guard let currentIndex = currentIndex else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < items.count else { return nil }
        self.currentIndex = nextIndex
        return items[nextIndex]
    }
    
    func previous() -> NamedImage? {
        guard let currentIndex = currentIndex, currentIndex > 0 else { return nil }
        self.currentIndex = currentIndex - 1
        return items[self.currentIndex!]
    }
    
    func first() -> NamedImage? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = 0
        return items[self.currentIndex!]
    }
    
    func last() -> NamedImage? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = items.count - 1
        return items[self.currentIndex!]
    }
    
    func random() -> NamedImage? {
        return strategy.selectImage(from: items)
    }
    
    func setStrategy(_ newStrategy: ImageSelectionStrategy) {
        self.strategy = newStrategy
    }
    
    func getStrategy() -> ImageSelectionStrategy {
        return strategy
    }
    
    func isLast() -> Bool {
        return currentIndex! >= (items.count - 1)
    }
    
    func isFirst() -> Bool {
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
