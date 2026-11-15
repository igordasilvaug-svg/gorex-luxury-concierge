// GOREX LUXURY CONCIERGE — Export de fichiers texte (XML SEPA, CSV…).
//
// Deux implémentations derrière la même API :
//   • web    : déclenche le téléchargement dans le navigateur ;
//   • mobile : signale que l'export n'est pas disponible sur cette plateforme
//              plutôt que de faire semblant.
//
// Le choix se fait à la compilation via l'import conditionnel : aucun
// `dart:html`/`package:web` n'est compilé sur Android/iOS.

export 'file_export_stub.dart'
    if (dart.library.js_interop) 'file_export_web.dart';
