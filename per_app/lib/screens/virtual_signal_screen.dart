import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../per_parser/per_file_parser.dart';

class VirtualSignalScreen extends StatefulWidget {
  final List<PerSignal> availableSignals;

  const VirtualSignalScreen({super.key, required this.availableSignals});

  @override
  State<VirtualSignalScreen> createState() => _VirtualSignalScreenState();
}

enum _VirtualMode { signalsOp, signalConstantOp, unaryFunction }

class _VirtualSignalScreenState extends State<VirtualSignalScreen> {
  _VirtualMode _mode = _VirtualMode.signalsOp;
  final Set<String> _selectedNames = {};
  String _binaryOp = '+';
  String _unaryOp = 'sin';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _constantController =
      TextEditingController(text: "1.0");

  final List<String> _binaryOps = ['+', '-', '*', '/'];
  final List<String> _unaryOps = ['sin', 'cos', 'tan'];

  double _applyOp(double a, double b, String op) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        return b == 0 ? 0 : a / b;
      default:
        return a;
    }
  }

  void _create() {
    final chosen = widget.availableSignals
        .where((s) => _selectedNames.contains(s.name))
        .toList();

    List<double> values;
    String name;

    switch (_mode) {
      case _VirtualMode.signalsOp:
        if (chosen.length < 2) {
          _showError(
              "Sélectionnez au moins 2 signaux pour une opération entre signaux.");
          return;
        }
        final n = chosen
            .map((s) => s.values.length)
            .reduce((a, b) => a < b ? a : b);
        values = List<double>.filled(n, 0.0);
        for (int i = 0; i < n; i++) {
          double acc = chosen[0].values[i];
          for (int s = 1; s < chosen.length; s++) {
            acc = _applyOp(acc, chosen[s].values[i], _binaryOp);
          }
          values[i] = acc;
        }
        name = _nameController.text.trim().isEmpty
            ? chosen.map((s) => s.name).join("_${_binaryOp}_")
            : _nameController.text.trim();
        break;

      case _VirtualMode.signalConstantOp:
        if (chosen.length != 1) {
          _showError("Sélectionnez exactement 1 signal.");
          return;
        }
        final constant = double.tryParse(_constantController.text.trim());
        if (constant == null) {
          _showError("La valeur constante doit être un nombre valide.");
          return;
        }
        final sig = chosen[0];
        values = List<double>.filled(sig.values.length, 0.0);
        for (int i = 0; i < sig.values.length; i++) {
          values[i] = _applyOp(sig.values[i], constant, _binaryOp);
        }
        name = _nameController.text.trim().isEmpty
            ? "${sig.name}_${_binaryOp}_${constant.toString()}"
            : _nameController.text.trim();
        break;

      case _VirtualMode.unaryFunction:
        if (chosen.length != 1) {
          _showError("Sélectionnez exactement 1 signal.");
          return;
        }
        final sig = chosen[0];
        values = List<double>.filled(sig.values.length, 0.0);
        for (int i = 0; i < sig.values.length; i++) {
          final a = sig.values[i];
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
        name = _nameController.text.trim().isEmpty
            ? "${_unaryOp}_${sig.name}"
            : _nameController.text.trim();
        break;
    }

    Navigator.pop(context, PerSignal(name, values));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
            SegmentedButton<_VirtualMode>(
              segments: const [
                ButtonSegment(
                    value: _VirtualMode.signalsOp,
                    label: Text("Signal(aux)", style: TextStyle(fontSize: 11))),
                ButtonSegment(
                    value: _VirtualMode.signalConstantOp,
                    label: Text("+ Constante", style: TextStyle(fontSize: 11))),
                ButtonSegment(
                    value: _VirtualMode.unaryFunction,
                    label: Text("sin/cos/tan", style: TextStyle(fontSize: 11))),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _selectedNames.clear();
              }),
            ),
            const SizedBox(height: 16),
            if (_mode == _VirtualMode.signalsOp ||
                _mode == _VirtualMode.signalConstantOp)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Opérateur"),
                items: _binaryOps
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _binaryOp = v!),
                value: _binaryOp,
              ),
            if (_mode == _VirtualMode.unaryFunction)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Fonction"),
                items: _unaryOps
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _unaryOp = v!),
                value: _unaryOp,
              ),
            if (_mode == _VirtualMode.signalConstantOp) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _constantController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: "Valeur constante",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(_mode == _VirtualMode.signalsOp
                ? "Sélectionnez les signaux (au moins 2) :"
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
                          if (_mode != _VirtualMode.signalsOp) {
                            _selectedNames.clear();
                          }
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