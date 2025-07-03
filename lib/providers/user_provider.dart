import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  // Getters de conveniencia para permisos
  bool get canPublish => _currentUser?.canPublish ?? false;
  bool get canUploadPhotos => _currentUser?.canUploadPhotos ?? false;
  bool get canManageReviews => _currentUser?.canManageReviews ?? false;
  bool get canViewContent => _currentUser?.canViewContent ?? false;
  
  UserRole? get userRole => _currentUser?.role;
  String get userRoleDisplayName => _currentUser?.role.displayName ?? 'Sin rol';

  // Inicializar el provider
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadCurrentUser();
      _listenToAuthChanges();
    } catch (e) {
      _setError('Error inicializando usuario: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cargar usuario actual
  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await UserService.getCurrentUserProfile();
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Error cargando perfil de usuario: $e');
    }
  }

  // Escuchar cambios en la autenticación
  void _listenToAuthChanges() {
    UserService.currentUserProfileStream.listen(
      (userProfile) {
        _currentUser = userProfile;
        _clearError();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error en el stream de usuario: $error');
      },
    );
  }

  // Crear perfil después del registro
  Future<bool> createUserProfile({
    required String userId,
    required String email,
    String? fullName,
    UserRole role = UserRole.visitante,
  }) async {
    _setLoading(true);
    try {
      final userProfile = await UserService.createUserProfile(
        userId: userId,
        email: email,
        fullName: fullName,
        role: role,
      );

      if (userProfile != null) {
        _currentUser = userProfile;
        _clearError();
        notifyListeners();
        return true;
      } else {
        _setError('Error creando perfil de usuario');
        return false;
      }
    } catch (e) {
      _setError('Error creando perfil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Actualizar perfil de usuario
  Future<bool> updateProfile({
    String? fullName,
    String? avatarUrl,
    UserRole? role,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    try {
      final updatedProfile = await UserService.updateUserProfile(
        userId: _currentUser!.id,
        fullName: fullName,
        avatarUrl: avatarUrl,
        role: role,
      );

      if (updatedProfile != null) {
        _currentUser = updatedProfile;
        _clearError();
        notifyListeners();
        return true;
      } else {
        _setError('Error actualizando perfil');
        return false;
      }
    } catch (e) {
      _setError('Error actualizando perfil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Cambiar rol de usuario
  Future<bool> changeRole(UserRole newRole) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    try {
      final success = await UserService.changeUserRole(_currentUser!.id, newRole);
      if (success) {
        _currentUser = _currentUser!.copyWith(role: newRole);
        _clearError();
        notifyListeners();
        return true;
      } else {
        _setError('Error cambiando rol de usuario');
        return false;
      }
    } catch (e) {
      _setError('Error cambiando rol: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Cerrar sesión
  void logout() {
    _currentUser = null;
    _clearError();
    notifyListeners();
  }

  // Recargar perfil
  Future<void> refreshProfile() async {
    await _loadCurrentUser();
  }

  // Métodos privados para manejo de estado
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // Verificar permisos específicos
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;

    switch (permission) {
      case 'publish':
        return _currentUser!.canPublish;
      case 'upload_photos':
        return _currentUser!.canUploadPhotos;
      case 'manage_reviews':
        return _currentUser!.canManageReviews;
      case 'view_content':
        return _currentUser!.canViewContent;
      default:
        return false;
    }
  }
}
