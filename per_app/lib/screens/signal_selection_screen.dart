import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import 'chart_screen.dart';
import 'virtual_signal_screen.dart';
import 'xy_screen.dart';
import 'resample_screen.dart';

class SignalSelectionScreen extends StatefulWidget {
  final PerFile perFile;
  const SignalSelectionScreen({super.key, required this.perFile});

  @override
  State<SignalSelectionScreen> createState() => _SignalSelectionScreenState();
}

class _SignalSelectionScreenState extends State<SignalSelectionScreen> {
  String _search = '';
  final Set<String> _selected = {};
  bool _sameChart = true;
  final List<PerSignal> _virtualSignals = [];

  List<PerSignal> get _allSignals =>
      [...widget.perFile.signals, ..._virtualSignals];

  Future<void> _openVirtualSignalCreator() async {
    final result = await Navigator.push<PerSignal>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VirtualSignalScreen(availableSignals: _allSignals),
      ),
    );
    if (result != null) {
      setState(() => _virtualSignals.add(result));
    }
  }

  Future<void> _openResample() async {
    final result = await Navigator.push<PerSignal>(
      context,
      MaterialPageRoute(
        builder: (context) => ResampleScreen(availableSignals: _allSignals),
      ),
    );
    if (result != null) {
      setState(() => _virtualSignals.add(result));
    }
  }

  void _openXYMode() {
    if (_selected.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Sélectionnez exactement 2 signaux pour le mode XY.")),
      );
      return;
    }
    final chosen =
        _allSignals.where((s) => _selected.contains(s.name)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            XYScreen(xSignal: chosen[0], ySignal: chosen[1]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allSignals
        .where((s) => s.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Signaux (${_allSignals.length})"),
        actions: [
          IconButton(
            onPressed: _openVirtualSignalCreator,
            icon: const Icon(Icons.functions),
            tooltip: "Créer un signal virtuel",
          ),
          IconButton(
            onPressed: _openResample,
            icon: const Icon(Icons.timeline),
            tooltip: "Resampling (interpolation)",
          ),
          IconButton(
            onPressed: _openXYMode,
            icon: const Icon(Icons.scatter_plot),
            tooltip: "Mode XY (nécessite 2 signaux sélectionnés)",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Rechercher un signal",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Text("${_selected.length} sélectionné(s)"),
                const Spacer(),
                const Text("Même graphique"),
                Switch(
                  value: _sameChart,
                  onChanged: (v) => setState(() => _sameChart = v),
                ),
                const Text("Séparés"),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final sig = filtered[index];
                final isSelected = _selected.contains(sig.name);
                final isVirtual = _virtualSignals.contains(sig);
                return CheckboxListTile(
                  title: Row(
                    children: [
                      if (isVirtual)
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.functions,
                              size: 14, color: Colors.deepPurple),
                        ),
                      Expanded(
                        child: Text(sig.name,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  value: isSelected,
                  dense: true,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selected.add(sig.name);
                      } else {
                        _selected.remove(sig.name);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selected.isEmpty
            ? null
            : () {
                final chosen = _allSignals
                    .where((s) => _selected.contains(s.name))
                    .toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChartScreen(
                      signals: chosen,
                      periodSeconds: widget.perFile.periodSeconds,
                      sameChart: _sameChart,
                    ),
                  ),
                );
              },
        label: const Text("Afficher"),
        icon: const Icon(Icons.show_chart),
      ),
    );
  }
}