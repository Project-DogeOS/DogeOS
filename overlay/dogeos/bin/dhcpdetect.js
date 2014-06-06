// This is tool is made to detect the dhcp server in same network, which is a
// checking step before we allow user to setup a PXE server (otherwise the PXE
// server will not work as dhcp server conflicts).

// usage: node dhcpdetect.js <either-mac> <timeout>s

// this tool will exit after <timeout>s 100%

// return:
//   exit code 0 for detected, or 1 for failure

// most of the code is adapted from
//   https://raw.githubusercontent.com/apaprocki/node-dhcpjs
//   Copyright (c) 2011 Andrew Paprocki
// by LI, Yu

var EventEmitter = require('events').EventEmitter;
var util = require('util');
var dgram = require('dgram');
var assert = require('assert');

// adapted from protocol.js

var protocol = (function () {
  var createEnum = function(v, n) {
    function Enum(value, name) {
      this.value = value;
      this.name = name;
    }
    Enum.prototype.toString = function() { return this.name; };
    Enum.prototype.valueOf = function() { return this.value; };
    return Object.freeze(new Enum(v, n));
  }

  var createHardwareAddress = function(t, a) {
    return Object.freeze({ type: t, address: a });
  }

  return {
    createHardwareAddress: createHardwareAddress,

    BOOTPMessageType: Object.freeze({
      BOOTPREQUEST: createEnum(1, 'BOOTPREQUEST'),
      BOOTPREPLY: createEnum(2, 'BOOTPREPLY'),
      get: function(value) {
        for (key in this) {
          var obj = this[key];
          if (obj == value)
            return obj;
        }
        return undefined;
      }
    }),

    // rfc1700 hardware types
    ARPHardwareType: Object.freeze({
      HW_ETHERNET: createEnum(1, 'HW_ETHERNET'),
      HW_EXPERIMENTAL_ETHERNET: createEnum(2, 'HW_EXPERIMENTAL_ETHERNET'),
      HW_AMATEUR_RADIO_AX_25: createEnum(3, 'HW_AMATEUR_RADIO_AX_25'),
      HW_PROTEON_TOKEN_RING: createEnum(4, 'HW_PROTEON_TOKEN_RING'),
      HW_CHAOS: createEnum(5, 'HW_CHAOS'),
      HW_IEEE_802_NETWORKS: createEnum(6, 'HW_IEEE_802_NETWORKS'),
      HW_ARCNET: createEnum(7, 'HW_ARCNET'),
      HW_HYPERCHANNEL: createEnum(8, 'HW_HYPERCHANNEL'),
      HW_LANSTAR: createEnum(9, 'HW_LANSTAR'),
      get: function(value) {
        for (key in this) {
          var obj = this[key];
          if (obj == value)
            return obj;
        }
        return undefined;
      }
    }),

    // rfc1533 code 53 dhcpMessageType
    DHCPMessageType: Object.freeze({
      DHCPDISCOVER: createEnum(1, 'DHCPDISCOVER'),
      DHCPOFFER: createEnum(2, 'DHCPOFFER'),
      DHCPREQUEST: createEnum(3, 'DHCPREQUEST'),
      DHCPDECLINE: createEnum(4, 'DHCPDECLINE'),
      DHCPACK: createEnum(5, 'DHCPACK'),
      DHCPNAK: createEnum(6, 'DHCPNAK'),
      DHCPRELEASE: createEnum(7, 'DHCPRELEASE'),
      get: function(value) {
        for (key in this) {
          var obj = this[key];
          if (obj == value)
            return obj;
        }
        return undefined;
      }
    })
  }
})();

// adapted from parser.js

