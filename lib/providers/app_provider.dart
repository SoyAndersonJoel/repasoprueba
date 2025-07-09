import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/app_models.dart';
import '../services/firebase_service.dart';

class AppProvider extends ChangeNotifier {
  UserProfile? _currentUser;
  List<TouristSpot> _touristSpots = [];
  List<TouristSpot> _favoriteSpots = [];
  bool _isLoading = false;
  bool _disposed = false;

  UserProfile? get currentUser => _currentUser;
  List<TouristSpot> get touristSpots => _touristSpots;
  List<TouristSpot> get favoriteSpots => _favoriteSpots;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get canPublish => _currentUser?.role == UserRole.publicador;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void setLoading(bool loading) {
    if (_disposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  void setUserFromAuth(UserProfile user) {
    _currentUser = user;
    print('User profile set from Auth: ${user.displayName} (${user.role})');
    
    // Usar WidgetsBinding para asegurar que notifyListeners se ejecute después del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
    
    // Cargar favoritos en segundo plano
    loadFavoriteSpots();
  }

  void clearUser() {
    _currentUser = null;
    _touristSpots = [];
    _favoriteSpots = [];
    notifyListeners();
  }

  Future<void> loadTouristSpots() async {
    setLoading(true);
    try {
      _touristSpots = await FirebaseService.getTouristSpots();
    } catch (e) {
      print('Error loading tourist spots: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> addTouristSpot(TouristSpot spot) async {
    await FirebaseService.createTouristSpot(spot);
    await loadTouristSpots();
  }

  Future<void> toggleFavorite(String spotId) async {
    if (_currentUser == null) return;
    
    await FirebaseService.toggleLike(spotId, _currentUser!.id);
    await loadFavoriteSpots();
    await loadTouristSpots(); // Refresh to update like counts
  }

  Future<void> loadFavoriteSpots() async {
    if (_currentUser == null || _disposed) return;
    
    try {
      final likedSpotIds = await FirebaseService.getLikedSpots(_currentUser!.id);
      final allSpots = await FirebaseService.getTouristSpots();
      _favoriteSpots = allSpots.where((spot) => likedSpotIds.contains(spot.id)).toList();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    } catch (e) {
      print('Error loading favorite spots: $e');
      _favoriteSpots = [];
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    }
  }

  Future<bool> isFavorite(String spotId) async {
    if (_currentUser == null) return false;
    return await FirebaseService.isLiked(spotId, _currentUser!.id);
  }

  Future<List<TouristSpot>> searchSpots(String query) async {
    return await FirebaseService.searchTouristSpots(query);
  }

  Future<void> createTouristSpot(TouristSpot spot, List<XFile> images) async {
    if (_currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    setLoading(true);
    try {
      print('Iniciando subida de sitio turístico...');
      
      // Validar número de imágenes
      if (images.length > FirebaseService.MAX_IMAGES_COUNT) {
        throw Exception('No puedes subir más de ${FirebaseService.MAX_IMAGES_COUNT} imágenes por sitio turístico.');
      }
      
      // Convertir XFile a Uint8List y validar tamaños
      final imageDataList = <Uint8List>[];
      print('Validando y convirtiendo ${images.length} imágenes...');
      
      for (int i = 0; i < images.length; i++) {
        print('Procesando imagen ${i + 1}/${images.length}...');
        final bytes = await images[i].readAsBytes();
        
        // Validar tamaño individual
        final validation = FirebaseService.validateSingleImage(bytes);
        if (!validation['isValid']) {
          throw Exception('Error en imagen ${i + 1}: ${validation['message']}');
        }
        
        imageDataList.add(bytes);
        print('Imagen ${i + 1} validada exitosamente (${validation['sizeKB']}KB)');
      }

      print('Todas las imágenes validadas. Creando sitio en Firestore...');        // Usar el método con validación completa
        try {
          print('Llamando a createTouristSpotWithValidation...');
          final docId = await FirebaseService.createTouristSpotWithValidation(spot, imageDataList);
          print('Sitio creado exitosamente con ID: $docId');
          
          // Recargar la lista sin cambiar el estado de loading
          // para evitar conflictos con la UI
          try {
            print('Recargando lista de sitios turísticos...');
            _touristSpots = await FirebaseService.getTouristSpots();
            if (!_disposed) {
              // Para Flutter Web: Forzar actualización usando addPostFrameCallback
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_disposed) {
                  notifyListeners();
                }
              });
            }
            print('Lista de sitios recargada exitosamente');
          } catch (e) {
            print('Error recargando lista de sitios: $e');
            // No lanzar el error aquí para no interrumpir el flujo de creación exitosa
          }
        } catch (e) {
          print('Error creando sitio en Firestore: $e');
          // Proporcionar mensaje más específico según el tipo de error
          if (e.toString().contains('size') && e.toString().contains('exceeds')) {
            throw Exception('Las imágenes son demasiado grandes. ${FirebaseService.getImageSizeInfo()}');
          } else if (e.toString().contains('Validación de imágenes')) {
            throw Exception(e.toString().replaceAll('Exception: ', ''));
          } else if (e.toString().contains('demasiado grande')) {
            throw Exception(e.toString().replaceAll('Exception: ', ''));
          }
          throw Exception('Error guardando en la base de datos: $e');
        }
      
    } catch (e) {
      print('Error en createTouristSpot: $e');
      rethrow;
    } finally {
      setLoading(false);
      print('Proceso de creación de sitio finalizado');
    }
  }
}
