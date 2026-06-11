import 'dart:io';
import 'package:flutter/material.dart';
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

/// "Ask your business" — owner/admin conversational assistant (read-only).
/// Voice will plug into the same flow via /ai-assistant/transcribe once a
/// recorder package + the Sarvam key are added.
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

  AssistantStatus? _status;
  bool _loadingStatus = true;
  bool _sending = false;
  final List<AssistantTurn> _turns = [];

  static const _suggestions = [
    "Today's sales?",
    'Who owes me the most money?',
    'How much did we collect this month?',
    'How much do we owe vendors?',
  ];

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    _repo = AiAssistantRepository(_client);
    _loadStatus();
  }

  @override
  void dispose() {
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

  Future<void> _toggleMic() async {
    if (_transcribing || _sending) return;
    if (_recording) {
      final path = await _rec.stop();
      if (mounted) setState(() => _recording = false);
      if (path != null) await _transcribe(path);
      return;
    }
    try {
      if (!await _rec.hasPermission()) {
        _toast('Microphone permission is needed for voice.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/ask_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: filePath,
      );
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      _toast('Could not start recording.');
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
    } catch (_) {
      if (mounted) setState(() { _status = const AssistantStatus(); _loadingStatus = false; });
    }
  }

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _inputCtrl.text).trim();
    if (q.isEmpty || _sending) return;
    _inputCtrl.clear();
    setState(() {
      _turns.add(AssistantTurn(isUser: true, text: q));
      _turns.add(const AssistantTurn(isUser: false, text: '', loading: true));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final ans = await _repo.ask(q);
      final answerText = ans.answer.isEmpty ? '(no answer)' : ans.answer;
      _replaceLast(AssistantTurn(isUser: false, text: answerText));
      _speak(answerText);
    } catch (e) {
      _replaceLast(AssistantTurn(isUser: false, text: _friendlyError(e)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
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
                  itemBuilder: (_, i) => _bubble(_turns[i]),
                ),
        ),
        if (_recording)
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF2F2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: const [
              Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 12),
              SizedBox(width: 8),
              Text('Listening… tap stop when done', style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
            ]),
          ),
        _inputBar(),
      ],
    );
  }

  Widget _emptyState() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.auto_awesome, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Ask anything about your business',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Tamil, English or mixed — sales, collections, vendor dues, invoices…',
              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
            : Text(t.text, style: TextStyle(color: fg, fontSize: 14.5, height: 1.35)),
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
            IconButton(
              tooltip: _recording ? 'Stop' : 'Speak',
              icon: _transcribing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_recording ? Icons.stop_circle : Icons.mic_none,
                      color: _recording ? AppColors.danger : AppColors.primary, size: 26),
              onPressed: (_transcribing || _sending) ? null : _toggleMic,
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
