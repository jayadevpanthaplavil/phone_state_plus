import Foundation
import CallKit
import Flutter

@available(iOS 10.0, *)
class PhoneStateHandler: NSObject, FlutterStreamHandler, CXCallObserverDelegate {

    private var _eventSink: FlutterEventSink?
    private var callObserver = CXCallObserver()

    // Track call times and holds per UUID
    private var callStartTimes: [UUID: Date] = [:]
    private var callEndTimes: [UUID: Date] = [:]
    private var callHoldIntervals: [UUID: [(from: Date, to: Date?)]] = [:]
    private var callHoldState: [UUID: Bool] = [:] // true if on hold

    override init() {
        super.init()
        callObserver.setDelegate(self, queue: nil)
    }

    private func getCallState(from call: CXCall) -> PhoneStateStatus {
        if !call.isOutgoing && !call.hasConnected && !call.hasEnded {
            return .CALL_INCOMING
        } else if call.isOutgoing && !call.hasConnected && !call.hasEnded {
            return .CALL_OUTGOING
        } else if call.hasConnected && !call.hasEnded {
            return call.isOnHold ? .CALL_ON_HOLD : .CALL_STARTED
        } else if call.hasEnded {
            return .CALL_ENDED
        } else {
            return .NOTHING
        }
    }

    private func sendCallState(_ status: PhoneStateStatus, call: CXCall) {
        let dateFormatter = ISO8601DateFormatter()
        let uuidString = call.uuid.uuidString
        let direction = call.isOutgoing ? "OUTGOING" : "INCOMING"

        // Track start time only when call actually started
        if (status == .CALL_STARTED || status == .CALL_ON_HOLD) && callStartTimes[call.uuid] == nil {
            callStartTimes[call.uuid] = Date()
        }

        // Track end time only when call ended
        if status == .CALL_ENDED && callEndTimes[call.uuid] == nil {
            callEndTimes[call.uuid] = Date()
        }

        let startTime = callStartTimes[call.uuid]
        let endTime = callEndTimes[call.uuid]

        let holdArray = callHoldIntervals[call.uuid]?.map { interval in
            [
                "start": dateFormatter.string(from: interval.from),
                "end": interval.to != nil ? dateFormatter.string(from: interval.to!) as Any : NSNull()
            ]
        } ?? []

        _eventSink?([
            "status": status.rawValue,
            "callUUID": uuidString,
            "startTime": startTime != nil ? dateFormatter.string(from: startTime!) : NSNull(),
            "endTime": endTime != nil ? dateFormatter.string(from: endTime!) : NSNull(),
            "direction": direction,
            "phoneNumber": NSNull(),
            "holdTimes": holdArray
        ])
    }

    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        let status = getCallState(from: call)
        let uuid = call.uuid

        // Track hold intervals
        if call.isOnHold {
            if callHoldState[uuid] != true {
                var intervals = callHoldIntervals[uuid] ?? []
                intervals.append((from: Date(), to: nil))
                callHoldIntervals[uuid] = intervals
                callHoldState[uuid] = true
            }
        } else if callHoldState[uuid] == true {
            if var intervals = callHoldIntervals[uuid], !intervals.isEmpty {
                var last = intervals.removeLast()
                last.to = Date()
                intervals.append(last)
                callHoldIntervals[uuid] = intervals
            }
            callHoldState[uuid] = false
        }

        sendCallState(status, call: call)

        // Clean up after call ended
        if status == .CALL_ENDED {
            callStartTimes.removeValue(forKey: uuid)
            callEndTimes.removeValue(forKey: uuid)
            callHoldIntervals.removeValue(forKey: uuid)
            callHoldState.removeValue(forKey: uuid)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _eventSink = events

        // Send snapshot of current calls
        for call in callObserver.calls {
            let status = getCallState(from: call)
            sendCallState(status, call: call)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _eventSink = nil
        return nil
    }
}
