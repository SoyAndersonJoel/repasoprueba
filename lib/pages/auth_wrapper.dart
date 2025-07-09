import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/app_models.dart';
import '../login_page.dart';
import 'home/main_navigation.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        
        if (session != null) {
          return FutureBuilder<UserProfile?>(
            future: _getUserProfile(context, session.user),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                          Colors.orange.shade800,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Configurando tu perfil...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              if (profileSnapshot.hasError) {
                print('Error in profile snapshot: ${profileSnapshot.error}');
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al configurar tu perfil',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Forzar recarga del perfil
                            (context as Element).markNeedsBuild();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Si llegamos aquí, el perfil se creó/cargó exitosamente
              return const MainNavigation();
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }

  Future<UserProfile?> _getUserProfile(BuildContext context, User user) async {
    try {
      print('AuthWrapper: Loading profile for user ID: ${user.id}');
      final provider = Provider.of<AppProvider>(context, listen: false);
      
      // Crear UserProfile directamente desde Auth de Supabase
      final userProfile = UserProfile.fromSupabaseAuth(user);
      
      // Asignar al provider
      provider.setUserFromAuth(userProfile);
      
      print('AuthWrapper: Profile created from Auth - ${userProfile.displayName} (${userProfile.role})');
      
      return userProfile;
    } catch (e) {
      print('Error creating user profile from Auth: $e');
      throw e; // Re-lanzar para que se maneje en el FutureBuilder
    }
  }
}
