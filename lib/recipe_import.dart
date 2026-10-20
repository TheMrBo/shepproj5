import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'recipe.dart';
import 'recipe_duration_parser.dart';

class RecipeImportException implements Exception {
  final String message;
  const RecipeImportException(this.message);
  @override
  String toString() => message;
}

class RecipeImporter {
  final http.Client Function() clientFactory;
  RecipeImporter({http.Client Function()? clientFactory})
    : clientFactory = clientFactory ?? http.Client.new;

  static Uri validateUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const RecipeImportException(
        'Enter a complete http:// or https:// recipe link.',
      );
    }
    return uri.removeFragment();
  }

  Future<Recipe> importUrl(String value) async {
    final uri = validateUrl(value);
    final client = clientFactory();
    try {
      return await (() async {
        final req = http.Request('GET', uri);
        req.headers.addAll({
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        });
        final response = await client.send(req);
        if (response.statusCode != 200) {
          throw RecipeImportException(
            'The website could not be read (${response.statusCode}). Try another recipe link.',
          );
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          if (bytes.length > 5 * 1024 * 1024) {
            throw const RecipeImportException(
              'This page is too large to import. Try a direct recipe page.',
            );
          }
        }
        return parseRecipeHtml(utf8.decode(bytes, allowMalformed: true), uri);
      })().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const RecipeImportException(
        'The website took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw RecipeImportException(
        kIsWeb
            ? 'This website may block browser imports. Try this link in the Android, iOS, or Windows app, or try another website.'
            : 'Could not reach this website. Check your connection and try again.',
      );
    } finally {
      client.close();
    }
  }
}

String _text(dynamic value) =>
    value is String ? (html.parseFragment(value).text ?? '').trim() : '';

String _cleanText(String input) {
  if (input.isEmpty) return '';
  var text = input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  text = text.replaceAll(
    RegExp(
      r'^(?:[•\-*]|\d+[.:)]|\bStep\s+\d+[.:)]?)\s*',
      caseSensitive: false,
    ),
    '',
  ).trim();

  if (text.isEmpty) return '';
  return text[0].toUpperCase() + text.substring(1);
}

