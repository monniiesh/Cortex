import BackgroundTasks

class BackgroundTaskService {

    static let processingTaskID = "com.moni.cortex.processing"
    static let refreshTaskID = "com.moni.cortex.refresh"

    var onProcess: (() async -> Void)?

    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskService.processingTaskID, using: nil) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self?.handleProcessingTask(processingTask)
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskService.refreshTaskID, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self?.handleRefreshTask(refreshTask)
        }
    }

    func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskService.processingTaskID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Error: failed to schedule processing task: \(error)")
        }
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskService.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Error: failed to schedule refresh task: \(error)")
        }
    }

    private func handleProcessingTask(_ task: BGProcessingTask) {
        scheduleProcessing()
        let onProcess = self.onProcess
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        Task {
            await onProcess?()
            task.setTaskCompleted(success: true)
        }
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        scheduleRefresh()
        let onProcess = self.onProcess
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        Task {
            await onProcess?()
            task.setTaskCompleted(success: true)
        }
    }
}
