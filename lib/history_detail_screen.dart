// novo arquivo: lib/history_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:folhas/detection_model.dart';
import 'dart:io';

class HistoryDetailScreen extends StatelessWidget {
  final DetectionHistory history;

  const HistoryDetailScreen({super.key, required this.history});

  Color _getColorForClass(String className) {
    final colors = Colors.primaries;
    final hash = className.hashCode;
    final index = hash % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da Detecção')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Imagem com Bounding Boxes ---
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: history.imageWidth / history.imageHeight,
                    child: Stack(
                      children: [
                        Image.file(File(history.imagePath), fit: BoxFit.cover),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: history.results.map((detection) {
                                final boxColor = _getColorForClass(
                                  detection.className,
                                );
                                final left =
                                    detection.x1_norm * constraints.maxWidth;
                                final top =
                                    detection.y1_norm * constraints.maxHeight;
                                final width =
                                    (detection.x2_norm - detection.x1_norm) *
                                    constraints.maxWidth;
                                final height =
                                    (detection.y2_norm - detection.y1_norm) *
                                    constraints.maxHeight;
                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: width,
                                  height: height,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: boxColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Lista de Resultados ---
              Text(
                'Resultados da Detecção',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.results.length,
                itemBuilder: (context, index) {
                  final detection = history.results[index];
                  final legendColor = _getColorForClass(detection.className);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: legendColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        detection.className,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: LinearProgressIndicator(
                          value: detection.confidence,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            legendColor,
                          ),
                        ),
                      ),
                      trailing: Text(
                        '${(detection.confidence * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