String _instructionText(String value) {
  final fragment = html.parseFragment(value);
  for (final node in fragment.querySelectorAll(
    'script, style, iframe, button, nav, .sharedaddy, .wprm-recipe-instruction-video',
  )) {
    node.remove();
  }
  return (fragment.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isNotice(String text) => RegExp(
  r'\b(do not make this recipe|recipe (?:is )?(?:withdrawn|under review)|important announcement)\b',
  caseSensitive: false,
).hasMatch(text);

bool _isPromotion(String text) => RegExp(
  r'^(subscribe\b|follow (?:me|us)\b|sign up\b|share this recipe\b|rate this recipe\b|leave a (?:comment|review)\b|watch (?:the |my )?video\b)',
  caseSensitive: false,
).hasMatch(text);

dynamic _fullInstructions(dynamic value) {
  if (value is! List) return value;
  final full = value
      .where(
        (v) =>
            v is Map &&
            RegExp(
              r'^(full|detailed) (recipe|instructions)$',
              caseSensitive: false,
            ).hasMatch(_text(v['name'])),
      )
      .toList();
  return full.isEmpty ? value : full;
}

// Only ordered cooking lists directly following a process photograph qualify.
// Never assign photos by page order or use a finished dish as a step photo.
List<({String text, String image})> _illustratedSteps(
  dom.Document document,
  Uri base,
) {
  final result = <({String text, String image})>[];
  for (final heading in document.querySelectorAll('h2, h3')) {
    if (!RegExp(
      r'^(how to (make|cook)|step.by.step)',
      caseSensitive: false,
    ).hasMatch(heading.text.trim())) {
      continue;
    }
    String pendingImage = '';
    for (
      var node = heading.nextElementSibling;
      node != null;
      node = node.nextElementSibling
    ) {
      if (['h2', 'h3', 'hr'].contains(node.localName)) break;
      if (node.localName == 'figure' || node.localName == 'p') {
        final image = node.querySelector('img');
        if (image != null) pendingImage = _elementImage(image, base);
      }
      if (node.localName == 'ol') {
        for (final li in node.children.where((e) => e.localName == 'li')) {
          final text = _instructionText(li.innerHtml);
          if (text.isNotEmpty && !_isPromotion(text)) {
            result.add((text: text, image: pendingImage));
          }
        }
        pendingImage = '';
      }
    }
  }
  return result;
}

String _matchedPhoto(
  String text,
  List<({String text, String image})> candidates,
) {
  const ignored = {
    'the',
    'and',
    'then',
    'with',
    'into',
    'until',
    'for',
    'you',
    'your',
    'this',
    'that',
    'they',
    'are',
    'all',
    'them',
    'from',
    'have',
    'it',
    'add',
    'cook',
    'stir',
    'small',
    'large',
    'well',
    'when',
    'need',
  };
  Set<String> words(String s) => RegExp(r'[a-z]{3,}')
      .allMatches(s.toLowerCase())
      .map((m) => m[0]!)
      .map((w) => w == 'coated' || w == 'coating' ? 'coat' : w)
      .where((w) => !ignored.contains(w))
      .toSet();
  final target = words(text);
  var best = 0.0;
  var second = 0.0;
  var image = '';
  for (final candidate in candidates) {
    if (candidate.image.isEmpty) continue;
    final tokens = words(candidate.text);
    final overlap = target.intersection(tokens).length;
    if (overlap < 3) continue;
    final score =
        overlap /
        (target.length < tokens.length ? target.length : tokens.length);
    if (score > best) {
      if (image != candidate.image) second = best;
      best = score;
      image = candidate.image;
    } else if (candidate.image != image && score > second) {
      second = score;
    }
  }
  return best >= 0.5 && best - second >= 0.15 ? image : '';
}

Iterable<Map<String, dynamic>> _recipes(dynamic value) sync* {
  if (value is List) {
    for (final item in value) {
      yield* _recipes(item);
    }
  } else if (value is Map<String, dynamic>) {
    final types = value['@type'] is List
        ? value['@type'] as List
        : [value['@type']];
    if (types.any(
      (t) =>
          t == 'Recipe' ||
          t == 'https://schema.org/Recipe' ||
          t == 'http://schema.org/Recipe',
    )) {
      yield value;
    }
    for (final child in value.values) {
      if (child is List || child is Map<String, dynamic>) {
        yield* _recipes(child);
      }
    }
  }
}

String _imageUrl(dynamic value, Uri base) {
  if (value is List) {
    for (final item in value) {
      final image = _imageUrl(item, base);
      if (image.isNotEmpty) return image;
    }
  } else if (value is Map) {
    return _imageUrl([value['contentUrl'], value['url'], value['@id']], base);
  } else if (value is String && value.trim().isNotEmpty) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null || value.trim().startsWith('#')) return '';
    final uri = base.resolveUri(parsed);
    if (['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty) {
      return uri.toString();
    }
  }
  return '';
}

String _elementImage(dom.Element? element, Uri base) {
  if (element == null) return '';
  for (final key in ['data-src', 'data-lazy-src', 'content', 'src', 'href']) {
    final image = _imageUrl(element.attributes[key], base);
    if (image.isNotEmpty) return image;
  }
  for (final key in ['data-srcset', 'srcset']) {
    for (final candidate in (element.attributes[key] ?? '').split(',')) {
      final image = _imageUrl(
        candidate.trim().split(RegExp(r'\s+')).first,
        base,
      );
      if (image.isNotEmpty) return image;
    }
  }
  return '';
}

dynamic _resolveImageReference(dynamic value, dynamic data) {
  if (value is List) {
    return value.map((v) => _resolveImageReference(v, data)).toList();
  }
  if (value is! Map ||
      value['@id'] == null ||
      value['url'] != null ||
      value['contentUrl'] != null) {
    return value;
  }
  dynamic find(dynamic node) {
    if (node is Map) {
      if (node['@id'] == value['@id'] &&
          (node['url'] != null || node['contentUrl'] != null)) {
        return node;
      }
      for (final child in node.values) {
        final found = find(child);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final child in node) {
        final found = find(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  return find(data);
}

String _dishImage(
  Map<String, dynamic> recipe,
  dynamic data,
  dom.Document document,
  Uri base,
) {
  final structured = _imageUrl(
    _resolveImageReference(recipe['image'], data),
    base,
  );
  if (structured.isNotEmpty) return structured;
  // Prefer explicitly designated recipe/social images over arbitrary page images.
  for (final selector in [
    'meta[property="og:image:secure_url"]',
    'meta[property="og:image"]',
    'meta[name="twitter:image"]',
    'meta[property="twitter:image"]',
    '[itemprop="image"]',
    '.wprm-recipe-image img',
    '.tasty-recipes-image img',
    '.recipe-image img',
    'img.recipe-image',
    'link[rel="image_src"]',
  ]) {
    for (final element in document.querySelectorAll(selector)) {
      final image = _elementImage(element, base);
      if (image.isNotEmpty) return image;
      final childImage = _elementImage(element.querySelector('img'), base);
      if (childImage.isNotEmpty) return childImage;
    }
  }
  return '';
}

List<({String text, String image, Duration? duration})> _steps(
  dynamic value,
  Uri base,
  dom.Document document,
) {
  if (value is List) {
    return value.expand((v) => _steps(v, base, document)).toList();
  }
  if (value is Map) {
    if (value['itemListElement'] != null) {
      return _steps(value['itemListElement'], base, document);
    }
    var image = _imageUrl(value['image'], base);
    final isoDurationStr = (value['performTime'] ?? value['duration'] ?? value['time']) as String?;
    Duration? stepDuration = isoDurationStr != null ? RecipeDurationParser.parseIso8601(isoDurationStr) : null;

    final stepUrl = Uri.tryParse(value['url'] is String ? value['url'] : '');
    if (image.isEmpty && stepUrl != null && stepUrl.hasFragment) {
      final resolved = base.resolveUri(stepUrl);
      if (resolved.removeFragment() == base.removeFragment()) {
        final element = document.getElementById(resolved.fragment);
        final img = element?.querySelector('img');
        image = _elementImage(img, base);
      }
    }
    return _steps(value['text'] ?? value['name'], base, document)
        .map(
          (step) => (
            text: step.text,
            image: image.isEmpty ? step.image : image,
            duration: step.duration ?? stepDuration,
          ),
        )
        .toList();
  }
  if (value is String) {
    return value
        .split(RegExp(r'\r?\n|<br\s*/?>', caseSensitive: false))
        .map((s) {
          final cleanText = _instructionText(s);
          final extracted = RecipeDurationParser.extractDuration(cleanText);
          return (
            text: cleanText,
            image: _imageUrl(
              html.parseFragment(s).querySelector('img')?.attributes['src'],
              base,
            ),
            duration: extracted.duration,
          );
        })
        .where((s) => s.text.isNotEmpty)
        .toList();
  }
  return [];
}

int _minutes(dynamic value) {
  if (value is! String) {
    return 0;
  }
  final match = RegExp(
    r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) {
    return 0;
  }
  int part(int i) => int.tryParse(match.group(i) ?? '') ?? 0;
  return part(1) * 1440 + part(2) * 60 + part(3) + (part(4) / 60).ceil();
}

Recipe parseRecipeHtml(String source, Uri url) {
  final document = html.parse(source);
  for (final script in document.querySelectorAll('script')) {
    if (script.attributes['type']?.toLowerCase().split(';').first.trim() !=
        'application/ld+json') {
      continue;
    }
    dynamic data;
    try {
      data = jsonDecode(script.text);
    } on FormatException {
      continue;
    }
    for (final item in _recipes(data)) {
      final name = _cleanText(_text(item['name']));
      final rawIngredients = item['recipeIngredient'];
      final ingredients =
          (rawIngredients is List ? rawIngredients : [rawIngredients])
              .map(
                (v) => v is Map
                    ? _cleanText('${v['value'] ?? ''} ${v['name'] ?? ''}')
                    : _cleanText(_text(v)),
              )
              .where((v) => v.isNotEmpty)
              .toList();
      final allSteps = _steps(item['recipeInstructions'], url, document);
      final notices = allSteps
          .where((s) => _isNotice(s.text))
          .map((s) => _cleanText(s.text))
          .where((s) => s.isNotEmpty)
          .toList();
      final illustrated = _illustratedSteps(document, url);
      final steps =
          _steps(_fullInstructions(item['recipeInstructions']), url, document)
              .where((s) => !_isNotice(s.text) && !_isPromotion(s.text))
              .map(
                (s) => (
                  text: _cleanText(s.text),
                  image: s.image.isNotEmpty
                      ? s.image
                      : _matchedPhoto(s.text, illustrated),
                  duration: s.duration ??
                      RecipeDurationParser.extractDuration(s.text).duration,
                ),
              )
              .where((s) => s.text.isNotEmpty)
              .toList();

      if (name.isEmpty || ingredients.isEmpty || steps.isEmpty) {
        continue;
      }
      final total = _minutes(item['totalTime']);

      final structuredInstructions = steps
          .asMap()
          .entries
          .map(
            (entry) => {
              'stepNumber': entry.key + 1,
              'directionText': entry.value.text,
              if (entry.value.duration != null)
                'timerDurationSeconds': entry.value.duration!.inSeconds,
            },
          )
          .toList();

      return Recipe.fromJson({
        'id': 'import:${url.removeFragment()}',
        'sourceUrl': url.removeFragment().toString(),
        'name': name,
        'category': 'Imported',
        'image': _dishImage(item, data, document, url),
        'rating': '',
        'description': '',
        'notices': notices,
        'time': total > 0
            ? total
            : _minutes(item['prepTime']) + _minutes(item['cookTime']),
        'ingredients': ingredients.map((v) => ['•', v]).toList(),
        'steps': steps.map((step) => step.text).toList(),
        'instructions': structuredInstructions,
        'stepImages': steps.map((step) => step.image).toList(),
      });
    }
  }

  final fallback = _parseHtmlFallback(document, url);
  if (fallback != null) {
    return fallback;
  }

  throw const RecipeImportException(
    'No complete recipe was found. Use a recipe page with ingredients and instructions; video-only and social media links are not supported.',
  );
}

Recipe? _parseHtmlFallback(dom.Document document, Uri url) {
  String name = '';
  for (final selector in [
    '.wprm-recipe-name',
    '.tasty-recipes-title',
    '.recipe-title',
    'h1.entry-title',
    'h1.recipe-title',
    'h1.post-title',
    '[itemprop="name"]',
    'h1',
  ]) {
    final el = document.querySelector(selector);
    if (el != null && el.text.trim().isNotEmpty) {
      name = _cleanText(el.text);
      if (name.isNotEmpty) break;
    }
  }

  final ingredients = <String>[];
  for (final selector in [
    '.wprm-recipe-ingredient',
    '.tasty-recipes-ingredients li',
    '.recipe-ingredients li',
    '[itemprop="recipeIngredient"]',
    '.ingredient',
    '.ingredients li',
  ]) {
    final elements = document.querySelectorAll(selector);
    if (elements.isNotEmpty) {
      for (final el in elements) {
        final text = _cleanText(_instructionText(el.innerHtml));
        if (text.isNotEmpty && !ingredients.contains(text)) {
          ingredients.add(text);
        }
      }
      if (ingredients.isNotEmpty) break;
    }
  }

  final steps = <({String text, String image, Duration? duration})>[];
  for (final selector in [
    '.wprm-recipe-instruction',
    '.tasty-recipes-instructions li',
    '.recipe-instructions li',
    '[itemprop="recipeInstructions"] li',
    '[itemprop="recipeInstructions"] p',
    '.instruction',
    '.instructions li',
  ]) {
    final elements = document.querySelectorAll(selector);
    if (elements.isNotEmpty) {
      for (final el in elements) {
        final text = _cleanText(_instructionText(el.innerHtml));
        if (text.isNotEmpty && !_isNotice(text) && !_isPromotion(text)) {
          final imgEl = el.querySelector('img');
          final img = _elementImage(imgEl, url);
          final extracted = RecipeDurationParser.extractDuration(text);
          steps.add((
            text: text,
            image: img,
            duration: extracted.duration,
          ));
        }
      }
      if (steps.isNotEmpty) break;
    }
  }

  if (name.isEmpty || ingredients.isEmpty || steps.isEmpty) {
    return null;
  }

  final image = _dishImage({}, {}, document, url);

  final structuredInstructions = steps
      .asMap()
      .entries
      .map(
        (entry) => {
          'stepNumber': entry.key + 1,
          'directionText': entry.value.text,
          if (entry.value.duration != null)
            'timerDurationSeconds': entry.value.duration!.inSeconds,
        },
      )
      .toList();

  return Recipe.fromJson({
    'id': 'import:${url.removeFragment()}',
    'sourceUrl': url.removeFragment().toString(),
    'name': name,
    'category': 'Imported',
    'image': image,
    'rating': '',
    'description': '',
    'notices': <String>[],
    'time': 30,
    'ingredients': ingredients.map((v) => ['•', v]).toList(),
    'steps': steps.map((step) => step.text).toList(),
    'instructions': structuredInstructions,
    'stepImages': steps.map((step) => step.image).toList(),
  });
}
