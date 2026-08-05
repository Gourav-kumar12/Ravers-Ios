//
//  Item.swift
//  Raverse-ios
//
//  Created by Gourav  on 05/08/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
