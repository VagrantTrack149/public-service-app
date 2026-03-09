const express = require('express');
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const router = express.Router();
const db = require('../../../db/conex_db');

// configurar passport serialization
passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((obj, done) => done(null, obj));

// Google OAuth
passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: process.env.GOOGLE_CALLBACK_URL || `http://localhost:${process.env.PORT || 3307}/auth/google/callback`
  },
  async (accessToken, refreshToken, profile, cb) => {
    try {
      const usuario = await db.login_google(
        profile.id,
        profile.displayName,
        profile.emails && profile.emails[0].value,
        profile.photos && profile.photos[0].value
      );
      // usuario ya contiene el id de la base de datos
      return cb(null, usuario);
    } catch (err) {
      console.error('login_google error', err);
      return cb(err, null);
    }
  }
));

// rutas auth
router.get('/auth/google',
  passport.authenticate('google', { scope: ['profile','email'] }));

router.get('/auth/google/callback',
  passport.authenticate('google', { failureRedirect: '/login.html' }),
  (req, res) => {
    res.redirect('/');
  });

// middleware proteger rutas
function ensureLoggedIn(req, res, next) {
  if (req.isAuthenticated()) return next();
  res.redirect('/');
}

// passport middlewares 
function initialize(app) {
  app.use(passport.initialize());
  app.use(passport.session());
  app.use(router);
}

module.exports = {
  initialize,
  ensureLoggedIn,
  router
};