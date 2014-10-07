// Generated by CoffeeScript 1.8.0
var User, checkBody, db, logger, nodemailer, sendEmail, user;

nodemailer = require("nodemailer");

logger = require('printit')({
  date: false,
  prefix: 'controllers:mails'
});

User = require('../lib/user');

user = new User();

db = require('../helpers/db_connect_helper').db_connect();

sendEmail = function(mailOptions, callback) {
  var transport;
  transport = nodemailer.createTransport("SMTP", {});
  return transport.sendMail(mailOptions, function(error, response) {
    transport.close();
    return callback(error, response);
  });
};

checkBody = function(body, attributes) {
  var attr, missingAttributes, _i, _len;
  missingAttributes = [];
  for (_i = 0, _len = attributes.length; _i < _len; _i++) {
    attr = attributes[_i];
    if (body[attr] == null) {
      missingAttributes.push(attr);
    }
  }
  return missingAttributes;
};

module.exports.send = function(req, res, next) {
  var attrs, body, err, mailOptions, missingAttributes;
  body = req.body;
  missingAttributes = checkBody(body, ['to', 'from', 'subject', 'content']);
  if (missingAttributes.length > 0) {
    attrs = missingAttributes.join(" ");
    err = new Error("Body has at least one missing attribute (" + attrs + ").");
    err.status = 400;
    return next(err);
  } else {
    mailOptions = {
      to: body.to,
      from: body.from,
      subject: body.subject,
      cc: body.cc,
      bcc: body.bcc,
      replyTo: body.replyTo,
      inReplyTo: body.inReplyTo,
      references: body.references,
      headers: body.headers,
      alternatives: body.alternatives,
      envelope: body.envelope,
      messageId: body.messageId,
      date: body.date,
      encoding: body.encoding,
      text: body.content,
      html: body.html || void 0
    };
    if (body.attachments != null) {
      mailOptions.attachments = body.attachments;
    }
    return sendEmail(mailOptions, function(error, response) {
      if (error) {
        logger.info("[sendMail] Error : " + error);
        return next(new Error(error));
      } else {
        return res.send(200, response);
      }
    });
  }
};

module.exports.sendToUser = function(req, res, next) {
  var attrs, body, err, missingAttributes;
  body = req.body;
  missingAttributes = checkBody(body, ['from', 'subject', 'content']);
  if (missingAttributes.length > 0) {
    attrs = missingAttributes.join(" ");
    err = new Error("Body has at least one missing attribute (" + attrs + ").");
    err.status = 400;
    return next(err);
  } else {
    return user.getUser(function(err, user) {
      var mailOptions;
      if (err) {
        logger.info("[sendMailToUser] err: " + err);
        return next(new Error(err));
      } else {
        mailOptions = {
          to: user.email,
          from: body.from,
          subject: body.subject,
          text: body.content,
          html: body.html || void 0
        };
        if (body.attachments != null) {
          mailOptions.attachments = body.attachments;
        }
        return sendEmail(mailOptions, function(error, response) {
          if (error) {
            logger.info("[sendMail] Error : " + error);
            return next(new Error(error));
          } else {
            return res.send(200, response);
          }
        });
      }
    });
  }
};

module.exports.sendFromUser = function(req, res, next) {
  var attrs, body, domain, err, missingAttributes;
  body = req.body;
  missingAttributes = checkBody(body, ['to', 'subject', 'content']);
  if (missingAttributes.length > 0) {
    attrs = missingAttributes.join(" ");
    err = new Error("Body has at least one missing attribute (" + attrs + ").");
    err.status = 400;
    return next(err);
  } else {
    domain = "cozycloud.cc";
    return db.view('cozyinstance/all', function(err, instance) {
      var _ref;
      if ((instance != null ? (_ref = instance[0]) != null ? _ref.value.domain : void 0 : void 0) != null) {
        domain = instance[0].value.domain;
      }
      return user.getUser(function(err, user) {
        var mailOptions;
        if (err) {
          logger.info("[sendMailFromUser] err: " + err);
          return next(new Error(err));
        } else {
          mailOptions = {
            to: body.to,
            from: "noreply@" + domain,
            subject: body.subject,
            text: body.content,
            html: body.html || void 0
          };
          if (body.attachments != null) {
            mailOptions.attachments = body.attachments;
          }
          return sendEmail(mailOptions, function(error, response) {
            if (error) {
              logger.info("[sendMail] Error : " + error);
              return next(new Error(error));
            } else {
              return res.send(200, response);
            }
          });
        }
      });
    });
  }
};
