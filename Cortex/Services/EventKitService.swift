import EventKit
import Observation

@MainActor
@Observable
class EventKitService: @unchecked Sendable {

    nonisolated(unsafe) private let eventStore = EKEventStore()

    var remindersAuthorized = false
    var calendarAuthorized = false

    // cached so I don't search for "Cortex" list on every reminder
    private var cortexList: EKCalendar?

    func requestRemindersAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            remindersAuthorized = granted
            return granted
        } catch {
            print("Error: reminders access request failed: \(error)")
            remindersAuthorized = false
            return false
        }
    }

    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            calendarAuthorized = granted
            return granted
        } catch {
            print("Error: calendar access request failed: \(error)")
            calendarAuthorized = false
            return false
        }
    }

    func findOrCreateCortexList() -> EKCalendar? {
        if let existing = cortexList {
            return existing
        }

        let calendars = eventStore.calendars(for: .reminder)
        if let found = calendars.first(where: { $0.title == "Cortex" }) {
            cortexList = found
            return found
        }

        let newList = EKCalendar(for: .reminder, eventStore: eventStore)
        newList.title = "Cortex"
        // try default source, fall back to local, then any available
        let source = eventStore.defaultCalendarForNewReminders()?.source
            ?? eventStore.sources.first(where: { $0.sourceType == .local })
            ?? eventStore.sources.first

        guard let resolvedSource = source else {
            print("Error: no reminders source available on this device")
            return nil
        }
        newList.source = resolvedSource

        do {
            try eventStore.saveCalendar(newList, commit: true)
            cortexList = newList
            return newList
        } catch {
            print("Error: failed to create Cortex reminders list: \(error)")
            return nil
        }
    }

    func createReminder(title: String, dueDate: Date?) async -> Bool {
        if !remindersAuthorized {
            let granted = await requestRemindersAccess()
            guard granted else {
                print("Error: reminders not authorized, can't create reminder")
                return false
            }
        }

        guard let list = findOrCreateCortexList() else {
            print("Error: couldn't get Cortex reminders list")
            return false
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = list

        if let due = dueDate {
            reminder.timeZone = TimeZone.current
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .timeZone], from: due
            )
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }

        do {
            try eventStore.save(reminder, commit: true)
            return true
        } catch {
            print("Error: failed to save reminder '\(title)': \(error)")
            return false
        }
    }

    func createEvent(title: String, startDate: Date?) async -> Bool {
        if !calendarAuthorized {
            let granted = await requestCalendarAccess()
            guard granted else {
                print("Error: calendar not authorized, can't create event")
                return false
            }
        }

        guard let defaultCal = eventStore.defaultCalendarForNewEvents else {
            print("Error: no writable default calendar available")
            return false
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate ?? Date()
        event.endDate = event.startDate.addingTimeInterval(3600)
        event.calendar = defaultCal

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Error: failed to save event '\(title)': \(error)")
            return false
        }
    }
}
