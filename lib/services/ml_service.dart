import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class MLService {
  final ImageLabeler _imageLabeler;

  MLService() : _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.7));

  Future<List<String>> extractLabels(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
    
    // Extract the text labels (e.g. "Footwear", "Pants", "Sunglasses")
    return labels.map((label) => label.label).toList();
  }

  void dispose() {
    _imageLabeler.close();
  }
}
