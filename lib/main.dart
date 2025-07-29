import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() => runApp(YOLODemo());

class YOLODemo extends StatefulWidget {
  @override
  _YOLODemoState createState() => _YOLODemoState();
}

class _YOLODemoState extends State<YOLODemo> {
  YOLO? yolo; //modelo
  File? selectedImage; //imagem selecionada
  List<dynamic> results = []; //resultados
  bool isLoading = false; //se o modelo ainda ta carregando
  List<dynamic> masks = [];
  
  @override
  void initState() {
    super.initState();
    loadYOLO(); //inicia o modelo no inicio do app
  }

  Future<void> loadYOLO() async {
    //carregar o modelo
    setState(() => isLoading = true);

    yolo = YOLO(modelPath: 'best_float32', task: YOLOTask.segment);

    await yolo!.loadModel();
    setState(() => isLoading = false);
  }

  Future<void> pickAndDetect() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
        isLoading = true;
      });

      final imageBytes = await selectedImage!.readAsBytes();
      final detectionResults = await yolo!.predict(imageBytes);

      final boxes = detectionResults['boxes'] as List<dynamic>;
      var masks = detectionResults['masks'] as List<dynamic>?;

      print('Detected ${boxes.length} objects');
      print('Masks available: ${masks}');

      setState(() {
        results = detectionResults['boxes'] ?? [];
        isLoading = false;
        masks = detectionResults['masks'] as List<dynamic>?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('YOLO Quick Demo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selectedImage != null)
                Container(height: 300, child: Image.file(selectedImage!)),

              SizedBox(height: 20),

              if (isLoading)
                CircularProgressIndicator()
              else
                Text('Detected ${results.length} objects'),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: yolo != null ? pickAndDetect : null,
                child: Text('Pick Image & Detect'),
              ),

              SizedBox(height: 20),

              // Show detection results
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final detection = results[index];
                    return ListTile(
                      title: Text(detection['class'] ?? 'Unknown'),
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
