import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import '../utils/resample_utils.dart';

class ResampleScreen extends StatefulWidget {
  final List<PerSignal> availableSignals;
  const ResampleScreen({super.key, required this.availableSignals});

  @override
  State<ResampleScreen> createState() => _ResampleScreenState();
}

class _ResampleScreenState extends State<ResampleScreen> {
  PerSignal? _signal;
  String _method = 'linear';
  int _factor = 2;
  final TextEditingController _nameController = TextEditingController();

  void _create() {
    if (_signal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir un signal.")),
      );
      return;
    }

    final newValues = _method == 'linear'
        ? ResampleUtils.linearResample(_signal!.values, _factor)
        : ResampleUtils.polynomialResample(_signal!.values, _factor);

    final name = _nameController.text.trim().isEmpty
        ? "${_signal!.name}_resample_x$_factor"
        : _nameController.text.trim();

    Navigator.pop(context, PerSignal(name, newValues));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resampling (interpolation)")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<PerSignal>(
              decoration: const InputDecoration(labelText: "Signal source"),
              items: widget.availableSignals
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _signal = v),
              value: _signal,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'linear', label: Text("Linéaire")),
                ButtonSegment(
                    value: 'polynomial', label: Text("Polynomiale")),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 16),
            Text("Facteur de multiplication des points : $_factor"),
            Slider(
              value: _factor.toDouble(),
              min: 2,
              max: 10,
              divisions: 8,
              label: "$_factor",
              onChanged: (v) => setState(() => _factor = v.round()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Nom du signal resamplé (optionnel)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _create,
              child: const Text("Créer le signal resamplé"),
            ),
          ],
        ),
      ),
    );
  }
}