var parser = (function() {
  var exports = {};
  exports.parse = function(msg, rinfo) {
    function trimNulls(str) {
      var idx = str.indexOf('\u0000');
      return (-1 === idx) ? str : str.substr(0, idx);
    }
    function readIpRaw(msg, offset) {
      if (0 === msg.readUInt8(offset))
        return undefined;
      return '' +
        msg.readUInt8(offset++) + '.' +
        msg.readUInt8(offset++) + '.' +
        msg.readUInt8(offset++) + '.' +
        msg.readUInt8(offset++);
    }
    function readIp(msg, offset, obj, name) {
      var len = msg.readUInt8(offset++);
      assert.strictEqual(len, 4);
      p.options[name] = readIpRaw(msg, offset);
      return offset + len;
    }
    function readString(msg, offset, obj, name) {
      var len = msg.readUInt8(offset++);
      p.options[name] = msg.toString('ascii', offset, offset + len);
      offset += len;
      return offset;
    }
    function readAddressRaw(msg, offset, len) {
      var addr = '';
      while (len-- > 0) {
        var b = msg.readUInt8(offset++);
        addr += (b + 0x100).toString(16).substr(-2);
        if (len > 0) {
          addr += ':';
        }
      }
      return addr;
    }
    //console.log(rinfo.address + ':' + rinfo.port + '/' + msg.length + 'b');
    var p = {
      op: protocol.BOOTPMessageType.get(msg.readUInt8(0)),
      // htype is combined into chaddr field object
      hlen: msg.readUInt8(2),
      hops: msg.readUInt8(3),
      xid: msg.readUInt32BE(4),
      secs: msg.readUInt16BE(8),
      flags: msg.readUInt16BE(10),
      ciaddr: readIpRaw(msg, 12),
      yiaddr: readIpRaw(msg, 16),
      siaddr: readIpRaw(msg, 20),
      giaddr: readIpRaw(msg, 24),
      chaddr: protocol.createHardwareAddress(
        protocol.ARPHardwareType.get(msg.readUInt8(1)),
        readAddressRaw(msg, 28, msg.readUInt8(2))),
        sname: trimNulls(msg.toString('ascii', 44, 108)),
        file: trimNulls(msg.toString('ascii', 108, 236)),
        magic: msg.readUInt32BE(236),
        options: {}
    };
    var offset = 240;
    var code = 0;
    while (code != 255 && offset < msg.length) {
      code = msg.readUInt8(offset++);
      switch (code) {
        case 0: continue;   // pad
        case 255: break;    // end
        case 1: {           // subnetMask
          offset = readIp(msg, offset, p, 'subnetMask');
          break;
        }
        case 2: {           // timeOffset
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len, 4);
          p.options.timeOffset = msg.readUInt32BE(offset);
          offset += len;
          break;
        }
        case 3: {           // routerOption
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len % 4, 0);
          p.options.routerOption = [];
          while (len > 0) {
            p.options.routerOption.push(readIpRaw(msg, offset));
            offset += 4;
            len -= 4;
          }
          break;
        }
        case 4: {           // timeServerOption
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len % 4, 0);
          p.options.timeServerOption = [];
          while (len > 0) {
            p.options.timeServerOption.push(readIpRaw(msg, offset));
            offset += 4;
            len -= 4;
          }
          break;
        }
        case 6: {           // domainNameServerOption
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len % 4, 0);
          p.options.domainNameServerOption = [];
          while (len > 0) {
            p.options.domainNameServerOption.push(
              readIpRaw(msg, offset));
              offset += 4;
              len -= 4;
          }
          break;
        }
        case 12: {          // hostName
          offset = readString(msg, offset, p, 'hostName');
          break;
        }
        case 15: {          // domainName
          offset = readString(msg, offset, p, 'domainName');
          break;
        }
        case 43: {          // vendorOptions
          var len = msg.readUInt8(offset++);
          p.options.vendorOptions = {};
          while (len > 0) {
            var vendop = msg.readUInt8(offset++);
            var vendoplen = msg.readUInt8(offset++);
            var buf = new Buffer(vendoplen);
            msg.copy(buf, 0, offset, offset + vendoplen);
            p.options.vendorOptions[vendop] = buf;
            len -= 2 + vendoplen;
          }
          break;
        }
        case 50: {          // requestedIpAddress
          offset = readIp(msg, offset, p, 'requestedIpAddress');
          break;
        }
        case 51: {          // ipAddressLeaseTime
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len, 4);
          p.options.ipAddressLeaseTime =
            msg.readUInt32BE(offset);
          offset += 4;
          break;
        }
        case 52: {          // optionOverload
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len, 1);
          p.options.optionOverload = msg.readUInt8(offset++);
          break;
        }
        case 53: {          // dhcpMessageType
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len, 1);
          var mtype = msg.readUInt8(offset++);
          assert.ok(1 <= mtype);
          assert.ok(8 >= mtype);
          p.options.dhcpMessageType = protocol.DHCPMessageType.get(mtype);
          break;
        }
        case 54: {          // serverIdentifier
          offset = readIp(msg, offset, p, 'serverIdentifier');
          break;
        }
        case 55: {          // parameterRequestList
          var len = msg.readUInt8(offset++);
          p.options.parameterRequestList = [];
          while (len-- > 0) {
            var option = msg.readUInt8(offset++);
            p.options.parameterRequestList.push(option);
          }
          break;
        }
        case 57: {          // maximumMessageSize
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len, 2);
          p.options.maximumMessageSize = msg.readUInt16BE(offset);
          offset += len;
          break;
        }
        case 58: {          // renewalTimeValue
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len, 4);
          p.options.renewalTimeValue = msg.readUInt32BE(offset);
          offset += len;
          break;
        }
        case 59: {          // rebindingTimeValue
          var len = msg.readUInt8(offset++);
          assert.strictEqual(len, 4);
          p.options.rebindingTimeValue = msg.readUInt32BE(offset);
          offset += len;
          break;
        }
        case 60: {          // vendorClassIdentifier
          offset = readString(msg, offset, p, 'vendorClassIdentifier');
          break;
        }
        case 61: {          // clientIdentifier
          var len = msg.readUInt8(offset++);
          p.options.clientIdentifier =
            protocol.createHardwareAddress(
              protocol.ARPHardwareType.get(msg.readUInt8(offset)),
          readAddressRaw(msg, offset + 1, len - 1));
          offset += len;
          break;
        }
        case 81: {          // fullyQualifiedDomainName
          var len = msg.readUInt8(offset++);
          p.options.fullyQualifiedDomainName = {
            flags: msg.readUInt8(offset),
            name: msg.toString('ascii', offset + 3, offset + len)
          };
          offset += len;
          break;
        }
        case 118: {       // subnetSelection
          offset = readIp(msg, offset, p, 'subnetAddress');
          break;
        }
        default: {
          var len = msg.readUInt8(offset++);
          console.error('Unhandled DHCP option ' + code + '/' + len + 'b');
          offset += len;
          break;
        }
      }
    }
    return p;
  };
  return exports;
})();

