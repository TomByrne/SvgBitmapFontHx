package font.svg;

import haxe.Utf8;

#if (haxe >=4)
import haxe.xml.Access;
#else
import haxe.xml.Fast as Access;
#end

/**
 * Represents all of the information contained in an SVG font file.
 * 
 * @author Michal Moczynski
 * @author Thomas Byrne
 */

class SvgFont
{
	static var EMPTY_PATH:String = "M0 0 Z";
	static var DEFAULT_PARSE_OPTIONS:SvgParseOptions = {
		overrideFill: '#FFFFFF'
	};
	
	public var fontFamily:String;
	public var fontWeight:Float;
	
	public var unitsPerEm:Float;
	public var ascent:Float;
	public var descent:Float;
	public var capHeight:Float;
	public var xHeight:Float;

	public var svgRendererXml:Xml; // For use with format.svg.SVGRenderer
	
	public var asciiToCharacterMap:Map<UInt, SvgCharacterVO> = new Map<UInt, SvgCharacterVO>();
	public var asciiCodes:Array<UInt> = [];

	public function new(){}
	 
	public static function fromString( svgString:String, ?fill:SvgFont, ?options:SvgParseOptions ) : SvgFont 
	{
		return fromXml( Xml.parse( svgString ), fill, options );
	}
	
	public static function fromXml(xml:Xml, ?fill:SvgFont, ?options:SvgParseOptions) : SvgFont 
	{
		if(options == null) options = DEFAULT_PARSE_OPTIONS;
		if(fill == null) fill = new SvgFont();

		var svgFont:Access = new Access(xml.firstElement());
		
		//getting basic font information
		var defs:Access = svgFont.node.defs;
		var font:Access = defs.node.font;
		var fontFace:Access = font.node.resolve("font-face");
		
		if (fontFace.has.resolve("font-family"))
			fill.fontFamily = fontFace.att.resolve("font-family");

		if (fontFace.has.resolve("font-weight"))
			fill.fontWeight = Std.parseFloat( fontFace.att.resolve("font-weight") );

		if (fontFace.has.resolve("units-per-em"))
			fill.unitsPerEm = Std.parseFloat( fontFace.att.resolve("units-per-em") );

		if (fontFace.has.resolve("descent"))
			fill.descent = Std.parseFloat( fontFace.att.resolve("descent") );

		if (fontFace.has.resolve("ascent"))
			fill.ascent = Std.parseFloat( fontFace.att.resolve("ascent") );

		if (fontFace.has.resolve("cap-height"))
			fill.capHeight = Std.parseFloat( fontFace.att.resolve("cap-height") );

		if (fontFace.has.resolve("x-height"))
			fill.xHeight = Std.parseFloat( fontFace.att.resolve("x-height") );
		
			
		//create svg compatible xml (glyph renamed to path, glyph-name renamed to id)
		fill.svgRendererXml = Xml.createElement('svg');
		
		for(glyph in font.nodes.glyph) {
			var path:Xml = Xml.createElement('path'); 
			path.set("id", glyph.att.resolve("glyph-name"));
			
			if(options.overrideFill != null)
				path.set("fill", options.overrideFill);
				
			if (glyph.has.resolve("d") == false)
				path.set("d", EMPTY_PATH);
			else
				path.set("d", glyph.att.resolve("d"));
				
			fill.svgRendererXml.addChild(path);
		}
		
		var defHAdvX:Float = font.has.resolve("horiz-adv-x") ? Std.parseInt( font.att.resolve("horiz-adv-x")) : 0;

		//generate SvgCharacterVOs (we needed an svg renderer ready before that)
		for (glyph in font.nodes.glyph) {
			if (glyph.has.resolve("unicode"))
			{
				var ascii:Int = parseUnicodeToAscii(glyph.att.resolve("unicode"));
				var char:SvgCharacterVO = {
					name:		glyph.att.resolve("glyph-name"),
					asciiCode:	ascii,
					unicode:	glyph.att.resolve("unicode"),
					
					hOriginX:		glyph.has.resolve("horiz-origin-x") ? Std.parseInt( glyph.att.resolve("horiz-origin-x")) : 0,
					hOriginY:		glyph.has.resolve("horiz-origin-y") ? Std.parseInt( glyph.att.resolve("horiz-origin-y")) : 0,
					hAdvX:			glyph.has.resolve("horiz-adv-x") ? Std.parseInt( glyph.att.resolve("horiz-adv-x")) : defHAdvX,
					
					vOriginX:		glyph.has.resolve("vert-origin-x") ? Std.parseInt( glyph.att.resolve("vert-origin-x")) : 0,
					vOriginY:		glyph.has.resolve("vert-origin-y") ? Std.parseInt( glyph.att.resolve("vert-origin-y")) : 0,
					vAdvY:			glyph.has.resolve("vert-adv-y") ? Std.parseInt( glyph.att.resolve("vert-adv-y")) : 0,
					
					svgShapeString:			glyph.has.resolve("d") ? glyph.att.resolve("d") : EMPTY_PATH,
					//svgShapeDisplayObject:	getShape( glyph.att.resolve("glyph-name") ),
					kerningAfterThisChar:	new Map<Int, Int>()	//key is an ascii code of the next letter, value is kerning
				}
				
				if (!glyph.has.resolve("vert-origin-x")) char.vOriginX = (char.hAdvX / 2); // Default as per spec
				if (!glyph.has.resolve("vert-origin-y")) char.vOriginY = fill.ascent; // Default as per spec
				
				fill.asciiToCharacterMap.set(ascii, char);
				fill.asciiCodes.push( ascii );
			}
		}

		//fill kernings
		for (hkern in font.nodes.hkern) {
			var u1:Int = parseUnicodeToAscii(hkern.att.u1);
			var u2:Int = parseUnicodeToAscii(hkern.att.u2);
			var k:Int = parseUnicodeToAscii(hkern.att.k);
			
			if (fill.asciiToCharacterMap.exists(u1))
			{
				var char:SvgCharacterVO = fill.asciiToCharacterMap.get(u1);
				char.kerningAfterThisChar.set(u2, k);
			}
		}

		return fill;
	}
	
	static function parseUnicodeToAscii(unicode:String):Int
	{		
		if ( unicode.indexOf("&#x") != -1)
		{
			var end:Int = unicode.indexOf(";");
			return Std.parseInt( "0x" + unicode.substr(3, end - 3) );
		}
		else
			return Utf8.charCodeAt(unicode, 0);
	}
}

typedef SvgCharacterVO =
{
	var name:String;
	var asciiCode:Int;
	var unicode:String;
	
	// For horizontally drawn text
	var hOriginX:Float;
	var hOriginY:Float;
	var hAdvX:Float;
	
	// For vertically drawn text
	var vOriginX:Float;
	var vOriginY:Float;
	var vAdvY:Float;
	
	var svgShapeString:String;
	//var svgShapeDisplayObject:DisplayObject;
	var kerningAfterThisChar:Map<Int, Int>;	//key is an ascii code of the next letter, value is kerning
}

typedef SvgParseOptions =
{
	overrideFill:String
}