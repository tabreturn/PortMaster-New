import { join } from 'path';
import fs from 'fs';
import { GlobalFonts } from '@napi-rs/canvas';

export default function initializeFontFace(romDir) {
  let resourcePath = romDir;
  const publicDir = join(romDir, 'public');
  if (fs.existsSync(publicDir)) {
    resourcePath = publicDir;
  }
  class FontFace {
    constructor(fontName, fontUrl) {
      this.fontName = fontName;
      this.fontUrl = fontUrl;
    }

    load() {
      // extract url from css url(path/to/font.ttf)
      const url = this.fontUrl.match(/url\((.*)\)/)[1];
      const fontPath = join(resourcePath, url);
      console.log('fontPath', fontPath);
      GlobalFonts.registerFromPath(fontPath, this.fontName);
      console.log(`Font ${this.fontName} registered from ${fontPath}`);

      return Promise.resolve(this);
    }
  }
  return FontFace;
}
