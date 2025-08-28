//
//  NamedImage.swift
//  Daily Pic
//
//  Created by Paul Zenker on 19.05.25.
//
import AppKit

public protocol NamedImageProtocol: Hashable, AnyObject {
    init(url: URL, creation_date: Date, image: NSImage?)
    var url: URL { get set }
    func unloadImage();
    func exists() -> Bool;
    func getTitle() -> String;
    func getSubtitle() -> String;
    func getDescription() -> String;
    func getDate() -> Date?;
    func loadNSImage() -> NSImage?; 
}
