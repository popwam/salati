import { createReadStream, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join } from 'node:path';

const port = Number.parseInt(process.env.PORT ?? '8080', 10);
const publicDirectory = join(process.cwd(), 'public');

const routes = new Map([
  ['/', 'index.html'],
  ['/privacy-policy', 'privacy-policy.html'],
  ['/privacy-policy.html', 'privacy-policy.html'],
  ['/account-deletion', 'account-deletion.html'],
  ['/account-deletion.html', 'account-deletion.html'],
  ['/data-deletion', 'data-deletion.html'],
  ['/data-deletion.html', 'data-deletion.html'],
  ['/terms-of-use', 'terms-of-use.html'],
  ['/terms-of-use.html', 'terms-of-use.html'],
  ['/child-safety', 'child-safety.html'],
  ['/child-safety.html', 'child-safety.html'],
]);

const contentTypes = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.css', 'text/css; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
]);

function sendText(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  response.end(body);
}

const server = createServer((request, response) => {
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.setHeader('Allow', 'GET, HEAD');
    sendText(response, 405, 'Method Not Allowed');
    return;
  }

  const pathname = new URL(request.url ?? '/', 'http://localhost').pathname;
  if (pathname === '/health') {
    sendText(response, 200, 'ok');
    return;
  }

  const normalizedPath = pathname.length > 1 && pathname.endsWith('/')
    ? pathname.slice(0, -1)
    : pathname;
  const fileName = routes.get(normalizedPath);
  if (!fileName) {
    sendText(response, 404, 'Not Found');
    return;
  }

  const filePath = join(publicDirectory, fileName);
  try {
    const fileSize = statSync(filePath).size;
    response.writeHead(200, {
      'Content-Type': contentTypes.get(extname(fileName)) ?? 'application/octet-stream',
      'Content-Length': fileSize,
      'Cache-Control': 'public, max-age=300',
    });
    if (request.method === 'HEAD') {
      response.end();
      return;
    }
    createReadStream(filePath).pipe(response);
  } catch {
    sendText(response, 404, 'Not Found');
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Salati legal pages listening on port ${port}`);
});
