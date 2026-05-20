//
//  workoutWidgetLiveActivity.swift
//  workoutWidget
//
//  Created by Hon Luu on 2/2/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct workoutWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct workoutWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: workoutWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension workoutWidgetAttributes {
    fileprivate static var preview: workoutWidgetAttributes {
        workoutWidgetAttributes(name: "World")
    }
}

extension workoutWidgetAttributes.ContentState {
    fileprivate static var smiley: workoutWidgetAttributes.ContentState {
        workoutWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: workoutWidgetAttributes.ContentState {
         workoutWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: workoutWidgetAttributes.preview) {
   workoutWidgetLiveActivity()
} contentStates: {
    workoutWidgetAttributes.ContentState.smiley
    workoutWidgetAttributes.ContentState.starEyes
}
