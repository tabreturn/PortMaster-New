import path from 'path';
import fs from 'fs';
import os from 'os';
import { LowSync } from 'lowdb';
import { JSONFileSync } from 'lowdb/node';

let db;

// Construct the path to the data file
const homeDir = os.homedir();
const launcherDir = path.join(homeDir, '.jsgamelauncher');


// Initialize and use your database
async function initializeDB(gameFolder) {

  // Ensure the launcher directory exists
  if (!fs.existsSync(launcherDir)) {
    fs.mkdirSync(launcherDir, { recursive: true });
  }

  const gameDir = path.join(launcherDir, gameFolder);

  // Ensure the game data directory exists
  if (!fs.existsSync(gameDir)) {
    fs.mkdirSync(gameDir, { recursive: true });
  }
  const dataFile = path.join(gameDir, 'data.json');

  console.log('Using data file:', dataFile);
  // Use JSON file for storage
  db = new LowSync(new JSONFileSync(dataFile), {});

  db.read();
  console.log('DB data:', db.data);
  db.data = db.data || {}; // Set default data if it's empty
  return {
    db,
    dataFile,
  };
}

export default async function createLocalStorage(gameFolder) {
  const initObj = await initializeDB(gameFolder);
  const ls = {
    __storageFile: initObj.dataFile,
    setItem: (key, value) => {
      console.log('called setItem', key, value);
      db.data[key] = String(value); // Set a value
      db.write(); // Write the data back to the file
    },
  
    getItem: (key) => {
      return db.data[key] || null;
    },
  
    removeItem: (key) => {
      delete db.data[key];
      db.write();
    },
  
    clear: () => {
      const keys = Object.keys(db.data);
      for (const key of keys) {
        delete db.data[key];
      }
      db.write();
    },
  
    key: (index) => {
      const keys = Object.keys(db.data);
      return keys[index] || null; // Return null if index is out of bounds
    },
  };
  
  Object.defineProperties(ls, {
    length: {
      get() {
        return Object.keys(db.data).length;
      },
      configurable: true,
      enumerable: true,
    },
  });
  
  return new Proxy(ls, {
    get: (target, prop) => {
      if (prop in target) {
        return target[prop];
      } else if (prop in db.data) {
        return db.data[prop];
      } else {
        return undefined;
      }
    },
    set: (target, prop, value) => {
      db.data[prop] = String(value); // Set a value
      db.write(); // Write the data back to the file
      return true;
    },
    deleteProperty: (target, prop) => {
      if (prop in target.storage) {
        delete db.data[key];
        db.write();
        return true;
      }
      return false;
    },
  });
}
