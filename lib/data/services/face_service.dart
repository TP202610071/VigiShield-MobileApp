import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../models/face_model.dart';

/// Talks to the backend FacesController (/api/faces).
class FaceService {
  final ApiClient _api;
  FaceService(this._api);

  /// Base URL of the backend, used to build absolute photo URLs for thumbnails.
  String get baseUrl => _api.currentBaseUrl;

  Future<List<FaceModel>> getFaces() async {
    final data = await _api.get<List<dynamic>>('/api/faces');
    return data
        .map((j) => FaceModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Register a new authorized face. The backend requires at least 3 photos.
  Future<FaceModel> addFace(String personName, List<XFile> photos) async {
    final form = FormData();
    form.fields.add(MapEntry('personName', personName));
    for (final photo in photos) {
      form.files.add(MapEntry(
        'photos', // must match [FromForm] List<IFormFile> photos
        await MultipartFile.fromFile(photo.path, filename: photo.name),
      ));
    }
    final data = await _api.postMultipart<Map<String, dynamic>>('/api/faces', form);
    return FaceModel.fromJson(data);
  }

  Future<void> deleteFace(String id) async {
    await _api.delete('/api/faces/$id');
  }
}
