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
    let eventService: EventService
    let observer: NotificationObserver
    let logicManager: LogicManager
        
    init() {
        print("App started")
        eventsJournal = SimpleJsonEventsJournal()
        eventService = EventService(eventsJournal: eventsJournal)
        observer = NotificationObserver(eventService: eventService)
        logicManager = LogicManager(eventService: eventService)
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
    let eventService: EventService
    
    init(eventService: EventService) {
        self.eventService = eventService
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
        eventService.saveEvent(time: Date.now, journalEventType: .sleep)
    }
    
    @objc func systemDidWake(_ notification: Notification) {
        print("System did wake up")
        let logMessage = "\(Date()) : System did wake up \n"
        appendTextToFile(text: logMessage, fileName: "SystemEvents.log")
        eventService.saveEvent(time: Date.now, journalEventType: .wake)
    }

    @objc func systemWillPowerOff(_ notification: Notification) {
        let logMessage = "\(Date()) : System will power off \n"
        appendTextToFile(text: logMessage, fileName: "SystemEvents.log")
        eventService.saveEvent(time: Date.now, journalEventType: .powerOff)
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

class EventService {
    private let eventsJournal: EventsJournal
    
    init (eventsJournal: EventsJournal) {
        self.eventsJournal = eventsJournal
    }
    
    public func saveEvent(time: Date, journalEventType: JournalEventType) {
        eventsJournal.saveEvent(journalEvent: JournalEvent(time: time, type: journalEventType))
    }
    
    public func getEvents() -> [JournalEvent] {
        return eventsJournal.getEvents()
    }
    
}

protocol EventsJournal {
    func saveEvent(journalEvent: JournalEvent)
    func getEvents() -> [JournalEvent]
}

class SimpleJsonEventsJournal: EventsJournal {
    private let journalFileName = "events_journal.json"
    
    func saveEvent(journalEvent: JournalEvent) {
        let event = JournalEvent(time: journalEvent.time, type: journalEvent.type)
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
    
    public func getEvents() -> [JournalEvent] {
        return readEvents() ?? []
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
    private let eventService: EventService
    
    init(eventService: EventService) {
        self.eventService = eventService;
        // eventService.saveEvent(time: Date.now, journalEventType: .appStart)
        let events = eventService.getEvents()
        print(events)
        
        // Example usage
        let currentTime = Date.now
        let redZoneStartTime = (hour: 22, minute: 0)
        let redZoneEndTime = (hour: 3, minute: 0)

        if isDate(currentTime, betweenStartTime: redZoneStartTime, andEndTime: redZoneEndTime) {
            print("The current time is between \(redZoneStartTime.hour):\(redZoneStartTime.minute) and \(redZoneEndTime.hour):\(redZoneEndTime.minute).")
        } else {
            print("The current time is not between \(redZoneStartTime.hour):\(redZoneStartTime.minute) and \(redZoneEndTime .hour):\(redZoneEndTime.minute).")
        }
        
    }
    
    func isDate(_ date: Date, betweenStartTime startTime: (hour: Int, minute: Int), andEndTime endTime: (hour: Int, minute: Int)) -> Bool {
        let calendar = Calendar.current
        
        // Extract the hour and minute components from the date
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return false
        }
        
        // Convert start and end times to minutes since midnight to simplify comparison
        let startMinutesSinceMidnight = startTime.hour * 60 + startTime.minute
        let endMinutesSinceMidnight = endTime.hour * 60 + endTime.minute
        let currentMinutesSinceMidnight = hour * 60 + minute
        
        if startMinutesSinceMidnight <= endMinutesSinceMidnight {
            // The time range does not cross midnight
            return currentMinutesSinceMidnight >= startMinutesSinceMidnight && currentMinutesSinceMidnight < endMinutesSinceMidnight
        } else {
            // The time range crosses midnight
            return currentMinutesSinceMidnight >= startMinutesSinceMidnight || currentMinutesSinceMidnight < endMinutesSinceMidnight
        }
    }

    
}

