import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class UserService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Stream para escuchar cambios en el perfil del usuario actual
  static Stream<UserProfile?> get currentUserProfileStream {
    return _supabase.auth.onAuthStateChange
        .asyncMap((data) async {
      if (data.session?.user != null) {
        return await getUserProfile(data.session!.user.id);
      }
      return null;
    });
  }

  // Obtener el perfil del usuario actual
  static Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    
    return await getUserProfile(user.id);
  }

  // Obtener perfil de usuario por ID
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error obteniendo perfil de usuario: $e');
      return null;
    }
  }

  // Crear perfil de usuario después del registro
  static Future<UserProfile?> createUserProfile({
    required String userId,
    required String email,
    String? fullName,
    UserRole role = UserRole.visitante,
  }) async {
    try {
      final userProfile = UserProfile(
        id: userId,
        email: email,
        fullName: fullName,
        role: role,
        createdAt: DateTime.now(),
      );

      final response = await _supabase
          .from('user_profiles')
          .insert(userProfile.toJson())
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error creando perfil de usuario: $e');
      return null;
    }
  }

  // Actualizar perfil de usuario
  static Future<UserProfile?> updateUserProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
    UserRole? role,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (role != null) updateData['role'] = role.value;

      final response = await _supabase
          .from('user_profiles')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error actualizando perfil de usuario: $e');
      return null;
    }
  }

  // Cambiar rol de usuario (solo para administradores)
  static Future<bool> changeUserRole(String userId, UserRole newRole) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'role': newRole.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Error cambiando rol de usuario: $e');
      return false;
    }
  }

  // Obtener todos los usuarios (para administración)
  static Future<List<UserProfile>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((user) => UserProfile.fromJson(user))
          .toList();
    } catch (e) {
      print('Error obteniendo usuarios: $e');
      return [];
    }
  }

  // Verificar si el usuario actual tiene un rol específico
  static Future<bool> hasRole(UserRole role) async {
    final profile = await getCurrentUserProfile();
    return profile?.role == role;
  }

  // Verificar si el usuario actual puede publicar
  static Future<bool> canPublish() async {
    final profile = await getCurrentUserProfile();
    return profile?.canPublish ?? false;
  }

  // Verificar si el usuario actual puede subir fotos
  static Future<bool> canUploadPhotos() async {
    final profile = await getCurrentUserProfile();
    return profile?.canUploadPhotos ?? false;
  }

  // Verificar si el usuario actual puede gestionar reseñas
  static Future<bool> canManageReviews() async {
    final profile = await getCurrentUserProfile();
    return profile?.canManageReviews ?? false;
  }
}
