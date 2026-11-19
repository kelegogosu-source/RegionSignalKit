#if canImport(Darwin)
import Darwin
#endif

internal enum RSKLocalNetwork {
    static func g2() -> Bool {
        #if canImport(Darwin)
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let head = first else { return false }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = head
        while let entry = cursor {
            let flags = Int32(entry.pointee.ifa_flags)
            let name = String(cString: entry.pointee.ifa_name).lowercased()
            if flags & IFF_UP != 0 && RSKStrings.c.contains(where: { name.hasPrefix($0) }) { return true }
            cursor = entry.pointee.ifa_next
        }
        #endif
        return false
    }
}
