import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../per_parser/per_file_parser.dart';

class VirtualSignalScreen extends StatefulWidget {
  final List<PerSignal> availableSignals;

  const VirtualSignalScreen({super.key, required this.availableSignals});

  @override
  State<VirtualSignalScreen> createState() => _VirtualSignalScreenState();
}

class _VirtualSignalScreenState extends State<VirtualSignalScreen> {
  bool _isBinary = true;
  final Set<String> _selectedNames = {};
  String _binaryOp = '+';
  String _unaryOp = 'sin';
  final TextEditingController _nameController = TextEditingController();

  final List<String> _binaryOps = ['+', '-', '*', '/'];
  final List<String> _unaryOps = ['sin', 'cos', 'tan'];

  void _create() {
    final chosen = widget.availableSignals
        .where((s) => _selectedNames.contains(s.name))
        .toList();

    if (_isBinary) {
      if (chosen.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Sélectionnez au moins 2 signaux pour une opération binaire.")),
        );
        return;
      }
    } else {
      if (chosen.length != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Sélectionnez exactement 1 signal pour une fonction unaire.")),
        );
        return;
      }
    }

    final n = chosen.map((s) => s.values.length).reduce((a, b) => a < b ? a : b);
    final values = List<double>.filled(n, 0.0);

    if (_isBinary) {
      for (int i = 0; i < n; i++) {
        double acc = chosen[0].values[i];
        for (int s = 1; s < chosen.length; s++) {
          final b = chosen[s].values[i];
          switch (_binaryOp) {
            case '+':
              acc = acc + b;
              break;
            case '-':
              acc = acc - b;
              break;
            case '*':
              acc = acc * b;
              break;
            case '/':
              acc = b == 0 ? 0 : acc / b;
              break;
          }
        }
        values[i] = acc;
      }
    } else {
      for (int i = 0; i < n; i++) {
        final a = chosen[0].values[i];
        switch (_unaryOp) {
          case 'sin':
            values[i] = math.sin(a);
            break;
          case 'cos':
            values[i] = math.cos(a);
            break;
          case 'tan':
            values[i] = math.tan(a);
            break;
        }
      }
    }

    final name = _nameController.text.trim().isEmpty
        ? _generateDefaultName(chosen)
        : _nameController.text.trim();

    Navigator.pop(context, PerSignal(name, values));
  }

  String _generateDefaultName(List<PerSignal> chosen) {
    if (_isBinary) {
      return chosen.map((s) => s.name).join("_${_binaryOp}_");
    } else {
      return "${_unaryOp}_${chosen[0].name}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un signal virtuel")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text("Opération (+ - * /)")),
                ButtonSegment(value: false, label: Text("Fonction (sin/cos/tan)")),
              ],
              selected: {_isBinary},
              onSelectionChanged: (s) => setState(() {
                _isBinary = s.first;
                _selectedNames.clear();
              }),
            ),
            const SizedBox(height: 16),
            if (_isBinary)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Opérateur"),
                items: _binaryOps
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _binaryOp = v!),
                value: _binaryOp,
              )
            else
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Fonction"),
                items: _unaryOps
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _unaryOp = v!),
                value: _unaryOp,
              ),
            const SizedBox(height: 16),
            Text(_isBinary
                ? "Sélectionnez les signaux (au moins 2, l'opération s'applique dans l'ordre choisi) :"
                : "Sélectionnez 1 signal :"),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.availableSignals.length,
                itemBuilder: (context, index) {
                  final sig = widget.availableSignals[index];
                  final isSelected = _selectedNames.contains(sig.name);
                  return CheckboxListTile(
                    title: Text(sig.name, style: const TextStyle(fontSize: 13)),
                    value: isSelected,
                    dense: true,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          if (!_isBinary) _selectedNames.clear();
                          _selectedNames.add(sig.name);
                        } else {
                          _selectedNames.remove(sig.name);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Nom du signal virtuel (optionnel)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _create,
              child: const Text("Créer le signal virtuel"),
            ),
          ],
        ),
      ),
    );
  }
}