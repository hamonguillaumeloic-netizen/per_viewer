import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import '../widgets/signal_chart_card.dart';

class ChartScreen extends StatelessWidget {
  final List<PerSignal> signals;
  final double periodSeconds;
  final bool sameChart;

  const ChartScreen({
    super.key,
    required this.signals,
    required this.periodSeconds,
    required this.sameChart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Graphique(s)"),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.playlist_add_check),
            tooltip: "Modifier les signaux affichés",
          ),
        ],
      ),
      body: sameChart
          ? SignalChartCard(
              signals: signals,
              periodSeconds: periodSeconds,
              title: "Signaux combinés",
            )
          : ListView.builder(
              itemCount: signals.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: SignalChartCard(
                    signals: [signals[index]],
                    periodSeconds: periodSeconds,
                    title: signals[index].name,
                  ),
                );
              },
            ),
    );
  }
}