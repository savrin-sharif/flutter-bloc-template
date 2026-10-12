import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc_template/core/network/connectivity_service.dart';

void main() {
  test(
    'publishes the initial check and real-time connection changes',
    () async {
      final source = _FakeConnectivityStatusSource([ConnectivityResult.none]);
      final service = ConnectivityService(source: source);
      addTearDown(() async {
        await service.dispose();
        await source.dispose();
      });

      await service.start();
      expect(service.isConnected, isFalse);

      source.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(service.isConnected, isTrue);

      source.emit([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(service.isConnected, isFalse);
    },
  );

  test('treats every non-none network interface as connected', () {
    final source = _FakeConnectivityStatusSource([ConnectivityResult.none]);
    final service = ConnectivityService(source: source, initiallyOnline: false);
    addTearDown(() async {
      await service.dispose();
      await source.dispose();
    });

    service.updateStatus([ConnectivityResult.ethernet]);
    expect(service.isConnected, isTrue);

    service.updateStatus([ConnectivityResult.none]);
    expect(service.isConnected, isFalse);
  });

  test('refreshes the current platform status on demand', () async {
    final source = _FakeConnectivityStatusSource([ConnectivityResult.mobile]);
    final service = ConnectivityService(source: source, initiallyOnline: false);
    addTearDown(() async {
      await service.dispose();
      await source.dispose();
    });

    expect(await service.refreshStatus(), isTrue);
    expect(source.checkCalls, 1);
  });

  group('with a reachability probe', () {
    test(
      'a false "none" report stays online when the server answers',
      () async {
        final source = _FakeConnectivityStatusSource([ConnectivityResult.none]);
        var probes = 0;
        final service = ConnectivityService(
          source: source,
          probe: () async {
            probes++;
            return true;
          },
        );
        addTearDown(() async {
          await service.dispose();
          await source.dispose();
        });

        await service.start();
        await pumpEventQueue();

        expect(service.isConnected, isTrue);
        expect(probes, 1);
      },
    );

    test('goes offline when the probe fails and recovers on recheck', () async {
      final source = _FakeConnectivityStatusSource([ConnectivityResult.wifi]);
      var reachable = false;
      final service = ConnectivityService(
        source: source,
        probe: () async => reachable,
        offlineRecheckInterval: const Duration(milliseconds: 20),
      );
      addTearDown(() async {
        await service.dispose();
        await source.dispose();
      });
      await service.start();

      source.emit([ConnectivityResult.none]);
      await pumpEventQueue();
      expect(service.isConnected, isFalse);

      reachable = true;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(service.isConnected, isTrue);
    });

    test('a server response restores online immediately', () async {
      final source = _FakeConnectivityStatusSource([ConnectivityResult.none]);
      final service = ConnectivityService(
        source: source,
        probe: () async => false,
        offlineRecheckInterval: const Duration(hours: 1),
      );
      addTearDown(() async {
        await service.dispose();
        await source.dispose();
      });
      await service.start();
      await pumpEventQueue();
      expect(service.isConnected, isFalse);

      service.reportReachable();
      expect(service.isConnected, isTrue);
    });

    test('a slow failing probe never overrides a newer report', () async {
      final source = _FakeConnectivityStatusSource([ConnectivityResult.wifi]);
      final probe = Completer<bool>();
      final service = ConnectivityService(
        source: source,
        probe: () => probe.future,
      );
      addTearDown(() async {
        await service.dispose();
        await source.dispose();
      });
      await service.start();

      source.emit([ConnectivityResult.none]);
      source.emit([ConnectivityResult.wifi]);
      probe.complete(false);
      await pumpEventQueue();

      expect(service.isConnected, isTrue);
    });
  });
}

final class _FakeConnectivityStatusSource implements ConnectivityStatusSource {
  _FakeConnectivityStatusSource(this.results);

  final _changes = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );
  List<ConnectivityResult> results;
  var checkCalls = 0;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checkCalls++;
    return results;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;

  void emit(List<ConnectivityResult> value) {
    results = value;
    _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}
