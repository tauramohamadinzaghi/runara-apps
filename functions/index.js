const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

// --- Pairing backend for IoT ---
try {
  admin.app();
} catch {
  admin.initializeApp();
}
setGlobalOptions({region: "asia-southeast2", maxInstances: 10});

const db = admin.firestore();

exports.ping = onRequest((req, res) => res.send("ok"));

exports.sendSos = onCall(async (request) => {
  const d = request.data || {};
  const topic = d.topic || "sos";

  await admin.messaging().send({
    topic,
    notification: {
      title: d.title || "Permintaan Bantuan Segera",
      body: d.address || d.body || "Tap untuk buka",
    },
    data: {
      type: "sos",
      name: String(d.name ?? ""),
      role: String(d.role ?? ""),
      address: String(d.address ?? ""),
      lat: d.lat != null ? String(d.lat) : "",
      lng: d.lng != null ? String(d.lng) : "",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
  });

  return {ok: true};
});

/**
 * DEVICE -> POST /offerPair
 * body: { deviceId: "esp32-abc", code: "123456" }
 * simpan penawaran pairing selama 5 menit
 */
exports.offerPair = onRequest({cors: true}, async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("POST only");
  const {deviceId, code} = req.body || {};
  if (!deviceId || !code) {
    return res.status(400).json({error: "deviceId & code required"});
  }

  await db.collection("pair_offers").doc(String(code)).set({
    deviceId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: Date.now() + 5 * 60 * 1000,
  });

  return res.json({ok: true});
});

/**
 * APP -> callable confirmPair({code})
 * cek code, kaitkan device ke user (jika login), hapus offer
 */
exports.confirmPair = onCall(async (data, context) => {
  const code = String(data?.code || "");
  if (!code) throw new HttpsError("invalid-argument", "code required");

  const offerRef = db.collection("pair_offers").doc(code);
  const snap = await offerRef.get();
  if (!snap.exists) throw new HttpsError("not-found", "invalid or expired code");

  const offer = snap.data() || {};
  if (offer.expiresAt && offer.expiresAt < Date.now()) {
    await offerRef.delete();
    throw new HttpsError("deadline-exceeded", "code expired");
  }

  const deviceId = String(offer.deviceId);
  const ownerUid = context.auth?.uid || null;

  await db.collection("devices").doc(deviceId).set(
      {
        ownerUid,
        pairedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );
  await offerRef.delete();

  return {ok: true, deviceId};
});

/**
 * DEVICE -> GET /deviceClaimStatus?deviceId=esp32-abc
 * untuk cek apakah sudah di-claim user
 */
exports.deviceClaimStatus = onRequest({cors: true}, async (req, res) => {
  const deviceId = String(req.query.deviceId || req.body?.deviceId || "");
  if (!deviceId) return res.status(400).json({error: "deviceId required"});

  const doc = await db.collection("devices").doc(deviceId).get();
  return res.json({ownerUid: doc.exists ? doc.data().ownerUid || null : null});
});
