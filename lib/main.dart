import 'package:flutter/material.dart';
import 'package:folhas/database_helper.dart';
import 'package:folhas/detection_model.dart';
import 'package:folhas/history_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:uuid/uuid.dart';

void main() {
  runApp(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: YOLODemo(),
    ),
  );
}

class YOLODemo extends StatefulWidget {
  @override
  _YOLODemoState createState() => _YOLODemoState();
}

class _YOLODemoState extends State<YOLODemo> {
  YOLO? yolo;
  File? selectedImage;
  List<dynamic> results = [];
  bool isLoading = false;

  double? _imageWidth;
  double? _imageHeight;

  Color _getColorForClass(String className) {
    final colors = Colors.primaries;
    final hash = className.hashCode;
    final index = hash % colors.length;
    return colors[index];
  }

  @override
  void initState() {
    super.initState();
    loadYOLO();
  }

  Future<void> loadYOLO() async {
    setState(() => isLoading = true);
    yolo = YOLO(modelPath: 'best_float32', task: YOLOTask.segment);
    await yolo!.loadModel();
    setState(() => isLoading = false);
  }

  Future<void> _loadImageDimensions(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    setState(() {
      _imageWidth = frameInfo.image.width.toDouble();
      _imageHeight = frameInfo.image.height.toDouble();
    });
  }

  Future<void> _pickAndDetect(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);

    if (image != null) {
      final imageFile = File(image.path);
      setState(() {
        selectedImage = imageFile;
        results = [];
        isLoading = true;
        _imageWidth = null;
        _imageHeight = null;
      });

      await _loadImageDimensions(imageFile);

      final imageBytes = await imageFile.readAsBytes();
      final detectionResults = await yolo!.predict(imageBytes);

      final allBoxes = detectionResults['boxes'] as List<dynamic>? ?? [];

      final filteredBoxes = allBoxes.where((box) {
        return box['confidence'] >= 0.7;
      }).toList();

      if (filteredBoxes.isNotEmpty) {
        await _saveDetection(imageFile, filteredBoxes);
      }

      setState(() {
        results = filteredBoxes;
        isLoading = false;
      });
    }
  }

  Future<void> _saveDetection(File imageFile,List<dynamic> filteredBoxes) async {
    // 1. Copiar a imagem para um diretório permanente
    final appDir = await getApplicationDocumentsDirectory();
    final newId = Uuid().v4();
    final savedImage = await imageFile.copy('${appDir.path}/$newId.png');

    // 2. Criar o objeto de histórico
    final historyEntry = DetectionHistory(
      id: newId,
      imagePath: savedImage.path,
      detectionDate: DateTime.now(),
      imageWidth: _imageWidth!,
      imageHeight: _imageHeight!,
    );

    // 3. Converter os resultados dinâmicos para nosso modelo tipado
    final detectionResults = filteredBoxes.map((box) {
      return DetectionResult(
        historyId: newId, // Link com o histórico
        className: box['class'],
        confidence: box['confidence'],
        x1_norm: box['x1_norm'],
        y1_norm: box['y1_norm'],
        x2_norm: box['x2_norm'],
        y2_norm: box['y2_norm'],
      );
    }).toList();

    // 4. Salvar no Banco de Dados SQLite
    await DatabaseHelper.instance.insertDetection(
      historyEntry,
      detectionResults,
    );

    print('Detecção salva com ID: ${historyEntry.id}');
  }

  // MUDANÇA: A função de diálogo foi completamente refeita para ficar mais bonita.
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context); // Pega o tema atual
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          // O título agora é uma coluna para incluir o ícone
          title: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.eco, // Ícone de folha
                  size: 30,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text("Sobre o App"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Este aplicativo usa Inteligência Artificial para identificar espécies de folhas em tempo real.",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Text(
                  "Como usar:",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildHelpStep(
                  icon: Icons.photo_library_outlined,
                  text:
                      "Use os botões para escolher uma imagem da galeria ou tirar uma foto com a câmera.",
                ),
                const SizedBox(height: 10),
                _buildHelpStep(
                  icon: Icons.document_scanner_outlined,
                  text:
                      "O app irá analisar a imagem, desenhando caixas coloridas nas folhas detectadas.",
                ),
                const SizedBox(height: 10),
                _buildHelpStep(
                  icon: Icons.check_circle_outline,
                  text:
                      "A lista de resultados mostrará apenas as detecções com 70% ou mais de confiança.",
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Entendi'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // NOVO: Widget auxiliar para criar os passos do tutorial de forma consistente.
  Widget _buildHelpStep({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildImageWithBoxes() {
    if (selectedImage == null || _imageWidth == null || _imageHeight == null) {
      return _buildInitialView();
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _imageWidth! / _imageHeight!,
      child: Stack(
        children: [
          Image.file(selectedImage!, fit: BoxFit.cover),
          LayoutBuilder(
            builder: (context, constraints) {
              double renderedWidth = constraints.maxWidth;
              double renderedHeight = constraints.maxHeight;
              return Stack(
                children: results.map((detection) {
                  final String className = detection['class'] ?? 'Unknown';
                  final Color boxColor = _getColorForClass(className);
                  final double left = detection['x1_norm'] * renderedWidth;
                  final double top = detection['y1_norm'] * renderedHeight;
                  final double width =
                      (detection['x2_norm'] - detection['x1_norm']) *
                      renderedWidth;
                  final double height =
                      (detection['y2_norm'] - detection['y1_norm']) *
                      renderedHeight;
                  return Positioned(
                    left: left,
                    top: top,
                    width: width,
                    height: height,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: boxColor, width: 2),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector de Folhas'),
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
            tooltip: 'Histórico',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Ajuda',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
                  child: _buildImageWithBoxes(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: yolo != null
                        ? () => _pickAndDetect(ImageSource.gallery)
                        : null,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeria'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: yolo != null
                        ? () => _pickAndDetect(ImageSource.camera)
                        : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Câmera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (results.isNotEmpty)
                Text(
                  'Resultados da Detecção (Confiança > 70%)',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              const SizedBox(height: 10),
              if (selectedImage != null && !isLoading && results.isEmpty)
                Text(
                  'Nenhuma folha detectada com mais de 70% de confiança.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final detection = results[index];
                  final String className = detection['class'] ?? 'Unknown';
                  final double confidence = detection['confidence'];
                  final Color legendColor = _getColorForClass(className);
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
                        className,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: LinearProgressIndicator(
                          value: confidence,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            legendColor,
                          ),
                        ),
                      ),
                      trailing: Text(
                        '${(confidence * 100).toStringAsFixed(1)}%',
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

  Widget _buildInitialView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_search,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Selecione uma imagem da galeria ou use a câmera para começar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
