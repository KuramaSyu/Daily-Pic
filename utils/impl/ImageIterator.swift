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
struct StrategyBasedImageIterator: IteratorProtocol {
    private let items: [NamedImage]
    private var strategy: ImageSelectionStrategy
    private var currentIndex: Int?
    
    init(items: [NamedImage], strategy: ImageSelectionStrategy) {
        self.items = items
        self.strategy = strategy
        self.currentIndex = items.isEmpty ? nil : -1
    }
    
    mutating func next() -> NamedImage? {
        guard let currentIndex = currentIndex else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < items.count else { return nil }
        self.currentIndex = nextIndex
        return items[nextIndex]
    }
    
    mutating func previous() -> NamedImage? {
        guard let currentIndex = currentIndex, currentIndex > 0 else { return nil }
        self.currentIndex = currentIndex - 1
        return items[self.currentIndex!]
    }
    
    mutating func first() -> NamedImage? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = 0
        return items[self.currentIndex!]
    }
    
    mutating func last() -> NamedImage? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = items.count - 1
        return items[self.currentIndex!]
    }
    
    mutating func random() -> NamedImage? {
        return strategy.selectImage(from: items)
    }
    
    mutating func setStrategy(_ newStrategy: ImageSelectionStrategy) {
        self.strategy = newStrategy
    }
}
