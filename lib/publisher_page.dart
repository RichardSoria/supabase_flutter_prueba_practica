import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'resenas_page.dart';

class TurismosPage extends StatefulWidget {
  const TurismosPage({super.key});

  @override
  State<TurismosPage> createState() => _TurismosPageState();
}

class _TurismosPageState extends State<TurismosPage> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();
  final TextEditingController provinciaController = TextEditingController();
  final TextEditingController ciudadController = TextEditingController();

  final List<Uint8List> fotosBytes = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  final uuid = const Uuid();

  Future<void> _pickImages(StateSetter setModalState) async {
    final picker = ImagePicker();

    final origen = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Seleccionar de galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (origen == null) return;

    if (origen == ImageSource.camera) {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (fotosBytes.length < 6) {
          setModalState(() {
            fotosBytes.add(bytes);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Máximo 6 imágenes permitidas.'),
              backgroundColor: Color(0xFF16243e), // Azul institucional
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (origen == ImageSource.gallery) {
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 100,
      );

      if ((pickedFiles.length + fotosBytes.length) <= 6) {
        for (var pickedFile in pickedFiles) {
          final bytes = await pickedFile.readAsBytes();
          setModalState(() {
            fotosBytes.add(bytes);
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Puedes subir entre 1 y 6 imágenes.'),
            backgroundColor: Color(0xFF16243e), // Azul institucional
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<List<String>> _subirImagenesASupabase() async {
    final storage = Supabase.instance.client.storage.from('turismo');
    final List<String> urls = [];

    for (var i = 0; i < fotosBytes.length; i++) {
      final String fileName = 'img_${uuid.v4()}.jpg';

      final String path = await storage.uploadBinary(
        fileName,
        fotosBytes[i],
        fileOptions: const FileOptions(
          upsert: false,
          contentType: 'image/jpeg',
        ),
      );

      if (path.isNotEmpty) {
        final publicUrl = storage.getPublicUrl(fileName);
        urls.add(publicUrl);
      } else {
        throw Exception(
          'Error al subir imagen: No se pudo obtener la ruta del archivo subido.',
        );
      }
    }

    return urls;
  }

  Future<void> _guardarTurismo(BuildContext context) async {
    final campos = [
      nombreController.text,
      descripcionController.text,
      latController.text,
      lngController.text,
      provinciaController.text,
      ciudadController.text,
    ];

    final camposVacios = campos.any((campo) => campo.trim().isEmpty);

    if (camposVacios) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Campos incompletos',
            style: TextStyle(
              color: Color(0xFF16243e), // Azul institucional
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'Por favor completa todos los campos obligatorios.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFFF8AD25), // Amarillo de atención
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    if (fotosBytes.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Faltan imágenes',
            style: TextStyle(
              color: Color(0xFF16243e),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Debes agregar al menos una fotografía.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Color(0xFFF8AD25),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    if (camposVacios) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Campos incompletos',
            style: TextStyle(
              color: Color(0xFF16243e), // Azul institucional
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'Por favor completa todos los campos obligatorios.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFFF8AD25), // Amarillo institucional
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    if (fotosBytes.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Faltan imágenes',
            style: TextStyle(
              color: Color(0xFF16243e), // Azul institucional
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'Debes agregar al menos una fotografía.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFFF8AD25), // Amarillo de atención
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmado = await _confirmarGuardarLugar();
    if (!confirmado) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF8AD25)),
        ),
      ),
    );

    try {
      final lat = double.tryParse(latController.text) ?? 0.0;
      final lng = double.tryParse(lngController.text) ?? 0.0;
      final ubicacion = GeoPoint(lat, lng);

      final urls = await _subirImagenesASupabase();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('users')
          .select('name, lastName')
          .eq('id', user.id)
          .single();

      final String autorNombre = '${data['name']} ${data['lastName']}';

      await FirebaseFirestore.instance.collection('turismo').add({
        'autor': autorNombre,
        'userID': user.id,
        'nombre': nombreController.text,
        'descripcion': descripcionController.text,
        'latitud': lat,
        'longitud': lng,
        'fotografias': urls,
        'provincia': provinciaController.text,
        'ciudad': ciudadController.text,
        'ubicacion': ubicacion,
        'fecha': Timestamp.now(),
      });

      Navigator.pop(context); // Cierra el spinner
      Navigator.pop(context); // Cierra el modal

      // Limpiar campos y fotos
      _clearForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lugar turístico guardado exitosamente.'),
          backgroundColor: Color(0xFF16243e), // Azul institucional
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Cierra el spinner
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('Ocurrió un error al guardar: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
  }

  void _clearForm() {
    nombreController.clear();
    descripcionController.clear();
    latController.clear();
    lngController.clear();
    provinciaController.clear();
    ciudadController.clear();
    fotosBytes.clear();
  }

  void _mostrarModalImagen(String url, String lugarId, bool esAutor) async {



    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              
              !esAutor ? 
              Text("")
              :
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmarEliminarImagen(lugarId, url);
                    },
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Eliminar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE72F2B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _actualizarImagen(lugarId, url);
                    },
                    icon: const Icon(Icons.image_search, color: Colors.white),
                    label: const Text('Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16243e),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmarGuardarLugar() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '¿Estás seguro?',
              style: TextStyle(
                color: Color(0xFF16243e), // Azul institucional
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: const Text(
              '¿Deseas guardar este lugar turístico?',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFFF8AD25), // Amarillo de atención
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _confirmarEliminarLugar(String id) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Estás seguro?',
          style: TextStyle(
            color: Color(0xFFE72F2B), // Rojo de alerta
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFE72F2B), // Rojo de alerta
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await FirebaseFirestore.instance.collection('turismo').doc(id).delete();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lugar eliminado exitosamente.'),
          backgroundColor: Color(0xFF16243e), // Azul institucional
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _confirmarEliminarImagen(String lugarId, String url) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar Imagen',
          style: TextStyle(
            color: Color(0xFFE72F2B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          '¿Deseas eliminar esta imagen?',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFE72F2B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      // Mostrar spinner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF8AD25)),
          ),
        ),
      );

      try {
        final doc = FirebaseFirestore.instance
            .collection('turismo')
            .doc(lugarId);
        await doc.update({
          'fotografias': FieldValue.arrayRemove([url]),
        });

        Navigator.pop(context); // Cierra el spinner
        return true;
      } catch (e) {
        Navigator.pop(context); // Cierra el spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la imagen: $e')),
        );
      }
    }

    return false;
  }

  Future<void> _agregarMasImagenes(String lugarId, int cantidadActual) async {
    final ImageSource? origen = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Seleccionar de galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (origen == null) return;

    final int cantidadDisponible = 6 - cantidadActual;
    final storage = Supabase.instance.client.storage.from('turismo');
    final nuevasUrls = <String>[];

    try {
      if (origen == ImageSource.camera) {
        final pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 100,
        );

        if (pickedFile != null) {
          if (cantidadDisponible < 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ya tienes 6 imágenes.'),
                backgroundColor: Color(0xFF16243e), // Azul institucional
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF8AD25)),
              ),
            ),
          );

          final bytes = await pickedFile.readAsBytes();
          final fileName = 'img_${uuid.v4()}.jpg';
          final path = await storage.uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

          if (path.isNotEmpty) {
            final url = storage.getPublicUrl(fileName);
            nuevasUrls.add(url);
          }

          Navigator.pop(context);
        }
      } else if (origen == ImageSource.gallery) {
        final pickedFiles = await picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 100,
        );

        if (pickedFiles.isEmpty) return;

        if (pickedFiles.length > cantidadDisponible) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Solo puedes agregar $cantidadDisponible imágenes.',
              ),
            ),
          );
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF8AD25)),
            ),
          ),
        );

        for (var pickedFile in pickedFiles) {
          final bytes = await pickedFile.readAsBytes();
          final fileName = 'img_${uuid.v4()}.jpg';

          final path = await storage.uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

          if (path.isNotEmpty) {
            final url = storage.getPublicUrl(fileName);
            nuevasUrls.add(url);
          }
        }

        Navigator.pop(context);
      }

      if (nuevasUrls.isNotEmpty) {
        final doc = FirebaseFirestore.instance
            .collection('turismo')
            .doc(lugarId);
        await doc.update({'fotografias': FieldValue.arrayUnion(nuevasUrls)});
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir imágenes: $e')));
    }
  }

  Future<void> _actualizarImagen(String lugarId, String urlAntiguo) async {
    final origen = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Seleccionar de galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (origen == null) return;

    final pickedFile = await picker.pickImage(source: origen);
    if (pickedFile == null) return;

    // Mostrar spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF8AD25)),
        ),
      ),
    );

    try {
      final nuevoBytes = await pickedFile.readAsBytes();
      final storage = Supabase.instance.client.storage.from('turismo');
      final nuevoNombre = 'img_${uuid.v4()}.jpg';

      final nuevoPath = await storage.uploadBinary(
        nuevoNombre,
        nuevoBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      if (nuevoPath.isNotEmpty) {
        final nuevaUrl = storage.getPublicUrl(nuevoNombre);
        final doc = FirebaseFirestore.instance
            .collection('turismo')
            .doc(lugarId);

        // Reemplaza la imagen antigua por la nueva
        await doc.update({
          'fotografias': FieldValue.arrayRemove([urlAntiguo]),
        });

        await doc.update({
          'fotografias': FieldValue.arrayUnion([nuevaUrl]),
        });
      }

      Navigator.pop(context); // Cierra el spinner
      // No cierres el modal de imagen aquí, déjalo al botón si es necesario
    } catch (e) {
      Navigator.pop(context); // Cierra el spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la imagen: $e')),
      );
    }
  }

  void _editarLugar(String id, Map<String, dynamic> data) {
    final nombreCtrl = TextEditingController(text: data['nombre']);
    final descripcionCtrl = TextEditingController(text: data['descripcion']);
    final latCtrl = TextEditingController(text: data['latitud'].toString());
    final lngCtrl = TextEditingController(text: data['longitud'].toString());
    final provinciaCtrl = TextEditingController(text: data['provincia']);
    final ciudadCtrl = TextEditingController(text: data['ciudad']);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Editar Lugar',
          style: TextStyle(
            color: Color(0xFF16243e),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 500, // <-- Aquí defines el ancho deseado
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _styledField(nombreCtrl, 'Nombre del Lugar'),
                  const SizedBox(height: 10),
                  _styledField(descripcionCtrl, 'Descripción', maxLines: 2),
                  const SizedBox(height: 10),
                  _styledField(latCtrl, 'Latitud', isNumber: true),
                  const SizedBox(height: 10),
                  _styledField(lngCtrl, 'Longitud', isNumber: true),
                  const SizedBox(height: 10),
                  _styledField(provinciaCtrl, 'Provincia'),
                  const SizedBox(height: 10),
                  _styledField(ciudadCtrl, 'Ciudad'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: Color(0xFFE72F2B), // Rojo de alerta
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(
              Icons.edit,
            ), // Ícono más representativo para editar
            label: const Text('Actualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16243e), // Azul institucional
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final campos = [
                nombreCtrl.text,
                descripcionCtrl.text,
                latCtrl.text,
                lngCtrl.text,
                provinciaCtrl.text,
                ciudadCtrl.text,
              ];

              final camposVacios = campos.any((campo) => campo.trim().isEmpty);

              if (camposVacios) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Campos incompletos',
                      style: TextStyle(
                        color: Color(0xFFE72F2B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: const Text(
                      'Por favor completa todos los campos.',
                      style: TextStyle(fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Aceptar',
                          style: TextStyle(
                            color: Color(0xFF16243e),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                return;
              }

              final confirmado = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    '¿Confirmar actualización?',
                    style: TextStyle(
                      color: Color(0xFF16243e), // Azul institucional
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  content: const Text(
                    '¿Estás seguro de actualizar este lugar turístico?',
                    style: TextStyle(fontSize: 16),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Color(0xFFE72F2B), // Rojo de alerta
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Sí, actualizar',
                        style: TextStyle(
                          color: Color(0xFF16243e), // Azul institucional
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmado != true) return;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFF8AD25),
                    ),
                  ),
                ),
              );

              try {
                await FirebaseFirestore.instance
                    .collection('turismo')
                    .doc(id)
                    .update({
                      'nombre': nombreCtrl.text,
                      'descripcion': descripcionCtrl.text,
                      'latitud': double.tryParse(latCtrl.text) ?? 0,
                      'longitud': double.tryParse(lngCtrl.text) ?? 0,
                      'provincia': provinciaCtrl.text,
                      'ciudad': ciudadCtrl.text,
                    });

                Navigator.pop(context); // spinner
                Navigator.pop(context); // modal

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lugar actualizado exitosamente.'),
                    backgroundColor: Color(0xFF16243e), // Azul institucional
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al actualizar: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _verResenas(String lugarId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('id', user.id)
        .single();

    final String rol = data['role'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResenasPage(
          lugarId: lugarId,
          rolUsuario: rol, // 'publicador' o 'visitante'
        ),
      ),
    );
  }

  Widget _styledField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
              : null,
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: const BorderSide(color: Color(0xFF98B7DF), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoText(String label, String value, {bool italic = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16, // más grande
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.black87, // azul institucional
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFormularioModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 30,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _styledField(nombreController, 'Nombre del Lugar'),
                    const SizedBox(height: 12),
                    _styledField(
                      descripcionController,
                      'Descripción',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _styledField(latController, 'Latitud', isNumber: true),
                    const SizedBox(height: 12),
                    _styledField(lngController, 'Longitud', isNumber: true),
                    const SizedBox(height: 12),
                    _styledField(provinciaController, 'Provincia'),
                    const SizedBox(height: 12),
                    _styledField(ciudadController, 'Ciudad'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _pickImages(setModalState),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Seleccionar Fotografías'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8AD25),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: fotosBytes.map((bytes) {
                        return Image.memory(
                          bytes,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _guardarTurismo(context),
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Lugar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16243e),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _clearForm(); // Limpia aunque el modal se cierre por fuera (por ejemplo deslizando)
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 22, 36, 62),
        foregroundColor: Colors.white,
        title: const Text('Lugares Turístico'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lugares turísticos guardados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('turismo')
                    .orderBy('fecha', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFF8AD25),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Text(
                      'Aún no hay lugares turísticos registrados.',
                    );
                  }

                  final user = Supabase.instance.client.auth.currentUser;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final docId = docs[index].id;

                      final nombre = data['nombre'] ?? '';
                      final descripcion = data['descripcion'] ?? '';
                      final ciudad = data['ciudad'] ?? '';
                      final provincia = data['provincia'] ?? '';
                      final autor = data['autor'] ?? 'Desconocido';
                      final userID =
                          data['userID']; // Asegúrate de guardar esto en Firestore
                      final latitud = data['latitud']?.toString() ?? '-';
                      final longitud = data['longitud']?.toString() ?? '-';
                      final fotos = List<String>.from(
                        data['fotografias'] ?? [],
                      );

                      final esCreador = userID == user?.id;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE72F2B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                descripcion,
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              _infoText("Provincia: ", provincia),
                              _infoText("Ciudad: ", ciudad),
                              _infoText(
                                "Coordenadas: ",
                                '$latitud°, $longitud°',
                              ),
                              _infoText("Publicado por: ", autor, italic: true),
                              const SizedBox(height: 12),

                              SizedBox(
                                height:
                                    (fotos.length / 3).ceil() *
                                    110, // 3 por fila, 100 alto + 10 spacing
                                child: GridView.count(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: fotos.map((url) {
                                    return GestureDetector(
                                      onTap: () =>
                                          _mostrarModalImagen(url, docId, esCreador),
                                      child: 
                                      
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.red,
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              const SizedBox(height: 8),

                              if (esCreador && fotos.length < 6)
                                TextButton.icon(
                                  onPressed: () =>
                                      _agregarMasImagenes(docId, fotos.length),
                                  icon: const Icon(Icons.add_a_photo),
                                  label: const Text('Agregar imagen'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF16243e),
                                  ),
                                ),

                              if (esCreador) const Divider(height: 24),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (esCreador)
                                    IconButton(
                                      onPressed: () =>
                                          _editarLugar(docId, data),
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Editar',
                                      color: Colors.white,
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.all(
                                              Color(0xFF16243e),
                                            ),
                                      ),
                                    ),
                                  if (esCreador)
                                    IconButton(
                                      onPressed: () =>
                                          _confirmarEliminarLugar(docId),
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Eliminar',
                                      color: Colors.white,
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.all(
                                              Color(0xFFE72F2B),
                                            ),
                                      ),
                                    ),
                                  IconButton(
                                    onPressed: () => _verResenas(docId),
                                    icon: const Icon(Icons.reviews),
                                    tooltip: 'Ver reseñas',
                                    color: Colors.white,
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStateProperty.all(
                                        Color(0xFF16243e),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF16243e),
        foregroundColor: Colors.white, // Ícono blanco
        tooltip: 'Añadir lugar turístico',
        onPressed: () => _mostrarFormularioModal(context),
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
    );
  }
}
