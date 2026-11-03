import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/screens/agenda/clinical_agenda_view.dart';
import 'package:odonto_controle/screens/dashboard/clinical_user_footer.dart';
import 'package:odonto_controle/ui/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [220.0, 288.0, 320.0]) {
      testWidgets('tema junto de Sair no rodapé $width / escuro $dark', (
        tester,
      ) async {
        AppColors.isDark = dark;
        addTearDown(() => AppColors.isDark = false);
        var changes = 0, logouts = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ClinicalAgendaStyle.theme,
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: Column(
                  children: [
                    const Expanded(child: Text('Navegação')),
                    ClinicalUserFooter(
                      name: 'Laucieli Costa de Sobrenome Longo',
                      subtitle: 'owner • Unidade de Sobrenome Longo',
                      dark: dark,
                      onLogout: () => logouts++,
                      onTheme: () => changes++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final theme = find.byKey(const ValueKey('clinical-theme-toggle'));
        final logout = find.byKey(const ValueKey('clinical-logout'));
        expect(theme, findsOneWidget);
        expect(
          tester.getCenter(theme).dy,
          greaterThan(tester.getCenter(logout).dy),
        );
        expect(tester.getCenter(theme).dx, tester.getCenter(logout).dx);
        expect(tester.getRect(theme).right, lessThanOrEqualTo(width));
        expect(tester.getRect(theme).top, greaterThan(400));
        await tester.tap(
          find.byTooltip(dark ? 'Usar modo claro' : 'Usar modo escuro'),
        );
        await tester.tap(logout);
        expect(changes, 1);
        expect(logouts, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
