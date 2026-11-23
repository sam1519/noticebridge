// Turns an uploaded file (PDF, image, or text) into plain text.

async function extractText(file) {
  const { mimetype, buffer, originalname } = file;
  const name = (originalname || '').toLowerCase();

  if (mimetype === 'application/pdf' || name.endsWith('.pdf')) {
    const pdfParse = require('pdf-parse/lib/pdf-parse.js');
    const data = await pdfParse(buffer);
    return data.text;
  }

  if (mimetype.startsWith('image/') || /\.(png|jpe?g|bmp|webp|gif|tiff?)$/.test(name)) {
    const Tesseract = require('tesseract.js');
    const { data } = await Tesseract.recognize(buffer, 'eng');
    return data.text;
  }

  if ((mimetype || '').startsWith('text/') || name.endsWith('.txt')) {
    return buffer.toString('utf8');
  }

  const err = new Error('Unsupported file type. Please upload a PDF, an image, or a text file.');
  err.status = 415;
  throw err;
}

module.exports = { extractText };
