// GOREX LUXURY CONCIERGE — logique de téléchargement APK (réassemblage côté client)
// Les APK sont découpés en morceaux (< 5 Mo) côté hébergement ; ce script les
// télécharge dans l'ordre, les réassemble en mémoire et vérifie l'empreinte
// SHA-256 avant de proposer le fichier .apk au téléchargement.
(function () {
  'use strict';

  var MANIFEST = null;
  var BASE = 'download/parts/';

  function fmt(n) { return (n / 1048576).toFixed(1).replace('.', ',') + ' Mo'; }

  function hex(buf) {
    var b = new Uint8Array(buf), s = '';
    for (var i = 0; i < b.length; i++) { s += b[i].toString(16).padStart(2, '0'); }
    return s;
  }

  async function sha256(buf) {
    if (window.crypto && crypto.subtle) {
      var d = await crypto.subtle.digest('SHA-256', buf);
      return hex(d);
    }
    return null;
  }

  function setStatus(item, text, on) {
    var st = item.parentNode.querySelector('[data-status]');
    if (!st) return;
    st.textContent = text;
    st.classList.toggle('on', on !== false);
  }
  function setProg(item, ratio) {
    var pr = item.parentNode.querySelector('[data-prog]');
    if (!pr) return;
    pr.classList.toggle('on', ratio > 0 && ratio < 1);
    var bar = pr.querySelector('i');
    if (bar) bar.style.width = Math.round(ratio * 100) + '%';
  }
  function showErr(msg) {
    var e = document.querySelector('[data-err]');
    if (!e) return;
    e.textContent = msg;
    e.classList.toggle('on', !!msg);
  }

  async function download(abi, item) {
    var f = MANIFEST.files[abi];
    if (!f) return;
    item.classList.add('busy');
    showErr('');
    try {
      var chunks = [], got = 0;
      for (var i = 0; i < f.parts.length; i++) {
        setStatus(item, 'Préparation… ' + (i + 1) + '/' + f.parts.length, true);
        var r = await fetch(BASE + f.parts[i], { cache: 'no-store' });
        if (!r.ok) throw new Error('partie ' + (i + 1) + ' indisponible (' + r.status + ')');
        var ab = await r.arrayBuffer();
        chunks.push(new Uint8Array(ab));
        got += ab.byteLength;
        setProg(item, got / f.size);
      }
      setProg(item, 0);
      setStatus(item, 'Vérification de l\u2019intégrité…', true);
      var blob = new Blob(chunks, { type: 'application/vnd.android.package-archive' });
      var full = await blob.arrayBuffer();
      var h = await sha256(full);
      if (h && h !== f.sha256) { throw new Error('contrôle d\u2019intégrité échoué'); }
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = f.filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(function () { URL.revokeObjectURL(url); }, 8000);
      setStatus(item, 'Téléchargement lancé — ' + fmt(f.size) + '.', true);
    } catch (err) {
      showErr('Échec du téléchargement : ' + (err && err.message ? err.message : err) + '. Réessayez ou utilisez un autre navigateur.');
      setStatus(item, '', false);
      setProg(item, 0);
    } finally {
      item.classList.remove('busy');
    }
  }

  document.addEventListener('DOMContentLoaded', async function () {
    try {
      var r = await fetch('download/manifest.json', { cache: 'no-store' });
      MANIFEST = await r.json();
    } catch (e) {
      showErr('Impossible de charger les informations de téléchargement.');
      return;
    }
    var items = document.querySelectorAll('.dl');
    for (var i = 0; i < items.length; i++) {
      (function (item) {
        var abi = item.getAttribute('data-abi');
        var f = MANIFEST.files[abi];
        if (f) {
          var sz = item.querySelector('[data-size]');
          if (sz) sz.textContent = fmt(f.size);
        }
        item.addEventListener('click', function () { download(abi, item); });
      })(items[i]);
    }
  });
})();
