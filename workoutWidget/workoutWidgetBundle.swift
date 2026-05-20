//
//  workoutWidgetBundle.swift
//  workoutWidget
//
//  Created by Hon Luu on 2/2/2026.
//

import WidgetKit
import SwiftUI

@main
struct workoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        workoutWidget()
        workoutWidgetControl()
        workoutWidgetLiveActivity()
    }
}
