import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared utility for parsing rich text formatting in journey content.
///
/// Supports:
/// - `**bold**` → bold text
/// - `*italic*` → italic text
/// - `{red|text}` → primary-colored text (with nested formatting)
/// - `Label:` at start of line → auto-bolded label
///
/// Used by journey screens to render formatted JSON content.
class RichTextParser {
  RichTextParser._();

  static final RegExp _malformedBibleCitationRegex = RegExp(
    r'\(((?:[1-3]\s*)?[A-Za-z]+(?:\s+[A-Za-z]+){0,5}\s+\d{1,3}:\d{1,3}(?:-\d{1,3})?)\|[^)]*\)',
  );

  // Bare Bible reference without parentheses: "James 1:27" or "1 John 2:3"
  // Matches at word boundaries followed by punctuation or whitespace
  static final RegExp _bareReferenceRegex = RegExp(
    r'\b((?:[1-3]\s+)?[A-Za-z]+(?:\s+[A-Za-z]+){0,5}\s+\d{1,3}:\d{1,3}(?:-\d{1,3})?)\b(?=[.,;:\s]|$)',
  );

  // Bible reference with pipe but no opening paren: "James 1:27|." or "James 1:27|text)"
  // Much more conservative: just match the ref, pipe, and minimal trailing content
  // This prevents consuming large chunks of text with [^)]*
  static final RegExp _bareRefWithPipeRegex = RegExp(
    r'(?<!\()((?:[1-3]\s+)?[A-Za-z]+(?:\s+[A-Za-z]+){0,5}\s+\d{1,3}:\d{1,3}(?:-\d{1,3})?)\|[.,;:]?',
  );

  // Malformed reference with extra opening paren: "(2 (Corinthians 7:10)" → "(2 Corinthians 7:10)"
  // Pattern: opening paren, optional digit+space, then another opening paren, then book name
  static final RegExp _doubleOpenParenRegex = RegExp(
    r'\(([1-3]\s+)\(([A-Za-z]+(?:\s+[A-Za-z]+){0,5}\s+\d{1,3}:\d{1,3}(?:-\d{1,3})?)\)',
  );

  /// Builds a [RichText] widget from a formatted string.
  ///
  /// Use this as a drop-in replacement for `Text(formattedString, style: ...)`.
  static Widget rich(
    String text,
    TextStyle style, {
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return RichText(
      text: TextSpan(children: buildInlineSpans(text, style)),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  /// Strips all formatting markers from a string, returning plain text.
  ///
  /// Useful when you need a clean string (e.g., for accessibility / semantics).
  static String stripFormatting(String text) {
    var result = _sanitizeMalformedBibleCitations(text);
    // Strip {red|...} → keep inner content
    result = result.replaceAllMapped(
      RegExp(r'\{red\|([^}]*)\}'),
      (m) => m.group(1) ?? '',
    );
    // Strip **bold** → keep inner content
    result = result.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (m) => m.group(1) ?? '',
    );
    // Strip *italic* → keep inner content
    result = result.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (m) => m.group(1) ?? '',
    );
    return result;
  }

  /// Inline renderer that supports:
  /// - `Label:` bolding at start of line
  /// - `**bold**`
  /// - `*italic*`
  /// - `{red|text}` (including multi-line spans)
  static List<TextSpan> buildInlineSpans(String text, TextStyle baseStyle) {
    final sanitized = _sanitizeMalformedBibleCitations(text);

    // Pre-process: if ** bold markers wrap around {red|} tags, split them
    // so that {red|} extraction doesn't orphan the ** markers.
    // e.g. **"quote" ({red|Ref}).** → **"quote" (**{red|Ref}**).**
    final processed = _splitBoldAroundRed(sanitized);

    // Now split into segments: regular text and {red|...} blocks.
    final segments = <_Segment>[];
    final redRegex = RegExp(r'\{red\|([^}]*)\}', dotAll: true);
    var lastEnd = 0;

    for (final m in redRegex.allMatches(processed)) {
      if (m.start > lastEnd) {
        segments.add(_Segment(processed.substring(lastEnd, m.start), false));
      }
      segments.add(_Segment(m.group(1)!, true));
      lastEnd = m.end;
    }
    if (lastEnd < processed.length) {
      segments.add(_Segment(processed.substring(lastEnd), false));
    }

    // Now process each segment
    final spans = <TextSpan>[];
    for (final seg in segments) {
      final style =
          seg.isRed
              ? baseStyle.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              )
              : baseStyle;
      spans.addAll(_processLines(seg.text, style));
    }

    return spans;
  }

  /// Process text line-by-line, handling `Label:` bolding and emphasis spans.
  static List<TextSpan> _processLines(String text, TextStyle baseStyle) {
    final lines = text.split('\n');
    final spans = <TextSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];

      final match = RegExp(
        r'^([A-Za-z0-9\s\-\(\)]+):\s*(.*)$',
      ).firstMatch(raw.trim());

