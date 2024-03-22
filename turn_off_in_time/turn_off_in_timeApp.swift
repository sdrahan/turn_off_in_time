//
//  turn_off_in_timeApp.swift
//  turn_off_in_time
//
//  Created by Serhii Drahan on 01.02.24.
//

import SwiftUI

@main
struct turn_off_in_timeApp: App {
    
    let eventsJournal: EventsJournal
    let observer: NotificationObserver
    let logicManager: LogicManager
        
    init() {
        print("App started")
        eventsJournal = EventsJournal()
        logicManager = LogicManager(eventsJournal: eventsJournal)
        observer = NotificationObserver(eventsJournal: eventsJournal)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct JournalEvent: Codable {
    let time: Date
    let type: JournalEventType
}

enum JournalEventType: Codable {
    case sleep
    case wake
    case powerOff
    case appStart
    case appClose
}

class NotificationObserver: NSObject {
    let eventsJournal: EventsJournal
    
    init(eventsJournal: EventsJournal) {
        self.eventsJournal = eventsJournal
        super.init()
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(systemWillPowerOff), name: NSWorkspace.willPowerOffNotification, object: nil)
        print("Subscribed to notifications");
    }

    @objc func systemWillSleep(_ notification: Notification) {
        print("System will go to sleep")
        let logMessage = "\(Date()) : System will go to sleep \n"
        appendTextToFile(text: logMessage, fileName: "SystemEvents.log")
        eventsJournal.appendEvent(time: Date.now, journalEventType: .sleep)
    }
    
    @objc func systemDidWake(_ notification: Notification) {
        print("System did wake up")
        let logMessage = "\(Date()) : System did wake up \n"
        appendTextToFile(text: logMessage, fileName: "SystemEvents.log")
        eventsJournal.appendEvent(time: Date.now, journalEventType: .wake)
    }

    @objc func systemWillPowerOff(_ notification: Notification) {
        let logMessage = "\(Date()) : System will power off \n"
        appendTextToFile(text: logMessage, fileName: "SystemEvents.log")
        eventsJournal.appendEvent(time: Date.now, journalEventType: .powerOff)
    }
    
    func appendTextToFile(text: String, fileName: String) {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            fileHandle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            do {
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error writing to log file: \(error)")
            }
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

}

class EventsJournal {
    private let journalFileName = "events_journal.json"
    
    public func appendEvent(time: Date, journalEventType: JournalEventType) {
        let event = JournalEvent(time: time, type: journalEventType)
        let fileURL = getDocumentsDirectory().appendingPathComponent(journalFileName)
        
        var journalEvents: [JournalEvent] = readEvents() ?? []
        journalEvents.append(event)
        
        do {
            let data = try JSONEncoder().encode(journalEvents)
            try data.write(to: fileURL, options: [.atomicWrite])
        } catch {
            print("Error writing event: \(error)")
        }
    }

    func readEvents() -> [JournalEvent]? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(journalFileName)
        if let data = try? Data(contentsOf: fileURL) {
            return try? JSONDecoder().decode([JournalEvent].self, from: data)
        }
        return nil
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

class LogicManager {
    private let eventsJournal: EventsJournal
    init(eventsJournal: EventsJournal) {
        self.eventsJournal = eventsJournal;
        eventsJournal.appendEvent(time: Date.now, journalEventType: .appStart)
    }
}

