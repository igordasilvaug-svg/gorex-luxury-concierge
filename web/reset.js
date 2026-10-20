// GOREX — Nettoyage du cache / service worker (page de réinitialisation).
// Fichier EXTERNE requis : la Content Security Policy du site bloque les
// scripts « inline » ; ce fichier est autorisé ('self').
(function () {
  var status = document.getElementById('status');
  var steps = document.querySelectorAll('#steps li');
  function mark(i, ok) {
    if (steps[i]) {
      steps[i].textContent = (ok ? '✅ ' : '⚠️ ') +
        steps[i].textContent.replace(/^[✅⚠️] /, '');
    }
  }
  async function run() {
    try {
      if ('serviceWorker' in navigator) {
        var regs = await navigator.serviceWorker.getRegistrations();
        for (var r of regs) { try { await r.unregister(); } catch (e) {} }
      }
      mark(0, true);

      if (window.caches && caches.keys) {
        var names = await caches.keys();
        for (var n of names) { try { await caches.delete(n); } catch (e) {} }
      }
      mark(1, true);

      if (status) {
        status.className = 'status ok';
        status.textContent = '✅ Terminé — votre appareil utilise la version à jour.';
      }

      setTimeout(function () {
        mark(2, true);
        if (status) status.textContent = 'Redirection vers le portail…';
        window.location.replace('/?fresh=' + Date.now());
      }, 1500);
    } catch (e) {
      if (status) status.textContent = 'Nettoyage partiel effectué. Cliquez ci-dessous.';
      var go = document.getElementById('go');
      if (go) go.style.display = 'inline-block';
    }
    setTimeout(function () {
      var go = document.getElementById('go');
      if (go) go.style.display = 'inline-block';
    }, 3000);
  }
  run();
})();