      if (match != null) {
        final label = match.group(1)!.trim();
        final rest = match.group(2) ?? '';

        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: baseStyle.copyWith(fontWeight: FontWeight.w700),
              ),
              ...buildEmphasisSpans(rest, baseStyle),
            ],
          ),
        );
      } else {
        spans.addAll(buildEmphasisSpans(raw, baseStyle));
      }

      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  /// Supports `**bold**`, `*italic*`, and `{red|text}` for colored emphasis.
  /// Allows nesting of formatting (e.g., `{red|**text**}` for red bold text).
  static List<TextSpan> buildEmphasisSpans(String input, TextStyle baseStyle) {
    final spans = <TextSpan>[];

    // Tokenize by {red|...}, **bold**, or *italic*
    final regex = RegExp(r'(\{red\|[^}]*\}|\*\*.*?\*\*|\*.*?\*)');
    final matches = regex.allMatches(input);

    var lastIndex = 0;

    for (final m in matches) {
      if (m.start > lastIndex) {
        spans.add(
          TextSpan(text: input.substring(lastIndex, m.start), style: baseStyle),
        );
      }

      final token = input.substring(m.start, m.end);

      if (token.startsWith('{red|') && token.endsWith('}')) {
        final inner = token.substring(5, token.length - 1);
        // Process inner content for nested bold/italic
        final innerSpans = buildEmphasisSpans(
          inner,
          baseStyle.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        );
        spans.addAll(innerSpans);
      } else if (token.startsWith('**') &&
          token.endsWith('**') &&
          token.length > 4) {
        final inner = token.substring(2, token.length - 2);
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length > 2) {
        final inner = token.substring(1, token.length - 1);
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: baseStyle));
      }

      lastIndex = m.end;
    }

    if (lastIndex < input.length) {
      spans.add(TextSpan(text: input.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }

  /// Pre-processes text so that ** bold markers don't span across {red|} tags.
  ///
  /// Transforms: `**"quote" ({red|Ref}).**` → `**"quote" (**{red|Ref}**).**`
  /// This prevents {red|} extraction from orphaning ** markers.
  static String _splitBoldAroundRed(String text) {
    final redRegex = RegExp(r'\{red\|[^}]*\}', dotAll: true);
    final redMatches = redRegex.allMatches(text).toList();
    if (redMatches.isEmpty) return text;

    var boldOpen = false;
    var lastEnd = 0;
    final buf = StringBuffer();

    for (final m in redMatches) {
      final before = text.substring(lastEnd, m.start);

      // Count ** in preceding text to track bold state
      final boldCount = RegExp(r'\*\*').allMatches(before).length;
      if (boldCount.isOdd) boldOpen = !boldOpen;

      buf.write(before);

      if (boldOpen) {
        // Bold is open — close it before {red|}, reopen after
        buf.write('**');
        buf.write(text.substring(m.start, m.end));
        buf.write('**');
      } else {
        buf.write(text.substring(m.start, m.end));
      }

      lastEnd = m.end;
    }

    buf.write(text.substring(lastEnd));
    return buf.toString();
  }

  static String _sanitizeMalformedBibleCitations(String text) {
    // 1. Fix double opening paren: (2 (Corinthians → (2 Corinthians
    var result = text.replaceAllMapped(_doubleOpenParenRegex, (m) {
      final digit = (m.group(1) ?? '').trim();
      final ref = (m.group(2) ?? '').trim();
      if (digit.isEmpty || ref.isEmpty) return m.group(0) ?? '';
      return '($digit $ref)';
    });

    // 2. Fix malformed citations with pipe: (Ref|text) → (Ref)
    result = result.replaceAllMapped(_malformedBibleCitationRegex, (m) {
      final ref = (m.group(1) ?? '').trim();
      if (ref.isEmpty) return m.group(0) ?? '';
      return '($ref)';
    });

    // 3. Fix bare references with pipe (no opening paren): Ref|text → (Ref)
    result = result.replaceAllMapped(_bareRefWithPipeRegex, (m) {
      final ref = (m.group(1) ?? '').trim();
      if (ref.isEmpty) return m.group(0) ?? '';
      // Preserve trailing punctuation if present
      final fullMatch = m.group(0)!;
      final trailingMatch = RegExp(r'[.,;:]?$').firstMatch(fullMatch);
      final trailing = trailingMatch?.group(0) ?? '';
      return '($ref)$trailing';
    });

    // 4. Fix bare references without pipe: James 1:27 → (James 1:27)
    result = result.replaceAllMapped(_bareReferenceRegex, (m) {
      final ref = (m.group(1) ?? '').trim();
      if (ref.isEmpty) return m.group(0) ?? '';
      // Check if already wrapped in parentheses—skip if so
      final fullMatch = m.group(0)!;
      if (fullMatch.startsWith('(') && fullMatch.endsWith(')')) {
        return fullMatch;
      }
      // Preserve trailing punctuation if present
      final trailingMatch = RegExp(r'[.,;:]?$').firstMatch(fullMatch);
      final trailing = trailingMatch?.group(0) ?? '';
      return '($ref)$trailing';
    });

    return result;
  }
}

/// Internal helper to track text segments for {red|} pre-processing.
class _Segment {
  final String text;
  final bool isRed;
  const _Segment(this.text, this.isRed);
}
