var devs = [];

function printUsb() {
  var re = /usb/i;
  devs.forEach(function(dev) {
    if (re.test(dev['Device Type']) || re.test(dev['Bus'])) {
      console.log(dev['Logical Node'].trim() + ',' + dev['Connected Device'].trim());
    }
  });
}

function printDvd() {
  var re = /dvd/i;
  devs.forEach(function(dev) {
    if (re.test(dev['Device Type']) || re.test(dev['Bus'])) {
      console.log(dev['Logical Node'].trim() + ',' + dev['Connected Device'].trim());
    }
  });
}

(function runCmd(cmd, args, callback) {
   var spawn = require('child_process').spawn;
   var child = spawn(cmd, args);
   var out = '';
   var err = '';
   child.stdout.on('data', function(buffer) { out += buffer.toString(); });
   child.stderr.on('data', function(buffer) { err += buffer.toString(); });
   child.on('close', function(code) { callback(code, out, err); });
})('rmformat', [ '-l' ], function(code, stdout, stderr) {
  if (code !== 0) {
    console.error(stderr);
    process.exit(code);
  }
  var re = /(\d+\.)?([^:\d]+):(.+)/;
  stdout.split('\n').forEach(function(line) {
    var r = re.exec(line);
    if (r) {
      if (r[1]) { // have #, so it is record-start
        devs.push({});
      }
      var t = devs[devs.length - 1];
      t[r[2].trim()] = r[3].trim();
    }
  });

  switch(process.argv[2]) {
    case 'usb':
      printUsb();
      break;
    case 'dvd':
      printDvd();
      break;
    default:
      break;
  }
});

