import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../../data/models/assistant_model.dart';
import '../../../data/repositories/ai_assistant_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../assistant_nav.dart';

/// "Ask your business" — owner/admin conversational assistant (read-only).
/// Supports typed input, press-and-hold one-shot voice, and a fully hands-free
/// "voice mode" (listen → auto-stop on silence → answer → speak → re-listen),
/// with tap-to-stop to interrupt.

/// Hands-free conversation state machine.
enum _VoiceState { off, listening, processing, speaking, paused }

class AskBusinessScreen extends ConsumerStatefulWidget {
  const AskBusinessScreen({super.key});
  @override
  ConsumerState<AskBusinessScreen> createState() => _AskBusinessScreenState();
}

class _AskBusinessScreenState extends ConsumerState<AskBusinessScreen> {
  late final ApiClient _client;
  late final AiAssistantRepository _repo;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final _rec = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  bool _recording = false;
  bool _transcribing = false;
  bool _speakAnswers = true; // read answers aloud

  // hold-to-talk live state
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _recTimer;
  DateTime? _recStart;
  String? _recPath;
  double _amp = 0; // 0..1 normalized live mic level
  int _recMs = 0;  // elapsed recording time

  // hands-free voice mode
  _VoiceState _vstate = _VoiceState.off;
  Timer? _vadTimer;        // polls for end-of-speech / timeouts
  Timer? _ttsSafety;       // failsafe if TTS completion never fires
  DateTime? _lastLoud;     // last time mic level crossed the speech threshold
  bool _heardSpeech = false;
  int _genToken = 0;       // bumped to discard a stale/cancelled turn
  static const double _speechThreshold = 0.12; // normalized level counted as speech
  static const int _silenceMs = 1400;  // trailing silence that ends a turn
  static const int _noSpeechMs = 8000; // give up listening if nothing is said
  static const int _maxTurnMs = 20000; // hard cap on one spoken question

  AssistantStatus? _status;
  bool _loadingStatus = true;
  bool _sending = false;
  final List<AssistantTurn> _turns = [];

  BusinessBrief? _brief; // proactive digest shown on open (no LLM)
  String _briefState = 'idle'; // idle | loading | done | error

