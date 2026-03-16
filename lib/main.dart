import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/local/cache_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BootstrapApp()));
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  static const _nativeDiagnostics = MethodChannel(
    'aadith_sai_billing_mobile/startup_diagnostics',
  );
  bool _ready = false;
  String _stage = 'Starting app...';
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_notifyNative('Bootstrap widget created'));
    unawaited(_initialize());
  }

  Future<void> _notifyNative(String message) async {
    try {
      await _nativeDiagnostics.invokeMethod('startupState', {'message': message});
    } catch (_) {
      // Ignore if the native side is not ready.
    }
  }

  Future<void> _initialize() async {
    try {
      setState(() => _stage = 'Loading configuration...');
      unawaited(_notifyNative(_stage));
      try {
        await dotenv.load(fileName: '.env').timeout(const Duration(seconds: 5));
      } catch (_) {
        // Fall back to defaults when local env is not present.
      }

      setState(() => _stage = 'Preparing local storage...');
      unawaited(_notifyNative(_stage));
      await Hive.initFlutter().timeout(const Duration(seconds: 10));

      setState(() => _stage = 'Loading app cache...');
      unawaited(_notifyNative(_stage));
      await CacheStorage.init().timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _ready = true;
        _stage = 'Ready';
      });
      unawaited(_notifyNative('Flutter app ready'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
      unawaited(_notifyNative('Startup error: $_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const App();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D6EFD),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Aadith Sai Billing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212529),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error == null ? _stage : 'Startup failed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_error == null)
                    const CircularProgressIndicator()
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8D7DA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFF842029),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _stage = 'Retrying startup...';
                        });
                        unawaited(_initialize());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
