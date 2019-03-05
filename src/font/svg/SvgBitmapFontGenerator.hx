package font.svg;

import imagsyd.time.EnterFrame;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.display.StageQuality;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import starling.core.Starling;
import starling.display.Quad;
import starling.text.BitmapFont;
import starling.text.TextField;
import starling.text.TextFormat;
import starling.text.model.format.FontRegistry;
import starling.textures.Texture;
import starling.utils.HAlign;
import starling.utils.VAlign;
import font.svg.SvgFont;

/**
 * Takes an SVG Font and generates a BitmapFont from it over a number of frames.
 * 
 * @author Michal Moczynski
 * @author Thomas Byrne
 */
class SvgBitmapFontGenerator 
{
	public var size:Float;
	public var svgFont:SvgFont;
	public var svgFontDisplays:SvgFontDisplays;
	
	var characterCounter:Int = 0;
	var snapped:Int = 0;
	
	var estimatedBitmapArea:Float = 0;
	var charOffsets:Map<Int, Point> = new Map<Int, Point>();
	var bitmapDatas:Map<Int, BitmapData> = new Map<Int, BitmapData>();
	var bitmapDataToAsciiMap:Map<BitmapData, Int> = new Map<BitmapData, Int>();
	var bitmapDataArray:Array<BitmapData> = [];//for sorting
	var common:Xml;
	var chars:Xml;
	var fontXml:Xml;
	var fontScale:Float;
	var allCharactersToBeAttached:Array<Int>;
	var finalizingFont:Bool;
	var charsPerFrame:Int;
	var forceFamily:String;
	var forceSuperSampling:Bool;
	var padding:Int;
	var scaleFactor:Float;
	var onComplete:Void->Void;
	
	public var superSampling:Float = 4;
	public var superSamplingScaleThreshold:Float = 0.1;//how small the display object scale has to be to use supersampling by default
	
	public function new(svgFont:SvgFontDisplays, size:Float, charsPerFrame:Int = 50, ?forceFamily:String, ?forceSuperSampling:Bool, ?padding:Int = 1, ?scaleFactor:Float = 1, ?onComplete:Void->Void ) 
	{
		this.svgFontDisplays = svgFont;
		this.svgFont = svgFontDisplays.svgFont;
		this.scaleFactor = scaleFactor;
		this.padding = Math.ceil( padding / scaleFactor);
		this.size = size;
		this.fontScale = size / svgFontDisplays.svgFont.unitsPerEm;
		this.charsPerFrame = charsPerFrame;
		this.forceFamily = forceFamily;		
		this.forceSuperSampling = forceSuperSampling;
		this.onComplete = onComplete;	
	}
	
	public function generateBitmapFont( allCharactersToBeAttached:Array<Int>)
	{
		this.allCharactersToBeAttached = allCharactersToBeAttached;
		
		//fill basic information in font xml
		fontXml = Xml.createElement("font");
		var info:Xml = Xml.createElement("info");
		
		//unique font name used later in TextField.registerBitmapFont and to bring that font in TextFormat
//		this.log("generating " + svgFont.fontFamily + "_" + size);
		info.set("face", svgFont.fontFamily + "_" + size);
		info.set("size", Std.string(size));
		fontXml.addChild(info);
		
		common = Xml.createElement("common");
		common.set("lineHeight", Std.string( Math.ceil( svgFont.capHeight * fontScale ) ) );
		common.set("base", Std.string(size));
		common.set("pages", "1");
		common.set("packed", "0");
		common.set("alphaChnl", "0");
		common.set("redChnl", "4");
		common.set("greenChnl", "4");
		common.set("blueChnl", "4");		
		fontXml.addChild(common);
		
		var pages:Xml = Xml.createElement("pages");
		var page:Xml = Xml.createElement("pages");
		page.set("id", "0");
		page.set("file", svgFont.fontFamily + "_" + size + "0");		
		
		fontXml.addChild(pages);		
		chars = Xml.createElement("chars");
		
		characterCounter = 0;
		snapped = 0;
		finalizingFont = false;
		
		EnterFrame.add( handleFrame );
	}
	
	function handleFrame():Void 
	{
		for (i in 0 ... charsPerFrame) 
		{
			snapSingleChar();
		}
	}
	
