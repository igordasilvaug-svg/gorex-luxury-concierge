import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/core/billing/accounting_export_service.dart';
import 'package:gorex_concierge/core/billing/reconciliation_service.dart';
import 'package:gorex_concierge/core/billing/reminder_service.dart';
import 'package:gorex_concierge/models/enums.dart';
import 'package:gorex_concierge/models/finance.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/finance/accounting_screen.dart';

Future<AppState> _ready() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await state.init();
  return state;
}

Widget _host(AppState state, Widget child) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: child)),
    );

FinanceDocument _invoice({
  String id = 'f1',
  String ref = 'GRX-INV-2025-0001',
  double unit = 1000,
  double tax = 21,
  double paid = 0,
  int dueInDays = -30,
  String? comm = '+++000/0000/00001+++',
  String client = 'Dimitri Kalashov',
  InvoiceStatus status = InvoiceStatus.sent,
}) => FinanceDocument(
  id: id,
  reference: ref,
  type: FinanceDocType.invoice,
  clientId: 'c1',
  clientName: client,
  date: DateTime.now().subtract(Duration(days: dueInDays.abs() + 30)),
  dueDate: DateTime.now().add(Duration(days: dueInDays)),
  lines: [FinanceLine(description: 'Prestation', unitPrice: unit)],
  taxPercent: tax,
  status: status,
  amountPaid: paid,
  structuredCommunication: comm,
);

