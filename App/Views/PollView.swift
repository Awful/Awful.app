//  PollView.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import HTMLReader
import Combine
import AwfulCore

// Views

@available(iOS 14.0, *)
struct PollView_Previews: PreviewProvider {
    
    static let testTheme = Theme.theme(named: "brightLight") // change this to preview different themes
    ?? Theme.defaultTheme()
    
    static var previews: some View {
        NavigationView {
            PollView(model: OptionViewModel(destination: .openPoll,
                                            pollHTMLString: OptionViewModel.openPollHTMLString,
                                            poll: Poll(pollID: "mock")))
            .environment(\.theme, testTheme)
        }
    }
}

struct PollView: View {
    @ObservedObject var model: OptionViewModel
    @SwiftUI.Environment(\.theme) var theme
    
    var body: some View {
        NavigationView {
            
            VStack {
                if self.model.poll.pollStatus == .open {
                    Picker("", selection: self.$model.selection) {
                        Text("Options").tag(0)
                        Text("Results").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if self.model.selection == 0 {
                        Button("Submit") {
                            Task {
                                await self.model.submitPoll()
                            }
                        }
                        .font(.body)
                        
                        ScrollView {
                            ForEach(Array(zip(self.model.pollOptions.indices, self.model.pollOptions)), id: \.1.id) { (index, pollOption) in
                                Toggle("\(pollOption.optionText)", isOn: self.$model.pollOptions[index].isSelected)
                                    .toggleStyle(CheckboxToggleStyle())
                                    .disabled(self.model.poll.pollType == .single
                                              && (self.model.pollOptions.filter { $0.isSelected }.count > 0
                                                  && self.model.pollOptions.filter { $0.isSelected }[0].id != pollOption.id
                                                 )
                                    )
                            }
                        }
                        .padding()
                        
                    } else {
                        PollResultsView(model: self.model)
                    }
                } else {
                    PollResultsView(model: self.model)
                }
            }
            
            
            
            
            
            .foregroundColor(theme[swiftColor: "listTextColor"]!)
            .background(
                theme[swiftColor: "sheetBackgroundColor"]!
                    .edgesIgnoringSafeArea(.all)
            )
            .onAppear {
                UITableView.appearance().backgroundColor = .clear
                // unselected
                UISegmentedControl.appearance().setTitleTextAttributes([
                    .font: UIFont.preferredFontForTextStyle(.body, weight: .regular),
                    .foregroundColor: theme[color: "listTextColor"]!
                ], for: .normal)
                UISegmentedControl.appearance().backgroundColor = theme[color: "backgroundColor"]!
                
                // selected
                UISegmentedControl.appearance().selectedSegmentTintColor = theme[color: "tintColor"]!
                UISegmentedControl.appearance().setTitleTextAttributes([
                    .font: UIFont.preferredFontForTextStyle(.body, weight: .regular),
                    .foregroundColor: theme[color: "selectedTextColor"]!
                ], for: .selected)
                
                Task.init(priority: .userInitiated) {
                    await self.model.getOpenPollOptions(htmlString: self.model.pollHTMLString)
                }
            }
            .alert(isPresented: self.$model.pollSubmitError) {
                Alert(title: Text("Title"), message: Text("This is the alert message"), dismissButton: .default(Text("OK")))
            }
        }
        .navigationBarTitle(Text(self.model.poll.pollQuestion), displayMode: .inline)
        
    }
}

struct PollResultsView: View {
    @ObservedObject var model: OptionViewModel
    @SwiftUI.Environment(\.theme) var theme
    
