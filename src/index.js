const express = require('express');
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const bcrypt = require('bcryptjs');
const router = express.Router();
const db = require('../db/conex_db');

//  Serialización 
passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((obj, done) => done(null, obj));

//  Google OAuth 
passport.use(new GoogleStrategy({
  clientID: process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  callbackURL: process.env.GOOGLE_CALLBACK_URL ||
               `http://localhost:${process.env.PORT || 3307}/auth/google/callback`
}, async (accessToken, refreshToken, profile, cb) => {
  try {
    const usuario = await db.login_google(
      profile.id,
      profile.displayName,
      profile.emails?.[0]?.value,
      profile.photos?.[0]?.value
    );
    return cb(null, usuario);
  } catch (err) {
    console.error('login_google error', err);
    return cb(err, null);
  }
}));

//  Rutas Google 
router.get('/auth/google',
  passport.authenticate('google', { scope: ['profile', 'email'] }));

router.get('/auth/google/callback',
  passport.authenticate('google', { failureRedirect: '/login' }),
  (req, res) => res.redirect('/'));

//  Registro local 
router.post('/api/register', async (req, res) => {
  try {
    const { nombre, email, password } = req.body || {};
    if (!nombre || !email || !password) return res.status(400).json({ error: 'Faltan datos' });
    if (password.length < 6)           return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
    if (!/^\S+@\S+\.\S+$/.test(email)) return res.status(400).json({ error: 'Correo inválido' });

    const existente = await db.obtenerUsuarioPorEmail(email);
    if (existente) return res.status(409).json({ error: 'Ese correo ya está registrado' });

    const hash = await bcrypt.hash(password, 10);
    const user = await db.registrarUsuarioLocal(nombre, email, hash);

    req.login(user, err => {
      if (err) return res.status(500).json({ error: 'Error al iniciar sesión' });
      res.json({ ok: true, user });
    });
  } catch (e) {
    console.error('register error', e);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

//  Login local 
router.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'Faltan datos' });

    const user = await db.obtenerUsuarioPorEmail(email);
    if (!user || !user.password_hash) return res.status(401).json({ error: 'Credenciales inválidas' });

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'Credenciales inválidas' });

    delete user.password_hash;
    req.login(user, err => {
      if (err) return res.status(500).json({ error: 'Error al iniciar sesión' });
      res.json({ ok: true, user });
    });
  } catch (e) {
    console.error('login error', e);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

//  Logout 
router.get('/logout', (req, res, next) => {
  req.logout(err => {
    if (err) return next(err);
    req.session?.destroy(() => res.redirect('/'));
  });
});

//  API usuario actual 
router.get('/api/me', (req, res) => {
  if (req.isAuthenticated && req.isAuthenticated()) {
    const { password_hash, ...user } = req.user || {};
    return res.json(user);
  }
  res.status(401).json({ error: 'No autenticado' });
});

//  Middleware 
function ensureLoggedIn(req, res, next) {
  if (req.isAuthenticated()) return next();
  res.redirect('/login');
}

function initialize(app) {
  app.use(passport.initialize());
  app.use(passport.session());
  app.use(router);
}

module.exports = { initialize, ensureLoggedIn, router };