// now continue to client.js

function Client(options) {
  if (options) {
    if (typeof(options) !== 'object')
      throw new TypeError('options must be an object');
  } else {
    options = {};
  }

  var self = this;
  EventEmitter.call(this, options);

  this.client = dgram.createSocket('udp4');
  this.client.on('message', function(msg) {
    var pkt = parser.parse(msg);
    switch (pkt.options.dhcpMessageType.value) {
      case protocol.DHCPMessageType.DHCPOFFER.value:
        self.emit('dhcpOffer', pkt);
      break;
      case protocol.DHCPMessageType.DHCPACK.value:
        self.emit('dhcpAck', pkt);
      break;
      case protocol.DHCPMessageType.DHCPNAK.value:
        self.emit('dhcpNak', pkt);
      break;
      default:
        assert(!'Client: received unhandled DHCPMessageType ' +
               pkt.options.dhcpMessageType.value);
    }
  });
  this.client.on('listening', function() {
    var address = self.client.address();
    self.emit('listening', address.address + ':' + address.port);
  });
}
util.inherits(Client, EventEmitter);

Client.prototype.bind = function(host, port, cb) {
  var that = this;
  if (!port) port = 68;
  this.client.bind(port, host, function() {
    that.client.setBroadcast(true);
    if (cb && cb instanceof Function) {
      process.nextTick(cb);
    }
  });
};

