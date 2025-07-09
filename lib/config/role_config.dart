/// Configuración de roles y permisos para la aplicación El Búho
class RoleConfig {
  /// Lista de emails autorizados para ser Publicadores
  /// Solo estos usuarios pueden publicar sitios turísticos
  static const List<String> AUTHORIZED_PUBLISHERS = [
    'joel.vilatuna123@gmail.com',
    // Agregar más emails aquí si necesario
  ];

  /// Determina si un email está autorizado para ser publicador
  static bool isAuthorizedPublisher(String email) {
    return AUTHORIZED_PUBLISHERS.contains(email.toLowerCase().trim());
  }

  /// Obtiene el rol apropiado basado en el email
  static String getRoleForEmail(String email) {
    return isAuthorizedPublisher(email) ? 'publicador' : 'visitante';
  }

  /// Obtiene el nombre de display apropiado basado en el rol
  static String getDisplayNameForRole(String email) {
    return isAuthorizedPublisher(email) ? 'Publicador Autorizado' : 'Visitante';
  }
}
