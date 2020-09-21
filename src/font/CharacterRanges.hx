package font;

/**
 * ...
 * @author Michal Moczynski
 * @author Thomas Byrne
 */
class CharacterRanges 
{
	//based on https://en.wikipedia.org/wiki/List_of_Unicode_characters
	public static var DIGITS:Array<Int> = [48, 49, 50, 51, 52, 53, 54, 55, 56, 57];
	public static var LATIN_UPPERCASE:Array<Int> = [32, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76 ,77 ,78 ,79 ,80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90];
	public static var LATIN_LOWERCASE:Array<Int> = [32, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122];
	public static var LATIN_PUNCTUATION_SYMBOL:Array<Int> = [32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 58, 59, 60, 61, 62, 63, 64, 91, 92, 93, 94, 95, 96, 123, 124, 125, 126];//32-47, 58-64, 91-96, 123-126
	public static var LATIN_ALL:Array<Int> = LATIN_UPPERCASE.concat(LATIN_LOWERCASE).concat(LATIN_PUNCTUATION_SYMBOL);

	public static var UNICODE_SYMBOLS_BASIC:Array<Int> = createRange(8211, 8222);
	public static var UNICODE_SYMBOLS_EXTENDED:Array<Int> = createRange(8224, 8266);
	public static var UNICODE_SYMBOLS:Array<Int> = UNICODE_SYMBOLS_BASIC.concat(UNICODE_SYMBOLS_EXTENDED);
	
	public static var LATIN1_UPPERCASE:Array<Int> = [192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 216, 217, 218, 219, 220, 221, 222];//192-214, 216-222
	public static var LATIN1_LOWERCASE:Array<Int> = [223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 248, 249, 250, 251, 252, 253, 254, 255];//223-246, 248-255
	public static var LATIN_SUPPLEMENT:Array<Int> = LATIN1_UPPERCASE.concat(LATIN1_LOWERCASE);

	//based on https://www.rapidtables.com/code/text/unicode-characters.html
	// copyright, registered trademark, sound recording copyright, trademark, service mark
	public static var INTELLECTUAL_PROPERTY:Array<Int> = [169, 174, 8471, 8482, 8480];
	
	public static var GREEK_ALPHABET:Array<Int> = createRange(913, 969);
	
	// dollar, euro, pound, yen / yuan, cent, indian Rupee, rupee, peso, korean won, thai baht, dong, shekel
	public static var CURRENCY_CODES:Array<Int> = [36, 8364, 163, 165, 162, 8377, 8360, 8369, 8361, 3647, 8363, 8362];
	
	// horizontal tab, line feed, carriage return / enter, non-breaking space
	public static var SPECIAL_CODES:Array<Int> = [9, 10, 13, 160];



	static function createRange(start:Int, end:Int) : Array<Int>
	{
		var ret = [];
		for(i in start ... end+1) ret.push(i);
		return ret;
	}
	
	/*public static var LATIN_EXTENDED_A_EUROPEAN:Array<Int> = [];//256-328, 329-383
	public static var LATIN_EXTENDED_B_NON_EUROPEAN:Array<Int> = [];//384-447
	public static var LATIN_EXTENDED_B_AFRICAN_CLICKS:Array<Int> = [];//448-451
	public static var LATIN_EXTENDED_B_CROATIAN:Array<Int> = [];//452-460
	public static var LATIN_EXTENDED_B_PINYIN:Array<Int> = [];//461-476
	public static var LATIN_EXTENDED_B_PHONETIC :Array<Int> = [];//477-511
	public static var LATIN_EXTENDED_B_SLOVENIAN_CROATIAN :Array<Int> = [];//512-535
	public static var LATIN_EXTENDED_B_ROMANIAN:Array<Int> = [];//536-539
	public static var LATIN_EXTENDED_B_MISCELLANEOUS:Array<Int> = [];//540-553, 567-591
	public static var LATIN_EXTENDED_B_LIVONIAN:Array<Int> = [];//554-563
	public static var LATIN_EXTENDED_B_SINOLOGY:Array<Int> = [];//564-566
	public static var LATIN_EXTENDED:Array<Int> = LATIN_EXTENDED_A_EUROPEAN.concat(LATIN_EXTENDED_B_NON_EUROPEAN).concat(LATIN_EXTENDED_B_AFRICAN_CLICKS).concat(LATIN_EXTENDED_B_CROATIAN).concat(LATIN_EXTENDED_B_PINYIN).concat(LATIN_EXTENDED_B_PHONETIC).concat(LATIN_EXTENDED_B_SLOVENIAN_CROATIAN).concat(LATIN_EXTENDED_B_ROMANIAN).concat(LATIN_EXTENDED_B_MISCELLANEOUS).concat(LATIN_EXTENDED_B_LIVONIAN).concat(LATIN_EXTENDED_B_SINOLOGY);
	
	
	public static var LATIN_EXTENDED_ADDITIONAL:Array<Int> = [];//647-669*/
	
	
	static var namedRanges:Map < String, Array<Int>> = [
		'digit' => DIGITS,
		'digits' => DIGITS,
		
		'latin' => LATIN_ALL,
		'latin.upper' => LATIN_UPPERCASE,
		'latin.lower' => LATIN_LOWERCASE,
		'latin.symbols' => LATIN_PUNCTUATION_SYMBOL,
		
		'latinSupplement' => LATIN_SUPPLEMENT,
		'latinSupplement.upper' => LATIN1_UPPERCASE,
		'latinSupplement.loser' => LATIN1_LOWERCASE,
		
		'unicodeSymbols' => UNICODE_SYMBOLS,
		'unicodeSymbols.basic' => UNICODE_SYMBOLS_BASIC,
		'unicodeSymbols.extended' => UNICODE_SYMBOLS_EXTENDED,

		'intellectualProperty' => INTELLECTUAL_PROPERTY,
		'greek.alphabet' => GREEK_ALPHABET,
		'currencyCodes' => CURRENCY_CODES,
		'specialCodes' => SPECIAL_CODES,
	];
	
	public static function fromStrings(strs:Array<String>):Array<Int>
	{
		var ret:Array<Int> = [];
		for (str in strs){
			ret = ret.concat(fromString(str));
		}
		return ret;
	}
	/**
	 * Can be in any of the following forms:
	 * "154,9238"
	 * "10-20,55"
	 * "latin, digits, 55 - 1000"
	 */
	public static function fromString(str:String):Array<Int>
	{
		var ret:Array<Int> = [];
		var parts:Array<String> = str.split(',');
		for (part in parts){
			part = StringTools.trim(part);
			
			var range:Array<Int> = namedRanges.get(part);
			if (range != null){
				ret = ret.concat(range);
				continue;
			}
			
			var dashInd:Int = part.indexOf('-');
			if (dashInd != -1){
				var startS:String = part.substr(0, dashInd);
				startS = StringTools.rtrim(startS);
				
				var endS:String = part.substr(dashInd + 1);
				endS = StringTools.ltrim(endS);
				
				var start:Int = Std.parseInt(startS);
				var end:Int = Std.parseInt(endS);
				if (Std.string(start) == startS && Std.string(end) == endS){
					for (i in start ... end + 1){
						ret.push(i);
					}
					continue;
				}
			}else{
				var char:Int = Std.parseInt(part);
				if (Std.string(char) == part){
					ret.push(char);
					continue;
				}
			}
			
			trace("Couldn't interpret character range part: " + part);
		}
		return ret;
	}
}