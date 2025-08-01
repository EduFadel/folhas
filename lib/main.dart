import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui' as ui;

void main() => runApp(YOLODemo());

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

  // MUDANÇA 1: Função para obter uma cor consistente para cada classe.
  // Usamos o hashCode do nome da classe para escolher uma cor de uma lista pré-definida.
  // Isso garante que "Manaca" sempre terá a mesma cor, por exemplo.
  Color _getColorForClass(String className) {
    final colors = Colors.primaries; // Lista de cores do Material Design
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

  Future<void> pickAndDetect() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

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
      final boxes = detectionResults['boxes'] as List<dynamic>? ?? [];

      setState(() {
        results = boxes;
        isLoading = false;
      });
    }
  }

  Widget _buildImageWithBoxes() {
    if (selectedImage == null || _imageWidth == null || _imageHeight == null) {
      return Container(height: 300);
    }

    return Container(
      height: 300,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double containerWidth = constraints.maxWidth;
          double containerHeight = constraints.maxHeight;

          double imageRatio = _imageWidth! / _imageHeight!;
          double containerRatio = containerWidth / containerHeight;

          double renderedWidth;
          double renderedHeight;
          double offsetX = 0;
          double offsetY = 0;

          if (imageRatio > containerRatio) {
            renderedWidth = containerWidth;
            renderedHeight = containerWidth / imageRatio;
            offsetY = (containerHeight - renderedHeight) / 2;
          } else {
            renderedHeight = containerHeight;
            renderedWidth = containerHeight * imageRatio;
            offsetX = (containerWidth - renderedWidth) / 2;
          }

          return Stack(
            children: [
              Positioned(
                left: offsetX,
                top: offsetY,
                width: renderedWidth,
                height: renderedHeight,
                child: Image.file(selectedImage!),
              ),

              ...results.map((detection) {
                final String className = detection['class'] ?? 'Unknown';
                // MUDANÇA 2: A cor da caixa agora vem da nossa função
                final Color boxColor = _getColorForClass(className);

                final double x1Norm = detection['x1_norm'];
                final double y1Norm = detection['y1_norm'];
                final double x2Norm = detection['x2_norm'];
                final double y2Norm = detection['y2_norm'];

                final double left = (x1Norm * renderedWidth) + offsetX;
                final double top = (y1Norm * renderedHeight) + offsetY;
                final double width = (x2Norm - x1Norm) * renderedWidth;
                final double height = (y2Norm - y1Norm) * renderedHeight;

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: Container(
                    decoration: BoxDecoration(
                      // Usa a cor específica da classe
                      border: Border.all(color: boxColor, width: 2),
                    ),
                    // MUDANÇA 3: O texto dentro da caixa foi REMOVIDO
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text('YOLO Quick Demo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildImageWithBoxes(),
              SizedBox(height: 20),
              if (isLoading)
                CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: yolo != null ? pickAndDetect : null,
                  child: Text('Pick Image & Detect'),
                ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final detection = results[index];
                    final String className = detection['class'] ?? 'Unknown';
                    // Obtém a cor para usar na bolinha
                    final Color legendColor = _getColorForClass(className);

                    return ListTile(
                      // MUDANÇA 4: Adiciona a bolinha colorida no início da linha
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: legendColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(className),
                      subtitle: Text(
                        'Confidence: ${(detection['confidence'] * 100).toStringAsFixed(1)}%',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}