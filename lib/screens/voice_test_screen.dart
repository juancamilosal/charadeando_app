import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/letter_words.dart';
import '../services/spanish_dictionary.dart';
import '../services/voice_listener.dart';
import '../services/voice_tools.dart';

/// Palabras de la prueba guiada: fáciles, con ñ, con tildes y compuestas.
const voiceTestWords = [
  // Fáciles.
  'perro', 'casa', 'mesa', 'gato', 'sol', 'luna', 'libro', 'agua', 'fuego',
  'pelota',
  // Con ñ.
  'niño', 'año', 'piña', 'montaña', 'señal', 'uña', 'ñandú', 'muñeca',
  // Con tildes.
  'canción', 'avión', 'café', 'lápiz', 'música', 'teléfono', 'corazón',
  'pájaro',
  // Compuestas.
  'sacapuntas', 'paraguas', 'abrelatas', 'cumpleaños', 'rascacielos',
  'salvavidas',
];

/// Cómo se graba el video mientras escucha (para ver si se puede).
enum TestVideo {
  off('Sin video'),
  withSound('Video con sonido'),
  muted('Video sin sonido');

  const TestVideo(this.label);
  final String label;
}

/// Una palabra en la lista en vivo.
class _Row {
  _Row(this.word, this.verdict);
  final HeardWord word;
  final WordVerdict verdict;
}

/// Resultado de una palabra de la prueba guiada.
class _GuidedResult {
  _GuidedResult(this.target, this.heard, this.ok, this.latency);
  final String target;
  final String heard;
  final bool ok;
  final Duration? latency;
}

