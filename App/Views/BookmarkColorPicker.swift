//  SetBookmarkColor.swift
//
//  Copyright 2021 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import AwfulCore


struct BookmarkColorPicker: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode
    
    var thread: AwfulThread
    
    func containedView() -> String {
        switch thread.starCategory {
        case .orange: return Theme.defaultTheme()["unreadBadgeOrangeColor"]!.hexCode
        case .red: return Theme.defaultTheme()["unreadBadgeRedColor"]!.hexCode
        case .yellow: return Theme.defaultTheme()["unreadBadgeYellowColor"]!.hexCode
        case .teal: return Theme.defaultTheme()["unreadBadgeTealColor"]!.hexCode
        case .green: return Theme.defaultTheme()["unreadBadgeGreenColor"]!.hexCode
        case .purple: return Theme.defaultTheme()["unreadBadgePurpleColor"]!.hexCode
        case .none: return Theme.defaultTheme()["unreadBadgeBlueColor"]!.hexCode
        }
    }
    
    
    var body: some View {
        var selection = containedView()
        
        VStack {
            
            Text(thread.title!)
                .foregroundColor(Color(hex: Theme.defaultTheme()["sheetTitleColor"]!))
                .font(.system(size: 16.0, weight: .regular, design: .rounded))
                .padding()
            
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: Theme.defaultTheme()["unreadBadgeRedColor"]!.hexCode))
                        .frame(width: 30, height: 30)
                        .onTapGesture(perform: {
                            selection = Theme.defaultTheme()["unreadBadgeRedColor"]!.hexCode
                            
                            
                            _ = ForumsClient.shared.setBookmarkColor(thread, as: 1)
                                .done {
                                    _ = ForumsClient.shared.listBookmarkedThreads(page: 1)
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                                .catch { error in
                                    print(error.localizedDescription)
                                }
                        })
                        .padding(10)
                    
                    if selection == Theme.defaultTheme()["unreadBadgeRedColor"]!.hexCode {
                        Circle()
                            .stroke(Color(hex: Theme.defaultTheme()["unreadBadgeRedColor"]!.hexCode), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }
                
                
                
                ZStack {
                    Circle()
                        .fill(Color(hex: Theme.defaultTheme()["unreadBadgeOrangeColor"]!.hexCode))
                        .frame(width: 30, height: 30)
                        .onTapGesture(perform: {
                            _ = ForumsClient.shared.setBookmarkColor(thread, as: 0)
                                .done {
                                    _ = ForumsClient.shared.listBookmarkedThreads(page: 1)
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                                .catch { error in
                                    print(error.localizedDescription)
                                }
                        })
                        .padding(10)
                    
                    if selection == Theme.defaultTheme()["unreadBadgeOrangeColor"]!.hexCode {
                        Circle()
                            .stroke(Color(hex: Theme.defaultTheme()["unreadBadgeOrangeColor"]!.hexCode), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }
                
                
                ZStack {
                    Circle()
                        .fill(Color(hex: Theme.defaultTheme()["unreadBadgeYellowColor"]!.hexCode))
                        .frame(width: 30, height: 30)
                        .onTapGesture(perform: {
                            _ = ForumsClient.shared.setBookmarkColor(thread, as: 2)
                                .done {
                                    _ = ForumsClient.shared.listBookmarkedThreads(page: 1)
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                                .catch { error in
                                    print(error.localizedDescription)
                                }
                        })
                        .padding(10)
                    
                    if selection == Theme.defaultTheme()["unreadBadgeYellowColor"]!.hexCode {
                        Circle()
                            .stroke(Color(hex: Theme.defaultTheme()["unreadBadgeYellowColor"]!.hexCode), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }
                
                
                ZStack {
                    Circle()
                        .fill(Color(hex: Theme.defaultTheme()["unreadBadgeGreenColor"]!.hexCode))
                        .frame(width: 30, height: 30)
                        .onTapGesture(perform: {
                            _ = ForumsClient.shared.setBookmarkColor(thread, as: 4)
                                .done {
                                    _ = ForumsClient.shared.listBookmarkedThreads(page: 1)
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                                .catch { error in
                                    print(error.localizedDescription)
                                }
                        })
                        .padding(10)
                    
                    if selection == Theme.defaultTheme()["unreadBadgeGreenColor"]!.hexCode {
                        Circle()
                            .stroke(Color(hex: Theme.defaultTheme()["unreadBadgeGreenColor"]!.hexCode), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }
                
                ZStack {
                    Circle()
                        .fill(Color(hex: Theme.defaultTheme()["unreadBadgeTealColor"]!.hexCode))
                        .frame(width: 30, height: 30)
                        .onTapGesture(perform: {
                            _ = ForumsClient.shared.setBookmarkColor(thread, as: 3)
                                .done {
                                    _ = ForumsClient.shared.listBookmarkedThreads(page: 1)
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                                .catch { error in
                                    print(error.localizedDescription)
                                }
                        })
                        .padding(10)
                    
                    if selection == Theme.defaultTheme()["unreadBadgeTealColor"]!.hexCode {
                        Circle()
                            .stroke(Color(hex: Theme.defaultTheme()["unreadBadgeTealColor"]!.hexCode), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }
                
                
                ZStack {
                    Circle()
                        .fill(Color(hex: Theme.defaultTheme()["unreadBadgePurpleColor"]!.hexCode))
                        .frame(width: 30, height: 30)
                        .onTapGesture(perform: {
                            _ = ForumsClient.shared.setBookmarkColor(thread, as: 5)
                                .done {
                                    _ = ForumsClient.shared.listBookmarkedThreads(page: 1)
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                                .catch { error in
                                    print(error.localizedDescription)
                                }
                        })
                        .padding(10)
                    
                    if selection == Theme.defaultTheme()["unreadBadgePurpleColor"]!.hexCode {
                        Circle()
                            .stroke(Color(hex: Theme.defaultTheme()["unreadBadgePurpleColor"]!.hexCode), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }
                
            }

            .frame(
                 minWidth: 0,
                 maxWidth: .infinity,
                 minHeight: 0,
                 maxHeight: .infinity,
                 alignment: .top
               )
               .background(Color(hex: Theme.defaultTheme()["sheetBackgroundColor"]!).edgesIgnoringSafeArea(.all))
        }
        .background(Color(hex: Theme.defaultTheme()["sheetBackgroundColor"]!).edgesIgnoringSafeArea(.all))
    }
        
}

extension Color {
    init(hex string: String) {
        var string: String = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if string.hasPrefix("#") {
            _ = string.removeFirst()
        }
        
        // Double the last value if incomplete hex
        if !string.count.isMultiple(of: 2), let last = string.last {
            string.append(last)
        }
        
        // Fix invalid values
        if string.count > 8 {
            string = String(string.prefix(8))
        }
        
        // Scanner creation
        let scanner = Scanner(string: string)
        
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        
        if string.count == 2 {
            let mask = 0xFF
            
            let g = Int(color) & mask
            
            let gray = Double(g) / 255.0
            
            self.init(.sRGB, red: gray, green: gray, blue: gray, opacity: 1)
            
        } else if string.count == 4 {
            let mask = 0x00FF
            
            let g = Int(color >> 8) & mask
            let a = Int(color) & mask
            
            let gray = Double(g) / 255.0
            let alpha = Double(a) / 255.0
            
            self.init(.sRGB, red: gray, green: gray, blue: gray, opacity: alpha)
            
        } else if string.count == 6 {
            let mask = 0x0000FF
            let r = Int(color >> 16) & mask
            let g = Int(color >> 8) & mask
            let b = Int(color) & mask
            
            let red = Double(r) / 255.0
            let green = Double(g) / 255.0
            let blue = Double(b) / 255.0
            
            self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
            
        } else if string.count == 8 {
            let mask = 0x000000FF
            let r = Int(color >> 24) & mask
            let g = Int(color >> 16) & mask
            let b = Int(color >> 8) & mask
            let a = Int(color) & mask
            
            let red = Double(r) / 255.0
            let green = Double(g) / 255.0
            let blue = Double(b) / 255.0
            let alpha = Double(a) / 255.0
            
            self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
            
        } else {
            self.init(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
        }
    }
}

//struct BookmarkColorPicker_Previews: PreviewProvider {
//
//    var thread: AwfulThread
//
//    static var previews: some View {
//        BookmarkColorPicker(thread: nil)
//    }
//}
