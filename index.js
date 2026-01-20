const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;
const cors= require('cors');

app.use(cors()); // Enable CORS for all routes

app.use(express.static(path.join(__dirname, 'public')));

app.listen(PORT, () => {
  console.log('Server running in port'+ PORT);
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'src', 'index.html'));
});