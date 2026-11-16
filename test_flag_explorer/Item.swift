//
//  Item.swift
//  test_flag_explorer
//
//  Created by Linh PQ on 11/16/26.
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
