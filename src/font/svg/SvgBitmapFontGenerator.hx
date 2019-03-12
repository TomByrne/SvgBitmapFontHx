package font.svg;

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
import starling.time.Tick;

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
	var charOffsetsX:Map<Int, Float> = new Map<Int, Float>();
	var charOffsetsY:Map<Int, Float> = new Map<Int, Float>();
	var bitmapDatas:Map<Int, BitmapData> = new Map<Int, BitmapData>();
	var bitmapDataToAsciiMap:Map<BitmapData, Int> = new Map<BitmapData, Int>();
	var bitmapDataArray:Array<BitmapData> = [];//for sorting
	var common:Xml;
	var chars:Xml;
	var fontXml:Xml;
	var fontScale:Float;
	var allCharactersToBeAttached:Array<Int>;
	var finalizingFont:Bool;
	var forceFamily:String;
	var onComplete:Void->Void;
	
	public var superSampling:Float = 1;
	public var superSamplingScaleThreshold:Float = 0.1; // How small the display object scale has to be to use supersampling by default
	
	public var gap:Int = 1;
	public var innerPadding:Int = 1;
	public var scaleFactor:Float = 1.0;
	public var generateMipMaps:Bool = false;
	public var charsPerFrame:Int = 50;
	
	public var snapAdvanceXTo:Float = 1;
	
	public function new(svgFont:SvgFontDisplays, size:Float, ?forceFamily:String, ?onComplete:Void->Void ) 
	{
		this.svgFontDisplays = svgFont;
		this.svgFont = svgFontDisplays.svgFont;
		this.size = size;
		this.fontScale = size / this.svgFont.unitsPerEm;
		this.forceFamily = forceFamily;		
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
		info.set("size", Std.string(size * scaleFactor)); // This shouldn't be scaled but needs to be to offsets the scaling in BitmapFont.parseFontXml
		fontXml.addChild(info);
		
		common = Xml.createElement("common");
		common.set("lineHeight", Std.string( Math.ceil( (svgFont.capHeight * fontScale) * scaleFactor ) ) );
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
		
		Tick.once( handleFrame );
	}
	
	function handleFrame():Void 
	{
        var moreLeft:Bool = false;
		for (i in 0 ... charsPerFrame) 
		{
			moreLeft = snapSingleChar();
		}
		if(moreLeft) Tick.once( handleFrame );
	}
	
	function snapSingleChar() : Bool 
	{
		if (finalizingFont)
			return false;
			
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
			finalizeFontGeneration();
			return false;
		}
		
		
		//snap the character
		var container:Sprite = new Sprite();
		var charDisplayObject:DisplayObject = svgFontDisplays.asciiToShape.get(char.asciiCode);
		charDisplayObject.transform.matrix = new Matrix();
		
		container.addChild(charDisplayObject);
		charDisplayObject.scaleY = -scaleFactor; // SVG y-axis is in opposite direction
        charDisplayObject.scaleX =  scaleFactor;
		var bounds:Rectangle = charDisplayObject.getBounds(container);

		var imageCropX:Int = -Math.ceil( -bounds.x * fontScale) - innerPadding;
		var imageCropY:Int = -Math.ceil( -bounds.y * fontScale) - innerPadding;
		var imageCropW:Int = Math.ceil( bounds.right * fontScale) - imageCropX + innerPadding * 2;
		var imageCropH:Int = Math.ceil( bounds.bottom * fontScale) - imageCropY + innerPadding * 2;
		
		charDisplayObject.x = -imageCropX / fontScale;
		charDisplayObject.y = -imageCropY / fontScale;

		charOffsetsX.set( char.asciiCode, imageCropX );
		charOffsetsY.set( char.asciiCode, imageCropY );

		var bmpDta:BitmapData;
		var m:Matrix = new Matrix();

        var superSample:Float = (fontScale <= superSamplingScaleThreshold ? superSampling : 1);
        
        m.scale(fontScale * superSampling, fontScale * superSampling);		
        bmpDta = new BitmapData( Math.ceil(imageCropW * superSampling), Math.ceil(imageCropH * superSampling), true, 0x00ffffff);
        bmpDta.drawWithQuality( container, m, null, null, null, true, StageQuality.BEST);
		
		if (superSample != 1)
		{
			var m2:Matrix = new Matrix();
			m2.scale( 1/superSample, 1/superSample);
			var bmpDta2:BitmapData = new BitmapData(imageCropW, imageCropH, true, 0x00ffffff);
			bmpDta2.drawWithQuality(bmpDta, m2, null, null, null, true, StageQuality.BEST);
			
			bmpDta.dispose();
            bmpDta = bmpDta2;			
		}
        
		estimatedBitmapArea += (bmpDta.width + 1) * (bmpDta.height + 1);
        bitmapDatas.set(char.asciiCode, bmpDta);
        bitmapDataToAsciiMap.set(bmpDta, char.asciiCode);
        bitmapDataArray.push(bmpDta);	
		
		snapped++;
        return true;
	}	
	
	function finalizeFontGeneration() 
	{
		chars.set("count", Std.string(snapped));
		
		//sort bitmaps by height		
		var estimatedSide:Float = Math.sqrt( estimatedBitmapArea );
		var nextPower:Int = Std.int( Math.pow(2, Math.ceil(Math.log(estimatedSide) / Math.log(2))) );
		
		var imageCropW:Int;
		var imageCropH:Int;
		
		//TODO: this parameter is not proved in any way and it depends on packing efficiency, there may be a better way to estimate bitmap size
		if (estimatedSide / nextPower < 0.7)		
			imageCropW = imageCropH = nextPower;
		else
		{
			imageCropW = 2 * nextPower;
			imageCropH = nextPower;
		}
		
		if (imageCropW > 4096 || imageCropH > 4096)
		{
			trace("Error: font bitmap size must be smaller than 4096x4096");
			return;
		}

		common.set("scaleW", Std.string(imageCropW));
		common.set("scaleH", Std.string(imageCropH));
		
		bitmapDataArray.sort(bitmapSort);		
		var combinedBitmapData:BitmapData = new BitmapData( imageCropW, imageCropH, true, 0x00ffffff);
		var lastPosX:Int = 0;
		var lastPosY:Int = 0;
		var lineHeight:Int = 0;
		
		//go through sorted char bitmaps and fill the texture
		for (b in bitmapDataArray) 
		{
			if (lastPosX == 0)
				lineHeight = b.height - innerPadding * 2;
				
			if (lastPosX + b.width > combinedBitmapData.width)
			{
				lastPosX = 0;
				lastPosY += lineHeight + gap;
			}

			var character:SvgCharacterVO = svgFont.asciiToCharacterMap.get( bitmapDataToAsciiMap.get(b) );
			var charNode:Xml = Xml.createElement("char");
			charNode.set("id", Std.string( character.asciiCode ) );
			charNode.set("x", Std.string( lastPosX) );
			charNode.set("y", Std.string( lastPosY + lineHeight - b.height ) );
			charNode.set("width", Std.string( b.width) );
			charNode.set("height", Std.string( b.height) );			
			charNode.set("xoffset", Std.string(charOffsetsX.get( character.asciiCode ) ));

            var yPos:Float = charOffsetsY.get( character.asciiCode );
			charNode.set("yoffset", Std.string(lineHeight + yPos - innerPadding));		
			
			var hAdv:Float = character.hAdvX == 0 ? b.width / scaleFactor : character.hAdvX * fontScale;
			charNode.set("xadvance", Std.string( snapTo(hAdv, snapAdvanceXTo / scaleFactor) * scaleFactor ) );
			
			charNode.set("page", "0" );
			charNode.set("chnl", "15" );
			chars.addChild( charNode );
			
			combinedBitmapData.copyPixels( b, new Rectangle(0, 0, b.width, b.height), new Point(lastPosX, lastPosY + lineHeight - b.height) );
			lastPosX += b.width + gap;
			b.dispose();
		}
		bitmapDataArray = [];
		bitmapDatas = null;
		bitmapDataToAsciiMap = null;
		
		fontXml.addChild(chars);
		addKerningNodes();

		//create the texture and register the font
		var texture:Texture = Texture.fromBitmapData( combinedBitmapData, generateMipMaps, scaleFactor );
		
		var bmFont = new BitmapFont(texture, fontXml);
		var regName = (forceFamily == null ? svgFont.fontFamily : forceFamily) + "_" + size;
		#if (starling < '2.0.0')
		TextField.registerBitmapFont( bmFont, regName );
		#else
		TextField.registerCompositor( bmFont, regName );
		#end
		FontRegistry.registerBitmapFont(bmFont, regName);
		
		if(onComplete != null) onComplete();
	}

    static function snapTo(value:Float, snapTo:Float = 1, ?up:Null<Bool>) : Float
    {
        if(snapTo == 0) return value;
        if(snapTo != 1) value /= snapTo;

        if(up == true) value = Math.ceil(value);
        else if(up == false) value = Math.floor(value);
        else value = Math.round(value);

        if(snapTo != 1) value *= snapTo;
        return value;
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
					kerning.set("amount", Std.string( snapTo(char.kerningAfterThisChar.get(nextCharAscii), snapAdvanceXTo) ));
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