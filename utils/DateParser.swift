//
//  DateHelper.swift
//  Daily Pic
//
//  Created by Paul Zenker on 19.05.25.
//
import AppKit

class DateParser {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    
    // Anchored to start: any 8-digit run deep in a SHA-256 hash (e.g. 80131228
    // inside hash 5cbe87b7...80131228...) would otherwise parse as a year-8013 date
    // and pin that file to the far-future end of the gallery sort.
    static let regex: NSRegularExpression? = {
        let pattern = "^\\d{8}"
        return try? NSRegularExpression(pattern: pattern)
    }()
    
    static func ordinalSuffix(for date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let day = calendar.component(.day, from: date)
        switch day % 10 {
        case 1 where day != 11: return "st"
        case 2 where day != 12: return "nd"
        case 3 where day != 13: return "rd"
        default: return "th"
        }
    }
    
    // Added function to centralize date formatting for views
    static func prettyDate(for date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d'\(ordinalSuffix(for: date))' MMMM"
        return outputFormatter.string(from: date)
    }
    
    static func getTodayMidnight() -> Date {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.startOfDay(for: Date())
    }
}
