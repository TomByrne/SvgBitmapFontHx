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
import starling.textures.Texture;
import font.svg.SvgFont;

/**
 * Takes an SVG Font and generates a BitmapFont from it over a number of frames.
 * 
 * @author Michal Moczynski
 * @author Thomas Byrne
 */
class SvgBitmapFontGenerator 
{
	// Use these to measure progress of processing
	@:isVar public var progress(default, null):UInt;
	@:isVar public var total(default, null):UInt;

	
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
	var finalizingFont:Bool;
	var fontScale:Float;

	var processChars:Array<SvgCharacterVO>;

	var config:SvgFontGeneratorConfig;

	var renderer:SvgFontRenderer;
	var svgFont:SvgFont;

	var registers:Array<BitmapFont->String->Void>;

	
	public function new(svgFont:SvgFont, config:SvgFontGeneratorConfig, ?registers:Array<BitmapFont->String->Void>, ?renderer:SvgFontRenderer) 
	{
		if(renderer != null){
			this.renderer = renderer;
		}else{
			this.renderer = new SvgFontRenderer(svgFont.svgRendererXml);
		}

		this.svgFont = svgFont;
		this.config = config;
		this.registers = registers == null ? [] : registers;

		if(config.size == null) config.size = svgFont.unitsPerEm;
		if(config.superSampling == null) config.superSampling = 1;
		if(config.superSamplingScaleThreshold == null) config.superSamplingScaleThreshold = 0.1;
		if(config.gap == null) config.gap = 1;
		if(config.innerPadding == null) config.innerPadding = 1;
		if(config.scaleFactor == null) config.scaleFactor = 1.0;
		if(config.generateMipMaps == null) config.generateMipMaps = false;
		if(config.snapAdvanceXTo == null) config.snapAdvanceXTo = 1;
		if(config.characters == null) config.characters = [];
		
		initialize();
	}
	
	// Call once all settings are ready
	function initialize()
	{
		this.fontScale = config.size / svgFont.unitsPerEm;
		
		//fill basic information in font xml
		fontXml = Xml.createElement("font");
		var info:Xml = Xml.createElement("info");
		
		info.set("face", svgFont.fontFamily + "_" + config.size);
		info.set("size", Std.string(config.size * config.scaleFactor)); // This shouldn't be scaled but needs to be to offsets the scaling in BitmapFont.parseFontXml
		fontXml.addChild(info);
		
		common = Xml.createElement("common");

		common.set("lineHeight", Std.string(config.size * config.scaleFactor));
		common.set("base", Std.string( Math.ceil( (svgFont.capHeight * fontScale) * config.scaleFactor ) ));

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
		page.set("file", svgFont.fontFamily + "_" + config.size + "0");		
		
		fontXml.addChild(pages);		
		chars = Xml.createElement("chars");
		
		characterCounter = 0;
		snapped = 0;
		finalizingFont = false;

		processChars = [];

		for (ascii in svgFont.asciiCodes)
		{
			var char = svgFont.asciiToCharacterMap.get( ascii );
			if ( Lambda.has(config.characters, char.asciiCode) )
			{
				processChars.push(char);
			}
		}
		total = processChars.length + 1; // Plus 1 for the 'finalise' step
		progress = 0;
	}
	
	public function processNow() 
	{
		process(total);
	}
	
	public function process(steps:Int=1):Void 
	{
		if(progress >= total) return; // already finalised

        for(i in 0 ... steps){
			if(progress == total - 1){
				finalizeFontGeneration();
				progress++;
				break;
			}else{
				processChar(processChars[progress]);
			}

			progress++;
		}
	}
	
