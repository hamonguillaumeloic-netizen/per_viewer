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
  PerSignal? _signalA;
  PerSignal? _signalB;
  String _binaryOp = '+';
  String _unaryOp = 'sin';
  final TextEditingController _nameController = TextEditingController();

  final List<String> _binaryOps = ['+', '-', '*', '/'];
  final List<String> _unaryOps = ['sin', 'cos', 'tan'];

  void _create() {
    if (_signalA == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir le signal A.")),
      );
      return;
    }
    if (_isBinary && _signalB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir le signal B.")),
      );
      return;
    }

    final name = _nameController.text.trim().isEmpty
        ? _generateDefaultName()
        : _nameController.text.trim();

    final n = _isBinary
        ? (_signalA!.values.length < _signalB!.values.length
            ? _signalA!.values.length
            : _signalB!.values.length)
        : _signalA!.values.length;

    final values = List<double>.filled(n, 0.0);

    if (_isBinary) {
      for (int i = 0; i < n; i++) {
        final a = _signalA!.values[i];
        final b = _signalB!.values[i];
        switch (_binaryOp) {
          case '+':
            values[i] = a + b;
            break;
          case '-':
            values[i] = a - b;
            break;
          case '*':
            values[i] = a * b;
            break;
          case '/':
            values[i] = b == 0 ? 0 : a / b;
            break;
        }
      }
    } else {
      for (int i = 0; i < n; i++) {
        final a = _signalA!.values[i];
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

    Navigator.pop(context, PerSignal(name, values));
  }

  String _generateDefaultName() {
    if (_isBinary) {
      return "${_signalA!.name}_${_binaryOp}_${_signalB!.name}";
    } else {
      return "${_unaryOp}_${_signalA!.name}";
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
                ButtonSegment(value: true, label: Text("Binaire (A op B)")),
                ButtonSegment(value: false, label: Text("Unaire (op(A))")),
              ],
              selected: {_isBinary},
              onSelectionChanged: (s) => setState(() => _isBinary = s.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PerSignal>(
              decoration: const InputDecoration(labelText: "Signal A"),
              items: widget.availableSignals
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _signalA = v),
              value: _signalA,
            ),
            const SizedBox(height: 16),
            if (_isBinary) ...[
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Opérateur"),
                items: _binaryOps
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _binaryOp = v!),
                value: _binaryOp,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PerSignal>(
                decoration: const InputDecoration(labelText: "Signal B"),
                items: widget.availableSignals
                    .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setState(() => _signalB = v),
                value: _signalB,
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Fonction"),
                items: _unaryOps
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _unaryOp = v!),
                value: _unaryOp,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Nom du signal virtuel (optionnel)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
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