import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Boundary around connectivity_plus so connection changes can be tested
/// without invoking a platform channel.
abstract interface class ConnectivityStatusSource {
  Future<List<ConnectivityResult>> checkConnectivity();

  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

final class ConnectivityPlusStatusSource implements ConnectivityStatusSource {
  ConnectivityPlusStatusSource([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() =>
      _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}

/// Whether a real server answers; confirms a platform "no network" report.
typedef ReachabilityProbe = Future<bool> Function();

/// Opens (and drops) a TCP connection to [target]'s host and port.
///
/// Uses `dart:io` sockets, so it is unavailable on the web.
ReachabilityProbe socketReachabilityProbe(
  Uri Function() target, {
  Duration timeout = const Duration(seconds: 4),
}) {
  return () async {
    try {
      final uri = target();
      final socket = await Socket.connect(uri.host, uri.port, timeout: timeout);
      socket.destroy();
      return true;
    } on Object {
      return false;
    }
  };
}

/// App-wide subscriber for network availability.
///
/// connectivity_plus on iOS can report `none` while the network works (it
/// reads `NWPathMonitor.currentPath` before the first path update). With a
/// probe, a `none` report only goes offline once the probe fails too, and
/// while offline the probe is retried every [offlineRecheckInterval]. Any
/// [reportReachable] call (e.g. a server response) restores online.
class ConnectivityService {
  ConnectivityService({
    ConnectivityStatusSource? source,
    bool initiallyOnline = true,
    this._probe,
    this.offlineRecheckInterval = const Duration(seconds: 5),
  }) : _source = source ?? ConnectivityPlusStatusSource(),
       isOnline = ValueNotifier<bool>(initiallyOnline);

  final ConnectivityStatusSource _source;
  final ReachabilityProbe? _probe;
  final Duration offlineRecheckInterval;
  final ValueNotifier<bool> isOnline;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _recheckTimer;
  bool _isStarted = false;
  bool _disposed = false;

  /// Bumps on every report so a slow probe never overrides a newer one.
  var _generation = 0;

  bool get isConnected => isOnline.value;

  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;
    _subscription = _source.onConnectivityChanged.listen(updateStatus);

    try {
      updateStatus(await _source.checkConnectivity());
    } on Object {
      // Preserve the last known state when the platform check itself fails.
    }
  }

  void updateStatus(List<ConnectivityResult> results) {
    final connected = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final generation = ++_generation;
    if (connected) {
      _setOnline(true);
      return;
    }
    final probe = _probe;
    if (probe == null) {
      _setOnline(false);
      return;
    }
    unawaited(_confirmOffline(probe, generation));
  }

  /// A server answered, so the network works whatever the platform says.
  void reportReachable() {
    if (_disposed) return;
    _generation++;
    _setOnline(true);
  }

  Future<bool> refreshStatus() async {
    try {
      updateStatus(await _source.checkConnectivity());
    } on Object {
      // A failed refresh is not evidence that the interface disconnected.
    }
    return isOnline.value;
  }

  Future<void> _confirmOffline(ReachabilityProbe probe, int generation) async {
    final reachable = await probe();
    if (_disposed || generation != _generation) return;
    _setOnline(reachable);
  }

  void _setOnline(bool online) {
    if (_disposed) return;
    if (online) {
      _recheckTimer?.cancel();
      _recheckTimer = null;
    } else if (_probe != null) {
      _recheckTimer ??= Timer.periodic(
        offlineRecheckInterval,
        (_) => unawaited(_recheck()),
      );
    }
    if (online != isOnline.value) isOnline.value = online;
  }

  Future<void> _recheck() async {
    final probe = _probe;
    if (probe == null || isOnline.value) return;
    final generation = _generation;
    final reachable = await probe();
    if (_disposed || generation != _generation || !reachable) return;
    _setOnline(true);
  }

  Future<void> dispose() async {
    _disposed = true;
    _recheckTimer?.cancel();
    await _subscription?.cancel();
    isOnline.dispose();
  }
}
