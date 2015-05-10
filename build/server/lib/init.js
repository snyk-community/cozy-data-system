// Generated by CoffeeScript 1.9.0
var async, db, getLostBinaries, log, thumb;

log = require('printit')({
  date: true,
  prefix: 'lib/init'
});

db = require('../helpers/db_connect_helper').db_connect();

async = require('async');

thumb = require('./thumb');

getLostBinaries = exports.getLostBinaries = function(callback) {
  var lostBinaries;
  lostBinaries = [];
  return db.view('binary/all', function(err, binaries) {
    if (!err && binaries.length > 0) {
      return db.view('binary/byDoc', function(err, docs) {
        var binary, doc, keys, _i, _j, _len, _len1;
        if (!err && (docs != null)) {
          keys = [];
          for (_i = 0, _len = docs.length; _i < _len; _i++) {
            doc = docs[_i];
            keys[doc.key] = true;
          }
          for (_j = 0, _len1 = binaries.length; _j < _len1; _j++) {
            binary = binaries[_j];
            if (keys[binary.id] == null) {
              lostBinaries.push(binary.id);
            }
          }
          return callback(null, lostBinaries);
        } else {
          return callback(null, []);
        }
      });
    } else {
      return callback(err, []);
    }
  });
};

exports.removeLostBinaries = function(callback) {
  return getLostBinaries(function(err, binaries) {
    if (err != null) {
      return callback(err);
    }
    return async.forEachSeries(binaries, (function(_this) {
      return function(binary, cb) {
        log.info("Remove binary " + binary);
        return db.get(binary, function(err, doc) {
          if (!err && doc) {
            return db.remove(doc._id, doc._rev, function(err, doc) {
              if (err) {
                log.error(err);
              }
              return cb();
            });
          } else {
            if (err) {
              log.error(err);
            }
            return cb();
          }
        });
      };
    })(this), callback);
  });
};

exports.addThumbs = function(callback) {
  return db.view('file/withoutThumb', function(err, files) {
    if (err) {
      return callback(err);
    } else if (files.length === 0) {
      return callback();
    } else {
      return async.forEachSeries(files, (function(_this) {
        return function(file, cb) {
          return db.get(file.id, function(err, file) {
            if (err) {
              log.info("Cant get File " + file.id + " for thumb");
              log.info(err);
              return cb();
            }
            thumb.create(file, false);
            return cb();
          });
        };
      })(this), callback);
    }
  });
};
