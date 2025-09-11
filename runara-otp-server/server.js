// server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const app = express();
app.use(cors());
app.use(express.json());

// ====== Firebase Admin init ======
let adminInitialized = false;
try {
  // 1) Pakai serviceAccountKey.json di root (disarankan saat dev)
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  adminInitialized = true;
  console.log('[firebase-admin] initialized with serviceAccountKey.json');
} catch (e) {
  // 2) Atau pakai GOOGLE_APPLICATION_CREDENTIALS (env var) yang menunjuk ke file JSON
  try {
    admin.initializeApp(); // baca GOOGLE_APPLICATION_CREDENTIALS
    adminInitialized = true;
    console.log('[firebase-admin] initialized with GOOGLE_APPLICATION_CREDENTIALS');
  } catch (e2) {
    console.error('[firebase-admin] init failed:', e2.message);
  }
}

if (!adminInitialized) {
  console.error('FATAL: Firebase Admin belum terinisialisasi. Pastikan serviceAccountKey.json atau GOOGLE_APPLICATION_CREDENTIALS diset.');
  process.exit(1);
}

// ====== Twilio init (Messaging Service OR From Number) ======
let twilio = null;
const hasTwilio =
  process.env.TWILIO_ACCOUNT_SID &&
  process.env.TWILIO_AUTH_TOKEN &&
  (process.env.TWILIO_MESSAGING_SID || process.env.TWILIO_FROM);

if (hasTwilio) {
  twilio = require('twilio')(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  );
  console.log('[twilio] enabled (sender =',
    process.env.TWILIO_MESSAGING_SID ? `service ${process.env.TWILIO_MESSAGING_SID}` : `number ${process.env.TWILIO_FROM}`,
    ')'
  );
} else {
  console.log('[twilio] disabled (env tidak lengkap). OTP akan di-log di console saja.');
}

// ====== OTP store sederhana (in-memory) ======
/** Map: phoneE164 -> { code, exp, attempts } */
const otpStore = new Map();
const OTP_TTL_MS = 2 * 60 * 1000; // 2 menit

function make6Code() {
  return (Math.floor(100000 + Math.random() * 900000)).toString();
}

// ====== Endpoint: kirim OTP ======
app.post('/otp/start', async (req, res) => {
  try {
    const phone = (req.body?.phone || '').trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      return res.status(400).json({ ok: false, error: 'Format nomor tidak valid. Gunakan E.164, contoh +62812xxxx.' });
    }

    const code = make6Code();
    const exp  = Date.now() + OTP_TTL_MS;
    otpStore.set(phone, { code, exp, attempts: 0 });

    // Kirim via Twilio kalau tersedia; kalau tidak, log di console
    if (twilio) {
      const payload = {
        to: phone,
        body: `RUNARA OTP: ${code}. Berlaku 2 menit.`,
      };

      // Utamakan Messaging Service (lebih kompatibel lintas negara)
      if (process.env.TWILIO_MESSAGING_SID) {
        payload.messagingServiceSid = process.env.TWILIO_MESSAGING_SID;
      } else {
        payload.from = process.env.TWILIO_FROM;
      }

      await twilio.messages.create(payload);
      console.log(`[otp] sent via Twilio to ${phone}`);
    } else {
      console.log(`[otp] ${phone} -> ${code} (Twilio OFF; kirim manual, kode hanya di-log)`);
    }

    return res.json({ ok: true });
  } catch (e) {
    console.error('/otp/start error:', e);
    return res.status(500).json({ ok: false, error: 'Gagal kirim OTP' });
  }
});

// ====== Endpoint: verifikasi OTP dan buat custom token ======
app.post('/otp/verify', async (req, res) => {
  try {
    const phone = (req.body?.phone || '').trim();
    const code  = (req.body?.code  || '').trim();

    const entry = otpStore.get(phone);
    if (!entry) {
      return res.status(400).json({ ok: false, error: 'OTP belum diminta atau sudah kedaluwarsa' });
    }
    if (Date.now() > entry.exp) {
      otpStore.delete(phone);
      return res.status(400).json({ ok: false, error: 'OTP kedaluwarsa, minta ulang' });
    }
    if (entry.attempts >= 5) {
      otpStore.delete(phone);
      return res.status(400).json({ ok: false, error: 'Percobaan terlalu banyak, minta ulang OTP' });
    }
    entry.attempts += 1;

    if (code !== entry.code) {
      return res.status(400).json({ ok: false, error: 'Kode OTP salah' });
    }

    // OTP benar: hapus dari store
    otpStore.delete(phone);

    // Buat UID (contoh: prefix phone:)
    const uid = `phone:${phone.replace(/[^\d+]/g, '')}`;

    // Buat custom token Firebase
    const customToken = await admin.auth().createCustomToken(uid, {
      auth_provider: 'phone-otp',
      phone,
    });

    return res.json({ ok: true, token: customToken });
  } catch (e) {
    console.error('/otp/verify error:', e);
    return res.status(500).json({ ok: false, error: 'Verifikasi gagal' });
  }
});

// ====== Health check ======
app.get('/health', (_req, res) => res.json({ ok: true }));

// ====== Start server ======
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`OTP API listening on :${PORT}`);
});
