import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';

void main() {
  runApp(const MaterialApp(home: Example()));
}


class Example extends StatelessWidget {
  const Example({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone State'), centerTitle: true),
      body: Platform.isAndroid
          ? AndroidCallWidget()
          : const IOSCallWidget(),
    );
  }
}


/// ------------------- ANDROID WIDGET -------------------
class AndroidCallWidget extends StatefulWidget {
  const AndroidCallWidget({super.key});

  @override
  State<AndroidCallWidget> createState() => _AndroidCallWidgetState();
}

class _AndroidCallWidgetState extends State<AndroidCallWidget> {
  bool granted = false;

  Future<bool> requestPermission() async {
    var status = await Permission.phone.request();

    return switch (status) {
      PermissionStatus.denied ||
      PermissionStatus.restricted ||
      PermissionStatus.limited ||
      PermissionStatus.permanentlyDenied =>
      false,
      PermissionStatus.provisional || PermissionStatus.granted => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return  Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (Platform.isAndroid)
            MaterialButton(
              onPressed: !granted
                  ? () async {
                bool temp = await requestPermission();
                setState(() {
                  granted = temp;
                });
              }
                  : null,
              child: const Text(
                  'Request permission of Phone and start listener'),
            ),
          StreamBuilder(
            stream: PhoneState.stream,
            builder: (context, snapshot) {
              PhoneState? status = snapshot.data;
              if (status == null) {
                return Text(
                  'Phone State not available',
                );
              }
              return Column(
                children: [
                  const Text(
                    'Status of call',
                    style: TextStyle(fontSize: 24),
                  ),
                  if (status.status == PhoneStateStatus.CALL_INCOMING ||
                      status.status == PhoneStateStatus.CALL_STARTED)
                    Text(
                      'Number: ${status.number}',
                      style: const TextStyle(fontSize: 24),
                    ),
                  if (status.duration != null)
                    Text(
                      'Duration of call: ${formatDuration(status.duration!)}',
                      style: const TextStyle(fontSize: 24),
                    ),
                  Icon(
                    getIcons(status.status),
                    color: getColor(status.status),
                    size: 80,
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours =
    duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : '';
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours$minutes:$seconds';
  }

  IconData getIcons(PhoneStateStatus status) {
    return switch (status) {
      PhoneStateStatus.NOTHING => Icons.clear,
      PhoneStateStatus.CALL_INCOMING || PhoneStateStatus.CALL_OUTGOING => Icons.add_call,
      PhoneStateStatus.CALL_STARTED || PhoneStateStatus.CALL_ON_HOLD => Icons.call,
      PhoneStateStatus.CALL_ENDED => Icons.call_end,
    };
  }

  Color getColor(PhoneStateStatus status) {
    return switch (status) {
      PhoneStateStatus.NOTHING || PhoneStateStatus.CALL_ENDED => Colors.red,
      PhoneStateStatus.CALL_INCOMING || PhoneStateStatus.CALL_OUTGOING => Colors.green,
      PhoneStateStatus.CALL_STARTED || PhoneStateStatus.CALL_ON_HOLD => Colors.orange,
    };
  }
}



/// ------------------- IOS WIDGET -------------------
class IOSCallWidget extends StatelessWidget {
  const IOSCallWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, PhoneState>>(
      stream: PhoneCallManager.callsStream,
      builder: (context, snapshot) {
        final calls = snapshot.data ?? {};
        if (calls.isEmpty) {
          return const Center(child: Text('No active calls'));
        }
        return ListView(
          children: calls.values.map((call) => _buildCallTile(call)).toList(),
        );
      },
    );
  }

  Widget _buildCallTile(PhoneState? call) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${call?.status.name}',
                style: const TextStyle(fontSize: 18)),
            if (call?.direction != null)
              Text('Direction: ${call?.direction}',
                  style: const TextStyle(fontSize: 16)),
            if (call?.number != null)
              Text('Number: ${call?.number}',
                  style: const TextStyle(fontSize: 16)),
            if (call?.startTime != null)
              Text(
                'Start Time: ${_formatDateTime(call?.startTime)}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            if (call?.endTime != null)
              Text(
                'End Time: ${_formatDateTime(call?.endTime)}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            if (call?.duration != null)
              Text('Duration: ${_formatDuration(call?.duration)}',
                  style: const TextStyle(fontSize: 16)),
            if (call?.holdTimes.isNotEmpty ?? false)
              Text(
                'Hold Intervals: ${call?.holdTimes.map((h) => "${_formatDateTime(h['start'])}-${_formatDateTime(h['end'])}").join(", ")}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            Icon(
              _getIcon(call?.status),
              color: _getColor(call?.status),
              size: 50,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "-";
    return DateFormat("yyyy-MM-dd HH:mm:ss z").format(dt.toLocal());
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "-";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : '';
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours$minutes:$seconds';
  }

  IconData _getIcon(PhoneStateStatus? status) {
    switch (status) {
      case PhoneStateStatus.CALL_INCOMING:
        return Icons.add_call;
      case PhoneStateStatus.CALL_OUTGOING:
        return Icons.call_made;
      case PhoneStateStatus.CALL_STARTED:
        return Icons.call;
      case PhoneStateStatus.CALL_ENDED:
        return Icons.call_end;
      case PhoneStateStatus.CALL_ON_HOLD:
        return Icons.pause_circle;
      case PhoneStateStatus.NOTHING:
        return Icons.clear;
      default:
        return Icons.help_outline;
    }
  }

  Color _getColor(PhoneStateStatus? status) {
    switch (status) {
      case PhoneStateStatus.CALL_INCOMING:
      case PhoneStateStatus.CALL_OUTGOING:
        return Colors.green;
      case PhoneStateStatus.CALL_STARTED:
        return Colors.orange;
      case PhoneStateStatus.CALL_ENDED:
      case PhoneStateStatus.NOTHING:
        return Colors.red;
      case PhoneStateStatus.CALL_ON_HOLD:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
