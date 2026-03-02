const express = require('express');
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;

const router = express.Router();

<<<<<<< HEAD
// configurar passport serialization
passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((obj, done) => done(null, obj));

// Google OAuth¿
=======
// configure passport serialization
passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((obj, done) => done(null, obj));

// Google OAuth strategy
>>>>>>> 14ebbfb6803338e62f592bf1f00101fd6390798e
passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: process.env.GOOGLE_CALLBACK_URL || `http://localhost:${process.env.PORT || 3307}/auth/google/callback`
  },
  async (accessToken, refreshToken, profile, cb) => {
<<<<<<< HEAD
    // Insert or update usuario db
=======
    // Insert or update user in database here if desired
>>>>>>> 14ebbfb6803338e62f592bf1f00101fd6390798e
    const usuario = {
      googleId: profile.id,
      nombre: profile.displayName,
      email: profile.emails && profile.emails[0].value
    };
    return cb(null, usuario);
  }
));

<<<<<<< HEAD
// ruta auth
=======
// authentication routes
>>>>>>> 14ebbfb6803338e62f592bf1f00101fd6390798e
router.get('/auth/google',
  passport.authenticate('google', { scope: ['profile','email'] }));

router.get('/auth/google/callback',
  passport.authenticate('google', { failureRedirect: '/login.html' }),
  (req, res) => {
    res.redirect('/');
  });

<<<<<<< HEAD
// middleware proteger rutas
=======
// middleware to protect routes
>>>>>>> 14ebbfb6803338e62f592bf1f00101fd6390798e
function ensureLoggedIn(req, res, next) {
  if (req.isAuthenticated()) return next();
  res.redirect('/');
}

<<<<<<< HEAD
// passport middlewares 
=======
// helper to wire passport middlewares onto an Express app
>>>>>>> 14ebbfb6803338e62f592bf1f00101fd6390798e
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
