import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/local_store.dart';

void main() {
  late Directory directory;
  late LocalStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('saldo-test');
    store = LocalStore(File('${directory.path}/data.json'));
    await store.saveAccount(Account(id: 'rub', name: 'Карта', opening: 100000));
    await store.saveAccount(Account(id: 'cash', name: 'Наличные'));
    await store.saveAccount(
      Account(
        id: 'broker',
        name: 'Брокер',
        kind: 'Инвестиции',
        opening: 1000000,
      ),
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'Expense, income and transfer survive reopening without double counting',
    () async {
      await store.saveOperation(
        Operation(
          id: 'expense',
          date: '2026-11-01',
          type: 'expense',
          account: 'rub',
          amount: 12550,
          category: 'Продукты',
        ),
      );
      await store.saveOperation(
        Operation(
          id: 'income',
          date: '2026-11-02',
          type: 'income',
          account: 'rub',
          amount: 20000,
          category: 'Зарплата',
        ),
      );
      await store.saveOperation(
        Operation(
          id: 'transfer',
          date: '2026-11-03',
          type: 'transfer',
          account: 'rub',
          target: 'cash',
          amount: 10000,
          received: 10000,
        ),
      );
      final reopened = LocalStore(store.file);
      await reopened.load();
      expect(reopened.balance('rub'), 97450);
      expect(reopened.balance('cash'), 10000);
      expect(reopened.total(DateTime(2026, 11), 'expense'), 12550);
      expect(reopened.total(DateTime(2026, 11), 'income'), 20000);
      expect(reopened.capital, 1107450);
      await reopened.deleteOperation('expense');
      expect(reopened.balance('rub'), 110000);
    },
  );

  test(
    'Trades include fees, realized profit, taxes and partial sales',
    () async {
      await store.saveTrade(
        Trade(
          id: 'b',
          date: '2026-01-01',
          account: 'broker',
          symbol: 'TEST',
          name: 'Тест',
          side: 'buy',
          units: 10000000,
          price: 10000,
          fee: 100,
        ),
      );
      await store.saveQuote('broker', 'TEST', 12000);
      expect(store.positions('broker').single.value, 120000);
      expect(store.positions('broker').single.profit, 19900);
      await store.saveTrade(
        Trade(
          id: 's',
          date: '2026-01-02',
          account: 'broker',
          symbol: 'TEST',
          name: 'Тест',
          side: 'sell',
          units: 4000000,
          price: 12000,
          fee: 50,
          tax: 1000,
        ),
      );
      final p = store.positions('broker').single;
      expect(p.units, 6000000);
      expect(p.cost, 60060);
      expect(p.realized, 6910);
      expect(p.profit, 18850);
      expect(store.balance('broker'), 946850);
      expect(store.capital, 1118850);
    },
  );

  test(
    'CSV deduplication and conflict rejection are atomic across reloads',
    () async {
      final rows = store.parseReport(sampleReport, 'broker');
      await store.importTrades(rows);
      final reopened = LocalStore(store.file);
      await reopened.load();
      await reopened.importTrades(rows);
      expect(reopened.trades.length, 4);
      final conflict = store.parseReport(
        sampleReport.replaceFirst('6000,6.55', '6000,9.55'),
        'broker',
      );
      await expectLater(reopened.importTrades(conflict), throwsFormatException);
      expect(reopened.trades.length, 4);
      expect(reopened.trades.first.price, 655);
      await expectLater(
        reopened.saveTrade(
          Trade(
            id: 'oversell',
            date: '2026-02-01',
            account: 'broker',
            symbol: 'TMOS',
            name: 'Фонд',
            side: 'sell',
            units: 99999999999,
            price: 800,
          ),
        ),
        throwsFormatException,
      );
      expect(reopened.trades.length, 4);
    },
  );

  test(
    'FX transfers and paid dividends update balances exactly once',
    () async {
      await store.saveAccount(
        Account(
          id: 'usd',
          name: 'USD',
          currency: 'USD',
          opening: 10000,
          rate: 90000000,
        ),
      );
      await store.saveOperation(
        Operation(
          id: 'fx',
          date: '2026-01-01',
          type: 'transfer',
          account: 'rub',
          target: 'usd',
          amount: 9000,
          received: 100,
        ),
      );
      expect(store.balance('rub'), 91000);
      expect(store.balance('usd'), 10100);
      final payout = Payout(
        id: 'coupon',
        account: 'broker',
        symbol: 'BOND',
        date: '2026-01-01',
        amount: 10000,
        tax: 1300,
        type: 'Купон',
      );
      await store.savePayout(payout);
      expect(store.balance('broker'), 1000000);
      await store.togglePayout(store.payouts.single);
      expect(store.balance('broker'), 1008700);
      expect(store.total(DateTime(2026, 1), 'income', 'Купон'), 8700);
      await store.togglePayout(store.payouts.single);
      expect(store.balance('broker'), 1000000);
    },
  );

  test(
    'Invalid CSV, impossible dates and excessive precision are rejected',
    () {
      expect(
        () => store.parseReport('trade_id,amount\ntrade-1,100', 'broker'),
        throwsFormatException,
      );
      expect(
        () => store.parseReport(
          sampleReport.replaceFirst('2026-01-10', '2026-02-30'),
          'broker',
        ),
        throwsFormatException,
      );
      expect(() => decimal('0.001'), throwsFormatException);
      expect(decimal('12,34'), 1234);
      expect(
        () => store.parseReport(
          sampleReport.replaceFirst('6000,6.55', '-1,6.55'),
          'broker',
        ),
        throwsFormatException,
      );
    },
  );

  test('Write failure restores in-memory state and a corrupt file is not overwritten', () async {
    final invalid = LocalStore(File('/dev/null/saldo.json'));
    await expectLater(
      invalid.saveAccount(Account(id: 'x', name: 'X')),
      throwsA(isA<FileSystemException>()),
    );
    expect(invalid.accounts, isEmpty);
    await store.file.writeAsString('broken json');
    final reopened = LocalStore(store.file);
    await expectLater(reopened.load(), throwsFormatException);
    expect(await store.file.readAsString(), 'broken json');
  });
}