/// Pantalla escondida para probar el reconocimiento de voz del juego
/// "Letras" (fase 1): se abre con 5 toques en la versión, en Ajustes, o
/// desde el enlace de depuración.
class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({super.key});

  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> {
  final _listener = VoiceListener();
  final _random = Random();
  StreamSubscription<HeardWord>? _sub;

  SpanishDictionary? _dictionary;
  Duration? _dictionaryLoad;
  String? _dictionaryError;
  VoiceDiagnosis? _diagnosis;

  bool _guided = false;
  bool _muteBeep = false;
  TestVideo _video = TestVideo.off;
  CameraController? _camera;
  String? _videoPath;
  String? _videoError;

  // Modo libre.
  String _letter = 'P';
  late WordChecker _checker = _newChecker();
  final _rows = <_Row>[];

  // Prueba guiada.
  int _target = 0;
  final _heardForTarget = <HeardWord>[];
  final _results = <_GuidedResult>[];

  final _manual = TextEditingController();
  WordVerdict? _manualVerdict;

  @override
  void initState() {
    super.initState();
    _listener.addListener(_refresh);
    _sub = _listener.words.listen(_onWord);
    _loadDictionary();
    _listener.init().then((_) => _diagnose());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDictionary() async {
    final watch = Stopwatch()..start();
    final SpanishDictionary dictionary;
    try {
      dictionary = await SpanishDictionary.load();
    } catch (e) {
      if (mounted) setState(() => _dictionaryError = '$e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _dictionary = dictionary;
      _dictionaryLoad = watch.elapsed;
      _checker = _newChecker();
    });
  }

  Future<void> _diagnose() async {
    final d = await VoiceTools.diagnose(_listener.localeId ?? 'es-CO');
    if (mounted) setState(() => _diagnosis = d);
  }

  WordChecker _newChecker() => WordChecker(
    _letter,
    inDictionary: (w) => _dictionary?.contains(w) ?? true,
  );

  void _newLetter() => setState(() {
    _letter =
        LetterWords.alphabet[_random.nextInt(LetterWords.alphabet.length)];
    _checker = _newChecker();
    _rows.clear();
  });

  void _onWord(HeardWord word) {
    if (!mounted) return;
    setState(() {
      if (_guided) {
        _guidedWord(word);
      } else {
        _rows.insert(0, _Row(word, _checker.check(word.text)));
      }
    });
  }

  /// Prueba guiada: vale si dijo la palabra (o la dijo separada en dos:
  /// "abre latas"). Con 3 palabras que no son, pasa a la siguiente.
  void _guidedWord(HeardWord word) {
    if (_target >= voiceTestWords.length) return;
    _heardForTarget.add(word);
    final target = LetterWords.repeatKey(voiceTestWords[_target]);
    final keys = [
      for (final w in _heardForTarget) LetterWords.repeatKey(w.text),
    ];
    final ok =
        keys.contains(target) || LetterWords.repeatKey(keys.join()) == target;
    if (ok || _heardForTarget.length >= 3) {
      _finishTarget(ok);
    }
  }

  void _finishTarget(bool ok) {
    _results.add(
      _GuidedResult(
        voiceTestWords[_target],
        _heardForTarget.map((w) => w.text).join(' '),
        ok,
        _heardForTarget.isEmpty ? null : _heardForTarget.first.latency,
      ),
    );
    _heardForTarget.clear();
    _target++;
  }

  Future<void> _toggle() async {
    if (_listener.active) {
      await _listener.stop();
      await VoiceTools.muteBeep(false);
      await _stopVideo();
    } else {
      if (_muteBeep) await VoiceTools.muteBeep(true);
      await _startVideo();
      await _listener.start();
    }
    _refresh();
  }

  Future<void> _startVideo() async {
    _videoPath = null;
    _videoError = null;
    if (_video == TestVideo.off) return;
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: _video == TestVideo.withSound,
      );
      _camera = camera;
      await camera.initialize();
      await camera.startVideoRecording();
    } catch (e) {
      _videoError = '$e';
    }
    _refresh();
  }

  Future<void> _stopVideo() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      if (camera.value.isRecordingVideo) {
        final file = await camera.stopVideoRecording();
        _videoPath = file.path;
      }
    } catch (e) {
      _videoError = '$e';
    }
    _camera = null;
    await camera.dispose();
    _refresh();
  }

  void _restartGuided() => setState(() {
    _target = 0;
    _heardForTarget.clear();
    _results.clear();
  });

  String get _report {
    final d = _diagnosis;
    final ok = _results.where((r) => r.ok).length;
    final times = [
      for (final r in _results)
        if (r.latency != null) r.latency!.inMilliseconds,
    ];
    final avg = times.isEmpty
        ? '-'
        : '${times.reduce((a, b) => a + b) ~/ times.length} ms';
    final buffer = StringBuffer()
      ..writeln('Prueba de voz de Charadeando')
      ..writeln(
        'Android ${d?.sdk ?? '?'} · idioma ${_listener.localeId} · '
        '${_listener.onDevice ? 'en el celular' : 'por internet'}'
        '${_listener.fellBackToNetwork ? ' (pasó a internet: ${_listener.fallbackReason})' : ''}',
      )
      ..writeln(
        'Español descargado: ${d?.spanishInstalled ?? 'no se sabe'} · '
        'bip silenciado: $_muteBeep · ${_video.label}',
      )
      ..writeln(
        'Aciertos: $ok de ${_results.length} · tiempo promedio: $avg · '
        'reinicios: ${_listener.restarts}',
      )
      ..writeln()
      ..writeln('| Palabra | Entendió | | Tiempo |')
      ..writeln('|---|---|---|---|');
    for (final r in _results) {
      buffer.writeln(
        '| ${r.target} | ${r.heard.isEmpty ? '(nada)' : r.heard} | '
        '${r.ok ? '✓' : '✗'} | '
        '${r.latency == null ? '-' : '${r.latency!.inMilliseconds} ms'} |',
      );
    }
    if (_listener.errors.isNotEmpty) {
      buffer.writeln('\nErrores: ${_listener.errors.join(', ')}');
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _listener.dispose();
    _camera?.dispose();
    _manual.dispose();
    VoiceTools.muteBeep(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = _listener.active;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prueba de voz'),
          bottom: TabBar(
            onTap: (i) => setState(() => _guided = i == 1),
            tabs: const [
              Tab(text: 'Libre'),
              Tab(text: '30 palabras'),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _settings(),
            const SizedBox(height: 12),
            _statusCard(),
            const SizedBox(height: 12),
            if (_guided) ..._guidedView() else ..._freeView(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _toggle,
          backgroundColor: listening ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          icon: Icon(listening ? Icons.stop : Icons.mic),
          label: Text(listening ? 'Parar' : 'Escuchar'),
        ),
      ),
    );
  }

  Widget _settings() {
    final d = _diagnosis;
    final enabled = !_listener.active;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Android ${d?.sdk ?? '?'} · reconocimiento: '
              '${d?.available ?? '?'} · sin internet posible: '
              '${d?.onDevice ?? '?'}',
            ),
            Text(
              'Español descargado: ${switch (d?.spanishInstalled) {
                true => 'sí',
                false => 'no',
                null => 'no se sabe (Android < 13)',
              }} · descargados: ${d?.installed?.join(', ') ?? '-'}'
              '${(d?.pending?.isNotEmpty ?? false) ? ' · bajando: ${d!.pending!.join(', ')}' : ''}',
            ),
            Text(
              'Diccionario: ${_dictionaryError != null
                  ? 'no cargó: $_dictionaryError'
                  : _dictionary == null
                  ? 'cargando…'
                  : '${_dictionary!.length} palabras en ${_dictionaryLoad!.inMilliseconds} ms'}',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    final ok = await VoiceTools.downloadLanguage(
                      _listener.localeId ?? 'es-CO',
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Se pidió descargar el español.'
                              : 'Este celular no deja pedir la descarga.',
                        ),
                      ),
                    );
                    await _diagnose();
                  },
                  child: const Text('Descargar español'),
                ),
                TextButton(
                  onPressed: _diagnose,
                  child: const Text('Revisar otra vez'),
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo en el celular (sin enviar audio)'),
              value: _listener.onDevice,
              onChanged: enabled
                  ? (v) => setState(() {
                      _listener.onDevice = v;
                      _listener.fellBackToNetwork = false;
                    })
                  : null,
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Silenciar el bip'),
              subtitle: const Text('Sonidos del sistema y notificaciones'),
              value: _muteBeep,
              onChanged: enabled ? (v) => setState(() => _muteBeep = v) : null,
            ),
            SegmentedButton<TestVideo>(
              segments: [
                for (final v in TestVideo.values)
                  ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {_video},
              onSelectionChanged: enabled
                  ? (s) => setState(() => _video = s.first)
                  : null,
            ),
            if (_camera?.value.isInitialized ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(height: 120, child: CameraPreview(_camera!)),
              ),
            if (_videoError != null) Text('Video: $_videoError'),
            if (_videoPath != null)
              TextButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Ver el video (¿tiene sonido?)'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _VideoDialog(path: _videoPath!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final l = _listener;
    final gaps = l.gaps;
    final avgGap = gaps.isEmpty
        ? '-'
        : '${gaps.map((g) => g.inMilliseconds).reduce((a, b) => a + b) ~/ gaps.length} ms';
    return Card(
      color: l.active ? Colors.green.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado: ${l.status} · idioma: ${l.localeId ?? '?'} · '
              '${l.onDevice ? 'en el celular' : 'por internet'}'
              '${l.fellBackToNetwork ? ' (pasó a internet: ${l.fallbackReason})' : ''}',
            ),
            Text(
              'Se volvió a encender ${l.restarts} veces · tiempo sin '
              'escuchar en cada corte: $avgGap',
            ),
            Text('Volumen del micrófono: ${l.level.toStringAsFixed(1)} dB'),
            LinearProgressIndicator(value: ((l.level + 2) / 12).clamp(0, 1)),
            const SizedBox(height: 6),
            Text(
              l.partial.isEmpty ? '…' : l.partial,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            if (l.errors.isNotEmpty)
              Text(
                'Errores: ${l.errors.reversed.take(5).join(', ')}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _freeView() => [
    Row(
      children: [
        Text(
          _letter,
          style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_checker.validCount} válidas',
                style: const TextStyle(fontSize: 24),
              ),
              TextButton(
                onPressed: _newLetter,
                child: const Text('Otra letra'),
              ),
            ],
          ),
        ),
      ],
    ),
    TextField(
      controller: _manual,
      decoration: const InputDecoration(
        labelText: 'Probar una palabra escrita',
      ),
      onSubmitted: (w) => setState(
        () => _manualVerdict = WordChecker(
          _letter,
          inDictionary: (x) => _dictionary?.contains(x) ?? true,
        ).check(w),
      ),
    ),
    if (_manualVerdict != null) Text(_manualVerdict!.label),
    const SizedBox(height: 8),
    for (final r in _rows)
      ListTile(
        dense: true,
        title: Text(r.word.text, style: const TextStyle(fontSize: 18)),
        subtitle: Text(r.verdict.label),
        trailing: Text(
          r.word.latency == null ? '-' : '${r.word.latency!.inMilliseconds} ms',
        ),
      ),
  ];

  List<Widget> _guidedView() {
    final done = _target >= voiceTestWords.length;
    return [
      if (!done) ...[
        Text(
          'Di: ${voiceTestWords[_target]}',
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
        ),
        Text('${_target + 1} de ${voiceTestWords.length}'),
        Text('Entendió: ${_heardForTarget.map((w) => w.text).join(' ')}'),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _finishTarget(false)),
              child: const Text('No la entiende: siguiente'),
            ),
            TextButton(
              onPressed: () => setState(_heardForTarget.clear),
              child: const Text('Repetir'),
            ),
          ],
        ),
      ] else
        const Text('¡Listo!', style: TextStyle(fontSize: 32)),
      Row(
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar resultados'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _report));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resultados copiados.')),
              );
            },
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: _restartGuided, child: const Text('Empezar')),
        ],
      ),
      for (final r in _results.reversed)
        ListTile(
          dense: true,
          leading: Text(r.ok ? '✓' : '✗', style: const TextStyle(fontSize: 20)),
          title: Text(r.target),
          subtitle: Text(r.heard.isEmpty ? '(nada)' : r.heard),
          trailing: Text(
            r.latency == null ? '-' : '${r.latency!.inMilliseconds} ms',
          ),
        ),
    ];
  }
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.path});
  final String path;

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final _controller = VideoPlayerController.file(File(widget.path));

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
