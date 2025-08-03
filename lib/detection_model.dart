// novo arquivo: lib/detection_models.dart

class DetectionResult {
  final int? id; // id da própria detecção
  final String historyId; // Chave estrangeira
  final String className;
  final double confidence;
  final double x1_norm;
  final double y1_norm;
  final double x2_norm;
  final double y2_norm;

  DetectionResult({
    this.id,
    required this.historyId,
    required this.className,
    required this.confidence,
    required this.x1_norm,
    required this.y1_norm,
    required this.x2_norm,
    required this.y2_norm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'historyId': historyId,
      'className': className,
      'confidence': confidence,
      'x1_norm': x1_norm,
      'y1_norm': y1_norm,
      'x2_norm': x2_norm,
      'y2_norm': y2_norm,
    };
  }
}

class DetectionHistory {
  final String id;
  final String imagePath;
  final DateTime detectionDate;
  final double imageWidth;
  final double imageHeight;
  List<DetectionResult> results; // Lista para carregar os resultados depois

  DetectionHistory({
    required this.id,
    required this.imagePath,
    required this.detectionDate,
    required this.imageWidth,
    required this.imageHeight,
    this.results = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'detectionDate': detectionDate.toIso8601String(), // Salva data como texto
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    };
  }

  factory DetectionHistory.fromMap(Map<String, dynamic> map) {
    return DetectionHistory(
      id: map['id'],
      imagePath: map['imagePath'],
      detectionDate: DateTime.parse(map['detectionDate']),
      imageWidth: map['imageWidth'],
      imageHeight: map['imageHeight'],
    );
  }
}
