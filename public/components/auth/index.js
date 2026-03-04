const express = require('express');
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;

const router = express.Router();

// configurar passport serialization
passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((obj, done) => done(null, obj));

// Google OAuth¿
passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: process.env.GOOGLE_CALLBACK_URL || `http://localhost:${process.env.PORT || 3307}/auth/google/callback`
  },
  async (accessToken, refreshToken, profile, cb) => {
    // Insert or update usuario db
    
    const usuario = {
      googleId: profile.id,
      nombre: profile.displayName,
      email: profile.emails && profile.emails[0].value
    };
    return cb(null, usuario);
  }
));

// ruta auth
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
