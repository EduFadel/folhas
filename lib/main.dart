import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui' as ui;

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

      setState(() {
        results = filteredBoxes;
        isLoading = false;
      });
    }
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
          Image.file(
            selectedImage!,
            fit: BoxFit.cover, 
          ),
          
          LayoutBuilder(builder: (context, constraints) {
            double renderedWidth = constraints.maxWidth;
            double renderedHeight = constraints.maxHeight;

            return Stack(
              children: results.map((detection) {
                final String className = detection['class'] ?? 'Unknown';
                final Color boxColor = _getColorForClass(className);
                
                final double left = detection['x1_norm'] * renderedWidth;
                final double top = detection['y1_norm'] * renderedHeight;
                final double width = (detection['x2_norm'] - detection['x1_norm']) * renderedWidth;
                final double height = (detection['y2_norm'] - detection['y1_norm']) * renderedHeight;

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
          }),
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
      ),
      // MUDANÇA 1: Envolvemos o corpo da tela com SingleChildScrollView
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildImageWithBoxes(), 
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: yolo != null ? () => _pickAndDetect(ImageSource.gallery) : null,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeria'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: yolo != null ? () => _pickAndDetect(ImageSource.camera) : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Câmera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (results.isNotEmpty)
                Text('Resultados da Detecção', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),

              if (selectedImage != null && !isLoading && results.isEmpty)
                Text('Nenhuma folha detectada com mais de 70% de confiança.', style: Theme.of(context).textTheme.bodyMedium),

              // MUDANÇA 2: Removemos o widget `Expanded`
              ListView.builder(
                // MUDANÇA 3: Adicionamos estas duas propriedades
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
                      leading: Container(width: 24, height: 24, decoration: BoxDecoration(color: legendColor, shape: BoxShape.circle)),
                      title: Text(className, style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: LinearProgressIndicator(
                          value: confidence,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(legendColor),
                        ),
                      ),
                      trailing: Text('${(confidence * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodyLarge),
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
        Icon(Icons.image_search, size: 80, color: Theme.of(context).colorScheme.primary),
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