"use strict";

const {setGlobalOptions} = require("firebase-functions");
const {onRequest, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Init admin (idempotent)
try {
  admin.app();
} catch (_) {
  admin.initializeApp();
}

// Global options (gabung region + maxInstances)
setGlobalOptions({region: "asia-southeast2", maxInstances: 10});

// HTTP quick check
exports.ping = onRequest((req, res) => {
  logger.info("ping");
  res.status(200).send("ok");
});

// Callable untuk kirim notifikasi SOS via FCM topic
exports.sendSos = onCall(async (request) => {
  const data = request.data || {};
  const topic = data.topic || "sos";
  const title = data.title || "SOS";
  const body = data.body || "Permintaan bantuan";

  await admin.messaging().send({
    topic,
    notification: {title, body},
  });

  return {ok: true};
});