    var body: some View {
        VStack {
            ScrollView {
                Spacer()
                ForEach(self.model.pollOptions, id: \.id){ option in
                    BarView(htmlElementValue: option.value, optionText: option.optionText, numberOfVotes: option.numberOfVotes, percent: option.percent)
                }
                Spacer()
            }
            
            Text(self.model.resultsTotal)
            
            if self.model.additionalMessage != "" {
                Text(self.model.additionalMessage)
            }
        }
        .foregroundColor(theme[swiftColor: "listTextColor"]!)
        .onAppear {
            Task.init(priority: .userInitiated) {
                await self.model.getCompletedPollOptions(pollID: self.model.poll.pollID)
            }
        }
    }
}

struct BarView: View {
    @SwiftUI.Environment(\.theme) var theme
    let htmlElementValue: String
    let maxValue: Int = 100
    let optionText: String
    let numberOfVotes: String
    let percent: Int
    let pollWidth: CGFloat = 365

    
    var body: some View {
        VStack{
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: (CGFloat(self.percent) / CGFloat(self.maxValue)) * pollWidth)
                    .foregroundColor(theme[swiftColor: "pollBarColor"]!)
                    .background(theme[swiftColor: "listBackgroundColor"]!)
                    .cornerRadius(5)
                HStack {
                    Text("\(optionText)").font(.headline)
                    Spacer()
                    Text("\(percent)%   \(numberOfVotes) votes").font(.subheadline)
                }
                .padding(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
            }
            
        }
        .foregroundColor(theme[swiftColor: "listTextColor"]!)
        .frame(width: pollWidth, height: 30, alignment: .center)
        .padding(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(theme[swiftColor: "listSeparatorColor"]!, lineWidth: 2)
                .padding(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
        )
    }
    
}



// Models

class OptionViewModel: ObservableObject {
    @Published var destination: Destination?
    @Published var selection = 0
    @Published var pollSubmitError = false
    @Published var selectedOptionString = ""
    @Published var htmlDoc: HTMLDocument = .init(string: "")
    @Published var poll: Poll
    @Published var pollQuestion: String = ""
    @Published var pollOptions: [PollOption]
    @Published var resultsTotal: String = ""
    @Published var pollHTMLString: String
    @Published var additionalMessage: String = ""
    
    enum Destination {
        case openPoll
        case showResults
    }
    
    init(destination: Destination? = nil,
         selection: Int = 0,
         pollSubmitError: Bool = false,
         selectedOptionString: String = "",
         pollOptions: [PollOption] = [],
         pollHTMLString: String = "",
         poll: Poll
    ) {
        self.destination = destination
        self.selection = selection
        self.pollOptions = pollOptions
        self.pollSubmitError = pollSubmitError
        self.selectedOptionString = selectedOptionString
        self.pollHTMLString = pollHTMLString
        self.poll = Poll(pollID: poll.pollID)
    }
    
    
    @MainActor
    func getOpenPollOptions(htmlString: String) async {
        htmlDoc = try! htmlString2HtmlDocument(htmlString: htmlString)
        
        // if the poll is closed or the poster has already voted then a message will be included in the table header:
        // <th colspan="4"><b>Red or Blue?</b><br>You have already voted in this poll</th>
        // in those cases, take the second line and save to the model for display in the view
        if let additionalMessage = htmlDoc.firstNode(matchingSelector: "th b + br") {
            if let twoLineHeaderText = additionalMessage.parent?.innerHTML.components(separatedBy: "<br>") {
                self.additionalMessage = twoLineHeaderText.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                self.poll.pollQuestion = String(twoLineHeaderText.first?.dropFirst(3).dropLast(4) ?? "")
            }
        } else {
            self.poll.pollQuestion = (htmlDoc.firstNode(matchingSelector: "tr")?.textContent ?? "") as String
        }
        
        
        self.poll.pollStatus = {
            if htmlDoc.firstNode(matchingSelector: "input[type = 'radio']") != nil {
                return .open
            } else {
                return .closed
            }
        }()
        
        for tr in htmlDoc.nodes(matchingSelector: "tbody tr td") {
            var haveSetPollType = false
            var option = PollOption()
            let optionNode = tr.firstNode(matchingSelector: "input[name *= 'optionnumber']")
            
            if let parentTrNode = optionNode?.parent?.parent {
                let optionInputElement = parentTrNode.firstNode(matchingSelector: "input")
                let optionTextTd = parentTrNode.firstNode(matchingSelector: "td:nth-child(2)")
                option.optionText = optionTextTd?.textContent ?? "nil"
                option.name = optionInputElement?["name"] ?? "nil"
                option.value = optionInputElement?["value"] ?? "nil"
                
                self.pollOptions.append(option)
                
                if (!haveSetPollType){
                    // set poll type using optionnumber name
                    self.poll.pollType = option.name.contains("[") ? .multi : .single
                    haveSetPollType = true
                }
            }
        }
    }
    
