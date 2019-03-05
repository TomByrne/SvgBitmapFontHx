@echo off
cd ../
del dist\\SvgBitmapFont.zip /Q
rmdir dist\\temp /S /Q
timeout 1

mkdir dist\\temp
xcopy src dist\\temp\\src /S /I
copy haxelib.json dist\\temp
copy run.n dist\\temp

powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('dist\\temp', 'dist\\SvgBitmapFont.zip'); }"
haxelib submit dist\\SvgBitmapFont.zip
rmdir dist\\temp /S /Q
pause