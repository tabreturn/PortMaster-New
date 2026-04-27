export class Video {
  constructor(...args) {
    console.log('Video constructor', args);
    this.src = '';
    this._readyState = 0;
    this._currentTime = 0;
    this._duration = 0;
    this._paused = false;
    this._ended = false;
  }
  play() {
    console.log('Video play');
  }
  pause() {
    console.log('Video pause');
  }
  load() {
    console.log('Video load');
  }
  addEventListner(type, listener) {
    console.log('video addEventListner', type, listener);
  }
  removeEventListner(type, listener) {
    console.log('video removeEventListner', type, listener);
  }
  set src(newsrc) {
    console.log('video set src', newsrc);
    this._src = newsrc;
  }
  get src() {
    console.log('video get src');
    return this._src;
  }
  get readyState() {
    console.log('video get readyState');
    return this._readyState;
  }
  get currentTime() {
    console.log('video get currentTime');
    return this._currentTime;
  }
  get duration() {
    console.log('video get duration');
    return this._duration;
  }
  get paused() {
    console.log('video get paused');
    return this._paused;
  }
  get ended() {
    console.log('video get ended');
    return this._ended;
  }
}
