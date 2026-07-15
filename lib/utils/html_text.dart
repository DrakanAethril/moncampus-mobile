/// Strips HugeRTE-authored sanitized HTML (as sent as-is by the backend, e.g. Message::$body,
/// Announcement::$body) down to plain text for display - not a full HTML renderer, just enough
/// for a browsing-only mobile client that doesn't want a new rendering dependency.
String stripHtmlToPlainText(String html) {
  final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), '\n');
  final decoded = withoutTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  return decoded.replaceAll(RegExp(r'\n{2,}'), '\n\n').trim();
}