Client.prototype.broadcastPacket = function(pkt, options, cb) {
  var port = 67;
  var host = '255.255.255.255';
  if (options) {
    if ('port' in options) port = options.port;
    if ('host' in options) host = options.host;
  }
  this.client.send(pkt, 0, pkt.length, port, host, cb);
};

Client.prototype.createPacket = function(pkt) {
  if (!('xid' in pkt))
    throw new Error('pkt.xid required');

  /* skip the customize ci/yi/si/gi part

  var ci = new Buffer(('ciaddr' in pkt) ?
      new v4.Address(pkt.ciaddr).toArray() : [0, 0, 0, 0]);
  var yi = new Buffer(('yiaddr' in pkt) ?
      new v4.Address(pkt.yiaddr).toArray() : [0, 0, 0, 0]);
  var si = new Buffer(('siaddr' in pkt) ?
      new v4.Address(pkt.siaddr).toArray() : [0, 0, 0, 0]);
  var gi = new Buffer(('giaddr' in pkt) ?
      new v4.Address(pkt.giaddr).toArray() : [0, 0, 0, 0]);
  */
  var ci = new Buffer([0, 0, 0, 0]);
  var yi = new Buffer([0, 0, 0, 0]);
  var si = new Buffer([0, 0, 0, 0]);
  var gi = new Buffer([0, 0, 0, 0]);


  if (!('chaddr' in pkt))
    throw new Error('pkt.chaddr required');
  var hw = new Buffer(pkt.chaddr.split(':').map(function(part) {
    return parseInt(part, 16);
  }));
  if (hw.length !== 6)
    throw new Error('pkt.chaddr malformed, only ' + hw.length + ' bytes');

  var p = new Buffer(1500);
  var i = 0;

  p.writeUInt8(pkt.op,    i++);
  p.writeUInt8(pkt.htype, i++);
  p.writeUInt8(pkt.hlen,  i++);
  p.writeUInt8(pkt.hops,  i++);
  p.writeUInt32BE(pkt.xid,   i); i += 4;
  p.writeUInt16BE(pkt.secs,  i); i += 2;
  p.writeUInt16BE(pkt.flags, i); i += 2;
  ci.copy(p, i); i += ci.length;
  yi.copy(p, i); i += yi.length;
  si.copy(p, i); i += si.length;
  gi.copy(p, i); i += gi.length;
  hw.copy(p, i); i += hw.length;
  p.fill(0, i, i + 10); i += 10; // hw address padding
  p.fill(0, i, i + 192); i += 192;
  p.writeUInt32BE(0x63825363, i); i += 4;

  if (pkt.options && 'requestedIpAddress' in pkt.options) {
    p.writeUInt8(50, i++); // option 50
    var requestedIpAddress = new Buffer(
      new v4.Address(pkt.options.requestedIpAddress).toArray());
      p.writeUInt8(requestedIpAddress.length, i++);
      requestedIpAddress.copy(p, i); i += requestedIpAddress.length;
  }
  if (pkt.options && 'dhcpMessageType' in pkt.options) {
    p.writeUInt8(53, i++); // option 53
    p.writeUInt8(1, i++);  // length
    p.writeUInt8(pkt.options.dhcpMessageType.value, i++);
  }
  if (pkt.options && 'serverIdentifier' in pkt.options) {
    p.writeUInt8(54, i++); // option 54
    var serverIdentifier = new Buffer(
      new v4.Address(pkt.options.serverIdentifier).toArray());
      p.writeUInt8(serverIdentifier.length, i++);
      serverIdentifier.copy(p, i); i += serverIdentifier.length;
  }
  if (pkt.options && 'parameterRequestList' in pkt.options) {
    p.writeUInt8(55, i++); // option 55
    var parameterRequestList = new Buffer(pkt.options.parameterRequestList);
    if (parameterRequestList.length > 16)
      throw new Error('pkt.options.parameterRequestList malformed');
    p.writeUInt8(parameterRequestList.length, i++);
    parameterRequestList.copy(p, i); i += parameterRequestList.length;
  }
  if (pkt.options && 'clientIdentifier' in pkt.options) {
    var clientIdentifier = new Buffer(pkt.options.clientIdentifier);
    var optionLength = 1 + clientIdentifier.length;
    if (optionLength > 0xff)
      throw new Error('pkt.options.clientIdentifier malformed');
    p.writeUInt8(61, i++);           // option 61
    p.writeUInt8(optionLength, i++); // length
    p.writeUInt8(0, i++);            // hardware type 0
    clientIdentifier.copy(p, i); i += clientIdentifier.length;
  }

  // option 255 - end
  p.writeUInt8(0xff, i++);

  // padding
  if ((i % 2) > 0) {
    p.writeUInt8(0, i++);
  } else {
    p.writeUInt16BE(0, i++);
  }

  var remaining = 300 - i;
  if (remaining) {
    p.fill(0, i, i + remaining); i+= remaining;
  }

  //console.log('createPacket:', i, 'bytes');
  return p.slice(0, i);
};

