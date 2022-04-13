const { src, dest, series, watch } = require('gulp');
const coffee = require('gulp-coffee');
const babel = require('gulp-babel');

function uglifyOrThru() {
  if (process.argv.includes('dev')) {
    const tap = require('gulp-tap');
    return tap((file) => console.log('Skip uglify: ' + file.path));
  }
  const uglify = require('gulp-uglify-es').default
  return uglify();
}

function zip(done) {
  const zipfld = require('zip-folder');
  const manifest = JSON.parse(require('fs').readFileSync('./dist/manifest.json'));
  return zipfld('./dist', `./zipped/shs.${manifest.version}.zip`, (err) => done(err));
}

function transpile() {
  return src('coffee/*.coffee')
    .pipe(coffee())
    .pipe(babel())
    .pipe(uglifyOrThru())
    .pipe(dest('dist'));
}

exports.watch = () => watch('coffee/*.coffee', transpile);

// for test
exports.dev = series(transpile);

// for product
exports.default = series(transpile, zip);
