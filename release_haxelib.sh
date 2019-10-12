#!/bin/sh
rm -f library.zip
zip -r library.zip src *.md haxelib.json *.hxml run.n
haxelib submit library.zip $HAXELIB_PWD --always