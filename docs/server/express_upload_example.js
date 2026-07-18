// Minimal Node/Express example to receive a ZIP upload and process frames with FFmpeg
// Usage: node express_upload_example.js

const express = require('express');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const app = express();
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);

app.post('/upload_frames', (req, res) => {
  const filename = 'upload_' + Date.now() + '.zip';
  const outPath = path.join(uploadDir, filename);
  const ws = fs.createWriteStream(outPath);
  req.pipe(ws);
  req.on('end', () => {
    console.log('Saved upload to', outPath);
    // Extract frames (assumes zip contains frames named frame_######.jpg)
    // Requires 'unzip' installed on server
    const unpackDir = outPath + '_files';
    fs.mkdirSync(unpackDir);
    exec(`unzip -qq ${outPath} -d ${unpackDir}`, (err) => {
      if (err) {
        console.error('Unzip failed', err);
        res.status(500).send('unzip failed');
        return;
      }
      // Compose with ffmpeg (15 fps example)
      const outMp4 = path.join(uploadDir, filename + '.mp4');
      const cmd = `ffmpeg -y -framerate 15 -i ${path.join(unpackDir, 'frame_%06d.jpg')} -c:v libx264 -pix_fmt yuv420p -crf 18 ${outMp4}`;
      exec(cmd, (err2, stdout, stderr) => {
        if (err2) {
          console.error('ffmpeg failed', err2, stderr);
          res.status(500).send('ffmpeg failed');
          return;
        }
        console.log('MP4 written to', outMp4);
        res.json({ mp4: outMp4 });
      });
    });
  });
});

app.listen(3000, () => console.log('Upload server listening on :3000'));
