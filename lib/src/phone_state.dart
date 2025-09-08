import 'dart:async';

import 'package:flutter/services.dart';
import 'package:phone_state/src/utils/constants.dart';
import 'package:phone_state/src/utils/phone_state_status.dart';
import 'dart:io';

class PhoneState {
  final PhoneStateStatus status;
  final String? number; // only for android
  final Duration? duration;
  final String? uuid; // only for ios
  final String? direction; // only for ios
  final DateTime? startTime; // only for ios
  final DateTime? endTime; // only for ios
  final List<Map<String, DateTime?>> holdTimes; // only for ios

  PhoneState._({
    required this.status,
    this.number,
    this.duration,
    this.uuid,
    this.direction,
    this.startTime,
    this.endTime,
    required this.holdTimes,
  });

  factory PhoneState.nothing() =>
      PhoneState._(status: PhoneStateStatus.NOTHING, holdTimes: []);

  static const EventChannel _eventChannel =
      EventChannel(Constants.EVENT_CHANNEL);

  static final Stream<PhoneState> stream =
      _eventChannel.receiveBroadcastStream().map((dynamic event) {
    final startTime = event['startTime'] != null
        ? DateTime.tryParse(event['startTime'])
        : null;
    final endTime =
        event['endTime'] != null ? DateTime.tryParse(event['endTime']) : null;

    final rawHolds = (event['holdTimes'] as List?) ?? [];
    final parsedHolds = rawHolds
        .map<Map<String, DateTime?>>((h) => {
              'start':
                  h['start'] != null ? DateTime.tryParse(h['start']) : null,
              'end': h['end'] != null ? DateTime.tryParse(h['end']) : null,
            })
        .toList();

    final duration = (Platform.isAndroid)
        ? (event['callDuration'] != 0
            ? Duration(seconds: event['callDuration'])
            : null)
        : (startTime != null
            ? (endTime ?? DateTime.now()).difference(startTime)
            : null);

    return PhoneState._(
      status: PhoneStateStatus.values.firstWhere(
        (e) => e.name == event['status'] as String,
        orElse: () => PhoneStateStatus.NOTHING,
      ),
      uuid: event['callUUID'],
      direction: event['direction'],
      startTime: startTime,
      endTime: endTime,
      number: event['phoneNumber'],
      holdTimes: parsedHolds,
      duration: duration,
    );
  });
}



/// A manager that tracks active and past phone calls by their UUID.
///
/// - Maintains a static map `_calls` where each entry represents a call's state.
/// - Listens to the [PhoneState.stream] for call events and updates the map.
/// - Exposes [callsStream], a stream of the current call map, so the UI or
///   other parts of the app can react to call state changes in real time.
// class PhoneCallManager {
//   static final Map<String, PhoneState> _calls = {};
//
//   static final Stream<Map<String, PhoneState>> callsStream =
//       PhoneState.stream.map((phoneState) {
//     final uuid = phoneState.uuid;
//     if (uuid == null || uuid.isEmpty) return Map.from(_calls);
//
//     _calls[uuid] = phoneState;
//     return Map.from(_calls);
//   });
//
//   /// Clears all calls from the internal map
//   static void clearCalls() {
//     _calls.clear();
//   }
// }

class PhoneCallManager {
  static final Map<String, PhoneState> _calls = {};
  static final StreamController<Map<String, PhoneState>> _callsController =
  StreamController<Map<String, PhoneState>>.broadcast();

  static StreamSubscription<PhoneState>? _subscription;
  static bool _isInitialized = false;

  /// Initialize the manager - must be called before using
  static void initialize() {
    if (_isInitialized) return;

    _subscription = PhoneState.stream.listen((phoneState) {
      print('📞 PhoneCallManager: Received phone state: $phoneState');

      final uuid = phoneState.uuid;
      if (uuid == null || uuid.isEmpty) {
        // For Android, use a default key since UUID might not be available
        final key = uuid ?? 'android_call_${DateTime.now().millisecondsSinceEpoch}';
        _calls[key] = phoneState;
      } else {
        _calls[uuid] = phoneState;
      }

      print('📞 PhoneCallManager: Current calls count: ${_calls.length}');
      _callsController.add(Map.from(_calls));
    });

    _isInitialized = true;
    print('📞 PhoneCallManager: Initialized');
  }

  /// Stream of current calls map
  static Stream<Map<String, PhoneState>> get callsStream {
    if (!_isInitialized) {
      initialize();
    }
    return _callsController.stream;
  }

  /// Get current calls map (synchronous access)
  static Map<String, PhoneState> get currentCalls => Map.from(_calls);

  /// Clears all calls from the internal map and notifies listeners
  static void clearCalls() {
    print('📞 PhoneCallManager: Clearing calls. Previous count: ${_calls.length}');
    _calls.clear();
    _callsController.add(Map.from(_calls));
    print('📞 PhoneCallManager: Calls cleared. New count: ${_calls.length}');
  }

  /// Reset the manager completely
  static void reset() {
    print('📞 PhoneCallManager: Resetting manager');
    _subscription?.cancel();
    _calls.clear();
    _isInitialized = false;
    if (!_callsController.isClosed) {
      _callsController.add(Map.from(_calls));
    }
  }

  /// Dispose resources
  static void dispose() {
    print('📞 PhoneCallManager: Disposing manager');
    _subscription?.cancel();
    _calls.clear();
    _callsController.close();
    _isInitialized = false;
  }


}