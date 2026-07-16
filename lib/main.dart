import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'ui/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:odonto_controle/screens/public/public_evaluation_screen.dart';

// Importando as telas
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_check_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('pt_BR', null); 

  runApp(const ClinicApp());
}

class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consultório Odontológico',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),

      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // AQUI MUDOU: Em vez de colocar o StreamBuilder direto, chamamos o Wrapper
      home: const AuthWrapper(), 
      routes: {
        // ... suas rotas existentes
        '/avaliacao': (context) => PublicEvaluationScreen(),
      },
    );
  }
}

// --- NOVA CLASSE: O GUARDIAO DO LOGIN ---
// Essa classe é quem decide se mostra Login ou Dashboard
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Se tem usuário logado, vai para a checagem de cargo/dashboard
        if (snapshot.hasData) return const RoleCheckScreen();
        // Se não tem, mostra login
        return const LoginScreen();
      },
    );
  }
}