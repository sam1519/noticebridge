import 'package:flutter_test/flutter_test.dart';
import 'package:noticebridge/models/models.dart';

void main() {
  test('Notice.fromJson reads summary levels', () {
    final n = Notice.fromJson({
      '_id': '1',
      'title': 'Test',
      'summary': {'simple': 'a', 'verySimple': 'b', 'detailed': 'c'},
      'createdAt': '2026-11-17T10:00:00.000Z',
    });
    expect(n.summaryFor('verySimple'), 'b');
    expect(n.summaryFor('detailed'), 'c');
    expect(n.summaryFor('simple'), 'a');
  });
}
