const sdlToWebKeys = {
  ctrl: 'Control',
  shift: 'Shift',
  alt: 'Alt',
  meta: 'Meta',
  space: ' ',
  enter: 'Enter',
  escape: 'Escape',
  backspace: 'Backspace',
  tab: 'Tab',
  up: 'ArrowUp',
  down: 'ArrowDown',
  left: 'ArrowLeft',
  right: 'ArrowRight',
}

function getWinEvent(type, e) {
  const evt = {
    type,
    key: sdlToWebKeys[e.key] || e.key,
    code: e.key,
    repeat: e.repeat,
    altKey: e.alt,
    ctrlKey: e.ctrl,
    shiftKey: e.shift,
  };
  return evt;
}

export default function initialize(appWindow) {
  globalThis.document = globalThis.document || {};
  let keyDownListeners = [];
  let keyUpListeners = [];
  let loadingEvents = [];
  let resizeEvents = [];
  globalThis.close = () => {
    console.log('window.close');
    process.exit(0);
  }

  appWindow.on('keyDown', (e) => {
    keyDownListeners.forEach((listener) => {
      const evt = getWinEvent('keydown', e);
      listener(evt);
    });
  });
  appWindow.on('keyUp', (e) => {
    keyUpListeners.forEach((listener) => {
      const evt = getWinEvent('keyup', e);
      listener(evt);
    });
  });

  globalThis.addEventListener = function (type, listener) {
    if (type === 'keydown') {
      keyDownListeners.push(listener);
    } else if (type === 'keyup') {
      keyUpListeners.push(listener);
    } else if (type === 'load') {
      loadingEvents.push(listener);
    } else if (type === 'resize') {
      resizeEvents.push(listener);
    }
  };

  globalThis.document.addEventListener = globalThis.addEventListener;
  globalThis.document.body.addEventListener = globalThis.addEventListener;

  globalThis.removeEventListener = function (type, listener) {
    if (type === 'keydown') {
      keyDownListeners = keyDownListeners.filter((l) => l !== listener);
    } else if (type === 'keyup') {
      keyUpListeners = keyUpListeners.filter((l) => l !== listener);
    } else if (type === 'load') {
      loadingEvents = loadingEvents.filter((l) => l !== listener);
    } else if (type === 'resize') {
      resizeEvents = resizeEvents.filter((l) => l !== listener);
    }
  }

  globalThis.document.removeEventListener = globalThis.removeEventListener;
  globalThis.document.body.removeEventListener = globalThis.removeEventListener;

  function callLoadingEvents() {
    for (const event of loadingEvents) {
      event({});
    }
    if (globalThis.onload) {
      globalThis.onload();
    }
  }

  function callResizeEvents() {
    for (const event of resizeEvents) {
      event({});
    }
    if (globalThis.onresize) {
      globalThis.onresize();
    }
  }

  return {
    callLoadingEvents,
    callResizeEvents,
  }
}
