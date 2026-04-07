import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'home_state.dart';
import 'model_runner.dart';
import 'orchestrator.dart';

// distil labs exact palette (CSS: #4D65FF focus, SVG logo fill: #99C7FF)
const _bg      = Color(0xFF080A0F);  // near-black page background
const _surface = Color(0xFF111420);  // dark surface (assistant bubble, input fill)
const _white   = Color(0xFFFFFFFF);  // primary button fill / text / borders
const _logo    = Color(0xFF99C7FF);  // logo blue (hint text, home icon)
const _textSec = Color(0xFF8890A4);  // muted secondary text
const _errorBg = Color(0xFF2A1520);  // dark red tint
const _errorTxt= Color(0xFFFF6B7A);  // soft red

typedef _Msg = ({String text, bool isUser, bool isError, Map<String, dynamic>? call, double ttft, double tps});

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          surface: _surface,
          primary: _white,
          onPrimary: _bg,
          onSurface: _white,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsible function call chip
// ---------------------------------------------------------------------------

class _FnCallChip extends StatefulWidget {
  final Map<String, dynamic> call;
  const _FnCallChip(this.call);

  @override
  State<_FnCallChip> createState() => _FnCallChipState();
}

class _FnCallChipState extends State<_FnCallChip> {
  bool _expanded = false;

