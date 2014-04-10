// read /usbkey/config for nic_tag s
var fs = require('fs');
var nics = {};
var nicsOrder = [];
fs.readFileSync('/usbkey/config').toString().split('\n').forEach(function(line) {
  var l = line.trim();
  var re = /(.+)_nic\s*=\s*(\S+)/;
  var r = re.exec(l);
  if (r) {
    nics[r[2]] = { tag: r[1] };
    nicsOrder.push(r[2]);
  }
});
(function runCmd(cmd, args, callback) {
   var spawn = require('child_process').spawn;
   var child = spawn(cmd, args);
   var out = '';
   var err = '';
   child.stdout.on('data', function(buffer) { out += buffer.toString(); });
   child.stderr.on('data', function(buffer) { err += buffer.toString(); });
   child.on('close', function(code) { callback(code, out, err); });
})('dladm', [ 'show-phys', '-pmo', 'link,address' ], function(code, stdout, stderr) {
  if (code !== 0) {
    console.error(stderr);
    process.exit(code);
  }
  stdout.split('\n').forEach(function(line) {
    var l = line.trim();
    var sp = l.indexOf(':');
    var link = l.slice(0, sp);
    var mac = l.slice(sp+1).replace(/\\\:/g, ':');
    if (mac in nics) { 
      nics[mac].link = link;
    }
  });
  nicsOrder.forEach(function(mac) {
    console.log(mac, nics[mac].tag, nics[mac].link);
  });
});
