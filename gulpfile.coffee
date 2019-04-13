{ task, src, dest, series } = require 'gulp'
coffee = require 'gulp-coffee'
babel  = require 'gulp-babel'
uglify = require('gulp-uglify-es').default
thru   = require 'through2'
hash   = require 'sha256-file'
jsedit = require 'gulp-json-editor'
zip    = require 'zip-folder'

through = ->
  thru.obj (file, enc, cb) ->
    cb null, file

applyUglify = ->
  if process.argv.includes('dev')
    through()
  else
    uglify()

zipDist = (done) ->
  if process.argv.includes('dev')
    return done()
  delete require.cache[__dirname + '/dist/manifest.json']
  { version } = require './dist/manifest.json'
  zip './dist', "./zipped/shs.#{version}.zip", (err) ->
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
    .pipe applyUglify()
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
  zipDist
)
