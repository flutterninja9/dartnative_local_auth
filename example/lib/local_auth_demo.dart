import 'package:dartnative/dartnative.dart';
import 'package:local_auth_kit/local_auth_kit.dart';

/// Exercises the public `LocalAuthentication` API on a device.
class LocalAuthDemo extends StatefulWidget {
  const LocalAuthDemo({super.key});

  @override
  State<LocalAuthDemo> createState() => _LocalAuthDemoState();
}

class _LocalAuthDemoState extends State<LocalAuthDemo> {
  final LocalAuthentication _auth = LocalAuthentication();

  bool? _supported;
  bool? _canCheck;
  List<BiometricType> _kinds = const [];
  bool _biometricOnly = false;
  bool _persist = false;
  bool _customCopy = false;
  String _status = 'Tap a button to query the device.';
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _append(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _log.insert(0, '$ts  $message');
    if (_log.length > 14) _log.removeLast();
  }

  Future<void> _refresh() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final kinds = await _auth.getAvailableBiometrics();
      setState(() {
        _supported = supported;
        _canCheck = canCheck;
        _kinds = kinds;
        _append(
          'refresh → supported=$supported canCheck=$canCheck kinds=${kinds.map((e) => e.name).join(",")}',
        );
      });
    } catch (e) {
      setState(() {
        _status = 'Refresh failed: $e';
        _append('refresh error → $e');
      });
    }
  }

  Future<void> _authenticate() async {
    setState(() => _status = 'Prompting…');
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock the local_auth_kit example',
        biometricOnly: _biometricOnly,
        persistAcrossBackgrounding: _persist,
        authMessages: _customCopy
            ? const [
                AndroidAuthMessages(
                  signInTitle: 'Unlock local_auth_kit',
                  signInHint: 'Use biometrics or device PIN',
                  cancelButton: 'No thanks',
                ),
                IOSAuthMessages(
                  cancelButton: 'No thanks',
                  localizedFallbackTitle: 'Use passcode',
                ),
              ]
            : const [AndroidAuthMessages(), IOSAuthMessages()],
      );
      setState(() {
        _status = ok ? 'Authenticated' : 'Not authenticated';
        _append('authenticate → $ok');
      });
    } on LocalAuthException catch (e) {
      setState(() {
        _status =
            'Failed: ${e.code.name}${e.description == null ? '' : ' — ${e.description}'}';
        _append('authenticate exception → ${e.code.name}');
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _append('authenticate error → $e');
      });
    }
  }

  Future<void> _stop() async {
    final stopped = await _auth.stopAuthentication();
    setState(() {
      _status = stopped ? 'Canceled in-flight prompt' : 'Nothing to cancel';
      _append('stopAuthentication → $stopped');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      brightness: Brightness.light,
      appBar: AppBar(
        title: const Text(
          'local_auth_kit',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Section('Device'),
          _Value('isDeviceSupported', _supported == null ? '…' : '$_supported'),
          _Value('canCheckBiometrics', _canCheck == null ? '…' : '$_canCheck'),
          _Value(
            'available',
            _kinds.isEmpty ? '(none)' : _kinds.map((e) => e.name).join(', '),
          ),
          const SizedBox(height: 12),
          Button(
            title: 'Refresh capabilities',
            variant: ButtonVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onPressed: _refresh,
          ),
          const SizedBox(height: 28),
          const _Section('Authenticate'),
          _Value('biometricOnly', '$_biometricOnly'),
          _Value('persistAcrossBackgrounding', '$_persist'),
          _Value('custom authMessages', '$_customCopy'),
          const SizedBox(height: 12),
          Button(
            title: _biometricOnly
                ? 'Use biometrics + device PIN'
                : 'Require biometrics only',
            variant: ButtonVariant.tinted,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onPressed: () => setState(() => _biometricOnly = !_biometricOnly),
          ),
          const SizedBox(height: 8),
          Button(
            title: _persist
                ? 'Disable persist-across-background'
                : 'Enable persist-across-background',
            variant: ButtonVariant.tinted,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onPressed: () => setState(() => _persist = !_persist),
          ),
          const SizedBox(height: 8),
          Button(
            title: _customCopy
                ? 'Use default prompt copy'
                : 'Use custom authMessages',
            variant: ButtonVariant.tinted,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onPressed: () => setState(() => _customCopy = !_customCopy),
          ),
          const SizedBox(height: 8),
          Button(
            title: 'Authenticate',
            variant: ButtonVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onPressed: _authenticate,
          ),
          const SizedBox(height: 8),
          Button(
            title: 'Stop authentication',
            variant: ButtonVariant.tinted,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onPressed: _stop,
          ),
          const _Hint(
            'On iOS, add NSFaceIDUsageDescription (this example already does). '
            'Cancel the sheet, lock the device, or background the app to see '
            'the exception codes.',
          ),
          const SizedBox(height: 28),
          const _Section('Status'),
          Text(
            _status,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 16),
          ),
          const SizedBox(height: 28),
          const _Section('Event log'),
          if (_log.isEmpty)
            const _Hint('No events yet.')
          else
            ..._log.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  e,
                  style: const TextStyle(
                    color: Color(0xFF1E9E4A),
                    fontSize: 13,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF636366),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      '$label: $value',
      style: const TextStyle(color: Color(0xFF111111), fontSize: 16),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
    ),
  );
}
