/*
   usage:
     node pkg.js pkg_summary
     node pkg.js pkg_summary search <name>
     node pkg.js pkg_summary dep <pkg_name>...
     node pkg.js pkg_summary dep_dev <pkg_name>...
     node pkg.js pkg_summary print <pkg_name>
     node pkg.js pkg_summary latest [option_print_prefix]
 */

var util = require('util');

function readFileByLine(filename, lineCallback, endCallback) {
  var rd = require('readline').createInterface({
    input: require('fs').createReadStream(filename),
    output: process.stdout,
    terminal: false
  })
  rd.on('line', lineCallback);
  rd.on('close', endCallback);
}

var allPkgs = [];
var pkgIndex = {};
var devMode = false;

function loadPkgs(filename, callback) {
  var pkgconf = {};
  var rawconf = [];
  readFileByLine(filename, function(line) {
    var l = line.trim();
    rawconf.push(l);
    if (l.length <= 0) {
      pkgconf.raw = rawconf;
      allPkgs.push(pkgconf);
      pkgconf = {};
      rawconf = [];
    } else {
      var p = l.indexOf('=');
      var k = l.slice(0, p).trim();
      var v = l.slice(p+1).trim();
      if (k in pkgconf) {
        if(util.isArray(pkgconf[k])) {
          pkgconf[k].push(v);
        } else {
          pkgconf[k] = [pkgconf[k], v];
        }
      } else {
        pkgconf[k] = v;
      }
    }
  },
  function() {
    allPkgs.forEach(function(pkg) {
      pkgIndex[pkg['FILE_NAME']] = pkg;
    });
    callback();
  });
}

function search(key, needReturn) {
  var re = /-\d/;
  function pkgMatch(fileName, key) {
    var r = re.exec(fileName);
    return fileName.slice(0, r.index) === key;
  }
  var r = [];
  allPkgs.forEach(function(pkg) {
    if (pkgMatch(pkg['FILE_NAME'], key)) {
      r.push(pkg['FILE_NAME']);
    }
  });
  if (needReturn) {
    return r;
  } else {
    r.forEach(function(name) {
      console.log(name);
    });
  }
}

function dep(pkgName) {
  function getPrefix(level) {
    if (devMode) {
      return '';
    }
    var r = [];
    for (var i=0; i<level; i++) { r.push(' '); }
    return r.join('');
  }
  function findPkg(pkgName) {
    var p = pkgName.indexOf('>=');
    if (p >= 0) {
      var key = pkgName.slice(0, p);
      var allPossible = search(key, 'wantReturn');
      return pkgIndex[allPossible[allPossible.length - 1]];
    }
    p = pkgName.indexOf('-[');
    if (p >= 0) {
      var key = pkgName.slice(0, p);
      var allPossible = search(key, 'wantReturn');
      return pkgIndex[allPossible[allPossible.length - 1]];
    }
    return pkgIndex[pkgName];
  }
  function parseDep(rawDep, dest) {
    var re = /{([\S]+)}/;
    var r = re.exec(rawDep);
    //console.log('will handle:', rawDep);
    if (r) {
      var suffix = rawDep.slice(r[0].length);
      r[1].split(',').forEach(function(dep) {
        dest.push(dep + suffix);
      });
    } else {
      dest.push(rawDep);
    }
  }
  function parseDeps(rawDeps) {
    var r = [];
    if (util.isArray(rawDeps)) {
      rawDeps.forEach(function(dep) {
        parseDep(dep, r);
      });
    } else {
      parseDep(rawDeps, r);
    }
    return r;
  }
  function findDep(level, pkgName) {
    var prefix = getPrefix(level);
    var pkg = findPkg(pkgName);
    if (!pkg) {
      console.log(prefix + '*' + pkgName);
      return;
    }
    console.log(prefix + pkg['FILE_NAME']);
    if ('DEPENDS' in pkg) {
      var deps = parseDeps(pkg['DEPENDS']);
      deps.forEach(function(dep) {
        findDep(level+1, dep);
      });
    }
  }
  findDep(0, pkgName);
}

function print(pkgName) {
  console.log(pkgIndex[pkgName]);
}

function printAll() {
  allPkgs.forEach(function(pkg) {
    console.log(pkg['FILE_NAME']);
  });
}

function latest(printPrefix) {
  var re1 = /(^.*)(p|pre)(\d+)\.(.*$)/; // test pre/p release
  var re2 = /(^.*)\.(.*$)/; // test non pre/p release
  var typeMap = { 'p': 2, '': 1, 'pre': 0 };
  function _parseType(pkgname) {
    var r = re1.exec(pkgname);
    if (r) {
      return typeMap[r[2]];
    } else {
      r = re2.exec(pkgname);
      if (r) {
        return typeMap[''];
      } else {
        console.log('oops:', pkgname);
        process.exit(1);
      }
    }
  }
  function _vercomp(pkgname1, pkgname2) {
    if (pkgname1 === undefined) { return -1; }
    var t1 = _parseType(pkgname1);
    var t2 = _parseType(pkgname2);
    if (t1 < t2) {
      return -1;
    } else if (t1 > t2) {
      return 1;
    }
    // very naive algorithm
    if (pkgname1.length < pkgname2.length) {
      // e.g. xxx-0.1.0 < xxx-0.1.10
      //      xxx-0.1.0 < xxx-0.1.1p1
      return -1;
    } else if (pkgname1.length > pkgname2.length) {
      return 1;
    } else {
      // now use the asc order
      if (pkgname1 < pkgname2) {
        return -1;
      } else if (pkgname1 === pkgname2) {
        return 0;
      } else {
        return 1;
      }
    }
  }

  var l = {};
  // use comment to differ the pkgs, and assume that pkgs input is in asc order
  allPkgs.forEach(function(pkg) {
    if (pkg['COMMENT']) {
      var r = _vercomp(l[pkg['COMMENT']], pkg['FILE_NAME']);
      if (r < 0) {
        l[pkg['COMMENT']] = pkg['FILE_NAME'];
      }
    } else {
      l[pkg['COMMENT']] = pkg['FILE_NAME'];
    }
  });
  Object.keys(l).forEach(function(key) {
    console.log((printPrefix || '') + l[key]);
  });
}

function printPkgSummary(pkgName) {
  if (pkgName in pkgIndex) {
    console.log(pkgIndex[pkgName].raw.join('\n'));
  }
}

loadPkgs(process.argv[2], function() {
  if (process.argv[3]) {
    switch(process.argv[3]) {
      case 'search':
        search(process.argv[4]);
        break;
      case 'dep_dev':
        devMode = true;
      case 'dep':
        for (var i=4; i<process.argv.length; i++) {
          dep(process.argv[i]);
        }
        break;
      case 'print':
        print(process.argv[4]);
        break;
      case 'pkg_summary':
        printPkgSummary(process.argv[4]);
        break;
      case 'latest':
        latest(process.argv[4]);
        break;
    }
  } else {
    printAll();
  }
});
