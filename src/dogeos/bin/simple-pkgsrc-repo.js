/* Usage:
     node <this.js> <repo_path> <port>
 */
var http = require('http'),
    url = require('url'),
    path = require('path'),
    fs = require('fs'),
    repoPath = process.argv[2],
    port = process.argv[3] || 8080;
 
http.createServer(function(request, response) {
  var uri = url.parse(request.url).pathname, 
      filename = path.join(repoPath, uri);
  
  fs.exists(filename, function(exists) {
    if(!exists) {
      response.writeHead(404, {'Content-Type': 'text/plain'});
      response.write('404 Not Found\n');
      response.end();
      return;
    }
 
    if (fs.statSync(filename).isDirectory()) { 
      filename += '/index.html';
    }

    fs.readFile(filename, 'binary', function(err, file) {
      if(err) {        
        response.writeHead(500, {'Content-Type': 'text/plain'});
        response.write(err + '\n');
        response.end();
        return;
      }

      var stat = fs.statSync(filename);

      response.writeHead(200, {
        'Content-Length': stat.size,
        'Content-Type': 'application/octet-stream',
        'Last-Modified': (new Date(Date.parse(stat.mtime))).toUTCString()
      }); 
      response.write(file, 'binary');
      response.end();
    });
  });
}).listen(parseInt(port, 10));
 
console.log('Simple pkgsrc repo server running at\n  => http://localhost:' + port + '/.');
