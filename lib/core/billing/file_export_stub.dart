// Implémentation hors navigateur : l'export de fichier n'est pas disponible.

/// Résultat d'une tentative d'export.
class ExportResult {
  final bool ok;
  final String? message;
  const ExportResult(this.ok, [this.message]);
}

/// Sur mobile/desktop, on ne prétend pas avoir exporté quoi que ce soit :
/// l'utilisateur est informé que la fonction est réservée au web.
ExportResult exportTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/xml',
}) {
  return const ExportResult(
    false,
    'Export de fichier disponible uniquement depuis la version web. '
    'Copiez le contenu affiché et transmettez-le à votre banque.',
  );
}
