/* Useage:
     node vercomp.js verstr1 verstr2
   Return (in exit):
     -1 - input wrong
     0 - equal
     1 - verstr1 < verstr2
     2 - verstr1 > verstr2
 */

var suffixPriority = {
  'p': 1,
  'nb': 1,
  '': 0,
  'pre': -1
};

var defaultVer = {
  main: '0',
  suffix: null
}

var parseVerstr = (function() {
  var re = /(\S+)(p|nb|pre)(\d+)/i;
  return function(verstr) {
    var r = re.exec(verstr);
    return r ? { main: r[1], suffix: [ r[2], r[3] ] } : { main: verstr, suffix: null };
  };
})();

function compVer(ver1, ver2) {
  if (ver2 === null) {
    return 2;
  }

  if (ver1 === null && ver2 !== null) {
    return 1;
  }

  if (ver1.main < ver2.main) {
    return 1;
  } else if (ver1.main > ver2.main) {
    return 2;
  } else {
    var sp1 = ver1.suffix ? suffixPriority[ver1.suffix[0]] : 0;
    var sp2 = ver2.suffix ? suffixPriority[ver2.suffix[0]] : 0;
    if (sp1 < sp2) {
      return 1;
    } else if (sp1 > sp2) {
      return 2;
    } else {
      var sv1 = ver1.suffix ? ver1.suffix[1] : '';
      var sv2 = ver2.suffix ? ver2.suffix[2] : '';
      return (sv1 < sv2) ? 1 : 2;
    }
  }
}

if (process.argc < 4) {
  process.exit(-1);
}

var verstr1 = process.argv[2].trim();
var verstr2 = process.argv[3].trim();
if (verstr1 === verstr2) {
  process.exit(0);
}

var ver1 = parseVerstr(verstr1);
var ver2 = parseVerstr(verstr2);
process.exit(compVer(ver1, ver2));
