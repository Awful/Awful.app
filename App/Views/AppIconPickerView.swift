//  AppIconPickerView.swift
//
//  Copyright 2022 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

struct AppIconPickerView: View {
    
    let appIcons: [AppIcon] = findAppIcons()
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack{
                ForEach(appIcons, id: \.iconName) { icon in
                    Button(action: {
                        if icon.iconName == "AppIcon" {
                            UIApplication.shared.setAlternateIconName(nil)
                        } else {
                            UIApplication.shared.setAlternateIconName(icon.iconName)
                        }
                    }){
                        Image("\(icon.iconName)Image")
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
}

#if DEBUG
struct AppIconPickerView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconPickerView()
    }
}
#endif