  Map<String, dynamic> get _args {
    final raw = widget.call['arguments'];
    return switch (raw) {
      Map<String, dynamic> m => m,
      String s => jsonDecode(s) as Map<String, dynamic>,
      _ => <String, dynamic>{},
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.call['name'] as String? ?? '';
    final args = _args;
    const mono = TextStyle(fontSize: 11, fontFamily: 'Courier', height: 1.3);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _logo.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _logo.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 13, color: _textSec),
                const SizedBox(width: 4),
                Text('fn  ', style: mono.copyWith(color: _textSec)),
                Text(name,
                    style: mono.copyWith(
                        color: _logo, fontWeight: FontWeight.w700)),
                if (args.isNotEmpty && !_expanded)
                  Text('(${args.keys.join(', ')})',
                      style: mono.copyWith(color: _textSec)),
              ],
            ),
            if (_expanded && args.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final e in args.entries)
                Text('  ${e.key}: ${e.value}',
                    style: mono.copyWith(color: _textSec, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home status screen
// ---------------------------------------------------------------------------

const _roomLabels = {
  'living_room': 'Living\nRoom',
  'bedroom':     'Bedroom',
  'kitchen':     'Kitchen',
  'bathroom':    'Bathroom',
  'office':      'Office',
  'hallway':     'Hallway',
};

const _doorLabels = {
  'front':  'Front',
  'back':   'Back',
  'garage': 'Garage',
  'side':   'Side',
};

const _sceneLabels = {
  'movie_night': 'Movie Night',
  'bedtime':     'Bedtime',
  'morning':     'Morning',
  'away':        'Away',
  'party':       'Party',
};

const _sceneIcons = {
  'movie_night': Icons.movie,
  'bedtime':     Icons.bedtime,
  'morning':     Icons.wb_sunny,
  'away':        Icons.directions_walk,
  'party':       Icons.celebration,
};

class _HomeStatusScreen extends StatelessWidget {
  final HomeState state;
  const _HomeStatusScreen(this.state);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (state.activeScene != null) ...[
            _sceneBanner(state.activeScene!),
            const SizedBox(height: 20),
          ],
          _sectionHeader('LIGHTS'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.0,
            children: _roomLabels.entries.map((e) => _lightTile(e.key, e.value)).toList(),
          ),
          const SizedBox(height: 24),
          _sectionHeader('THERMOSTAT'),
          const SizedBox(height: 10),
          _thermostatCard(),
          const SizedBox(height: 24),
          _sectionHeader('DOORS'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: _doorLabels.entries.map((e) => _doorTile(e.key, e.value)).toList(),
          ),
          const SizedBox(height: 24),
          _sectionHeader('SCENES'),
          const SizedBox(height: 10),
          _scenesRow(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(
            color: _textSec,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4),
      );

  Widget _sceneBanner(String scene) {
    final icon = _sceneIcons[scene] ?? Icons.auto_awesome;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _logo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _logo.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _logo, size: 16),
          const SizedBox(width: 8),
          const Text('Scene active: ', style: TextStyle(color: _textSec, fontSize: 13)),
          Text(_sceneLabels[scene] ?? scene,
              style: const TextStyle(
                  color: _logo, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _lightTile(String room, String label) {
    final on = state.lights[room] ?? false;
    return Container(
      decoration: BoxDecoration(
        color: on ? _logo.withValues(alpha: 0.1) : _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: on ? _logo.withValues(alpha: 0.45) : _white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            on ? Icons.lightbulb : Icons.lightbulb_outline,
            color: on ? _logo : _textSec,
            size: 22,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
                color: on ? _white : _textSec,
                fontSize: 10,
                fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                height: 1.3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _thermostatCard() {
    final modeColor = switch (state.thermostatMode) {
      'heat' => const Color(0xFFFF8A65),
      'cool' => _logo,
      _      => _white,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.thermostat, color: modeColor, size: 28),
          const SizedBox(width: 12),
          Text(
            '${state.temperature}°F',
            style: const TextStyle(
                color: _white, fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: modeColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              state.thermostatMode,
              style: TextStyle(
                  color: modeColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doorTile(String door, String label) {
    final locked = state.doors[door] ?? true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: locked
              ? _white.withValues(alpha: 0.08)
              : _errorTxt.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(locked ? Icons.lock : Icons.lock_open,
              color: locked ? _textSec : _errorTxt, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _white, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(locked ? 'locked' : 'unlocked',
                  style: TextStyle(
                      color: locked ? _textSec : _errorTxt, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scenesRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sceneLabels.entries.map((e) {
        final active = state.activeScene == e.key;
        final icon = _sceneIcons[e.key] ?? Icons.auto_awesome;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? _logo.withValues(alpha: 0.1) : _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? _logo.withValues(alpha: 0.45)
                  : _white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? _logo : _textSec),
              const SizedBox(width: 6),
              Text(e.value,
                  style: TextStyle(
                      color: active ? _logo : _textSec,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// App shell
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _homeState    = HomeState();
  late final _orchestrator = SmartHomeOrchestrator(homeState: _homeState);
  final _runner       = ModelRunner();
  final _messages     = <_Msg>[];
  final _inputCtrl    = TextEditingController();
  final _scrollCtrl   = ScrollController();

  bool _loading  = true;
  bool _ready    = false;
  bool _thinking = false;
  String? _error;
  int _tabIndex  = 0;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<String> _modelPath() async {
    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/smart-home-model';
    }
    return '/sdcard/smart-home-model';
  }

  Future<void> _loadModel() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
    try {
      final path = await _modelPath();
      await _runner.load(path);
      if (!mounted) return;
      setState(() { _ready = true; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _thinking) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add((text: text, isUser: true, isError: false, call: null, ttft: 0, tps: 0));
      _thinking = true;
    });
    _scrollToBottom();
    _orchestrator.addUserMessage(text);

    try {
      final result = await _runner.infer(_orchestrator.messagesForModel, kTools);
      if (result['ok'] != true) throw Exception(result['error']);
      final calls = result['functionCalls'] as List?;
      final candidate = (calls != null && calls.isNotEmpty)
          ? (calls.first as Map).cast<String, dynamic>()
          : null;
      final ttft = (result['ttft'] as num?)?.toDouble() ?? 0;
      final tps = (result['tps'] as num?)?.toDouble() ?? 0;

      String response;
      Map<String, dynamic>? call;
      if (candidate == null) {
        _orchestrator.recordAssistantMessage('');
        response = _orchestrator.handleNoFunctionCall();
      } else {
        _orchestrator.recordAssistantCall(candidate);
        response = _orchestrator.handleFunctionCall(candidate);
        call = candidate;
      }

      if (!mounted) return;
      setState(() {
        _messages.add((text: response, isUser: false, isError: false, call: call, ttft: ttft, tps: tps));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add((text: 'Error: $e', isUser: false, isError: true, call: null, ttft: 0, tps: 0));
      });
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
    _scrollToBottom();
  }

  void _reset() => setState(() {
        _messages.clear();
        _orchestrator.reset();
        _homeState.reset();
      });

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _runner.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _homeState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _white.withValues(alpha: 0.08)),
        ),
        title: Row(children: [
          Icon(_tabIndex == 0 ? Icons.chat_bubble_outline : Icons.home,
              color: _logo, size: 20),
          const SizedBox(width: 8),
          Text(_tabIndex == 0 ? 'Smart Home' : 'Home Status',
              style: const TextStyle(color: _white, fontWeight: FontWeight.w600)),
          if (_ready && _tabIndex == 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _white.withValues(alpha: 0.6)),
              ),
              child: const Text('On-device',
                  style: TextStyle(
                      fontSize: 11, color: _white, fontWeight: FontWeight.w500)),
            ),
          ],
        ]),
        actions: [
          if (_ready)
            IconButton(
              icon: const Icon(Icons.refresh, color: _textSec),
              onPressed: _reset,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _loading
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: _white),
                    SizedBox(height: 16),
                    Text('Loading model…', style: TextStyle(color: _textSec)),
                  ],
                ))
              : _error != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!,
                          style: const TextStyle(color: _errorTxt)),
                    ))
                  : _chat(),
          _HomeStatusScreen(_homeState),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _bg,
        indicatorColor: _logo.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, color: _textSec),
            selectedIcon: Icon(Icons.chat_bubble, color: _logo),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: _textSec),
            selectedIcon: Icon(Icons.home, color: _logo),
            label: 'Home',
          ),
        ],
      ),
    );
  }

  Widget _chat() {
    return Column(children: [
      Expanded(
        child: _messages.isEmpty
            ? _empty()
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _bubble(_messages[i]),
              ),
      ),
      if (_thinking)
        LinearProgressIndicator(
          backgroundColor: _surface,
          valueColor: const AlwaysStoppedAnimation<Color>(_white),
        ),
      _input(),
    ]);
  }

  Widget _empty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.chat_bubble_outline, size: 48, color: _white.withValues(alpha: 0.15)),
        const SizedBox(height: 12),
        const Text('Try a command:', style: TextStyle(color: _textSec, fontSize: 13)),
        const SizedBox(height: 8),
        for (final hint in [
          '"Turn on the bedroom lights"',
          '"Set thermostat to 72°F"',
          '"Lock the front door"',
          '"Activate movie night scene"',
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(hint,
                style: const TextStyle(
                    color: _logo, fontStyle: FontStyle.italic, fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _bubble(_Msg msg) {
    final maxW = BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78);

    if (msg.isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: maxW,
          decoration: BoxDecoration(
            color: _errorBg,
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(16),
              topRight:    Radius.circular(16),
              bottomLeft:  Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: _errorTxt.withValues(alpha: 0.4)),
          ),
          child: Text(msg.text, style: const TextStyle(color: _errorTxt, fontSize: 15)),
        ),
      );
    }

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: maxW,
          decoration: const BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.only(
              topLeft:     Radius.circular(20),
              topRight:    Radius.circular(20),
              bottomLeft:  Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(msg.text, style: const TextStyle(color: _bg, fontSize: 15)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: maxW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.call != null) _FnCallChip(msg.call!),
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(20),
                  topRight:    Radius.circular(20),
                  bottomLeft:  Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: _white.withValues(alpha: 0.15)),
              ),
              child: Text(msg.text,
                  style: const TextStyle(color: _white, fontSize: 15)),
            ),
            if (msg.tps > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'TTFT ${msg.ttft.toStringAsFixed(0)}ms  ·  ${msg.tps.toStringAsFixed(1)} tok/s',
                  style: const TextStyle(color: _textSec, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _input() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              enabled: !_thinking,
              style: const TextStyle(color: _white),
              decoration: InputDecoration(
                hintText: 'Say a command…',
                hintStyle: TextStyle(color: _white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: _surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: _white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: _white.withValues(alpha: 0.6)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: _white.withValues(alpha: 0.08)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _thinking ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: _white,
              disabledBackgroundColor: _white.withValues(alpha: 0.15),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: Icon(Icons.send, color: _thinking ? _textSec : _bg),
          ),
        ]),
      ),
    );
  }
}
