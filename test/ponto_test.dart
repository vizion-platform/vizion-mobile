import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizion_mobile/features/ponto/domain/ponto_record_model.dart';
import 'package:vizion_mobile/features/ponto/data/ponto_service.dart';
import 'package:vizion_mobile/features/ponto/presentation/ponto_screen.dart';
import 'package:vizion_mobile/features/ponto/presentation/widgets/slide_to_punch_button.dart';
import 'package:vizion_mobile/features/ponto/presentation/widgets/ponto_timeline_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PontoDomain & Service Tests', () {
    test('PontoDay calculates worked hours and balance correctly', () {
      final date = DateTime(2026, 8, 15);
      final punches = [
        PontoPunch(
          id: 'p1',
          type: PontoType.entrada,
          timestamp: DateTime(2026, 8, 15, 8, 0),
        ),
        PontoPunch(
          id: 'p2',
          type: PontoType.saidaAlmoco,
          timestamp: DateTime(2026, 8, 15, 12, 0),
        ),
        PontoPunch(
          id: 'p3',
          type: PontoType.retornoAlmoco,
          timestamp: DateTime(2026, 8, 15, 13, 0),
        ),
        PontoPunch(
          id: 'p4',
          type: PontoType.saida,
          timestamp: DateTime(2026, 8, 15, 17, 30),
        ),
      ];

      final day = PontoDay(date: date, punches: punches);

      // Period 1: 8h to 12h = 4h (240 min)
      // Period 2: 13h to 17h30 = 4h30 (270 min)
      // Total: 510 minutes = 8h 30m
      expect(day.workedMinutes, equals(510));
      expect(day.formattedWorkedHours, equals('08h 30m'));
      expect(day.balanceMinutes, equals(30)); // +30m
      expect(day.formattedBalanceHours, equals('+00h 30m'));
    });

    test('PontoService registers punches in sequence', () async {
      SharedPreferences.setMockInitialValues({});

      final today = await PontoService.getTodayPonto();
      expect(PontoService.getNextPunchType(today), equals(PontoType.entrada));

      final res1 = await PontoService.registerPunch(type: PontoType.entrada);
      expect(res1.punch.type, equals(PontoType.entrada));
      expect(PontoService.getNextPunchType(res1.day), equals(PontoType.saidaAlmoco));

      final res2 = await PontoService.registerPunch(type: PontoType.saidaAlmoco);
      expect(res2.punch.type, equals(PontoType.saidaAlmoco));
      expect(PontoService.getNextPunchType(res2.day), equals(PontoType.retornoAlmoco));
    });

    test('PontoService loads and retains previous days history in Espelho de Ponto', () async {
      final now = DateTime.now();
      final summary = await PontoService.getMonthPonto(now.year, now.month);
      expect(summary.year, equals(now.year));
      expect(summary.month, equals(now.month));
      expect(summary.days, isNotNull);
    });
  });

  group('PontoScreen Widget Tests', () {
    testWidgets('Renders PontoScreen with Bater Ponto and Espelho de Ponto tabs', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: PontoScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Tab titles
      expect(find.text('Bater Ponto'), findsOneWidget);
      expect(find.text('Espelho de Ponto'), findsOneWidget);

      // Verify Digital Clock Header
      expect(find.text('HORA ATUAL OFICIAL'), findsOneWidget);
      expect(find.text('GPS Ativo'), findsOneWidget);

      // Verify Worked Hours section
      expect(find.text('Horas Trabalhadas Hoje'), findsOneWidget);

      // Verify Timeline section & stages
      expect(find.text('Linha do Tempo'), findsOneWidget);
      expect(find.text('Entrada'), findsWidgets);
      expect(find.text('Saída Almoço'), findsWidgets);
      expect(find.text('Volta Almoço'), findsWidgets);
      expect(find.text('Saída'), findsWidgets);

      // Tap on 'Espelho de Ponto' tab
      await tester.tap(find.text('Espelho de Ponto'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Banco de Horas card
      expect(find.text('SALDO DO BANCO DE HORAS'), findsOneWidget);
      expect(find.text('Trabalhadas'), findsOneWidget);
      expect(find.text('Previstas'), findsOneWidget);
    });

    testWidgets('Ponto subwidgets on narrow 340x831 dimensions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(340, 831);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final today = await PontoService.getTodayPonto();
      final nextType = PontoService.getNextPunchType(today);

      // Subtest 1: SlideToPunchButton alone
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: SlideToPunchButton(
                nextPunchType: nextType,
                onConfirmed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'SlideToPunchButton overflowed');

      // Subtest 2: PontoTimelineWidget alone
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: PontoTimelineWidget(
                todayDay: today,
                nextPunchType: nextType,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'PontoTimelineWidget overflowed');

      // Subtest 3: Full PontoScreen (Bater Ponto Tab)
      await tester.pumpWidget(
        const MaterialApp(
          home: PontoScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'PontoScreen Bater Ponto tab overflowed');

      // Subtest 4: Switch to Espelho de Ponto Tab on 340x831
      await tester.tap(find.text('Espelho de Ponto'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('SALDO DO BANCO DE HORAS'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'PontoScreen Espelho de Ponto tab overflowed');
    });

    testWidgets('SlideToPunchButton triggers confirmation on slide', (tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: SlideToPunchButton(
                  nextPunchType: PontoType.entrada,
                  onConfirmed: () {
                    confirmed = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Drag across the button from left to right
      final buttonFinder = find.byType(SlideToPunchButton);
      expect(buttonFinder, findsOneWidget);

      await tester.drag(buttonFinder, const Offset(300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(confirmed, isTrue);

      // Advance reset timer
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