Client.prototype.createDiscoverPacket = function(user) {
  var pkt = {
    op:     0x01,
    htype:  0x01,
    hlen:   0x06,
    hops:   0x00,
    xid:    0x00000000,
    secs:   0x0000,
    flags:  0x0000,
    ciaddr: '0.0.0.0',
    yiaddr: '0.0.0.0',
    siaddr: '0.0.0.0',
    giaddr: '0.0.0.0',
  };
  if ('xid' in user) pkt.xid = user.xid;
  if ('chaddr' in user) pkt.chaddr = user.chaddr;
  if ('options' in user) pkt.options = user.options;
  return Client.prototype.createPacket(pkt);
};

// now is the command line part
// adapted from example-client.js

var client = new Client();
client.on('message', function(pkt) {
  console.error('message:', util.inspect(pkt, false, 3));
});
client.on('dhcpOffer', function(pkt) {
  //console.error('dhcpOffer:', util.inspect(pkt, false, 3));
  // got offer, it is a success
  console.log('detected');
  process.exit(0);
});
client.on('dhcpAck', function(pkt) {
  console.error('dhcpAck:', util.inspect(pkt, false, 3));
});
client.on('dhcpNak', function(pkt) {
  console.error('dhcpNak:', util.inspect(pkt, false, 3));
});
client.on('listening', function(addr) {
  console.error('listening on', addr);
});
client.bind('0.0.0.0', 68, function() {
  console.error('bound to 0.0.0.0:68');
});

// Configure a DHCPDISCOVER packet:
//   xid 0x01               Transaction ID. This is a counter that the DHCP
//                          client should maintain and increment every time
//                          a packet is broadcast.
//
//   chaddr                 Ethernet address of the interface being configured.
//
//   options                Object containing keys that map to DHCP options.
//
//   dhcpMessageType        Option indicating a DHCP protocol message (as
//                          opposed to a plain BOOTP protocol message).
//
//   clientIdentifier       Option indicating a client-configured unique name
//                          to be used to disambiguate the lease on the server.

var pkt = {
  xid: 0x01,
  chaddr: process.argv[2],
  options: {
    dhcpMessageType: protocol.DHCPMessageType.DHCPDISCOVER,
    clientIdentifier: 'dogeos-dhcp-detector',
  }
};

var discover = client.createDiscoverPacket(pkt);
client.broadcastPacket(discover, undefined, function() {
  console.error('dhcpDiscover: sent');
});

setTimeout(function() {
  console.error('timeout');
  process.exit(1);
}, (process.argv[3] || 5)*1000);
