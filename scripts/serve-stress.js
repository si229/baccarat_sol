const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../tools");
const port = Number(process.env.STRESS_PORT || 8787);

const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const requested = url.pathname === "/" ? "/stress-test.html" : url.pathname;
  const filePath = path.resolve(root, `.${decodeURIComponent(requested)}`);

  if (!filePath.startsWith(root)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.readFile(filePath, (error, content) => {
    if (error) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    res.writeHead(200, { "Content-Type": types[path.extname(filePath)] || "application/octet-stream" });
    res.end(content);
  });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Baccarat stress lab: http://127.0.0.1:${port}/`);
});
