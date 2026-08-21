import 'package:flutter_riverpod/legacy.dart';
import '../../video_editor/models/video_edit_settings.dart';
import '../../video_editor/services/pixabay_api_service.dart';
import '../services/media_import_service.dart';

class ReelImageState {
  final List<StockImage> pixabay;
  final List<StockImage> localDownloaded;
  final bool loading;
  final String? error;
  final String query;
  const ReelImageState({this.pixabay=const[], this.localDownloaded=const[], this.loading=false, this.error, this.query=''});
  ReelImageState copyWith({List<StockImage>? pixabay, List<StockImage>? localDownloaded, bool? loading, String? error, String? query}) => ReelImageState(pixabay: pixabay??this.pixabay, localDownloaded: localDownloaded??this.localDownloaded, loading: loading??this.loading, error: error, query: query??this.query);
}

class ReelImageNotifier extends StateNotifier<ReelImageState> {
  final PixabayApiService _api = PixabayApiService();
  final _validator = MediaImportService();
  ReelImageNotifier(): super(const ReelImageState());
  Future<void> search(String q) async {
    state = state.copyWith(loading: true, query: q, error: null);
    try {
      final res = await _api.fetchImages(query: q, perPage: 30);
      state = state.copyWith(pixabay: res, loading: false);
    } catch (e) { state = state.copyWith(loading: false, error: e.toString()); }
  }
  Future<void> loadDownloaded() async {
    try { final res = await _api.getDownloadedImages(); state = state.copyWith(localDownloaded: res);} catch(_){}
  }
  Future<String?> downloadAndValidate(StockImage img) async {
    try {
      final dl = await _api.downloadImage(img);
      final path = dl?.localPath ?? img.localPath;
      if (path==null) return null;
      await _validator.validate(path);
      await loadDownloaded();
      return path;
    } catch(e){ state = state.copyWith(error: MediaImportService.friendly(e)); return null; }
  }
  Future<String?> validateLocal(String path) async { await _validator.validate(path); return path; }
}

final reelImageProvider = StateNotifierProvider<ReelImageNotifier, ReelImageState>((ref)=>ReelImageNotifier());
