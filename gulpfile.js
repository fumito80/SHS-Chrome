const { src, dest, series, watch } = require('gulp');
const coffee = require('gulp-coffee');
const babel = require('gulp-babel');

function uglifyOrThru() {
  if (process.argv.includes('dev') || process.argv.includes('watch')) {
    const tap = require('gulp-tap');
    return tap((file) => console.log('Skip uglify: ' + file.path));
  }
  const uglify = require('gulp-uglify-es').default
  return uglify();
}

function zip(postFix = '') {
  return function zip(done) {
    const zipfolder = require('zip-folder');
    const manifest = JSON.parse(require('fs').readFileSync(`./dist${postFix}/manifest.json`));
    return zipfolder(`./dist${postFix}`, `./zipped/shs${postFix}.${manifest.version}.zip`, (err) => done(err));
  }
}

function transpile() {
  return src('coffee/*.coffee')
    .pipe(coffee())
    .pipe(babel())
    .pipe(uglifyOrThru())
    .pipe(dest('dist'));
}

function transpileFF() {
  return src('coffee/*.coffee')
    .pipe(coffee())
    .pipe(dest('dist-ff'));
}

function assetsFF() {
  return src('dist/**/*.*')
    .pipe(dest('dist-ff'));
}

function manifestFF() {
  return src(`./firefox/manifest.json`)
    .pipe(dest('dist-ff'));
}

exports.watch = () => watch('./coffee/*.coffee', transpile);

// for test
exports.dev = series(transpile);

// for product
exports.build = series(transpile, zip());

// Firefox
exports.watchFF = () => watch('./coffee/*.coffee', assetsFF, transpileFF, manifestFF);

// for test
exports.devFF = series(assetsFF, transpileFF, manifestFF);

// for product
exports.buildFF = series(assetsFF, transpileFF, manifestFF, zip('-ff'));