	function snapSingleChar():Void 
	{
		if (finalizingFont)
			return;
			
		//find the next char to be snapped in this frame
		var foundCharToSnap:Bool = false;		
		var char:SvgCharacterVO = null;
		while (foundCharToSnap == false && characterCounter < svgFont.asciiCodes.length)
		{
			char = svgFont.asciiToCharacterMap.get( svgFont.asciiCodes[characterCounter] );
			
			//check if this character is on t he list of required characters
			if ( Lambda.has(allCharactersToBeAttached, char.asciiCode) )
			{
				foundCharToSnap = true;
			}
			characterCounter++;
		}
		
		//check if reached end of the characters list
		if ( characterCounter >= svgFont.asciiCodes.length)
		{
			finalizingFont = true;
			EnterFrame.remove( handleFrame );
			finalizeFontGeneration();
			return;
		}
		
		
		//snap the character
		var container:Sprite = new Sprite();
		var charDisplayObject:DisplayObject = svgFontDisplays.asciiToShape.get(char.asciiCode);
		charDisplayObject.transform.matrix = new Matrix();
		
		container.addChild(charDisplayObject);
		var bounds:Rectangle = charDisplayObject.getBounds(container);
		
		var fullOffsetX:Float = 0;
		var fullOffsetY:Float = 0;
		
		fullOffsetX = -bounds.x;
		if (bounds.height > svgFont.capHeight)
		{
			fullOffsetY = bounds.y + bounds.height;
		}
		else
		{
			fullOffsetY = bounds.y + bounds.height;
		}

		var fullPixelSizeInSvg:Float = svgFont.unitsPerEm / size;
		
		var fullPixelsOffsetX:Float = Math.ceil( fullOffsetX / fullPixelSizeInSvg) * fullPixelSizeInSvg;
		var fullPixelsOffsetY:Float = Math.ceil( fullOffsetY / fullPixelSizeInSvg ) * fullPixelSizeInSvg;
		
		charDisplayObject.x = fullPixelsOffsetX;
		charDisplayObject.y = fullPixelsOffsetY;

		var bmpWidth:Int = Math.ceil( bounds.width / fullPixelSizeInSvg);
		var bmpHeight:Int = Math.ceil( bounds.height / fullPixelSizeInSvg);

		charDisplayObject.scaleY = -1;

		charOffsets.set( char.asciiCode, new Point( -fullPixelsOffsetX / fullPixelSizeInSvg, - fullPixelsOffsetY / fullPixelSizeInSvg) );

		var bmpDta:BitmapData;
		var m:Matrix = new Matrix();
		
		if (fontScale <= superSamplingScaleThreshold || forceSuperSampling != null)
		{
			m.scale(fontScale * superSampling, fontScale * superSampling);		
			bmpDta = new BitmapData( Math.ceil(bmpWidth * superSampling), Math.ceil(bmpHeight * superSampling), true, 0x00ffffff);
			bmpDta.drawWithQuality( container, m, null, null, null, true, StageQuality.BEST);
			
			var m2:Matrix = new Matrix();
			m2.scale( 1/superSampling, 1/superSampling);
			var bmpDta2:BitmapData = new BitmapData(bmpWidth, bmpHeight, true, 0x00ffffff);
			estimatedBitmapArea += (bmpDta2.width + 1) * (bmpDta2.height + 1);
			bmpDta2.drawWithQuality(bmpDta, m2, null, null, null, true, StageQuality.BEST);
			
			bmpDta.dispose();
			
			bitmapDatas.set(char.asciiCode, bmpDta2);
			bitmapDataToAsciiMap.set(bmpDta2, char.asciiCode);
			bitmapDataArray.push(bmpDta2);				
		}
		else
		{
			m.scale(fontScale, fontScale);		
			bmpDta = new BitmapData( bmpWidth, (bmpHeight), true, 0x00ffffff);
			bmpDta.drawWithQuality( container, m, null, null, null, true, StageQuality.BEST);
			
			bitmapDatas.set(char.asciiCode, bmpDta);
			bitmapDataToAsciiMap.set(bmpDta, char.asciiCode);
			bitmapDataArray.push(bmpDta);			
		}
		
		snapped++;
	}	
	
