//
//  Download.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//
import Foundation


let resolutions = ["auto", "UHD", "1920x1200", "1920x1080", "1366x768", "1280x720", "1024x768", "800x600"]

let markets = ["auto", "ar-XA", "da-DK", "de-AT", "de-CH", "de-DE", "en-AU", "en-CA", "en-GB",
    "en-ID", "en-IE", "en-IN", "en-MY", "en-NZ", "en-PH", "en-SG", "en-US", "en-WW", "en-XA", "en-ZA", "es-AR",
    "es-CL", "es-ES", "es-MX", "es-US", "es-XL", "et-EE", "fi-FI", "fr-BE", "fr-CA", "fr-CH", "fr-FR",
    "he-IL", "hr-HR", "hu-HU", "it-IT", "ja-JP", "ko-KR", "lt-LT", "lv-LV", "nb-NO", "nl-BE", "nl-NL",
    "pl-PL", "pt-BR", "pt-PT", "ro-RO", "ru-RU", "sk-SK", "sl-SL", "sv-SE", "th-TH", "tr-TR", "uk-UA",
    "zh-CN", "zh-HK", "zh-TW"]

let marketName = [
    "auto", "(شبه الجزيرة العربية‎) العربية", "dansk (Danmark)", "Deutsch (Österreich)",
    "Deutsch (Schweiz)", "Deutsch (Deutschland)", "English (Australia)", "English (Canada)",
    "English (United Kingdom)", "English (Indonesia)", "English (Ireland)", "English (India)", "English (Malaysia)",
    "English (New Zealand)", "English (Philippines)", "English (Singapore)", "English (United States)",
    "English (International)", "English (Arabia)", "English (South Africa)", "español (Argentina)", "español (Chile)",
    "español (España)", "español (México)", "español (Estados Unidos)", "español (Latinoamérica)", "eesti (Eesti)",
    "suomi (Suomi)", "français (Belgique)", "français (Canada)", "français (Suisse)", "français (France)",
    "(עברית (ישראל", "hrvatski (Hrvatska)", "magyar (Magyarország)", "italiano (Italia)", "日本語 (日本)", "한국어(대한민국)",
    "lietuvių (Lietuva)", "latviešu (Latvija)", "norsk bokmål (Norge)", "Nederlands (België)", "Nederlands (Nederland)",
    "polski (Polska)", "português (Brasil)", "português (Portugal)", "română (România)", "русский (Россия)",
    "slovenčina (Slovensko)", "slovenščina (Slovenija)", "svenska (Sverige)", "ไทย (ไทย)", "Türkçe (Türkiye)",
    "українська (Україна)", "中文（中国）", "中文（中國香港特別行政區）", "中文（台灣）"
]

let BingImageURL = "https://www.bing.com/HPImageArchive.aspx";
let BingParams: [String : Any] = [ "format": "js", "idx": 0 , "n": 8 , "mbl": 1 , "mkt": "" ]

class BingWallpaper {
    static let shared = BingWallpaper() // Singleton instance
    
    private init() {} // Private initializer to prevent external instantiation
    
    var json_cache: [String: Response] = [:]
    
    // Function to Build Query String
    func buildQuery(from parameters: [String: Any]) -> String {
        return parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }
    
    func fetchJSON(from url: URL) async throws -> Response? {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        do {
            if String(data: data, encoding: .utf8) != nil {
                // Print or handle the raw JSON string if needed
                // print("Raw JSON Data from \(url): \(jsonString)")
            }

            let response = try JSONDecoder().decode(Response.self, from: data)
            return response
        } catch {
            print("Error decoding data: \(error)")
            throw error
        }
    }

    /// Converts yyyymmdd date string to Date
    func convertToDate(from dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
//        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
//        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter.date(from: dateString)
    }

    /// Converts a Date to a yyyymmdd string
    func convertToString(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
//        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
//        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter.string(from: date)
    }
    
    func downloadImage(of date: Date) async -> Response? {
        print("Try to download for date \(date)")
        if let resp = json_cache[convertToString(from: date)] {
            return resp
        }
        let url = requestUrl(of: date)
        
        do {
            let json = try await fetchJSON(from: url)
            if let response = json {
                for picture in response.images {
                    print("Try to add \(picture.enddate)")
                    if let date = convertToDate(from: picture.enddate) {
                        print("Add \(date) to json_cache")
                        json_cache[picture.enddate] = Response(
                            market: response.market,
                            images: [picture]
                        )
                    }
                }
            }
            let resp = json_cache[convertToString(from: date)]
            return resp
        } catch {
            print("Error fetching or parsing JSON from \(url): \(error.localizedDescription)")
            return nil
        }
    }
    
    func daysDifference(from date: Date) -> Int {
        let calendar = Calendar.autoupdatingCurrent
        
        // Set both dates to midnight to normalize
        let today = calendar.startOfDay(for: Date())
        //let givenDateMidnight = calendar.date(bySettingHour: 1, minute: 1, second: 1, of: date)!
        
        // Calculate the difference in days
        let components = calendar.dateComponents([.day], from: date, to: today)
        let off =  abs(components.day ?? 0)
        print("offset of date \(date) and \(today) = \(off)")
        return off
    }
    
    func requestUrl(of date: Date) -> URL {
        let day_offset = daysDifference(from: date)
        let day_amount = 10 // limit should be 8
        // day_offset = min(7, day_offset)
        //print("offset of date \(date) = \(day_offset)")

        let parameters = getParameters(idx: day_offset, n: day_amount)
        let query = buildQuery(from: parameters)
        return URL(string: "\(BingImageURL)?\(query)")!
    }
    
    func getParameters(idx: Int = 0, n: Int = 1) -> [String: Any] {
        [ "format": "js", "idx": idx, "n": n, "mbl": 1, "mkt": "auto" ]
    }
}
