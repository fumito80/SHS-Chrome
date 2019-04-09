$OutputEncoding = [Text.Encoding]::UTF8;

node ./node_modules/.bin/coffee -co js coffee/popup.coffee
C:\Users\fumit\AppData\Roaming\npm\coffee -co js coffee/script.coffee

./node_modules/.bin/uglifyjs js/popup.js -nc -m | Set-Content -Encoding UTF8 ExtSearch/lib/popup.js
./node_modules/.bin/uglifyjs js/script.js -nc -m | Set-Content -Encoding UTF8 ExtSearch/lib/script.js

pause
