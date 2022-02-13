{ src, dest, series } = require 'gulp'
coffee = require 'gulp-coffee'
babel  = require 'gulp-babel'
uglify = require('gulp-uglify-es').default
tap    = require 'gulp-tap'
zipfld = require 'zip-folder'

uglifyOrThru = ->
  if process.argv.includes 'dev'
    tap (file) -> console.log 'Skip uglify: ' + file.path
  else
    uglify()

zip = (done) ->
  manifest = JSON.parse require('fs').readFileSync('./dist/manifest.json')
  zipfld './dist', "./zipped/shs.#{manifest.version}.zip", (err) ->
    done(err)

transpile = ->
  src 'coffee/*.coffee'
    .pipe coffee()
    .pipe babel()
    .pipe uglifyOrThru()
    .pipe dest 'dist'

# for test
exports.dev = series transpile

# for product
exports.default = series transpile, zip