  /// Starter chips — technicians get field-work questions, everyone else the owner set.
  List<String> get _suggestions {
    final user = ref.read(authProvider).user;
    if (user?.isTechnician == true) {
      return const [
        'What tickets are assigned to me?',
        'Any overdue repairs?',
        'Tickets awaiting parts?',
        'Warranties expiring this month?',
      ];
    }
    if (user?.isOperator == true) {
      return const [
        'What maintenance is due on my machines?',
        'Which documents expire soon?',
        'How many hours did my machine run this week?',
        'Any open breakdowns?',
      ];
    }
    return const [
      "Today's sales?",
      'Who owes me the most money?',
      'How much did we collect this month?',
      'How much do we owe vendors?',
    ];
  }

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    _repo = AiAssistantRepository(_client);
    // When the assistant finishes speaking in voice mode, reopen the mic for the next turn.
    _tts.setCompletionHandler(_onTtsDone);
    _tts.setCancelHandler(() {}); // manual stop transitions are handled inline
    _loadStatus();
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _recTimer?.cancel();
    _vadTimer?.cancel();
    _ttsSafety?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _rec.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (!_speakAnswers || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      // Pick a voice language from the answer's script (Tamil vs default English).
      final isTamil = RegExp(r'[஀-௿]').hasMatch(text);
      await _tts.setLanguage(isTamil ? 'ta-IN' : 'en-IN');
      await _tts.speak(text);
    } catch (_) {/* TTS unavailable — silent */}
  }

  // Press-and-hold: start on touch-down.
  Future<void> _startHold() async {
    if (_recording || _transcribing || _sending) return;
    try {
      if (!await _rec.hasPermission()) {
        _toast('Microphone permission is needed for voice.');
        return;
      }
      final dir = await getTemporaryDirectory();
      _recPath = '${dir.path}/ask_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: _recPath!,
      );
      _recStart = DateTime.now();
      HapticFeedback.mediumImpact();
      // live mic level → drives the pulsing glow + waveform
      _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
        final norm = ((a.current + 45) / 45).clamp(0.0, 1.0);
        if (mounted) setState(() => _amp = norm);
      });
      _recTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (_recStart != null && mounted) setState(() => _recMs = DateTime.now().difference(_recStart!).inMilliseconds);
      });
      if (mounted) setState(() { _recording = true; _recMs = 0; });
    } catch (_) {
      _toast('Could not start recording.');
    }
  }

  // Release (send:true) or drag-off / cancel (send:false).
  Future<void> _stopHold({required bool send}) async {
    if (!_recording) return;
    final ms = _recStart != null ? DateTime.now().difference(_recStart!).inMilliseconds : 0;
    await _ampSub?.cancel(); _ampSub = null;
    _recTimer?.cancel(); _recTimer = null;
    _recStart = null;
    String? path;
    try { path = await _rec.stop(); } catch (_) {}
    if (mounted) setState(() { _recording = false; _amp = 0; _recMs = 0; });
    // too short or cancelled → discard, no transcription
    if (!send || ms < 600) {
      if (send && ms < 600) _toast('Hold the mic and speak.');
      if (path != null) { try { await File(path).delete(); } catch (_) {} }
      return;
    }
    if (path != null) await _transcribe(path);
  }

  String _fmtElapsed(int ms) {
    final s = (ms / 1000).floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ── hands-free voice mode ────────────────────────────────────────────────
  Future<void> _enterVoiceMode() async {
    if (_vstate != _VoiceState.off) return;
    if (_recording) await _stopHold(send: false); // drop any one-shot capture
    await _listenTurn();
  }

  Future<void> _exitVoiceMode() async {
    _genToken++;
    await _ampSub?.cancel(); _ampSub = null;
    _vadTimer?.cancel(); _vadTimer = null;
    _ttsSafety?.cancel(); _ttsSafety = null;
    try { await _rec.stop(); } catch (_) {}
    await _tts.stop();
    _recStart = null;
    if (mounted) setState(() { _vstate = _VoiceState.off; _amp = 0; _recMs = 0; });
  }

  Future<void> _listenTurn() async {
    if (_vstate == _VoiceState.off && _recStart != null) return;
    try {
      if (!await _rec.hasPermission()) {
        _toast('Microphone permission is needed for voice.');
        await _exitVoiceMode();
        return;
      }
      final dir = await getTemporaryDirectory();
      _recPath = '${dir.path}/ask_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: _recPath!,
      );
      _recStart = DateTime.now();
      _heardSpeech = false;
      _lastLoud = null;
      _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
        final norm = ((a.current + 45) / 45).clamp(0.0, 1.0);
        _amp = norm;
        if (norm > _speechThreshold) { _heardSpeech = true; _lastLoud = DateTime.now(); }
        if (mounted) setState(() {});
      });
      _vadTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _onVadTick());
      if (mounted) setState(() { _vstate = _VoiceState.listening; _recMs = 0; });
    } catch (_) {
      _toast('Could not start listening.');
      await _exitVoiceMode();
    }
  }

  void _onVadTick() {
    if (_vstate != _VoiceState.listening || _recStart == null) return;
    final now = DateTime.now();
    final elapsed = now.difference(_recStart!).inMilliseconds;
    if (mounted) setState(() => _recMs = elapsed);
    if (elapsed > _maxTurnMs) { _finishListening(process: _heardSpeech); return; }
    if (!_heardSpeech) {
      if (elapsed > _noSpeechMs) _finishListening(process: false, pause: true);
      return;
    }
    if (_lastLoud != null && now.difference(_lastLoud!).inMilliseconds > _silenceMs) {
      _finishListening(process: true);
    }
  }

  Future<void> _finishListening({required bool process, bool pause = false}) async {
    await _ampSub?.cancel(); _ampSub = null;
    _vadTimer?.cancel(); _vadTimer = null;
    _recStart = null;
    String? path;
    try { path = await _rec.stop(); } catch (_) {}
    if (mounted) setState(() => _amp = 0);
    if (_vstate == _VoiceState.off) return;
    if (!process) {
      if (path != null) { try { await File(path).delete(); } catch (_) {} }
      if (pause) { if (mounted) setState(() => _vstate = _VoiceState.paused); }
      else { await _listenTurn(); }
      return;
    }
    if (mounted) setState(() => _vstate = _VoiceState.processing);
    if (path == null) { await _listenTurn(); return; }
    final myToken = ++_genToken;
    String text = '';
    try { text = await _repo.transcribe(path); } catch (_) {}
    try { await File(path).delete(); } catch (_) {}
    if (_vstate == _VoiceState.off || myToken != _genToken) return; // cancelled
    if (text.trim().isEmpty) { await _listenTurn(); return; } // heard nothing usable
    await _voiceAsk(text.trim(), myToken);
  }

  Future<void> _voiceAsk(String q, int myToken) async {
    final history = _historyFromTurns();
    setState(() {
      _turns.add(AssistantTurn(isUser: true, text: q));
      _turns.add(const AssistantTurn(isUser: false, text: '', loading: true));
    });
    _scrollToEnd();
    String answerText;
    AssistantAnswer? ans;
    try {
      ans = await _repo.ask(q, history: history);
      answerText = ans.answer.isEmpty ? '(no answer)' : ans.answer;
    } catch (e) {
      answerText = _friendlyError(e);
    }
    // Always resolve the loading bubble; only continue the loop if still current.
    _replaceLast(AssistantTurn(isUser: false, text: answerText, suggestions: ans?.suggestions ?? const [], data: ans?.data ?? const [], navigate: ans?.navigate, animate: true));
    _scrollToEnd();
    _maybeAutoOpen(ans);
    if (_vstate == _VoiceState.off || myToken != _genToken) return; // interrupted
    if (_speakAnswers) {
      if (mounted) setState(() => _vstate = _VoiceState.speaking);
      _ttsSafety?.cancel();
      _ttsSafety = Timer(const Duration(seconds: 30), () { if (_vstate == _VoiceState.speaking) _onTtsDone(); });
      await _speak(answerText);
    } else {
      await _listenTurn();
    }
  }

  void _onTtsDone() {
    _ttsSafety?.cancel(); _ttsSafety = null;
    if (_vstate == _VoiceState.speaking) _listenTurn();
  }

  // The big orb is state-aware: submit early while listening, STOP while
  // thinking/speaking (tap-to-interrupt), resume when paused.
  void _voiceTap() {
    switch (_vstate) {
      case _VoiceState.listening:
        _finishListening(process: _heardSpeech);
        break;
      case _VoiceState.processing:
        _genToken++; // discard the in-flight result
        _resolveLoadingBubble();
        _listenTurn();
        break;
      case _VoiceState.speaking:
        _genToken++;
        _ttsSafety?.cancel(); _ttsSafety = null;
        _tts.stop();
        _listenTurn();
        break;
      case _VoiceState.paused:
        _listenTurn();
        break;
      case _VoiceState.off:
        break;
    }
  }

  void _resolveLoadingBubble() {
    if (_turns.isNotEmpty && _turns.last.loading) {
      _replaceLast(const AssistantTurn(isUser: false, text: '(stopped)'));
    }
  }

  (String, String) _voiceLabels() {
    switch (_vstate) {
      case _VoiceState.listening: return ('Listening…', 'Speak now — tap when done');
      case _VoiceState.processing: return ('Thinking…', 'Tap to stop');
      case _VoiceState.speaking: return ('Speaking…', 'Tap to stop & ask again');
      case _VoiceState.paused: return ('Tap to talk', 'Voice mode paused');
      case _VoiceState.off: return ('', '');
    }
  }

  Future<void> _transcribe(String path) async {
    setState(() => _transcribing = true);
    try {
      final text = await _repo.transcribe(path);
      if (text.trim().isNotEmpty) {
        _send(text.trim()); // voice → ask right away (hands-free); the answer is spoken back
      } else {
        _toast('Didn\'t catch that — please try again.');
      }
    } catch (e) {
      _toast(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _transcribing = false);
      try { await File(path).delete(); } catch (_) {}
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadStatus() async {
    try {
      final s = await _repo.status();
      if (mounted) setState(() { _status = s; _loadingStatus = false; });
      // Once we know the feature is live, pull the proactive brief to greet the user with it.
      if (s.enabled && s.configured) _loadBrief();
    } catch (_) {
      if (mounted) setState(() { _status = const AssistantStatus(); _loadingStatus = false; });
    }
  }

  // The "morning brief" — a direct read (no LLM); failures degrade silently to the suggestions.
  Future<void> _loadBrief() async {
    if (_briefState != 'idle') return;
    if (mounted) setState(() => _briefState = 'loading');
    try {
      final b = await _repo.brief();
      if (mounted) setState(() { _brief = b; _briefState = 'done'; });
    } catch (_) {
      if (mounted) setState(() => _briefState = 'error');
    }
  }

  // Prior turns (excluding loading bubbles) give the assistant context for follow-ups.
  List<Map<String, String>> _historyFromTurns() => _turns
      .where((t) => !t.loading && t.text.trim().isNotEmpty)
      .map((t) => {'role': t.isUser ? 'user' : 'assistant', 'content': t.text})
      .toList();

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _inputCtrl.text).trim();
    if (q.isEmpty || _sending) return;
    _inputCtrl.clear();
    final history = _historyFromTurns();
    setState(() {
      _turns.add(AssistantTurn(isUser: true, text: q));
      _turns.add(const AssistantTurn(isUser: false, text: '', loading: true));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final ans = await _repo.ask(q, history: history);
      final answerText = ans.answer.isEmpty ? '(no answer)' : ans.answer;
      _replaceLast(AssistantTurn(isUser: false, text: answerText, suggestions: ans.suggestions, data: ans.data, navigate: ans.navigate, animate: true));
      _speak(answerText);
      _maybeAutoOpen(ans);
    } catch (e) {
      _replaceLast(AssistantTurn(isUser: false, text: _friendlyError(e)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  /// The user explicitly asked to go somewhere ("take me to X" / "yes, open it") —
  /// open it after a beat so they see the answer first. The button stays in the
  /// transcript, so coming back to the chat keeps it usable.
  void _maybeAutoOpen(AssistantAnswer? ans) {
    final nav = ans?.navigate;
    if (nav == null || !nav.auto || !nav.openableOnMobile) return;
    final wasVoice = _vstate != _VoiceState.off;
    Future.delayed(Duration(milliseconds: wasVoice ? 1600 : 900), () {
      if (!mounted) return;
      if (_vstate != _VoiceState.off) _exitVoiceMode();
      openAssistantDestination(context, ref, nav);
    });
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('503') || s.toLowerCase().contains('not configured')) {
      return 'The assistant isn\'t fully set up yet (AI key pending). Please try again later.';
    }
    if (s.contains('403') || s.toLowerCase().contains('not enabled')) {
      return 'This feature isn\'t enabled for your company.';
    }
    return 'Sorry, something went wrong. Please rephrase and try again.';
  }

  void _replaceLast(AssistantTurn turn) {
    if (!mounted) return;
    setState(() {
      if (_turns.isNotEmpty) _turns[_turns.length - 1] = turn;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ask your business'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        actions: [
          if (_status?.enabled == true)
            IconButton(
              tooltip: _vstate == _VoiceState.off ? 'Hands-free voice mode' : 'Exit voice mode',
              icon: Icon(_vstate == _VoiceState.off ? Icons.graphic_eq : Icons.stop_circle,
                  color: _vstate == _VoiceState.off ? null : AppColors.danger),
              onPressed: () => _vstate == _VoiceState.off ? _enterVoiceMode() : _exitVoiceMode(),
            ),
          IconButton(
            tooltip: _speakAnswers ? 'Mute voice' : 'Speak answers',
            icon: Icon(_speakAnswers ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() => _speakAnswers = !_speakAnswers);
              if (!_speakAnswers) _tts.stop();
            },
          ),
        ],
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : (_status?.enabled != true ? _locked() : _chat()),
    );
  }

  Widget _locked() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.workspace_premium_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('AI Assistant is a premium add-on',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Ask about sales, collections, dues and more in your own words. Contact your administrator to enable it for your company.',
                style: TextStyle(color: Color(0xFF64748B)), textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _chat() {
    return Column(
      children: [
        if (_status?.configured == false)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF7ED),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text('Assistant key not yet configured on the server — answers will be available once set up.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9A3412))),
          ),
        Expanded(
          child: _turns.isEmpty
              ? _emptyState()
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(14),
                  itemCount: _turns.length,
                  itemBuilder: (_, i) {
                    final t = _turns[i];
                    final isLast = i == _turns.length - 1;
                    final rows = t.isUser ? null : _extractRows(t.data);
                    return Column(
                      key: ValueKey(i),
                      crossAxisAlignment: t.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        _bubble(t),
                        if (rows != null) _dataTable(rows),
                        if (!t.isUser && t.navigate != null) _navCard(t.navigate!),
                        if (isLast && !t.isUser && !_sending && t.suggestions.isNotEmpty) _followups(t.suggestions),
                      ],
                    );
                  },
                ),
        ),
        if (_vstate == _VoiceState.off && _recording)
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF2F2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 12),
              const SizedBox(width: 8),
              Text(_fmtElapsed(_recMs),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
              const SizedBox(width: 12),
              Expanded(child: _waveBar()),
              const SizedBox(width: 12),
              const Text('Release to send', style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
            ]),
          ),
        _vstate == _VoiceState.off ? _inputBar() : _voicePanel(),
      ],
    );
  }

  Widget _voicePanel() {
    final (label, sub) = _voiceLabels();
    final listening = _vstate == _VoiceState.listening;
    final speaking = _vstate == _VoiceState.speaking;
    final processing = _vstate == _VoiceState.processing;
    final orbColor = listening
        ? AppColors.primary
        : speaking
            ? AppColors.danger
            : processing
                ? const Color(0xFF6366F1)
                : const Color(0xFF94A3B8);
    final icon = listening
        ? Icons.mic
        : (speaking || processing)
            ? Icons.stop_rounded
            : Icons.mic_none;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _voiceTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: orbColor.withValues(alpha: 0.12),
                boxShadow: listening
                    ? [BoxShadow(color: orbColor.withValues(alpha: 0.25 + 0.45 * _amp), blurRadius: 10 + 26 * _amp, spreadRadius: 2 + 9 * _amp)]
                    : null,
              ),
              child: Icon(icon, color: orbColor, size: 38),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: listening
                ? Text(_fmtElapsed(_recMs), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                : (processing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const SizedBox.shrink()),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _exitVoiceMode,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Exit voice mode'),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    final name = (ref.read(authProvider).user?.name ?? '').trim();
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.auto_awesome, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          if (firstName.isNotEmpty) ...[
            Text('Hi $firstName 👋',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
          ],
          Text(firstName.isNotEmpty ? 'How can I help today?' : 'Ask anything about your business',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Tamil, English or mixed — sales, collections, vendor dues, invoices…',
              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 6),
          const Text('Type, or hold the 🎤 to talk',
              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          if (_briefState == 'loading') ...[
            const SizedBox(height: 16),
            const Center(child: Text('Pulling together your brief…',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic))),
          ],
          if (_briefState == 'done' && _brief != null && _brief!.hasContent) ...[
            const SizedBox(height: 16),
            _briefCard(_brief!),
          ],
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map((s) => ActionChip(label: Text(s), onPressed: _sending ? null : () => _send(s)))
                .toList(),
          ),
        ],
      );
  }

  Widget _bubble(AssistantTurn t) {
    final align = t.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = t.isUser ? AppColors.primary : Colors.white;
    final fg = t.isUser ? Colors.white : const Color(0xFF0F172A);
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: t.isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: t.loading
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : (t.animate
                ? _TypewriterText(t.text, style: TextStyle(color: fg, fontSize: 14.5, height: 1.35))
                : Text(t.text, style: TextStyle(color: fg, fontSize: 14.5, height: 1.35))),
      ),
    );
  }

  // Pull the first list-of-rows from the tool results for a compact table.
  List<Map<String, dynamic>>? _extractRows(List<dynamic> data) {
    for (final d in data) {
      final res = (d is Map) ? d['result'] : null;
      if (res is Map) {
        for (final v in res.values) {
          if (v is List && v.isNotEmpty && v.first is Map) {
            return v.take(5).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      }
    }
    return null;
  }

  String _fmtCell(String key, dynamic v) {
    if (v is num) {
      final grouped = v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
      final money = RegExp(r'owed|amount|total|outstanding|paid|balance|value|payable|sales', caseSensitive: false).hasMatch(key);
      return money ? '₹$grouped' : grouped;
    }
    return v?.toString() ?? '';
  }

  Widget _dataTable(List<Map<String, dynamic>> rows) {
    final cols = rows.first.keys.take(3).toList();
    Widget cell(String text, {bool header = false}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: header ? 11.5 : 12,
                  color: header ? const Color(0xFF64748B) : const Color(0xFF334155),
                  fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                )),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 6),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Container(color: const Color(0xFFF8FAFC), child: Row(children: cols.map((c) => cell(c, header: true)).toList())),
        ...rows.map((r) => Row(children: cols.map((c) => cell(_fmtCell(c, r[c]))).toList())),
      ]),
    );
  }

  // "Open <screen>" action under an answer. Tapping navigates in-app when the screen exists on
  // mobile; for web-only screens (the General Ledger pages) we show a non-tappable web-portal note.
  // The proactive brief, rendered as titled section cards (Needs-attention highlighted).
  Widget _briefCard(BusinessBrief b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (b.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(b.summary,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ),
        ...b.sections.map((s) {
          final attention = s.title.toLowerCase().contains('attention');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: attention ? const Color(0xFFFFF7ED) : Colors.white,
              border: Border.all(color: attention ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.icon} ${s.title}'.trim(),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                ...s.lines.map((ln) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('• $ln',
                          style: TextStyle(fontSize: 12, height: 1.35, color: attention ? const Color(0xFF9A3412) : const Color(0xFF475569))),
                    )),
              ],
            ),
          );
        }),
        if (b.alertsRoute != null && b.alertCount > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: FilledButton.tonal(
                onPressed: () => openAssistantDestination(
                    context, ref, AssistantNavigate(label: 'Alerts', mobileRoute: b.alertsRoute)),
                child: Text('Open Alerts (${b.alertCount})'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _navCard(AssistantNavigate nav) {
    if (nav.openableOnMobile) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: OutlinedButton.icon(
            onPressed: () => openAssistantDestination(context, ref, nav),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('Open ${nav.label}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: Color(0xFFC7D2FE)),
              backgroundColor: const Color(0xFFEEF2FF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.language, size: 16, color: Color(0xFF64748B)),
        const SizedBox(width: 8),
        Flexible(
          child: Text('${nav.label} is available on the web portal',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
        ),
      ]),
    );
  }

  Widget _followups(List<String> suggestions) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: suggestions
              .map((s) => ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4338CA))),
                    onPressed: _sending ? null : () => _send(s),
                    backgroundColor: const Color(0xFFEEF2FF),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                  ))
              .toList(),
        ),
      );

  Widget _waveBar() {
    const n = 16;
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(n, (i) {
          final phase = 0.4 + ((i * 7) % 10) / 10.0; // per-bar variation so it looks alive
          final h = (4 + 18 * _amp * phase).clamp(4.0, 22.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            width: 3,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask about sales, dues, payments…',
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _transcribing
                ? const SizedBox(width: 46, height: 46, child: Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2)))
                : Tooltip(
                    message: 'Hold to talk',
                    child: Listener(
                      onPointerDown: (_) { if (!_sending) _startHold(); },
                      onPointerUp: (_) => _stopHold(send: true),
                      onPointerCancel: (_) => _stopHold(send: false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: _recording ? 54 : 46,
                        height: _recording ? 54 : 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _recording ? AppColors.danger : const Color(0xFFEFF3FF),
                          boxShadow: _recording
                              ? [BoxShadow(
                                  color: AppColors.danger.withValues(alpha: 0.30 + 0.45 * _amp),
                                  blurRadius: 8 + 24 * _amp,
                                  spreadRadius: 1 + 9 * _amp,
                                )]
                              : null,
                        ),
                        child: Icon(_recording ? Icons.mic : Icons.mic_none,
                            color: _recording ? Colors.white : AppColors.primary, size: _recording ? 26 : 24),
                      ),
                    ),
                  ),
            const SizedBox(width: 2),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sending ? null : () => _send(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reveals text progressively for a "typing" feel. Animates once on first build.
class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _TypewriterText(this.text, {this.style});
  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  int _n = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _n = 0;
    if (widget.text.isEmpty) return;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _n += 2;
        if (_n >= widget.text.length) { _n = widget.text.length; t.cancel(); }
      });
    });
  }

  @override
  void didUpdateWidget(covariant _TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _start(); // re-animate only when the text actually changes
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      Text(widget.text.substring(0, _n.clamp(0, widget.text.length)), style: widget.style);
}
