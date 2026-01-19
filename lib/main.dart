import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_size/window_size.dart';

import 'db/database_helper.dart';
import 'views/home_page.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> _configureWindow() async {
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setWindowTitle('Manutenção de Viaturas');

      final screens = await getScreenList();
      final primary = screens.first;

      const double largura = 1400;
      final double altura = primary.visibleFrame.height;

      setWindowFrame(
        Rect.fromLTWH(
          (primary.visibleFrame.width - largura) / 2 +
              primary.visibleFrame.left,
          primary.visibleFrame.top,
          largura,
          altura,
        ),
      );

      setWindowMinSize(const Size(1400, 850));
      setWindowMaxSize(Size.infinite);
    }
  } catch (_) {
    // window_size não disponível/permitido -> ignora
  }
}

void main() {
  runZonedGuarded(
    () async {
      // Tudo dentro da MESMA zone:
      WidgetsFlutterBinding.ensureInitialized();

      // Localização pt-BR (datas etc.)
      try {
        await initializeDateFormatting('pt_BR', null);
      } catch (_) {}

      // Janela (desktop)
      await _configureWindow();

      // Banco: garante APPDATA + migrações aplicadas
      try {
        await DatabaseHelper.warmUp();
      } catch (e) {
        debugPrint('Falha ao abrir banco: $e');
      }

      runApp(const MyApp());
    },
    (error, stack) {
      // Log de exceções não capturadas
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manutenção de Viaturas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [routeObserver],
      home: const HomePage(),
    );
  }
}