	function finalizeFontGeneration() 
	{
		chars.set("count", Std.string(snapped));
		
		//sort bitmaps by height		
		var estimatedSide:Float = Math.sqrt( estimatedBitmapArea );
		var nextPower:Int = Std.int( Math.pow(2, Math.ceil(Math.log(estimatedSide) / Math.log(2))) );
		
		var bmpWidth:Int;
		var bmpHeight:Int;
		
		//TODO: this parameter is not proved in any way and it depends on packing efficiency, there may be a better way to estimate bitmap size
		if (estimatedSide / nextPower < 0.7)		
			bmpWidth = bmpHeight = nextPower;
		else
		{
			bmpWidth = 2 * nextPower;
			bmpHeight = nextPower;
		}
		
		if (bmpWidth > 4096 || bmpHeight > 4096)
		{
			trace("Error: font bitmap size must be smaller than 4096x4096");
			return;
		}

		common.set("scaleW", Std.string(bmpWidth));
		common.set("scaleH", Std.string(bmpHeight));
		
		bitmapDataArray.sort(bitmapSort);		
		var combinedBitmapData:BitmapData = new BitmapData( bmpWidth, bmpHeight, true, 0x00ffffff);
		var lastPosX:Int = 0;
		var lastPosY:Int = 0;
		var lineHeight:Int = 0;
		
		//go throu sorted char bitmaps and fill the texture
		for (b in bitmapDataArray) 
		{
			if (lastPosX == 0)
				lineHeight = b.height;
				
			if (lastPosX + b.width > combinedBitmapData.width)
			{
				lastPosX = 0;
				lastPosY += lineHeight + padding;
			}

			var character:SvgCharacterVO = svgFont.asciiToCharacterMap.get( bitmapDataToAsciiMap.get(b) );
			var charNode:Xml = Xml.createElement("char");
			charNode.set("id", Std.string( character.asciiCode ) );
			charNode.set("x", Std.string( lastPosX) );
			charNode.set("y", Std.string( lastPosY + lineHeight - b.height ) );
			charNode.set("width", Std.string( b.width) );
			charNode.set("height", Std.string( b.height) );			
			charNode.set("xoffset", Std.string(charOffsets.get( character.asciiCode ).x ));
			charNode.set("yoffset", Std.string(charOffsets.get( character.asciiCode ).y ));		
			
			var hAdv:Float = character.hAdvX == 0 ? b.width : character.hAdvX * fontScale;
			charNode.set("xadvance", Std.string( hAdv ) );
			
			charNode.set("page", "0" );
			charNode.set("chnl", "15" );
			chars.addChild( charNode );
			
			combinedBitmapData.copyPixels( b, new Rectangle(0, 0, b.width, b.height), new Point(lastPosX, lastPosY + lineHeight - b.height) );
			lastPosX += b.width + padding;
			b.dispose();
		}
		bitmapDataArray = [];
		bitmapDatas = null;
		bitmapDataToAsciiMap = null;
		
		fontXml.addChild(chars);
		addKerningNodes();

		//create the texture and register the font
		var texture:Texture = Texture.fromBitmapData( combinedBitmapData, true, false, 1 / scaleFactor );
		
		var bmFont = new BitmapFont(texture, fontXml);
		var regName = (forceFamily == null ? svgFont.fontFamily : forceFamily) + "_" + size;
		#if !starling2
		TextField.registerBitmapFont( bmFont, regName );
		#else
		TextField.registerCompositor( bmFont, regName );
		#end
		FontRegistry.registerBitmapFont(bmFont, regName);
		
		if(onComplete != null) onComplete();
	}
	
	function addKerningNodes() 
	{
		var kernings:Xml = Xml.createElement("kernings");
		var kerningsCount:Int = 0;
		
		for (ascii in svgFont.asciiCodes) 
		{
			if ( Lambda.has(allCharactersToBeAttached, ascii) )
			{
				var char:SvgCharacterVO = svgFont.asciiToCharacterMap.get(ascii);
				for ( nextCharAscii in char.kerningAfterThisChar.keys() ) 
				{
					var kerning:Xml = Xml.createElement("kerning");
					kerning.set("first", Std.string(ascii));
					kerning.set("second", Std.string(nextCharAscii));
					kerning.set("amount", Std.string( char.kerningAfterThisChar.get(nextCharAscii) ));
					kernings.addChild(kerning);
					kerningsCount++;
				}
			}
		}
		kernings.set( "count", Std.string(kerningsCount) );
	}
		
	function bitmapSort( x:BitmapData, y:BitmapData ):Int
	{
		if ( y.height - x.height <= 0 )
			return -1;			
		else
			return 1;
	}
	
	
}