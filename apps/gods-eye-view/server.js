'use strict';
// Minimal static file server (Node stdlib only) for the gods-eye-view Vite build.
// Tier 1 is a keyless static deployment: no API keys, no key-brokering backend.
// Serves /app/dist with SPA fallback; /api/* returns 404 JSON so the client
// can fall back to direct upstream fetches where the provider allows CORS.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, 'dist');
const PORT = parseInt(process.env.PORT || '4173', 10);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.wasm': 'application/wasm',
  '.glb': 'model/gltf-binary',
  '.gltf': 'model/gltf+json',
  '.webmanifest': 'application/manifest+json',
  '.txt': 'text/plain; charset=utf-8',
};

function send(res, code, body, type) {
  const buf = Buffer.from(body);
  res.writeHead(code, {
    'Content-Type': type || 'text/plain; charset=utf-8',
    'Content-Length': buf.length,
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(buf);
}

function serveIndex(res) {
  fs.readFile(path.join(ROOT, 'index.html'), (err, index) => {
    if (err) return send(res, 500, 'index.html missing');
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Length': index.length,
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(index);
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url || '/', 'http://localhost');
  const pathname = decodeURIComponent(url.pathname);

  if (pathname === '/healthz') return send(res, 200, 'ok');
  if (pathname.startsWith('/api/')) {
    return send(
      res,
      404,
      JSON.stringify({ error: 'api proxy not enabled in keyless static build' }),
      'application/json; charset=utf-8',
    );
  }

  // Normalize + block traversal; everything stays under ROOT.
  let filePath = path.normalize(path.join(ROOT, pathname));
  if (!filePath.startsWith(ROOT)) return send(res, 403, 'forbidden');

  fs.stat(filePath, (err, st) => {
    if (!err && st.isDirectory()) filePath = path.join(filePath, 'index.html');
    fs.readFile(filePath, (readErr, data) => {
      if (readErr) {
        // SPA fallback for extensionless routes (client-side router).
        if (!path.extname(pathname)) {
          serveIndex(res);
          return;
        }
        return send(res, 404, 'not found');
      }
      const ext = path.extname(filePath).toLowerCase();
      const headers = {
        'Content-Type': MIME[ext] || 'application/octet-stream',
        'Content-Length': data.length,
        'X-Content-Type-Options': 'nosniff',
        'Cache-Control': pathname.startsWith('/assets/')
          ? 'public, max-age=31536000, immutable'
          : 'public, max-age=3600',
      };
      res.writeHead(200, headers);
      if (req.method === 'HEAD') return res.end();
      res.end(data);
    });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`static server listening on 0.0.0.0:${PORT} root=${ROOT}`);
});
