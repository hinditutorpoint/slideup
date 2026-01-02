import 'download_model.dart';

class ModelInfo {
  final String id;
  final String name;
  final String url;
  final SherpaModelType modelType;
  final String language;
  final String? description;
  final int version;
  final String? checksum;
  final int? estimatedSize;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.url,
    required this.modelType,
    required this.language,
    this.description,
    this.version = 1,
    this.checksum,
    this.estimatedSize,
  });

  DownloadedModel toDownloadedModel() {
    return DownloadedModel(
      id: id,
      name: name,
      url: url,
      modelType: modelType,
      language: language,
      description: description,
      version: version,
      checksum: checksum,
      totalBytes: estimatedSize ?? 0,
    );
  }
}
