import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/app_models.dart';
import 'dart:typed_data';
import 'dart:convert';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // CONSTANTES PARA VALIDACIÓN DE TAMAÑO
  static const int FIRESTORE_MAX_DOCUMENT_SIZE = 1048576; // 1MB en bytes
  static const int MAX_IMAGE_SIZE_KB = 200; // 200KB por imagen para tener margen
  static const int MAX_IMAGES_COUNT = 5; // Máximo 5 imágenes para no exceder el límite
  static const int MAX_IMAGE_SIZE_BYTES = MAX_IMAGE_SIZE_KB * 1024;

  // NOTA: Los perfiles de usuario ahora se manejan con Auth de Supabase (user_metadata)
  // Firebase solo se usa para sitios turísticos, reseñas, respuestas y likes

  // Método para validar el tamaño de una imagen individual
  static bool isImageSizeValid(Uint8List imageData) {
    return imageData.length <= MAX_IMAGE_SIZE_BYTES;
  }

  // Método para calcular el tamaño estimado de un documento
  static int calculateDocumentSize(TouristSpot spot, List<String> base64Images) {
    // Crear un mapa serializable para el cálculo de tamaño
    final spotData = {
      'title': spot.title,
      'description': spot.description,
      'location': spot.location,
      'latitude': spot.latitude,
      'longitude': spot.longitude,
      'imageUrls': base64Images, // Usar las imágenes base64
      'authorId': spot.authorId,
      'authorName': spot.authorName,
      'createdAt': spot.createdAt.toIso8601String(), // Convertir a string para el cálculo
      'updatedAt': spot.updatedAt.toIso8601String(), // Convertir a string para el cálculo
      'likesCount': spot.likesCount,
      'reviewsCount': spot.reviewsCount,
    };
    
    try {
      final jsonString = jsonEncode(spotData);
      return utf8.encode(jsonString).length;
    } catch (e) {
      print('Error calculando tamaño del documento: $e');
      print('Datos del spot: $spotData');
      rethrow;
    }
  }

  // Método para mostrar información sobre límites
  static String getImageLimitsInfo() {
    return 'Límites de imágenes:\n'
           '• Máximo ${MAX_IMAGES_COUNT} imágenes\n'
           '• Máximo ${MAX_IMAGE_SIZE_KB}KB por imagen\n'
           '• Tamaño total del documento: 1MB máximo';
  }

  // Método para validar todas las imágenes antes de la conversión
  static Map<String, dynamic> validateImages(List<Uint8List> imageDataList) {
    if (imageDataList.length > MAX_IMAGES_COUNT) {
      return {
        'isValid': false,
        'error': 'Máximo ${MAX_IMAGES_COUNT} imágenes permitidas. Has seleccionado ${imageDataList.length}.'
      };
    }

    for (int i = 0; i < imageDataList.length; i++) {
      if (!isImageSizeValid(imageDataList[i])) {
        final sizeKB = (imageDataList[i].length / 1024).round();
        return {
          'isValid': false,
          'error': 'La imagen ${i + 1} es muy grande (${sizeKB}KB). El máximo permitido es ${MAX_IMAGE_SIZE_KB}KB por imagen.'
        };
      }
    }

    return {'isValid': true};
  }

  // Tourist Spot Services
  static Future<String> createTouristSpot(TouristSpot spot) async {
    try {
      print('Guardando sitio en Firestore: ${spot.title}');
      final spotData = spot.toFirestore();
      print('Datos del sitio: $spotData');
      
      final docRef = await _firestore.collection('tourist_spots').add(spotData).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: La creación del documento tardó más de 30 segundos');
        },
      );
      
      print('Documento creado con ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error en createTouristSpot: $e');
      rethrow;
    }
  }

  static Future<List<TouristSpot>> getTouristSpots({int? limit}) async {
    Query query = _firestore.collection('tourist_spots').orderBy('createdAt', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => TouristSpot.fromFirestore(doc)).toList();
  }

  static Future<TouristSpot?> getTouristSpot(String spotId) async {
    final doc = await _firestore.collection('tourist_spots').doc(spotId).get();
    if (doc.exists) {
      return TouristSpot.fromFirestore(doc);
    }
    return null;
  }

  static Stream<List<TouristSpot>> getTouristSpotsStream() {
    return _firestore
        .collection('tourist_spots')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => TouristSpot.fromFirestore(doc)).toList());
  }

  static Future<List<TouristSpot>> searchTouristSpots(String query) async {
    final snapshot = await _firestore
        .collection('tourist_spots')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThan: query + 'z')
        .get();
    
    return snapshot.docs.map((doc) => TouristSpot.fromFirestore(doc)).toList();
  }

  // Review Services
  static Future<String> createReview(Review review) async {
    final docRef = await _firestore.collection('reviews').add(review.toFirestore());
    
    // Update review count in tourist spot
    await _firestore.collection('tourist_spots').doc(review.touristSpotId).update({
      'reviewsCount': FieldValue.increment(1),
    });
    
    return docRef.id;
  }

  static Future<List<Review>> getReviewsForSpot(String spotId) async {
    try {
      print('Cargando reseñas para sitio: $spotId');
      final snapshot = await _firestore
          .collection('reviews')
          .where('touristSpotId', isEqualTo: spotId)
          .orderBy('createdAt', descending: true)
          .get();
      
      print('Reseñas encontradas: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error detallado al cargar reseñas: $e');
      
      // Si falla la consulta con orderBy, intentar sin ordenar
      if (e.toString().contains('index') || e.toString().contains('composite')) {
        print('Error de índice detectado, intentando consulta simple...');
        try {
          final snapshot = await _firestore
              .collection('reviews')
              .where('touristSpotId', isEqualTo: spotId)
              .get();
          
          final reviews = snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
          // Ordenar manualmente
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          print('Reseñas cargadas con consulta simple: ${reviews.length}');
          return reviews;
        } catch (e2) {
          print('Error en consulta simple: $e2');
          rethrow;
        }
      }
      rethrow;
    }
  }

  static Stream<List<Review>> getReviewsForSpotStream(String spotId) {
    try {
      return _firestore
          .collection('reviews')
          .where('touristSpotId', isEqualTo: spotId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList());
    } catch (e) {
      print('Error en stream de reseñas: $e');
      // Fallback: stream sin ordenar
      return _firestore
          .collection('reviews')
          .where('touristSpotId', isEqualTo: spotId)
          .snapshots()
          .map((snapshot) {
            final reviews = snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
            reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return reviews;
          });
    }
  }

  // Reply Services
  static Future<String> createReply(Reply reply) async {
    final docRef = await _firestore.collection('replies').add(reply.toFirestore());
    return docRef.id;
  }

  static Future<List<Reply>> getRepliesForReview(String reviewId) async {
    try {
      print('Cargando respuestas para reseña: $reviewId');
      final snapshot = await _firestore
          .collection('replies')
          .where('reviewId', isEqualTo: reviewId)
          .orderBy('createdAt', descending: false)
          .get();
      
      print('Respuestas encontradas: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => Reply.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error detallado al cargar respuestas: $e');
      
      // Si falla la consulta con orderBy, intentar sin ordenar
      if (e.toString().contains('index') || e.toString().contains('composite')) {
        print('Error de índice detectado en respuestas, intentando consulta simple...');
        try {
          final snapshot = await _firestore
              .collection('replies')
              .where('reviewId', isEqualTo: reviewId)
              .get();
          
          final replies = snapshot.docs.map((doc) => Reply.fromFirestore(doc)).toList();
          // Ordenar manualmente (ascendente para respuestas)
          replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          print('Respuestas cargadas con consulta simple: ${replies.length}');
          return replies;
        } catch (e2) {
          print('Error en consulta simple de respuestas: $e2');
          rethrow;
        }
      }
      rethrow;
    }
  }

  static Stream<List<Reply>> getRepliesForReviewStream(String reviewId) {
    try {
      return _firestore
          .collection('replies')
          .where('reviewId', isEqualTo: reviewId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Reply.fromFirestore(doc)).toList());
    } catch (e) {
      print('Error en stream de respuestas: $e');
      // Fallback: stream sin ordenar
      return _firestore
          .collection('replies')
          .where('reviewId', isEqualTo: reviewId)
          .snapshots()
          .map((snapshot) {
            final replies = snapshot.docs.map((doc) => Reply.fromFirestore(doc)).toList();
            replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return replies;
          });
    }
  }

  // Storage Services - Convertir imagen a Base64 para Firestore
  static String convertImageToBase64(Uint8List imageData) {
    try {
      final base64String = base64Encode(imageData);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      print('Error converting image to base64: $e');
      rethrow;
    }
  }

  static Future<List<String>> convertMultipleImagesToBase64(List<Uint8List> imageDataList) async {
    // Validar número máximo de imágenes
    if (imageDataList.length > MAX_IMAGES_COUNT) {
      throw Exception('No puedes subir más de $MAX_IMAGES_COUNT imágenes por sitio turístico.');
    }

    // Validar tamaño individual de cada imagen
    for (int i = 0; i < imageDataList.length; i++) {
      if (!isImageSizeValid(imageDataList[i])) {
        final imageSizeKB = (imageDataList[i].length / 1024).round();
        final maxSizeKB = (MAX_IMAGE_SIZE_BYTES / 1024).round();
        throw Exception('La imagen ${i + 1} es demasiado grande (${imageSizeKB}KB). '
            'El tamaño máximo permitido es ${maxSizeKB}KB por imagen. '
            'Por favor, comprime la imagen antes de subirla.');
      }
    }

    final List<String> base64Images = [];
    
    // Procesar imágenes una por una con pausa para Flutter Web
    for (int i = 0; i < imageDataList.length; i++) {
      print('Convirtiendo imagen ${i + 1}/${imageDataList.length} a base64...');
      
      // Para Flutter Web: Agregar una pausa pequeña entre conversiones
      // para permitir que el UI se actualice y evitar bloqueos
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      final base64Image = convertImageToBase64(imageDataList[i]);
      base64Images.add(base64Image);
      
      // Liberación de memoria explícita para Flutter Web
      // (aunque Dart tiene GC, en Web es bueno ser explícito)
      print('Imagen ${i + 1} convertida exitosamente');
    }
    
    return base64Images;
  }

  static Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  // Like Services
  static Future<void> toggleLike(String spotId, String userId) async {
    final likeDoc = _firestore.collection('likes').doc('${spotId}_$userId');
    final likeSnapshot = await likeDoc.get();
    
    if (likeSnapshot.exists) {
      // Unlike
      await likeDoc.delete();
      await _firestore.collection('tourist_spots').doc(spotId).update({
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // Like
      await likeDoc.set({
        'spotId': spotId,
        'userId': userId,
        'createdAt': Timestamp.now(),
      });
      await _firestore.collection('tourist_spots').doc(spotId).update({
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  static Future<bool> isLiked(String spotId, String userId) async {
    final likeDoc = await _firestore.collection('likes').doc('${spotId}_$userId').get();
    return likeDoc.exists;
  }

  static Future<List<String>> getLikedSpots(String userId) async {
    final snapshot = await _firestore
        .collection('likes')
        .where('userId', isEqualTo: userId)
        .get();
    
    return snapshot.docs.map((doc) => doc.data()['spotId'] as String).toList();
  }

  // Validar tamaño de imagen antes de convertir
  static bool validateImageSize(Uint8List imageData) {
    return imageData.length <= MAX_IMAGE_SIZE_BYTES;
  }

  // Validar tamaño total estimado del documento
  static bool validateTotalDocumentSize(List<Uint8List> images, TouristSpot spot) {
    // Calcular tamaño aproximado del documento base (sin imágenes)
    // Crear un mapa serializable para el cálculo
    final spotDataForCalculation = {
      'title': spot.title,
      'description': spot.description,
      'location': spot.location,
      'latitude': spot.latitude,
      'longitude': spot.longitude,
      'imageUrls': [], // Vacío para el cálculo base
      'authorId': spot.authorId,
      'authorName': spot.authorName,
      'createdAt': spot.createdAt.toIso8601String(),
      'updatedAt': spot.updatedAt.toIso8601String(),
      'likesCount': spot.likesCount,
      'reviewsCount': spot.reviewsCount,
    };
    
    final spotJson = jsonEncode(spotDataForCalculation);
    int baseDocumentSize = utf8.encode(spotJson).length;
    
    // Calcular tamaño estimado de las imágenes en Base64 (Base64 incrementa ~33% el tamaño)
    int totalImageSize = 0;
    for (var imageData in images) {
      totalImageSize += (imageData.length * 1.33).round(); // Factor de conversión Base64
    }
    
    int totalEstimatedSize = baseDocumentSize + totalImageSize;
    print('Tamaño estimado del documento: ${totalEstimatedSize} bytes (límite: ${FIRESTORE_MAX_DOCUMENT_SIZE})');
    
    return totalEstimatedSize <= (FIRESTORE_MAX_DOCUMENT_SIZE * 0.9); // 90% del límite para seguridad
  }

  // Validar sitio turístico completo antes de guardarlo
  static Future<String> createTouristSpotWithValidation(TouristSpot spot, List<Uint8List>? imageDataList) async {
    try {
      print('Iniciando createTouristSpotWithValidation...');
      
      // Si hay imágenes, validar tamaño total del documento
      if (imageDataList != null && imageDataList.isNotEmpty) {
        print('Validando ${imageDataList.length} imágenes...');
        
        if (!validateTotalDocumentSize(imageDataList, spot)) {
          final totalSizeKB = imageDataList.fold<int>(0, (sum, img) => sum + img.length) ~/ 1024;
          final maxSizeKB = (FIRESTORE_MAX_DOCUMENT_SIZE * 0.5) ~/ 1024; // Recomendamos usar máximo 50% del límite
          
          throw Exception('El tamaño total de las imágenes (${totalSizeKB}KB) es demasiado grande. '
              'Para evitar errores, mantén el total de imágenes bajo ${maxSizeKB}KB. '
              'Recomendación: usa menos imágenes o comprimelas más.');
        }
        
        print('Validación de tamaño exitosa. Convirtiendo imágenes...');
        
        // Convertir imágenes con validación (optimizado para Flutter Web)
        final base64Images = await convertMultipleImagesToBase64(imageDataList);
        
        print('Imágenes convertidas exitosamente. Creando objeto TouristSpot...');
        
        // Crear sitio con imágenes
        final spotWithImages = TouristSpot(
          id: spot.id,
          title: spot.title,
          description: spot.description,
          location: spot.location,
          latitude: spot.latitude,
          longitude: spot.longitude,
          imageUrls: base64Images,
          authorId: spot.authorId,
          authorName: spot.authorName,
          createdAt: spot.createdAt,
          updatedAt: DateTime.now(), // Actualizar timestamp
          likesCount: spot.likesCount,
          reviewsCount: spot.reviewsCount,
        );
        
        print('Guardando en Firestore...');
        final result = await createTouristSpot(spotWithImages);
        print('Sitio guardado exitosamente con ID: $result');
        
        // Para Flutter Web: Pausa breve para permitir que se complete la operación
        await Future.delayed(const Duration(milliseconds: 200));
        
        return result;
      } else {
        print('Creando sitio sin imágenes...');
        // Crear sitio sin imágenes
        return await createTouristSpot(spot);
      }
    } catch (e) {
      print('Error en createTouristSpotWithValidation: $e');
      rethrow;
    }
  }

  // Método auxiliar para mostrar información sobre límites de tamaño
  static String getImageSizeInfo() {
    final maxImageKB = (MAX_IMAGE_SIZE_BYTES / 1024).round();
    final maxTotalKB = (FIRESTORE_MAX_DOCUMENT_SIZE * 0.5 / 1024).round();
    
    return '''
📸 Límites de imágenes:
• Máximo $MAX_IMAGES_COUNT imágenes por sitio
• Máximo ${maxImageKB}KB por imagen
• Tamaño total recomendado: bajo ${maxTotalKB}KB

💡 Tips para reducir tamaño:
• Usa formato JPEG en lugar de PNG
• Reduce la resolución antes de subir
• Usa herramientas de compresión de imágenes
    ''';
  }

  // Método para validar una sola imagen antes de seleccionarla
  static Map<String, dynamic> validateSingleImage(Uint8List imageData) {
    final isValid = validateImageSize(imageData);
    final sizeKB = (imageData.length / 1024).round();
    final maxSizeKB = (MAX_IMAGE_SIZE_BYTES / 1024).round();
    
    return {
      'isValid': isValid,
      'sizeKB': sizeKB,
      'maxSizeKB': maxSizeKB,
      'message': isValid 
          ? 'Imagen válida (${sizeKB}KB)'
          : 'Imagen demasiado grande (${sizeKB}KB). Máximo permitido: ${maxSizeKB}KB'
    };
  }

  // Método de test para verificar conectividad
  static Future<bool> testFirestoreConnection() async {
    try {
      print('Probando conexión a Firestore...');
      await _firestore.collection('reviews').limit(1).get();
      print('✅ Conexión a Firestore exitosa');
      return true;
    } catch (e) {
      print('❌ Error de conexión a Firestore: $e');
      return false;
    }
  }
}
