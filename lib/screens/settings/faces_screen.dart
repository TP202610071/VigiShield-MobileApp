import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/face_model.dart';
import '../../data/services/face_service.dart';

/// Manage authorized faces (the people the AI recognizes by name).
class FacesScreen extends StatefulWidget {
  const FacesScreen({super.key});

  @override
  State<FacesScreen> createState() => _FacesScreenState();
}

class _FacesScreenState extends State<FacesScreen> {
  late final FaceService _service = FaceService(context.read<ApiClient>());

  bool _loading = true;
  String? _error;
  List<FaceModel> _faces = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final faces = await _service.getFaces();
      if (!mounted) return;
      setState(() {
        _faces = faces;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete(FaceModel face) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar rostro',
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('¿Eliminar a "${face.personName}" del reconocimiento facial?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar',
                style: GoogleFonts.inter(color: AppColors.alertRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteFace(face.id);
      await _load();
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.alertRed);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Caras autorizadas',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add_a_photo_outlined, color: Colors.black),
        label: Text('Registrar',
            style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
    }
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, color: AppColors.alertRed, size: 48),
        const SizedBox(height: 16),
        Center(
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
              onPressed: _load,
              child: Text('Reintentar', style: GoogleFonts.inter(color: AppColors.accent))),
        ),
      ]);
    }
    if (_faces.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        const Icon(Icons.face_retouching_natural_outlined,
            color: AppColors.textSecondary, size: 56),
        const SizedBox(height: 16),
        Center(
          child: Text('Sin rostros registrados',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Registra a las personas de confianza para que la IA las identifique '
            'por su nombre y marque a los desconocidos.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _faces.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _faceCard(_faces[i]),
    );
  }

  Widget _faceCard(FaceModel face) {
    final thumb = face.photoPaths.isNotEmpty
        ? '${_service.baseUrl}${face.photoPaths.first}'
        : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56, height: 56,
            child: thumb != null
                ? Image.network(thumb, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbFallback())
                : _thumbFallback(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(face.personName,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('${face.photoPaths.length} foto(s)',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
        IconButton(
          onPressed: () => _confirmDelete(face),
          icon: const Icon(Icons.delete_outline, color: AppColors.alertRed, size: 22),
        ),
      ]),
    );
  }

  Widget _thumbFallback() => Container(
        color: AppColors.surfaceElevated,
        child: const Icon(Icons.person, color: AppColors.textMuted, size: 28),
      );

  // ── Add face sheet ───────────────────────────────────────────────────────────

  void _openAddSheet() {
    final nameCtrl = TextEditingController();
    final picker = ImagePicker();
    final List<XFile> selected = [];
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> startLiveScan() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              _snack('Escribe el nombre de la persona', AppColors.alertRed);
              return;
            }
            Navigator.pop(ctx);
            final ok = await context.push<bool>('/settings/faces/enroll', extra: name);
            if (ok == true) {
              await _load();
              if (mounted) _snack('Rostro registrado', AppColors.safeGreen);
            }
          }

          Future<void> pickFromGallery() async {
            final imgs = await picker.pickMultiImage(imageQuality: 85);
            if (imgs.isNotEmpty) setS(() => selected.addAll(imgs));
          }

          Future<void> saveFromGallery() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              _snack('Escribe el nombre de la persona', AppColors.alertRed);
              return;
            }
            if (selected.length < 3) {
              _snack('Selecciona al menos 3 fotos', AppColors.alertRed);
              return;
            }
            setS(() => saving = true);
            try {
              await _service.addFace(name, selected);
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
              if (mounted) _snack('Rostro registrado', AppColors.safeGreen);
            } catch (e) {
              setS(() => saving = false);
              if (ctx.mounted) _snack(e.toString(), AppColors.alertRed);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrar rostro',
                      style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Escanea el rostro en vivo (recomendado) para capturar varios ángulos automáticamente.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.inter(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nombre de la persona',
                      labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Primary: live biometric scan
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : startLiveScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.face_retouching_natural, color: Colors.black, size: 20),
                      label: Text('Escaneo facial en vivo',
                          style: GoogleFonts.inter(
                              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('o sube fotos',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                    ),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ]),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: saving ? null : pickFromGallery,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 0),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, color: AppColors.accent, size: 18),
                    label: Text('Elegir fotos de galería (mín. 3)',
                        style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13)),
                  ),
                  if (selected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selected.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(selected[i].path),
                                width: 76, height: 76, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2, right: 2,
                            child: GestureDetector(
                              onTap: saving ? null : () => setS(() => selected.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving ? null : saveFromGallery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
                            : Text('Registrar con ${selected.length} foto(s)',
                                style: GoogleFonts.inter(
                                    color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
