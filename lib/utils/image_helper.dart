import 'package:flutter/foundation.dart';

class ImageHelper {
  /// Valida si una URL de imagen es válida
  static bool isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      
      // Verificar que sea una URL absoluta con esquema http/https
      if (!uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return false;
      }
      
      // Verificar que tenga un host válido
      if (uri.host.isEmpty) {
        return false;
      }
      
      // Lista de extensiones y dominios válidos para imágenes
      final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
      final validDomains = [
        'firebasestorage.googleapis.com',
        'storage.googleapis.com',
        'lh3.googleusercontent.com',
        'supabase.co',
        'imgur.com',
        'picsum.photos'
      ];
      
      // Verificar si la URL contiene una extensión de imagen válida
      final hasValidExtension = validExtensions.any((ext) => 
        url.toLowerCase().contains(ext));
      
      // Verificar si es de un dominio conocido de imágenes
      final hasValidDomain = validDomains.any((domain) => 
        url.contains(domain));
      
      return hasValidExtension || hasValidDomain;
      
    } catch (e) {
      if (kDebugMode) {
        print('Error validating image URL: $e');
      }
      return false;
    }
  }

  /// Obtiene headers HTTP apropiados para cargar imágenes
  static Map<String, String> getImageHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
      'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'es-ES,es',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };
  }

  /// Limpia URLs de imágenes removiendo parámetros innecesarios
  static String cleanImageUrl(String url) {
    if (url.isEmpty) return url;
    
    try {
      final uri = Uri.parse(url);
      // Para Firebase Storage, mantener solo los parámetros esenciales
      if (url.contains('firebasestorage.googleapis.com')) {
        return uri.toString();
      }
      return url;
    } catch (e) {
      return url;
    }
  }
}
