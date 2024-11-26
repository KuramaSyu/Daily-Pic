//
//  Tasks.swift
//  DailyPic
//
//  Created by Paul Zenker on 26.11.24.
//

import SwiftUI
import Combine

class DelayedTaskManager: ObservableObject {
    // Stores the current countdown
    @Published var timeRemaining: TimeInterval = 0
    
    // Stores the cancellable task
    private var taskCancellable: Task<Void, Never>?
    
    // Private countdown timer
    private var countdownTimer: Timer?
    
    func scheduleTask(delay: TimeInterval, task: @escaping () async -> Void) {
        // Cancel any existing task
        taskCancellable?.cancel()
        countdownTimer?.invalidate()
        
        // Reset time remaining
        timeRemaining = delay
        
        // Start countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            self.timeRemaining -= 1
            
            if self.timeRemaining <= 0 {
                timer.invalidate()
            }
        }
        
        // Create a new task with delay
        taskCancellable = Task {
            do {
                // Wait for the specified delay
                try await Task.sleep(for: .seconds(delay))
                
                // Execute the actual task
                await task()
            } catch is CancellationError {
                print("Task was cancelled")
            } catch {
                print("Task failed: \(error)")
            }
        }
    }
    
    func cancelTask() {
        taskCancellable?.cancel()
        countdownTimer?.invalidate()
        timeRemaining = 0
    }
}

struct DelayedTaskView: View {
    @StateObject private var taskManager = DelayedTaskManager()
    
    func startTask() {
        taskManager.scheduleTask(delay: 300) {
            try? await ImageManager.shared.downloadImage(of: Date())
        }
    }
    var body: some View {
        VStack {
            // Countdown label
            Text(timeString(from: taskManager.timeRemaining))
                .font(.largeTitle)
                .padding()
            
//            // Start task button
//            Button("Start 5 Minute Delayed Task") {
//                taskManager.scheduleTask(delay: 300) {
//                    // Example task: downloading an image
//                    try? await ImageManager.shared.downloadImage(of: Date())
//                }
//            }
            
            // Cancel button
            Button("Cancel Task") {
                taskManager.cancelTask()
            }
            .disabled(taskManager.timeRemaining == 0)
        }
    }
    
    // Helper to format time
    func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
