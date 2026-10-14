/// A persisted update notice only describes the running app if the versions still match.
public enum PostUpdateNotice {
    /// An unacknowledged notice can outlive the installed version (for example after a manual
    /// upgrade or downgrade). Retire it through the updater's acknowledgement API so it cannot
    /// reappear on a later launch. Do not invent a notice for an update the updater never recorded.
    public static func reconcile(
        recordedVersion: String?,
        runningVersion: String?,
        acknowledge: () -> Void,
    ) -> String? {
        guard let recordedVersion else { return nil }
        guard !recordedVersion.isEmpty, recordedVersion == runningVersion else {
            acknowledge()
            return nil
        }
        return recordedVersion
    }
}
