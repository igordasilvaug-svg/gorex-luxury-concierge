// Implémentation navigateur : téléchargement réel du fichier.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Résultat d'une tentative d'export.
class ExportResult {
  final bool ok;
  final String? message;
  const ExportResult(this.ok, [this.message]);
}

/// Déclenche le téléchargement de [content] sous le nom [filename].
///
/// Utilise un blob et un lien temporaire : aucune dépendance supplémentaire,
/// et le fichier est bien produit localement (pas d'appel réseau).
ExportResult exportTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/xml',
}) {
  try {
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.style.display = 'none';
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    // Libère la mémoire une fois le téléchargement amorcé.
    web.URL.revokeObjectURL(url);
    return ExportResult(true, 'Fichier $filename téléchargé');
  } catch (e) {
    return ExportResult(false, 'Téléchargement impossible : $e');
  }
}
