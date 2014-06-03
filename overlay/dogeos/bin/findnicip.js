var ifaces = require('os').networkInterfaces();
for (var dev in ifaces) {
  var alias=0;
  ifaces[dev].forEach(function(details){
    if (details.family=='IPv4' && details.address !== '127.0.0.1') {
      console.log(dev+(alias?':'+alias:''), details.address);
      ++alias;
    }
  });
}
