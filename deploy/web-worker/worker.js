export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let path = url.pathname;
    if (path === "/" || path === "") path = "/index.html";
    // SPA fallback: serve index.html for unknown non-asset paths
    let assetRes = await env.ASSETS.fetch(new URL(path, url.origin));
    if (assetRes.status === 404 && !path.includes(".")) {
      assetRes = await env.ASSETS.fetch(new URL("/index.html", url.origin));
    }
    const headers = new Headers(assetRes.headers);
    headers.set("X-Frame-Options", "ALLOWALL");
    headers.set("Content-Security-Policy", "frame-ancestors *");
    headers.set("Access-Control-Allow-Origin", "*");
    return new Response(assetRes.body, { status: assetRes.status, headers });
  },
};
