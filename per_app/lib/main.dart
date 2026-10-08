import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'per_parser/per_file_parser.dart';
import 'screens/signal_selection_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PER Viewer',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _channel = MethodChannel('per_viewer/open_file');

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupChannel();
    _checkInitialFile();
  }

  void _setupChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileOpened') {
        final filePath = call.arguments as String?;
        if (filePath != null) {
          _parseAndNavigate(filePath);
        }
      }
    });
  }

  Future<void> _checkInitialFile() async {
    try {
      final filePath =
          await _channel.invokeMethod<String>('getInitialFile');
      if (filePath != null) {
        _parseAndNavigate(filePath);
      }
    } catch (_) {
      // Pas de fichier initial, comportement normal.
    }
  }

  Future<void> _parseAndNavigate(String filePath) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final perFile = await PerFileParser.parseFile(filePath);
      setState(() => _loading = false);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignalSelectionScreen(perFile: perFile),
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickAndParse() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.single.path == null) {
        setState(() => _loading = false);
        return;
      }

      final filePath = result.files.single.path!;
      await _parseAndNavigate(filePath);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PER Viewer")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _pickAndParse,
                icon: const Icon(Icons.folder_open),
                label: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Choisir un fichier .per"),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  "Erreur : $_error",
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}