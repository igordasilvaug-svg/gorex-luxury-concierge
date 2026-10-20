// GOREX — Auto-réparation : purge des Service Worker / caches résiduels.
// Fichier EXTERNE : la Content Security Policy du site bloque les scripts
// « inline », ce fichier est autorisé ('self').
(function () {
  try {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function (regs) {
        regs.forEach(function (r) { try { r.unregister(); } catch (e) {} });
      });
    }
    if (window.caches && caches.keys) {
      caches.keys().then(function (names) {
        names.forEach(function (n) { try { caches.delete(n); } catch (e) {} });
      });
    }
  } catch (e) {}
})();
