{ task, src, dest, series } = require 'gulp'
coffee = require 'gulp-coffee'
babel  = require 'gulp-babel'
uglify = require('gulp-uglify-es').default
tap    = require 'gulp-tap'
jsedit = require 'gulp-json-editor'
hash   = require 'sha256-file'
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

setScriptHash = ->
  sha256 = hash './dist/lib/script.js'
  src './dist/manifest.json'
    .pipe jsedit
      "content_security_policy": "script-src 'unsafe-eval' 'self' 'sha256-#{sha256}'; object-src 'self';"
    .pipe dest 'dist'

transpile = ->
  src 'coffee/*.coffee'
    .pipe coffee()
    .pipe babel()
    .pipe uglifyOrThru()
    .pipe dest 'dist/lib'

# for test
task 'dev', series(
  transpile
  setScriptHash
)

# for product
task 'default', series(
  transpile
  setScriptHash
  zip
)