	function processChar(char:SvgCharacterVO) : Bool 
	{
		//snap the character
		var container:Sprite = new Sprite();
		var charDisplayObject:DisplayObject = renderer.render(char.name);
		charDisplayObject.transform.matrix = new Matrix();
		
		container.addChild(charDisplayObject);
		charDisplayObject.scaleY = -config.scaleFactor; // SVG y-axis is in opposite direction
        charDisplayObject.scaleX =  config.scaleFactor;
		var bounds:Rectangle = charDisplayObject.getBounds(container);

		var imageCropX:Int = -Math.ceil( -bounds.x * fontScale) - config.innerPadding;
		var imageCropY:Int = -Math.ceil( -bounds.y * fontScale) - config.innerPadding;
		var imageCropW:Int = Math.ceil( bounds.right * fontScale) - imageCropX + config.innerPadding * 2;
		var imageCropH:Int = Math.ceil( bounds.bottom * fontScale) - imageCropY + config.innerPadding * 2;
		
		charDisplayObject.x = -imageCropX / fontScale;
		charDisplayObject.y = -imageCropY / fontScale;

		charOffsetsX.set( char.asciiCode, imageCropX );
		charOffsetsY.set( char.asciiCode, imageCropY );

		var bmpDta:BitmapData;
		var m:Matrix = new Matrix();

        var superSample:Float = (fontScale <= config.superSamplingScaleThreshold ? config.superSampling : 1);
        
        m.scale(fontScale * config.superSampling, fontScale * config.superSampling);		
        bmpDta = new BitmapData( Math.ceil(imageCropW * config.superSampling), Math.ceil(imageCropH * config.superSampling), true, 0x00ffffff);
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
				lineHeight = b.height - config.innerPadding * 2;
				
			if (lastPosX + b.width > combinedBitmapData.width)
			{
				lastPosX = 0;
				lastPosY += lineHeight + config.gap;
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
			charNode.set("yoffset", Std.string(lineHeight + yPos - config.innerPadding));		
			
			var hAdv:Float = character.hAdvX == 0 ? b.width / config.scaleFactor : character.hAdvX * fontScale;
			charNode.set("xadvance", Std.string( snapTo(hAdv, config.snapAdvanceXTo / config.scaleFactor) * config.scaleFactor ) );
			
			charNode.set("page", "0" );
			charNode.set("chnl", "15" );
			chars.addChild( charNode );
			
			combinedBitmapData.copyPixels( b, new Rectangle(0, 0, b.width, b.height), new Point(lastPosX, lastPosY + lineHeight - b.height) );
			lastPosX += b.width + config.gap;
			b.dispose();
		}
		bitmapDataArray = [];
		bitmapDatas = null;
		bitmapDataToAsciiMap = null;
		
		fontXml.addChild(chars);
		addKerningNodes();

		//create the texture and register the font
		var texture:Texture = Texture.fromBitmapData( combinedBitmapData, config.generateMipMaps, config.scaleFactor );
		
		var bmFont = new BitmapFont(texture, fontXml);
		var regName = (config.forceFamily == null ? svgFont.fontFamily : config.forceFamily) + "_" + config.size;

		for(register in registers){
			register(bmFont, regName);
		}
	}

	public function addDefaultRegisters()
	{
		#if starling
			#if (starling < '2.0.0')
			registers.push(TextField.registerBitmapFont);
			#else
			registers.push(TextField.registerCompositor);
			#end
		#end

		#if starlingTextDisplay
		registers.push(starling.text.model.format.FontRegistry.registerBitmapFont);
		#end

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
			if ( Lambda.has(config.characters, ascii) )
			{
				var char:SvgCharacterVO = svgFont.asciiToCharacterMap.get(ascii);
				for ( nextCharAscii in char.kerningAfterThisChar.keys() ) 
				{
					if ( !Lambda.has(config.characters, nextCharAscii) ) continue;

					var kerning:Xml = Xml.createElement("kerning");
					kerning.set("first", Std.string(ascii));
					kerning.set("second", Std.string(nextCharAscii));
					kerning.set("amount", Std.string( snapTo(char.kerningAfterThisChar.get(nextCharAscii), config.snapAdvanceXTo) ));
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