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
class PhoneCallManager {
  static final Map<String, PhoneState> _calls = {};

  static final Stream<Map<String, PhoneState>> callsStream =
      PhoneState.stream.map((phoneState) {
    final uuid = phoneState.uuid;
    if (uuid == null || uuid.isEmpty) return Map.from(_calls);

    _calls[uuid] = phoneState;
    return Map.from(_calls);
  });
}
