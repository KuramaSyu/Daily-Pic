import SwiftUI
import os
import UniformTypeIdentifiers


// MARK: - Image Selection Strategy Protocol
public protocol ImageSelectionStrategy {
    associatedtype ImageType: NamedImageProtocol
    func selectImage(from images: [ImageType]) -> ImageType?
}

public struct AnyImageSelectionStrategy<ImageType: NamedImageProtocol>: ImageSelectionStrategy {
    public typealias ImageType = ImageType
    private let _selectImage: ( [ImageType] ) -> ImageType?
        
    init<S: ImageSelectionStrategy>(_ strategy: S) where S.ImageType == ImageType {
        self._selectImage = strategy.selectImage
    }
    
    public func selectImage(from images: [ImageType]) -> ImageType? {
        return self._selectImage(images)
    }
}

// MARK: - Random Selection Strategy
public struct AnyRandomImageStrategy<T: NamedImageProtocol>: ImageSelectionStrategy {
    public typealias ImageType = T

    public init() {}

    public func selectImage(from images: [T]) -> T? {
        return images.randomElement()
    }
}

// MARK: - Favorite-Only Random Strategy
public struct FavoriteRandomImageStrategy<T: NamedImageProtocol & Hashable>: ImageSelectionStrategy {
    public typealias ImageType = T

    let favorites: Set<T>

    public init(favorites: Set<T>) {
        self.favorites = favorites
    }

    public func selectImage(from images: [T]) -> T? {
        let favoriteImages = images.filter { favorites.contains($0) }
        return favoriteImages.randomElement()
    }
}

// Iterator that supports different strategies
class StrategyBasedImageIterator<imageType: NamedImageProtocol>: IteratorProtocol{
    typealias S = AnyImageSelectionStrategy<imageType>; // use of type erased struct, to define inner Type <imageType>
    private var items: [imageType]
    private var strategy: S
    private var currentIndex: Int?
    
    init<T: ImageSelectionStrategy>(items: [imageType], strategy: T) where T.ImageType == imageType {
        self.items = items
        self.strategy = AnyImageSelectionStrategy(strategy)
        self.currentIndex = items.isEmpty ? nil : -1
    }
    
    func setItems(_ items: [imageType], track_index: Bool = false) {
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
    
    func getItems() -> [imageType] {
        return self.items
    }
    
    func current() -> imageType? {
        guard let currentIndex = currentIndex else { return nil }
        if currentIndex >= items.count {
            return last()
        }
        return items[currentIndex]
    }
    func next() -> imageType? {
        guard let currentIndex = currentIndex else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < items.count else { return nil }
        self.currentIndex = nextIndex
        return items[nextIndex]
    }
    
    func previous() -> imageType? {
        guard let currentIndex = currentIndex, currentIndex > 0 else { return nil }
        self.currentIndex = currentIndex - 1
        return items[self.currentIndex!]
    }
    
    func first() -> imageType? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = 0
        return items[self.currentIndex!]
    }
    
    func last() -> imageType? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = items.count - 1
        return items[self.currentIndex!]
    }
    
    func random() -> imageType? {
        let image = self.strategy.selectImage(from: items)
        guard let image = image else {return nil}
        if let index = items.firstIndex(of: image) {
            self.currentIndex = index
        }
        return image
    }
    
    func setStrategy<T: ImageSelectionStrategy>(_ newStrategy: T) where T.ImageType == imageType {
        self.strategy = AnyImageSelectionStrategy(newStrategy)
    }
    
    func getStrategy() ->any ImageSelectionStrategy {
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