    @MainActor
    func getCompletedPollOptions(pollID: String) async {
        var htmlString = ""
        if pollID != "mock" {
            htmlString = await fetchPollResults(pollID: pollID)
        } else {
            htmlString = OptionViewModel.resultsHTMLString
        }
        htmlDoc = try! htmlString2HtmlDocument(htmlString: htmlString)
        
        if let resultsTableHtmlDoc = htmlDoc.firstNode(matchingSelector: "table[class='standard']") {
            self.pollOptions.removeAll()
            
            // if the poll is closed / poster has already voted a message will be alongside the question text in the th:
            // <th colspan="4"><b>Red or Blue?</b><br>You have already voted in this poll</th>
            // in those cases, take the second line and save to the model for display in the view
            if let additionalMessage = htmlDoc.firstNode(matchingSelector: "th b + br") {
                if let twoLineHeaderText = additionalMessage.parent?.innerHTML.components(separatedBy: "<br>") {
                    self.additionalMessage = twoLineHeaderText.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    self.poll.pollQuestion = String(twoLineHeaderText.first?.dropFirst(3).dropLast(4) ?? "")
                }
            } else {
                self.poll.pollQuestion = (htmlDoc.firstNode(matchingSelector: "tr")?.textContent ?? "") as String
            }
            
            if let header = resultsTableHtmlDoc.firstNode(matchingSelector: "th") {
                header.removeFromParentNode()
            }
            for junkNode in resultsTableHtmlDoc.nodes(matchingSelector: ".graphbar") {
                junkNode.removeFromParentNode()
            }
            
            // the last tr contains the results. we take what we need and then remove it before looping through the other rows
            var rows = resultsTableHtmlDoc.nodes(matchingSelector: "tr")
            
            let lastRow = rows[rows.count - 1]
            
            // we only want the total number of votes from this whole tr, which is the second td textContent (e.g. "2 votes")
            self.resultsTotal = lastRow.childElementNodes[1].textContent
            
            rows.removeLast()
            
            for tr in rows {
                var option = PollOption()
                var action = 1
                
                // now we have three td elements: Option Text, Number of Votes and score percentage
                for td in tr.nodes(matchingSelector: "td") {
                    if action == 1 {
                        option.optionText = td.textContent
                        action = 2
                        continue
                    }
                    else if action == 2 {
                        option.numberOfVotes = (td.textContent)
                        action = 3
                        continue
                    }
                    else {
                        // "0%" or "100%" etc
                        let scanner = Scanner(string: td.textContent)
                        _ = scanner.scanUpToCharacters(from: .decimalDigits)
                        
                        option.percent = scanner.scanCharacters(from: .decimalDigits).map { Int($0) ?? 0 }!
                    }
                }
                
                self.pollOptions.append(option)
            }
            
            self.pollOptions.removeAll { option in
                option.optionText.allSatisfy(\.isWhitespace)
            }
            
            self.pollOptions = self.pollOptions.sorted(by: { $0.percent > $1.percent })
        }
    }
    
    @MainActor
    func submitPoll() async {
        var components = URLComponents()
        components.path = "poll.php"
        components.queryItems = [
            URLQueryItem(name: "action", value: "pollvote"),
            URLQueryItem(name: "pollid", value: self.poll.pollID)
        ]
        
        self.pollOptions.filter { $0.isSelected }.forEach {
            // multi select polls: optionnumber[23] = yes
            if $0.name.contains("[") {
                components.queryItems?.append(URLQueryItem(name: $0.name, value: "yes"))
            } else {
                // single choice polls: optionnumber = 3
                components.queryItems?.append(URLQueryItem(name: $0.name, value: $0.value))
            }
        }
        
        var urlRequest = URLRequest(url: components.url(relativeTo: ForumsClient.shared.baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        guard let queryItems = components.queryItems, !queryItems.isEmpty else { return }
        
        let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        guard let queryItemString = queryString.data(using: .utf8) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.upload(for: urlRequest, from: queryItemString)
            // Handle success
            guard let string = String(data: data, encoding: .utf8) else { return }
            
            print("Response Data: \(string)")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response HTTP status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    self.poll.pollStatus = .closed
                    self.selection = 1
                }
            }
            
            
            
        } catch {
            // Handle error
            print("Error: \(error)")
            self.pollSubmitError = true
        }
        
    }
    
    func fetchPollResults(pollID: String) async -> String {
        let pollResultsHtml: String
        do {
            let url = URL(string: "\(ForumsClient.shared.baseURL!)/poll.php?action=showresults&pollid=\(pollID)")!
            
            let (data, _) = try await URLSession.shared.data(from: url)
            pollResultsHtml = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            pollResultsHtml = "Failed to fetch"
        }
        return pollResultsHtml
    }
    
    func htmlString2HtmlDocument(htmlString: String) throws -> HTMLDocument {
        return HTMLDocument(string: htmlString)
    }
}



struct Poll {
    let pollID: String
    var pollQuestion: String = ""
    var pollOptions: [PollOption]
    var pollStatus: PollStatus
    var pollType: PollType
    