BankTransaction _tx({
  String id = 'bt1',
  double amount = 1210,
  String comm = '+++000/0000/00001+++',
  String cp = 'Dimitri Kalashov',
}) => BankTransaction(
  id: id,
  date: DateTime.now(),
  amount: amount,
  counterparty: cp,
  communication: comm,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('ReconciliationService — scoring', () {
    test('OGM + montant identiques → score élevé', () {
      final d = _invoice();
      final t = _tx();
      final score = ReconciliationService.score(t, d);
      expect(score, greaterThanOrEqualTo(0.9));
    });

    test('facture payée → score nul', () {
      final d = _invoice(paid: 1210, status: InvoiceStatus.paid);
      final t = _tx();
      expect(ReconciliationService.score(t, d), 0);
    });

    test('montant différent et pas de communication → score faible', () {
      final d = _invoice(comm: null);
      final t = _tx(amount: 50, comm: 'Virement');
      expect(ReconciliationService.score(t, d), lessThan(0.5));
    });

    test('reconcile retourne la meilleure facture', () {
      final d1 = _invoice(id: 'a', ref: 'GRX-INV-2025-0001');
      final d2 = _invoice(
        id: 'b',
        ref: 'GRX-INV-2025-0002',
        unit: 5000,
        comm: '+++000/0000/00002+++',
      );
      final t = _tx(amount: 1210, comm: '+++000/0000/00001+++');
      final m = ReconciliationService.reconcile(t, [d1, d2]);
      expect(m.matched, true);
      expect(m.document!.id, 'a');
      expect(m.method, PaymentMatchMethod.structuredCommunication);
    });

    test('reconcile sous le seuil → non rapproché', () {
      final d = _invoice(comm: null);
      final t = _tx(amount: 3, comm: 'xyz');
      final m = ReconciliationService.reconcile(t, [d]);
      expect(m.matched, false);
    });

    test('autoMatch n\'utilise pas deux fois la même facture', () {
      final d = _invoice(id: 'a');
      final t1 = _tx(id: 't1', amount: 1210);
      final t2 = _tx(id: 't2', amount: 1210);
      final matches = ReconciliationService.autoMatch([t1, t2], [d]);
      final matched = matches.where((m) => m.matched).length;
      expect(matched, 1);
    });
  });

  group('ReminderService — escalade', () {
    test('seuils de niveau par jours de retard', () {
      expect(ReminderService.targetLevel(0), ReminderLevel.none);
      expect(ReminderService.targetLevel(10), ReminderLevel.first);
      expect(ReminderService.targetLevel(25), ReminderLevel.second);
      expect(ReminderService.targetLevel(60), ReminderLevel.finalNotice);
    });

    test('facture non échue → pas de relance', () {
      final d = _invoice(dueInDays: 10);
      expect(ReminderService.plan(d).due, false);
    });

    test('facture échue 10 jours → 1ʳᵉ relance due', () {
      final d = _invoice(dueInDays: -10);
      final p = ReminderService.plan(d);
      expect(p.due, true);
      expect(p.nextLevel, ReminderLevel.first);
    });

    test('déjà relancée au niveau cible → pas de nouvelle relance', () {
      final d = _invoice(dueInDays: -10)
          .copyWith(reminderLevel: ReminderLevel.first);
      expect(ReminderService.plan(d).due, false);
    });

    test('anti-spam : délai minimum entre relances', () {
      final d = _invoice(dueInDays: -25).copyWith(
        reminderLevel: ReminderLevel.first,
        lastReminderAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      final p = ReminderService.plan(d);
      expect(p.due, false);
      expect(p.reason.contains('jour'), true);
    });

    test('pending ne retourne que les relances à envoyer', () {
      final due = _invoice(id: 'a', dueInDays: -10);
      final ok = _invoice(id: 'b', dueInDays: 5);
      final plans = ReminderService.pending([due, ok]);
      expect(plans.length, 1);
      expect(plans.first.document.id, 'a');
    });

    test('email de mise en demeure contient la référence et le montant', () {
      final d = _invoice(dueInDays: -60);
      final mail = ReminderService.buildEmail(
        d,
        ReminderLevel.finalNotice,
        companyName: 'GOREX LUXURY CONCIERGE',
        companyVat: 'BE0000000000',
        iban: 'BE00 0000 0000 0000',
      );
      expect(mail.subject.contains(d.reference), true);
      expect(mail.body.contains('Mise en demeure') ||
          mail.body.contains('contentieux'), true);
      expect(mail.body.contains(d.structuredCommunication!), true);
    });
  });

  group('AccountingExportService — journal des ventes', () {
    test('CSV : en-tête + une ligne par facture + totaux', () {
      final docs = [
        _invoice(id: 'a', ref: 'GRX-INV-2025-0001', unit: 1000, tax: 21),
        _invoice(id: 'b', ref: 'GRX-INV-2025-0002', unit: 2000, tax: 0),
      ];
      final csv = AccountingExportService.buildSalesJournalCsv(docs);
      final lines = csv.trim().split('\n');
      expect(lines.first.contains('Reference'), true);
      expect(lines.length, 4); // header + 2 factures + totaux
      expect(csv.contains('TOTAUX'), true);
      // Décimales belges (virgule)
      expect(csv.contains(','), true);
    });

    test('CSV : filtre par exercice', () {
      final docs = [
        FinanceDocument(
          id: 'a',
          reference: 'GRX-INV-2024-0001',
          type: FinanceDocType.invoice,
          clientId: 'c1',
          clientName: 'X',
          date: DateTime(2024, 1, 1),
          lines: const [FinanceLine(description: 'x', unitPrice: 100)],
        ),
      ];
      final csv = AccountingExportService.buildSalesJournalCsv(docs, year: 2025);
      // Seulement l'en-tête et la ligne de totaux (aucune facture 2025).
      expect(csv.trim().split('\n').length, 2);
    });
  });

  group('AppState — module comptable', () {
    test('bankTransactions seedées et persistées', () async {
      final s = await _ready();
      expect(s.bankTransactions, isNotEmpty);
      expect(s.unmatchedTransactions, isNotEmpty);
    });

    test('markInvoicePaid solde la facture', () async {
      final s = await _ready();
      final d = _invoice(id: 'z1', unit: 1000, tax: 0);
      s.financeDocs.add(d);
      await s.markInvoicePaid('z1');
      final after = s.financeById('z1')!;
      expect(after.status, InvoiceStatus.paid);
      expect(after.amountPaid, 1000);
      expect(after.paidAt, isNotNull);
    });

    test('reconcileTransaction marque la transaction et paie la facture',
        () async {
      final s = await _ready();
      final d = _invoice(id: 'z2', unit: 1000, tax: 0);
      s.financeDocs.add(d);
      s.bankTransactions.add(_tx(id: 'btz', amount: 1000, comm: 'GRX-INV-2025-0001'));
      await s.reconcileTransaction('btz', 'z2');
      expect(s.financeById('z2')!.status, InvoiceStatus.paid);
      expect(
        s.bankTransactions.firstWhere((t) => t.id == 'btz').matched,
        true,
      );
    });

    test('autoReconcile rapproche automatiquement les crédits', () async {
      final s = await _ready();
      final n = await s.autoReconcile();
      expect(n, greaterThan(0));
      expect(s.unmatchedTransactions.length, lessThan(5));
    });

    test('sendReminder fait progresser le niveau', () async {
      final s = await _ready();
      final d = _invoice(id: 'z3', dueInDays: -10);
      s.financeDocs.add(d);
      final plan = await s.sendReminder('z3');
      expect(plan!.due, true);
      expect(s.financeById('z3')!.reminderLevel, ReminderLevel.first);
      expect(s.financeById('z3')!.status, InvoiceStatus.overdue);
    });

    test('overdueCount / overdueAmount', () async {
      final s = await _ready();
      expect(s.overdueCount, greaterThanOrEqualTo(1));
      expect(s.overdueAmount, greaterThan(0));
    });

    test('buildReminderEmail utilise la société', () async {
      final s = await _ready();
      final d = _invoice(dueInDays: -60);
      final mail = s.buildReminderEmail(d, ReminderLevel.finalNotice);
      expect(mail.subject, isNotEmpty);
      expect(mail.body.contains('GOREX'), true);
    });

    test('persistance : rechargement conserve les transactions', () async {
      final s = await _ready();
      await s.markInvoicePaid(
        s.financeDocs.firstWhere((d) => d.type == FinanceDocType.invoice).id,
      );
      final s2 = AppState();
      await s2.init();
      expect(s2.bankTransactions.length, s.bankTransactions.length);
    });
  });

  group('AccountingScreen — rendu', () {
    testWidgets('affiche les KPIs et les onglets', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_host(s, const AccountingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Comptabilité'), findsOneWidget);
      expect(find.text('Rapprochement'), findsOneWidget);
      expect(find.text('Relances'), findsOneWidget);
      expect(find.text('Export comptable'), findsOneWidget);
    });

    testWidgets('onglet relances affiche les impayés', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_host(s, const AccountingScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relances'));
      await tester.pumpAndSettle();
      expect(find.text('Factures échues'), findsOneWidget);
    });
  });
}
