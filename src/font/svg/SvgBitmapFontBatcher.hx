package font.svg;

import openfl.utils.Assets;
import font.CharacterRanges;

/**
 * Takes a list of font definitions and generates BitmapFonts for each font/size.
 * 
 * @author Thomas Byrne
 */
class SvgBitmapFontBatcher
{
	var fonts:Array<SvgFontDefSize>;
	var fontIterator:Iterator<SvgFontDefSize>;
	var currentFont:SvgFontDefSize;
	var fontDefs:Map<String, SvgFontDisplays> = new Map();
    var scaleFactor:Float;
    var charPadding:Int;
    var onComplete:Void->Void;
    var generateMipMaps:Bool;

	public function new(fonts:Array<SvgFontDefSize>, scaleFactor:Float = 1, charPadding:Int = 1, generateMipMaps:Bool, ?onComplete:Void->Void):Void
	{
        this.fonts = fonts;
        this.scaleFactor = scaleFactor;
        this.generateMipMaps = generateMipMaps;
        this.charPadding = charPadding;
        this.onComplete = onComplete;
        
		fontIterator = fonts.iterator();
		generateNextFont();
	}
	
	function generateNextFont() 
	{
		if (fontIterator.hasNext())
		{
			currentFont = fontIterator.next();
			var svgFontDisplays:SvgFontDisplays = fontDefs.get(currentFont.name);
			if(svgFontDisplays == null)
			{
				var svgFont:SvgFont = SvgFont.fromString(Assets.getText(currentFont.def.svgSource) );
				svgFontDisplays = SvgFontDisplays.create(svgFont);
				fontDefs.set(currentFont.name, svgFontDisplays);
			}
			var bitmapFontGenerator:SvgBitmapFontGenerator = new SvgBitmapFontGenerator( svgFontDisplays, currentFont.size, 100, currentFont.name, charPadding, scaleFactor, handleFontGenerated);
			bitmapFontGenerator.generateMipMaps = generateMipMaps;
            bitmapFontGenerator.generateBitmapFont( CharacterRanges.fromStrings(currentFont.def.ranges) );
			
		}else{
			if(onComplete != null) onComplete();
		}
		
	}
	
	function handleFontGenerated():Void 
	{
		generateNextFont();
	}

}

typedef SvgFontDefSize =
{
	name:String,
	def:SvgFontDef,
	size:Float,
}

typedef SvgFontDef =
{
	family:String,
	font:String,
	sizes:Array<Int>,
	?svgSource:String,
	ranges:Array<String>,
}