    enum PollType {
        case single
        case multi
    }
    enum PollStatus {
        case none
        case open
        case closed
    }
    init(
        pollID: String,
        pollOptions: [PollOption] = [],
        pollType: PollType = .single,
        pollStatus: PollStatus = .open
    ){
        self.pollOptions = pollOptions
        self.pollType = pollType
        self.pollStatus = pollStatus
        self.pollID = pollID
    }
}


struct PollOption: Identifiable, Equatable {
    var optionText = ""
    var value = ""
    var name = ""
    let id = UUID()
    var isSelected: Bool = false
    var votes = ""
    var percent = 0
    var numberOfVotes = ""
}



// thanks to https://swiftwithmajid.com/2020/03/04/customizing-toggle-in-swiftui/
struct CheckboxToggleStyle: ToggleStyle {
    @SwiftUI.Environment(\.isEnabled) var isEnabled
    @SwiftUI.Environment(\.theme) var theme
    
    func makeBody(configuration: Configuration) -> some View {
        return HStack {
            configuration.label
                .font(.body)
            Spacer()
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : isEnabled ? "square" : "square.fill")
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundColor(configuration.isOn ? theme[swiftColor: "tintColor"]! : isEnabled ? theme[swiftColor: "listTextColor"]! : theme[swiftColor: "placeholderTextColor"]!)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}

extension OptionViewModel {
    static let openPollHTMLString = """
                            <form action="poll.php" method="POST">
                              <input type="hidden" name="action" value="pollvote" />
                              <input type="hidden" name="pollid" value="38013" />
                              <table class="standard" id="main_full">
                                <tbody>
                                  <tr>
                                    <th colspan="4"><b>Which of these four options is the BEST ONE?</b></th>
                                  </tr>
                                  <tr>
                                    <td width="5%"><input type="radio" name="optionnumber[1]" value="yes" /></td>
                                    <td colspan="3">Option 1</td>
                                  </tr>
                                  <tr>
                                    <td width="5%"><input type="radio" name="optionnumber[2]" value="yes" /></td>
                                    <td colspan="3">Option 2</td>
                                  </tr>
                                  <tr>
                                    <td width="5%"><input type="radio" name="optionnumber[3]" value="yes" /></td>
                                    <td colspan="3">Option 3</td>
                                  </tr>
                                  <tr>
                                    <td width="5%"><input type="radio" name="optionnumber[4]" value="yes" /></td>
                                    <td colspan="3">Option 4</td>
                                  </tr>
                                </tbody>
                              </table>
                              <div style="text-align: right" class="smalltext">
                                [<a href="poll.php?action=polledit&amp;pollid=38013">Edit Poll (moderators only)</a>]
                              </div>
                              <div style="margin-bottom: 8px">
                                <input type="submit" class="bginput" value="Vote!" />
                                <a href="poll.php?action=showresults&amp;pollid=38013">View Results</a>
                              </div>
                            </form>
                            """
    
    static let resultsHTMLString = """
                            <table class="standard">
                            <tr><th colspan="4"><b>Great poll or the greatest poll?</b><br>You have already voted in this poll</th></tr>
                            <tr>
                            <td align="right">Nice Colbert ripoff bro</td>
                            <td class="graphbar">
                            <img src="//fi.somethingawful.com/images/polls/bar2-l.gif" width="3" height="10" alt="">
                            <img src="//fi.somethingawful.com/images/polls/bar2.gif" width="200" height="10" alt="">
                            <img src="//fi.somethingawful.com/images/polls/bar2-r.gif" width="3" height="10" alt="">
                            </td>
                            <td width="67">1</td>
                            <td align="center" width="67">100.00%</td>
                            </tr><tr>
                            <td align="right">Real original fuckstick</td>
                            <td class="graphbar">
                            <img src="//fi.somethingawful.com/images/polls/bar3-l.gif" width="3" height="10" alt="">
                            <img src="//fi.somethingawful.com/images/polls/bar3.gif" width="0" height="10" alt="">
                            <img src="//fi.somethingawful.com/images/polls/bar3-r.gif" width="3" height="10" alt="">
                            </td>
                            <td width="67">0</td>
                            <td align="center" width="67">0%</td>
                            </tr>
                            <tr>
                            <td align="right" colspan="2"><b>Total:</b></td>
                            <td align="center"><b>1 votes</b></td>
                            <td align="center"><b>100%</b></td>
                            </tr>
                            </table>
                            """
    
    static let mockOpenMultiChoicePoll = OptionViewModel(
        pollHTMLString: resultsHTMLString,
        poll: Poll(pollID: "1111",
                   pollOptions: [],
                   pollType: Poll.PollType.single,
                   pollStatus: .closed
                  )
    )
}
