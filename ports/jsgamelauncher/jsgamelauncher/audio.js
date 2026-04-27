export class Audio {
  constructor(...args) {
    console.log('Audio constructor', args);
    this.src = '';
    this._readyState = 0;
    this._currentTime = 0;
    this._duration = 0;
    this._paused = false;
    this._ended = false;
  }
  canPlaySound(type) {
    console.log('audio canPlaySound', type);
    return true;
  }
  canPlayType(type) {
    // we're using ffmpeg, we can decode anything.
    return 'probably';
  }
  addEventListner(type, listener) {
    console.log('audio addEventListner', type, listener);
  }
  removeEventListner(type, listener) {
    console.log('audio  removeEventListner', type, listener);
  }
  set src(newsrc) {
    console.log('audio set src', newsrc);
    this._src = newsrc;
  }
  get src() {
    console.log('audio get src');
    return this._src;
  }
  play() {
    console.log('Audio play');
  }
  pause() {
    console.log('Audio pause');
  }
  load() {
    console.log('Audio load');
  }
  set volume(newvolume) {
    console.log('audio set volume', newvolume);
    this._volume = newvolume;
  }
  get volume() {
    console.log('audio get volume');
    return this._volume;
  }
  set loop(newloop) {
    console.log('audio set loop', newloop);
    this._loop = newloop;
  }
  get loop() {
    console.log('audio get loop');
    return this._loop;
  }
  set currentTime(newcurrentTime) {
    console.log('audio set currentTime', newcurrentTime);
    this._currentTime = newcurrentTime;
  }
  get currentTime() {
    console.log('audio get currentTime');
    return this._currentTime;
  }
  get duration() {
    console.log('audio get duration');
    return this._duration;
  }
  get paused() {
    console.log('audio get paused');
    return this._paused;
  }
  get ended() {
    console.log('audio get ended');
    return this._ended;
  }
  get readyState() {
    console.log('audio get readyState');
    return this._readyState;
  }
}
