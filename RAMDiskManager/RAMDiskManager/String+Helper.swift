//
//  String+Helper.swift
//  RAMDiskManager
//
//  Created by Yannick Hilber on 27.11.21.
//  Copyright © 2021 Stoyan Stoyanov. All rights reserved.
//

import Foundation
import AppKit

extension String {
    private static let slugSeparator = "_"
    private static let slugSafeCharacters = "0123456789abcdefghijklmnopqrstuvwxyz"
    public func convertedToSlug() -> String {
        return self
          .applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false)? // æ -> ae
          .applyingTransform(.stripDiacritics, reverse: false)? // é -> e
          .lowercased() // A -> a
          .split(whereSeparator: { !String.slugSafeCharacters.contains($0) }) // "a:/a.,a;$-a" -> ["a", "a", "a", "a"]
          .joined(separator: String.slugSeparator) // ["a", "a", "a", "a"] -> "a_a_a_a"
          ?? ""
    }

    public func showInAlert() {
        let alert = NSAlert();
        alert.messageText = self;
        alert.runModal();
    }
}
