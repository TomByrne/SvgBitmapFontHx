## SVG Bitmap Font Generator ![](https://travis-ci.org/TomByrne/SvgBitmapFontHx.svg?branch=master)[![Lang](https://img.shields.io/badge/language-haxe-orange.svg?style=flat-square&colorB=EA8220)](http://haxe.org)
Takes SVG fonts and converts them to the BitmapFont format used by Starling.
Depends on the `svg` library for drawing shapes.
Depends on OpenFL for rendering to bitmap.

### Usage

There are two main ways to use the generator, either using `SvgBitmapFontGenerator` to generate a single font, or using `SvgBitmapFontBatcher` to generate a bunch of fonts. The second method is much more efficient than running the first method multiple times, as it internally caches certain elements.

Both methods also support breaking the generation down into steps to avoid locking up your application while fonts are being generated (detailed at the bottom).

#### SvgFontGeneratorConfig

Both of these methods take a config object `SvgFontGeneratorConfig`.

This config determines how the `BitmapFont` gets generated, props with an asterisk `*` only work on `SvgBitmapFontGenerator` (as these properties get specified separately per font).

```haxe
var config:SvgFontGeneratorConfig = {

	// Font size to render *
	size: 20,

	// Override fontFamily in SvgFont *
	forceFamily: 'MyFont',

	// Which characters to include *
	characters: CharacterRanges.fromStrings(['digits', 'latin', 'latinSupplement.upper']),

	// Whether to generate mipmaps in texture
	generateMipMaps: true,

	// Gap between characters in texture - default=1
	gap: 1,

	// Scale factor to apply to rendering (for HiDPI displays) - default=1
	scaleFactor: 1,

	// Pad characters within frame to avoid curve cropping - default=1
	innerPadding: 1,

	// Apply rounding to 'advanceXTo' values to ensure that characters fall on a pixel - default=1
	snapAdvanceXTo: 1,

	// Fonts can be rendered at a higher resolution, then resampled at a lower resolution (super-sampling) - default=1 (i.e. no super-sampling)
	superSampling: 3,

	// Super-sampling is mostly required for very small fonts, this threshold determines the scale below which super-sampling gets used - default=0.1
	superSamplingScaleThreshold: 0.1,
}
```

#### SvgBitmapFontGenerator

```haxe
// Get your SVG data from somewhere
var svgData:String = '<svg>...</svg>';

// SvgFont is an object representation of an SVG font 
var svgFont:SvgFont = SvgFont.fromString(svgData);

// This config determines how the BitmapFont gets generated, props are optional unless noted
var config:SvgFontGeneratorConfig = ... // see above

// SvgBitmapFontGenerator co-ordinates the generating of the BitmapFont
var generator:SvgBitmapFontGenerator = new SvgBitmapFontGenerator( svgFont, config );

// Make resulting BitmapFont get auto-registered with available font libraries (supports Starling, starling-text-display)
generator.addDefaultRegisters();

// Generate the whole font immediately (i.e. synchronously)
generator.processNow();
```

#### SvgBitmapFontBatcher

```haxe
var fontMedium =
{
	// This will be used to register the font
	family: "MarkForMc_Medium",

	// This asset should be included in the build using the Lime assets system
	svgSource: "fonts/MarkForMc_Medium.svg",

	// More character ranges can be found in CharacterRanges class
	ranges: ["digit","latin", "latinSupplement", "unicodeSymbols.basic"]
}

var fontBold =
{
	family: "MarkForMc_Bold",
	svgSource: "fonts/MarkForMc_Bold.svg",
	ranges: ["digit","latin", "latinSupplement", "unicodeSymbols.basic"]
}

// This is a list of font sizes to generate
var sizes = [
	{ def:fontMedium, size:32},
	{ def:fontMedium, size:16},
	{ def:fontMedium, size:12},
	
	{ def:fontBold, size:32},
	{ def:fontBold, size:16},
	{ def:fontBold, size:12},
];

// Fonts get registered as '{family}_{size}'

// SvgBitmapFontBatcher co-ordinates the generating of the BitmapFonts
var batcher = new SvgBitmapFontBatcher(sizes, config);

// Make resulting BitmapFont get auto-registered with available font libraries (supports Starling, starling-text-display)
batcher.addDefaultRegisters();

// Generate the whole font immediately (i.e. synchronously)
batcher.processNow();
```

#### Asynchronous font generation

Both `SvgFontGeneratorConfig` and `SvgBitmapFontBatcher` expose an identical API for breaking down the generating of fonts into chunks, so it can be done in a pseudo-asynchronous way.

This API doesn't internally hook into any timer, so you have to manually hook into a frame loop and continue calling `process()` until `progress:Int` equals `total:Int`.

```haxe
// Add a hook into the frame timer (platform-specific)
// OpenFL used as an example
Lib.current.addEventListener(Event.ENTER_FRAME, onEnterFrame);
function onEnterFrame(e:Event)
{
	// Process 5 characters each frame
	generator.process(5);
	trace('processing: ' + generator.progress + '/' + generator.total);

	if(generator.progress == generator.total){
		trace('finished processing font');
        Lib.current.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
	}
}
```

