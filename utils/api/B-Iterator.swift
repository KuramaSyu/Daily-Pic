//
//  B-Iterator.swift
//  Daily Pic
//
//  Created by Paul Zenker on 27.01.25.
//

struct BidirectionalArrayIterator<T>: IteratorProtocol {
    private let items: [T]
    private var currentIndex: Int?

    init(items: [T]) {
        self.items = items
        self.currentIndex = items.isEmpty ? nil : -1 // Start before the first item
    }

    // Required by IteratorProtocol
    mutating func next() -> T? {
        guard let currentIndex = currentIndex else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < items.count else { return nil }
        self.currentIndex = nextIndex
        return items[nextIndex]
    }

    // Custom functionality
    mutating func previous() -> T? {
        guard let currentIndex = currentIndex, currentIndex > 0 else { return nil }
        self.currentIndex = currentIndex - 1
        return items[self.currentIndex!]
    }

    mutating func first() -> T? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = 0
        return items[self.currentIndex!]
    }

    mutating func last() -> T? {
        guard !items.isEmpty else { return nil }
        self.currentIndex = items.count - 1
        return items[self.currentIndex!]
    }
    
    mutating func random() -> T? {
        if items.isEmpty {
            return nil
        }
        let randomIndex = Int.random(in: 0..<items.count)
        self.currentIndex = randomIndex
        return items[randomIndex]
    }
}


protocol BidirectionalIterable {
    associatedtype Element
    mutating func next() -> Element?
    mutating func previous() -> Element?
    mutating func first() -> Element?
    mutating func last() -> Element?
}
