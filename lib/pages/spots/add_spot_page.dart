import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import '../../providers/app_provider.dart';
import '../../models/app_models.dart';
import '../../services/firebase_service.dart';

class AddSpotPage extends StatefulWidget {
  const AddSpotPage({super.key});

  @override
  State<AddSpotPage> createState() => _AddSpotPageState();
}

class _AddSpotPageState extends State<AddSpotPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _loadingMessage = 'Procesando...'; // Para mostrar mensajes específicos
  
  final List<String> _allowedFormats = ['jpg', 'jpeg', 'png', 'webp'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  bool _isValidImageFormat(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return _allowedFormats.contains(extension);
  }

  Future<XFile?> _compressImageIfNeeded(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final sizeInKB = bytes.length / 1024;
      
      // Si la imagen es menor al límite, no comprimirla
      if (sizeInKB <= FirebaseService.MAX_IMAGE_SIZE_KB) {
        return imageFile;
      }
      // Leer la imagen
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('No se pudo procesar la imagen');
      }
      
      // Calcular nueva calidad basada en el tamaño
      int quality = 85;
      final sizeInMB = sizeInKB / 1024;
      if (sizeInMB > 10) {
        quality = 60;
      } else if (sizeInMB > 8) {
        quality = 70;
      } else if (sizeInMB > 6) {
        quality = 80;
      }
      
      // Redimensionar si es muy grande
      img.Image resizedImage = image;
      if (image.width > 1920 || image.height > 1920) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? 1920 : null,
          height: image.height > image.width ? 1920 : null,
        );
      }
      
      // Comprimir la imagen
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      
      // Crear archivo temporal (compatible con web)
      final tempPath = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = XFile.fromData(
        compressedBytes,
        name: tempPath,
        mimeType: 'image/jpeg',
      );
      
      final compressedSizeKB = compressedBytes.length / 1024;
      print('Imagen comprimida: ${sizeInKB.toStringAsFixed(1)}KB → ${compressedSizeKB.toStringAsFixed(1)}KB');
      
      return tempFile;
    } catch (e) {
      print('Error comprimiendo imagen: $e');
      return null;
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        final validImages = <XFile>[];
        
        for (final image in images) {
          if (_selectedImages.length + validImages.length >= FirebaseService.MAX_IMAGES_COUNT) {
            _showSnackBar(
              'Solo puedes seleccionar hasta ${FirebaseService.MAX_IMAGES_COUNT} imágenes',
              Colors.orange,
            );
            break;
          }
          
          // Validar formato de imagen
          if (!_isValidImageFormat(image.name)) {
            _showSnackBar(
              'Formato no válido para ${image.name}. Formatos permitidos: ${_allowedFormats.join(', ').toUpperCase()}',
              Colors.red,
            );
            continue;
          }
          
          // Validar tamaño de imagen y comprimir si es necesario
          final bytes = await image.readAsBytes();
          final sizeInKB = bytes.length / 1024;
          
          XFile processedImage = image;
          
          // Si la imagen es muy grande, intentar comprimirla
          if (sizeInKB > FirebaseService.MAX_IMAGE_SIZE_KB) {
            _showSnackBar(
              'Comprimiendo imagen ${image.name} (${(sizeInKB / 1024).toStringAsFixed(1)}MB)...',
              Colors.blue,
            );
            
            final compressedImage = await _compressImageIfNeeded(image);
            if (compressedImage != null) {
              processedImage = compressedImage;
              _showSnackBar(
                'Imagen ${image.name} comprimida exitosamente',
                Colors.green,
              );
            } else {
              _showSnackBar(
                'No se pudo comprimir ${image.name}. Intenta con una imagen más pequeña.',
                Colors.red,
              );
              continue;
            }
          }
          
          validImages.add(processedImage);
        }
        
        if (validImages.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(validImages);
          });
          _showSnackBar(
            '${validImages.length} imagen(es) añadida(s) correctamente',
            Colors.green,
          );
        }
      }
    } catch (e) {
      _showSnackBar('Error al seleccionar imágenes: $e', Colors.red);
    }
  }

  Future<void> _takePicture() async {
    try {
      if (_selectedImages.length >= FirebaseService.MAX_IMAGES_COUNT) {
        _showSnackBar(
          'Ya has alcanzado el límite de ${FirebaseService.MAX_IMAGES_COUNT} imágenes',
          Colors.orange,
        );
        return;
      }
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        // Validar formato de imagen
        if (!_isValidImageFormat(image.name)) {
          _showSnackBar(
            'Formato no válido. Formatos permitidos: ${_allowedFormats.join(', ').toUpperCase()}',
            Colors.red,
          );
          return;
        }
        
        // Validar tamaño de imagen y comprimir si es necesario
        final bytes = await image.readAsBytes();
        final sizeInKB = bytes.length / 1024;
        
        XFile processedImage = image;
        
        // Si la imagen es muy grande, intentar comprimirla
        if (sizeInKB > FirebaseService.MAX_IMAGE_SIZE_KB) {
          _showSnackBar(
            'Comprimiendo imagen (${(sizeInKB / 1024).toStringAsFixed(1)}MB)...',
            Colors.blue,
          );
          
          final compressedImage = await _compressImageIfNeeded(image);
          if (compressedImage != null) {
            processedImage = compressedImage;
            _showSnackBar(
              'Imagen comprimida exitosamente',
              Colors.green,
            );
          } else {
            _showSnackBar(
              'No se pudo comprimir la imagen. Intenta con una imagen más pequeña.',
              Colors.red,
            );
            return;
          }
        }
        
        setState(() {
          _selectedImages.add(processedImage);
        });
        
        _showSnackBar(
          'Imagen capturada correctamente',
          Colors.green,
        );
      }
    } catch (e) {
      _showSnackBar('Error al tomar foto: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _publishSpot() async {
    // Prevenir múltiples ejecuciones
    if (_isLoading) {
      print('Ya se está ejecutando una subida, ignorando...');
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedImages.isEmpty) {
      _showSnackBar(
        'Debes seleccionar al menos 1 imagen',
        Colors.red,
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    
    if (provider.currentUser?.role != UserRole.publicador) {
      _showSnackBar(
        'Solo los publicadores pueden crear sitios turísticos',
        Colors.red,
      );
      return;
    }

    print('Iniciando _publishSpot...');
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Validando datos...';
    });

    try {
      // Validar que latitud y longitud sean números válidos
      final latitude = double.tryParse(_latitudeController.text.trim());
      final longitude = double.tryParse(_longitudeController.text.trim());
      
      if (latitude == null || longitude == null) {
        _showSnackBar('Por favor ingresa valores numéricos válidos para latitud y longitud', Colors.red);
        return;
      }
      
      // Validar rangos de latitud y longitud
      if (latitude < -90 || latitude > 90) {
        _showSnackBar('La latitud debe estar entre -90 y 90 grados', Colors.red);
        return;
      }
      
      if (longitude < -180 || longitude > 180) {
        _showSnackBar('La longitud debe estar entre -180 y 180 grados', Colors.red);
        return;
      }
      
      final spot = TouristSpot(
        id: '',
        title: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: '${latitude}, ${longitude}', // Combinar coordenadas como ubicación
        latitude: latitude,
        longitude: longitude,
        imageUrls: [],
        authorId: provider.currentUser!.id,
        authorName: provider.currentUser!.displayName,
        createdAt: DateTime.now(), // Fecha de publicación automática
        updatedAt: DateTime.now(),
      );

      // Actualizar mensaje de progreso
      if (mounted) {
        setState(() {
          _loadingMessage = 'Subiendo sitio turístico...';
        });
      }

      await provider.createTouristSpot(spot, _selectedImages);
      
      // Verificar si el widget está montado antes de continuar
      if (!mounted) return;
      
      // Actualizar mensaje
      setState(() {
        _loadingMessage = 'Finalizando...';
      });
      
      _showSnackBar('¡Sitio turístico publicado exitosamente!', Colors.green);
      
      // Para Flutter Web: Forzar actualización del UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Forzar rebuild
          });
        }
      });
      
      // Limpiar formulario
      _formKey.currentState!.reset();
      _nameController.clear();
      _descriptionController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      setState(() {
        _selectedImages.clear();
      });
      
      // Esperar más tiempo en Flutter Web para permitir que el GC limpie memoria
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Verificar nuevamente si está montado antes de navegar
      if (!mounted) return;
      
      // Navegar de vuelta con un método más robusto para Flutter Web
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        // Fallback para Flutter Web
        Navigator.of(context).pushReplacementNamed('/');
      }
      
    } catch (e) {
      print('Error detallado en _publishSpot: $e');
      
      // Verificar si el widget está montado antes de mostrar errores
      if (!mounted) return;
      
      String errorMessage = 'Error al publicar sitio';
      
      if (e.toString().contains('Timeout')) {
        errorMessage = 'La subida está tardando demasiado. Verifica tu conexión a internet.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Error de permisos. Verifica la configuración de Firebase.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Error de conexión. Verifica tu internet.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      _showSnackBar(errorMessage, Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildImageGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Imágenes (${_selectedImages.length}/${FirebaseService.MAX_IMAGES_COUNT})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Mínimo: 1',
              style: TextStyle(
                fontSize: 12,
                color: _selectedImages.isNotEmpty ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Botones para añadir imágenes
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedImages.length < FirebaseService.MAX_IMAGES_COUNT ? _pickImages : null,
                icon: const Icon(Icons.photo_library),
                label: const Text('Galería'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.shade600),
                  foregroundColor: Colors.orange.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedImages.length < FirebaseService.MAX_IMAGES_COUNT ? _takePicture : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Cámara'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.shade600),
                  foregroundColor: Colors.orange.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Grid de imágenes seleccionadas
        if (_selectedImages.isNotEmpty) ...[
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List>(
                          future: _selectedImages[index].readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              );
                            } else {
                              return Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ] else ...[
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay imágenes seleccionadas',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    // Verificar si el usuario puede publicar
    if (provider.currentUser?.role != UserRole.publicador) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Publicar Sitio'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Acceso Restringido',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Solo los usuarios con perfil de Publicador\npueden crear sitios turísticos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar Sitio Turístico'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_location_alt,
                          color: Colors.orange.shade600,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Comparte un sitio increíble',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ayuda a otros a descubrir lugares únicos',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nombre del sitio
              TextFormField(
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa el nombre del sitio';
                  }
                  if (value.trim().length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Nombre del sitio turístico *',
                  prefixIcon: Icon(Icons.place, color: Colors.orange.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Coordenadas - Latitud y Longitud
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Requerido';
                        }
                        final latitude = double.tryParse(value.trim());
                        if (latitude == null) {
                          return 'Número inválido';
                        }
                        if (latitude < -90 || latitude > 90) {
                          return 'Entre -90 y 90';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Latitud *',
                        prefixIcon: Icon(Icons.location_on, color: Colors.orange.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                        ),
                        hintText: 'Ej: -0.1807',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Requerido';
                        }
                        final longitude = double.tryParse(value.trim());
                        if (longitude == null) {
                          return 'Número inválido';
                        }
                        if (longitude < -180 || longitude > 180) {
                          return 'Entre -180 y 180';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Longitud *',
                        prefixIcon: Icon(Icons.location_on, color: Colors.orange.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                        ),
                        hintText: 'Ej: -78.4678',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Información sobre coordenadas
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Puedes obtener las coordenadas desde Google Maps haciendo clic derecho en el mapa',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa una descripción';
                  }
                  if (value.trim().length < 20) {
                    return 'La descripción debe tener al menos 20 caracteres';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Descripción *',
                  prefixIcon: Icon(Icons.description, color: Colors.orange.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                  ),
                  hintText: 'Describe qué hace especial a este sitio...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              // Sección de imágenes
              _buildImageGrid(),
              const SizedBox(height: 32),

              // Botón de publicar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _publishSpot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Colors.orange.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _loadingMessage,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Publicar Sitio Turístico',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Información adicional
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Requisitos para las imágenes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📷 Mínimo 1 imagen, máximo ${FirebaseService.MAX_IMAGES_COUNT}\n'
                      '📏 Tamaño máximo: ${FirebaseService.MAX_IMAGE_SIZE_KB}KB por imagen\n'
                      '🖼️ Formatos permitidos: ${_allowedFormats.map((f) => f.toUpperCase()).join(', ')}\n'
                      '💡 Tip: Usa imágenes de buena calidad y bien iluminadas\n'
                      '⚠️ Las imágenes grandes se comprimen automáticamente',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
