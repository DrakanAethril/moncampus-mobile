import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/work_item.dart';

/// A « À lire » is settled by its document being opened, and the phone has to be able to name that
/// document to the server - that is the whole of `readingAttachmentId` and of the attachment's own
/// `id`. Both are read here because both are what the row and the sheet call the open route with;
/// an app that lost them would go back to launching the address itself and leaving no trace.
void main() {
  group('WorkItem reading', () {
    test('names the lone support the row opens', () {
      final item = WorkItem.fromJson({
        'id': 12,
        'title': 'Lire le chapitre 3',
        'state': 'todo',
        'dueDate': '2026-09-14T08:00:00+02:00',
        'action': 'read',
        'nature': 'to_read',
        'readingAttachmentId': 7,
      });

      expect(item.action, WorkAction.read);
      expect(item.readingAttachmentId, 7);
    });

    test('names none when the travail carries several, the sheet taking over',
        () {
      final item = WorkItem.fromJson({
        'id': 12,
        'title': 'Lire les deux chapitres',
        'state': 'todo',
        'dueDate': '2026-09-14T08:00:00+02:00',
        'action': 'read',
        'nature': 'to_read',
      });

      expect(item.readingAttachmentId, isNull);
    });
  });

  group('WorkAttachment', () {
    test('carries the id the open route is called with', () {
      final attachment = WorkAttachment.fromJson({
        'id': 7,
        'label': 'Chapitre 3.pdf',
        'kind': 'PDF',
        'url': 'https://cdn.example.org/abc.pdf',
      });

      expect(attachment.id, 7);
      expect(attachment.label, 'Chapitre 3.pdf');
    });

    test('falls back on its address when the server names no id', () {
      final attachment = WorkAttachment.fromJson({
        'label': 'Chapitre 3.pdf',
        'kind': 'PDF',
        'url': 'https://cdn.example.org/abc.pdf',
      });

      expect(attachment.id, isNull);
      expect(attachment.url, isNotNull);
    });
  });
}
