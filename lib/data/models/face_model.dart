/// An authorized face profile (a known person the AI should recognize).
class FaceModel {
  final String id;
  final String personName;
  final List<String> photoPaths; // server-relative, e.g. /uploads/faces/.../x.jpg
  final DateTime createdAt;

  FaceModel({
    required this.id,
    required this.personName,
    required this.photoPaths,
    required this.createdAt,
  });

  factory FaceModel.fromJson(Map<String, dynamic> json) => FaceModel(
        id: json['id'].toString(),
        personName: (json['personName'] ?? '').toString(),
        photoPaths: ((json['photoPaths'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
      );
}
