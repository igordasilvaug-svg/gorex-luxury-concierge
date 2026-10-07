export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/' || url.pathname === '/index.html' || url.pathname === '/privacy') {
      const html = await env.ASSETS.fetch(new URL('/index.html', request.url));
      return new Response(html.body, {
        headers: { 'content-type': 'text/html; charset=utf-8' },
      });
    }
    return env.ASSETS.fetch(request);
  },
};
