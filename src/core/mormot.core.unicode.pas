/// Framework Core Low-Level Unicode UTF-8 UTF-16 Ansi Conversion
// - this unit is a part of the Open Source Synopse mORMot framework 2,
// licensed under a MPL/GPL/LGPL three license - see LICENSE.md
unit mormot.core.unicode;

{
  *****************************************************************************

   Efficient Unicode Conversion Classes shared by all framework units
   - UTF-8 Efficient Encoding / Decoding
   - Cross-Platform Charset and CodePage Support
   - UTF-8 / UTF-16 / Ansi Conversion Classes
   - Text File Loading with BOM/Unicode Support
   - Low-Level String Conversion Functions
   - Text Case-(in)sensitive Conversion and Comparison
   - UTF-8 String Manipulation Functions
   - TRawUtf8DynArray Processing Functions
   - Operating-System Independent Unicode Process

  *****************************************************************************
}

interface

{$I ..\mormot.defines.inc}

uses
  classes,
  sysutils,
  mormot.core.base,
  mormot.core.os;


{ *************** UTF-8 Efficient Encoding / Decoding }

// some constants used for UTF-8 conversion, including UTF-16 surrogates

const
  /// the Unicode consortium (and RFC 3629) limit to the U+0000..U+10FFFF range
  // - as most UTF-16 softwares or languages (e.g. Windows, Java, C#, JavaScript)
  UNICODE_MAX = $10ffff;

type
  TUtf8TableExtra = record
    offset, minimum: cardinal;
  end;

  /// define a lookup table for efficient UTF-8 processing
  // - supporting the full original UTF-8 U+0000..U+7FFFFFFF range, even if
  // only U+0000..U+10FFFF (<=UNICODE_MAX) is considered valid today
  // - see http://floodyberry.wordpress.com/2007/04/14/utf-8-conversion-tricks
  {$ifdef USERECORDWITHMETHODS}
  TUtf8Table = record
  {$else}
  TUtf8Table = object
  {$endif USERECORDWITHMETHODS}
  public
    /// allow GetHighUtf8Ucs4() to validate and decode an UTF-8 sequence
    Extra: array[0..5] of TUtf8TableExtra;
    /// the number of extra bytes in addition to the first UTF-8 byte
    // - since RFC 3629, only values within the 0..3 range should appear, i.e.
    // up to UTF8_MAX within the U+0000..U+10FFFF official Unicode range
    Lookup: TByteToByte;
    /// retrieve a >127 UCS-4 CodePoint from an UTF-8 sequence
    // - decode original UTF-8 values up to U+7FFFFFFF > UNICODE_MAX = U+10FFFF
    function GetHighUtf8Ucs4(var U: PUtf8Char): Ucs4CodePoint;
      {$ifdef HASINLINE}inline;{$endif}
  end;
  PUtf8Table = ^TUtf8Table;

const
  /// TUtf8Table.Lookup[] value for a 7-bit ASCII character
  UTF8_ASCII   = 0;
  /// maximum TUtf8Table.Lookup[] value within UTF-16 / Unicode accessible range
  // - this unit supports the full original UTF-8 range, but this constant could
  // be used to ensure RFC 3629 / Unicode expectations, as for IsValidUtf8()
  UTF8_MAX     = 3;
  /// impossible TUtf8Table.Lookup[] value
  UTF8_INVALID = 6;
  /// special encoding of ending #0 in TUtf8Table.Lookup[]
  UTF8_ZERO    = 7;

  /// constant lookup table for efficient UTF-8 processing
  UTF8_TABLE: TUtf8Table = (
    Extra: (
      (offset: $00000000;  minimum: $00010000),  // 0: 0000 0000 - 0000 007F
      (offset: $00003080;  minimum: $00000080),  // 1: 0000 0080 - 0000 07FF
      (offset: $000e2080;  minimum: $00000800),  // 2: 0000 0800 - 0000 FFFF
      (offset: $03c82080;  minimum: $00010000),  // 3: 0001 0000 - 001F FFFF
      (offset: $fa082080;  minimum: $00200000),  // 4: outside UTF-16 range
      (offset: $82082080;  minimum: $04000000)); // 5: outside UTF-16 range
    Lookup: (
      7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
      3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 6, 6)
    );

  UTF8_NEED_UTF16_SURROGATES = 3; // 4 UTF-8 bytes trigger surrogates in UTF-16
  UTF8_EXTRA1_OFFSET = $00003080; // = UTF8_TABLE.Extra[1].offset for $0..$7ff
  UTF8_7FF  = $80c0;              // 16-bit UTF8 constant for $80..$7ff
  UTF8_FFFF = $008080e0;          // 24-bit UTF8 constant for $800..$ffff
  UTF8_10FF = $808080f0;          // 32-bit UTF8 constant for $10000..$10ffff
  UTF8_UNICODE_REPLACEMENT_CHARACTER = $bdbfef; // U+fffd encoded as UTF-8

  UTF16_HISURROGATE_MIN  = $d800;
  UTF16_HISURROGATE_MAX  = $dbff;
  UTF16_LOSURROGATE_MIN  = $dc00;
  UTF16_LOSURROGATE_MAX  = $dfff;
  UTF16_SURROGATE_OFFSET = $d7c0;
  UTF16_SURROGATE_MIN    = $010000;
  UTF16_SURROGATE_MAX    = UNICODE_MAX;
  UTF16_SURROGATE_FLAGS  = UTF16_HISURROGATE_MIN or (UTF16_LOSURROGATE_MIN shl 16);

  /// replace any incoming UCS-4 which is unrepresentable as a single WideChar
  // - i.e. which would need a UTF-16 surrogates pair for proper encoding
  // - set e.g. by GetUtf8WideChar(), Utf8UpperReference() or
  // RawUnicodeToUtf8() when ccfReplacementCharacterForUnmatchedSurrogate is set
  // - encoded as $ef $bf $bd bytes in UTF-8
  UNICODE_REPLACEMENT_CHARACTER = $fffd;


/// internal function, used to retrieve a >127 US4 CodePoint from UTF-8
// - not to be called directly, but from inlined higher-level functions
// - here U^ shall be always >= #80
// - decode original UTF-8 values up to U+7FFFFFFF > UNICODE_MAX = U+10FFFF
// - typical use is as such:
// !  ch := ord(P^);
// !  if ch and $80=0 then
// !    inc(P) else
// !    ch := GetHighUtf8Ucs4(P);
function GetHighUtf8Ucs4(var U: PUtf8Char): Ucs4CodePoint;

/// decode UTF-16 WideChar from UTF-8 input buffer
// - any surrogate (Ucs4>$ffff) is returned as UNICODE_REPLACEMENT_CHARACTER=$fffd
function GetUtf8WideChar(P: PUtf8Char): cardinal;

/// get the UCS-4 CodePoint stored in P^ (decode UTF-8 if necessary)
// - decode original UTF-8 values up to U+7FFFFFFF > UNICODE_MAX = U+10FFFF
function NextUtf8Ucs4(var P: PUtf8Char): Ucs4CodePoint;

/// internal function converting a UTF-16 surrogates pair into UTF-8
// - return the number of bytes written into Dest (usually 4 or 3 for U+fffd
// UTF8_UNICODE_REPLACEMENT_CHARACTER when malformatted surrogates are detected)
// - as called e.g. by Utf16HiCharToUtf8() or JsonUnicodeEscapeToUtf8()
function Utf16SurrogateToUtf8(Dest: PUtf8Char; c1, c2: cardinal): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// UTF-8 encode one UTF-16 encoded UCS-4 CodePoint into Dest
// - c = Source[-1] is expected to be > $7f, and Source could be increased after
// the following UTF-16 surrogate pair (maybe written as U+fffd)
// - return the number of bytes written into Dest (i.e. from 1 up to 4)
function Utf16HiCharToUtf8(Dest: PUtf8Char; c: cardinal; var Source: PWord): PtrInt;

/// UTF-8 encode one standard Unicode CodePoint <= UNICODE_MAX = U+10FFFF into Dest
// - return the number of bytes written into Dest (i.e. from 1 up to 6)
function IsoUcsToUtf8(c: cardinal; Dest: PUtf8Char): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// UTF-8 encode one full range UCS-4 CodePoint into Dest
// - support the whole original UTF-8 range even over the maximum UTF-16/Unicode
// encoding or RFC 3629 range, i.e. up to U+7FFFFFFF > UNICODE_MAX = U+10FFFF
// - return the number of bytes written into Dest (i.e. from 1 up to 6)
function Ucs4ToUtf8(ucs4: Ucs4CodePoint; Dest: PUtf8Char): PtrInt;

type
  /// option set for RawUnicodeToUtf8() conversion
  TCharConversionFlags = set of (
    ccfNoTrailingZero,
    ccfReplacementCharacterForUnmatchedSurrogate);

/// convert a UTF-16 PWideChar buffer into a UTF-8 string
procedure RawUnicodeToUtf8(WideChar: PWideChar; WideCharCount: integer;
  var result: RawUtf8; Flags: TCharConversionFlags = [ccfNoTrailingZero]); overload;

/// convert a UTF-16 PWideChar buffer into a UTF-8 temporary buffer
procedure RawUnicodeToUtf8(WideChar: PWideChar; WideCharCount: integer;
  var result: TSynTempBuffer; Flags: TCharConversionFlags); overload;

/// convert a UTF-16 PWideChar buffer into a UTF-8 string
function RawUnicodeToUtf8(WideChar: PWideChar; WideCharCount: integer;
  Flags: TCharConversionFlags = [ccfNoTrailingZero]): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert a UTF-16 PWideChar buffer into a UTF-8 buffer
// - replace system.UnicodeToUtf8 implementation, which is rather slow
// since Delphi 2009+
// - append a #0 terminator to the ending PUtf8Char, unless ccfNoTrailingZero is set
// - if ccfReplacementCharacterForUnmatchedSurrogate is set, this function will identify
// unmatched surrogate pairs and replace them with UNICODE_REPLACEMENT_CHARACTER -
// see https://en.wikipedia.org/wiki/Specials_(Unicode_block) - otherwise, it
// will stop the conversion at the faulty UTF-16 input
function RawUnicodeToUtf8(Dest: PUtf8Char; DestLen: PtrUInt;
  Source: PWideChar; SourceLen: PtrUInt; Flags: TCharConversionFlags): PtrUInt; overload;

/// convert a UTF-16 PWideChar buffer into a UTF-8 string
// - this version doesn't resize the resulting RawUtf8 string, but return
// the new resulting RawUtf8 byte count into Utf8Length
function RawUnicodeToUtf8(WideChar: PWideChar; WideCharCount: integer;
  out Utf8Length: integer): RawUtf8; overload;


/// convert an UTF-8 encoded text into a WideChar (UTF-16) buffer
// - faster than System.Utf8ToUnicode
// - sourceBytes can by 0, therefore length is computed from zero terminated source
// - enough place must be available in dest buffer (guess is sourceBytes*3+2)
// - a WideChar(#0) is added at the end (if something is written) unless
// NoTrailingZero is TRUE
// - returns the BYTE count written in dest, excluding the ending WideChar(#0)
function Utf8ToWideChar(dest: PWideChar; source: PUtf8Char; sourceBytes: PtrUInt = 0;
  NoTrailingZero: boolean = false): PtrInt; overload;

/// convert an UTF-8 encoded text into a WideChar (UTF-16) buffer
// - faster than System.Utf8ToUnicode
// - this overloaded function expect a MaxDestChars parameter
// - sourceBytes can not be 0 for this function
// - enough place must be available in dest buffer (guess is sourceBytes*3+2)
// - a WideChar(#0) is added at the end (if something is written) unless
// NoTrailingZero is TRUE
// - returns the BYTE COUNT (not WideChar count) written in dest, excluding the
// ending WideChar(#0)
function Utf8ToWideChar(dest: PWideChar; source: PUtf8Char;
  MaxDestChars, sourceBytes: PtrUInt; NoTrailingZero: boolean = false): PtrInt; overload;

/// calculate the UTF-16 Unicode characters count, UTF-8 encoded in source^
// - count may not match the UCS-4 CodePoint, in case of UTF-16 surrogates
// - faster than System.Utf8ToUnicode with dest=nil
function Utf8ToUnicodeLength(source: PUtf8Char): PtrUInt;

/// returns TRUE if the supplied buffer has valid UTF-8 encoding
// - on Haswell AVX2 Intel/AMD CPUs, will use very efficient ASM
// - warning: AVX2 version won't refuse #0 characters within the buffer
// - follows RFC 3629 / Unicode requirements, i.e. up to 4-bytes UTF-8 sequences,
// to stay within U+0000..U+10FFFF (as accessible with surrogates in UTF-16)
var
  IsValidUtf8Buffer: function(source: PUtf8Char; sourcelen: PtrInt): boolean;

/// returns TRUE if the supplied buffer has valid UTF-8 encoding
// - could be called directly on small input, if #0 characters should be refused
function IsValidUtf8Pas(source: PUtf8Char; len: PtrInt): boolean;

/// returns TRUE if the supplied RawUtf8 has valid UTF-8 encoding
// - could be called directly on small input, if #0 characters should be refused
function IsValidUtf8Small(const source: RawByteString): boolean;
  {$ifdef HASINLINE}inline;{$endif}

/// returns TRUE if the supplied buffer has valid UTF-8 encoding
// - on Haswell AVX2 Intel/AMD CPUs, will use very efficient ASM, reaching e.g.
// 21 GB/s parsing speed on a Core i5-13500
// - warning: AVX2 version won't refuse #0 characters within the buffer - use
// IsValidUtf8NotVoid() if you are not sure that your input is pure text
function IsValidUtf8(const source: RawByteString): boolean;
  {$ifdef HASINLINE}inline;{$endif}

/// returns TRUE if the supplied buffer has valid UTF-8 encoding and no #0 within
// - will also refuse #0 characters within the buffer even on AVX2
function IsValidUtf8NotVoid(source: PUtf8Char; len: PtrInt): boolean; overload;
  {$ifdef HASINLINE}{$ifndef ASMX64AVXNOCONST}inline;{$endif}{$endif}

/// returns TRUE if the supplied buffer has valid UTF-8 encoding and no #0 within
// - will also refuse #0 characters within the buffer even on AVX2
function IsValidUtf8NotVoid(const source: RawByteString): boolean; overload;

/// returns TRUE if the supplied #0-ending buffer has valid UTF-8 encoding
// - just a wrapper around IsValidUtf8Buffer(source, StrLen(source)) so if you
// know the source length, you would better call IsValidUtf8Buffer() directly
// - on Haswell AVX2 Intel/AMD CPUs, will use very efficient ASM, reaching e.g.
// 15 GB/s parsing speed on a Core i5-13500 - StrLen() itself runs at 37 GB/s
function IsValidUtf8Ptr(source: PUtf8Char): boolean;
  {$ifdef HASINLINE}inline;{$endif}

/// detect UTF-8 content and mark the variable with the CP_UTF8 codepage
// - to circumvent FPC concatenation bug with CP_UTF8 and CP_RAWBYTESTRING
procedure DetectRawUtf8(var source: RawByteString);
  {$ifndef HASCODEPAGE}{$ifdef HASINLINE}inline;{$endif}{$endif}

/// returns TRUE if the supplied buffer has valid UTF-8 encoding with no #1..#31
// control characters
// - supplied input is a pointer to a #0 ended text buffer
function IsValidUtf8WithoutControlChars(source: PUtf8Char): boolean; overload;

/// returns TRUE if the supplied buffer has valid UTF-8 encoding with no #0..#31
// control characters
// - supplied input is a RawUtf8 variable
function IsValidUtf8WithoutControlChars(const source: RawUtf8): boolean; overload;

/// check if any forbidden 7-bit char appears in the supplied text
// - is a wrapper around strcspn()
function ContainsChars(const text, forbidden: RawUtf8): boolean;

/// will truncate the supplied UTF-8 value if its length exceeds the specified
// UTF-16 Unicode characters count
// - count may not match the UCS-4 CodePoint, in case of UTF-16 surrogates
// - returns FALSE if text was not truncated, TRUE otherwise
function Utf8TruncateToUnicodeLength(var text: RawUtf8; maxUtf16: integer): boolean;

/// will truncate the supplied UTF-8 value if its length exceeds the specified
// bytes count
// - this function will ensure that the returned content will contain only valid
// UTF-8 sequence, i.e. will trim the whole trailing UTF-8 sequence
// - returns FALSE if text was not truncated, TRUE otherwise
function Utf8TruncateToLength(var text: RawUtf8; maxBytes: PtrUInt): boolean;

/// compute the truncated length of the supplied UTF-8 value if it exceeds the
// specified bytes count
// - this function will ensure that the returned content will contain only valid
// UTF-8 sequence, i.e. will trim the whole trailing UTF-8 sequence
// - returns maxBytes if text was not truncated, or the number of fitting bytes
function Utf8TruncatedLength(const text: RawUtf8; maxBytes: PtrUInt): PtrInt; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// compute the truncated length of the supplied UTF-8 value if it exceeds the
// specified bytes count
// - this function will ensure that the returned content will contain only valid
// UTF-8 sequence, i.e. will trim the whole trailing UTF-8 sequence
// - returns maxBytes if text was not truncated, or the number of fitting bytes
function Utf8TruncatedLength(text: PAnsiChar; textlen, maxBytes: PtrUInt): PtrInt; overload;

/// calculate the UTF-16 Unicode characters count of the UTF-8 encoded first line
// - count may not match the UCS-4 CodePoint, in case of UTF-16 surrogates
// - end the parsing at first #13 or #10 character
function Utf8FirstLineToUtf16Length(source: PUtf8Char): PtrInt;


{ ************** Cross-Platform Charset and CodePage Support }

const
  ANSI_CHARSET        = 0;
  DEFAULT_CHARSET     = 1;
  SYMBOL_CHARSET      = 2;
  SHIFTJIS_CHARSET    = 128;
  HANGEUL_CHARSET     = 129;
  JOHAB_CHARSET       = 130;
  GB2312_CHARSET      = 134;
  CHINESEBIG5_CHARSET = 136;
  GREEK_CHARSET       = 161;
  TURKISH_CHARSET     = 162;
  VIETNAMESE_CHARSET  = 163;
  HEBREW_CHARSET      = 177;
  ARABIC_CHARSET      = 178;
  BALTIC_CHARSET      = 186;
  RUSSIAN_CHARSET     = 204;
  THAI_CHARSET        = 222;
  EASTEUROPE_CHARSET  = 238;
  OEM_CHARSET         = 255;

/// convert a char set to a code page
function CharSetToCodePage(CharSet: integer): cardinal;

/// convert a code page to a char set
function CodePageToCharSet(CodePage: cardinal): integer;

/// check if a code page is known to be of fixed width, i.e. not MBCS
// - i.e. will be implemented as a TSynAnsiFixedWidth
function IsFixedWidthCodePage(aCodePage: cardinal): boolean;

/// return a code page number into human-friendly text
// - e.g. 'shift_jis' for aCodePage = 932, or 'ms1252' for 1252
// - returns the lowercased Unicode_CodePageName(aCodePage) value
function CodePageToText(aCodePage: cardinal): RawUtf8;

type
  /// a list of common human languages, in identifier alphabetic order
  TLanguage = (lngUndefined,
    lngAfrikaans,  lngAlbanian, lngAlsatian,   lngArabic,     lngArmenian,
    lngAssamese,   lngAzeri,    lngBashkir,    lngBasque,     lngBelarusian,
    lngBengali,    lngBosnian,  lngBreton,     lngBulgarian,  lngCatalan,
    lngChinese,    lngCorsican, lngCroatian,   lngCzech,      lngDanish,
    lngDari,       lngDivehi,   lngDutch,      lngEnglish,    lngEstonian,
    lngFaeroese,   lngFarsi,    lngFinnish,    lngFrench,     lngFrisian,
    lngGalician,   lngGeorgian, lngGerman,     lngGreek,      lngGreenlandic,
    lngGujarati,   lngHebrew,   lngHindi,      lngHungarian,  lngIcelandic,
    lngIndonesian, lngIrish,    lngItalian,    lngJapanese,   lngKannada,
    lngKashmiri,   lngKazak,    lngKonkani,    lngKorean,     lngKyrgyz,
    lngLao,        lngLatvian,  lngLithuanian, lngMacedonian, lngMalay,
    lngMalayalam,  lngManipuri, lngMarathi,    lngMongolian,  lngNepali,
    lngNorwegian,  lngOccitan,  lngOriya,      lngPashto,     lngPolish,
    lngPortuguese, lngPunjabi,  lngRomanian,   lngRussian,    lngSanskrit,
    lngSerbian,    lngSindhi,   lngSlovak,     lngSlovenian,  lngSpanish,
    lngSwahili,    lngSwedish,  lngSyriac,     lngTamil,      lngTatar,
    lngTelugu,     lngThai,     lngTurkish,    lngUkrainian,  lngUrdu,
    lngUzbek,      lngVietnamese);

const
  // see https://slaviccenters.duke.edu/webliogra/bosnian-croatian-serbian
  lngBCS = [lngBosnian, lngCroatian, lngSerbian];

  // see https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-lcid
  LANG_NEUTRAL     = $00;
  LANG_AFRIKAANS   = $36;
  LANG_ALBANIAN    = $1c;
  LANG_ALSATIAN    = $84;
  LANG_ARABIC      = $01;
  LANG_ARMENIAN    = $2b;
  LANG_ASSAMESE    = $4d;
  LANG_AZERI       = $2c;
  LANG_BASHKIR     = $6d;
  LANG_BASQUE      = $2d;
  LANG_BELARUSIAN  = $23;
  LANG_BENGALI     = $45;
  LANG_BOSNIAN     = $1a;
  LANG_BRETON      = $7e;
  LANG_BULGARIAN   = $02;
  LANG_CATALAN     = $03;
  LANG_CHINESE     = $04;
  LANG_CORSICAN    = $83;
  LANG_CROATIAN    = $1a;
  LANG_CZECH       = $05;
  LANG_DANISH      = $06;
  LANG_DARI        = $8c;
  LANG_DIVEHI      = $65;
  LANG_DUTCH       = $13;
  LANG_ENGLISH     = $09;
  LANG_ESTONIAN    = $25;
  LANG_FAEROESE    = $38;
  LANG_FARSI       = $29;
  LANG_FINNISH     = $0b;
  LANG_FRENCH      = $0c;
  LANG_FRISIAN     = $62;
  LANG_GALICIAN    = $56;
  LANG_GEORGIAN    = $37;
  LANG_GERMAN      = $07;
  LANG_GREEK       = $08;
  LANG_GREENLANDIC = $6f;
  LANG_GUJARATI    = $47;
  LANG_HEBREW      = $0d;
  LANG_HINDI       = $39;
  LANG_HUNGARIAN   = $0e;
  LANG_ICELANDIC   = $0f;
  LANG_INDONESIAN  = $21;
  LANG_IRISH       = $3c;
  LANG_ITALIAN     = $10;
  LANG_JAPANESE    = $11;
  LANG_KANNADA     = $4b;
  LANG_KASHMIRI    = $60;
  LANG_KAZAK       = $3f;
  LANG_KONKANI     = $57;
  LANG_KOREAN      = $12;
  LANG_KYRGYZ      = $40;
  LANG_LAO         = $54;
  LANG_LATVIAN     = $26;
  LANG_LITHUANIAN  = $27;
  LANG_MACEDONIAN  = $2f;
  LANG_MALAY       = $3e;
  LANG_MALAYALAM   = $4c;
  LANG_MANIPURI    = $58;
  LANG_MARATHI     = $4e;
  LANG_MONGOLIAN   = $50;
  LANG_NEPALI      = $61;
  LANG_NORWEGIAN   = $14;
  LANG_OCCITAN     = $82;
  LANG_ORIYA       = $48;
  LANG_PASHTO      = $63;
  LANG_POLISH      = $15;
  LANG_PORTUGUESE  = $16;
  LANG_PUNJABI     = $46;
  LANG_ROMANIAN    = $18;
  LANG_RUSSIAN     = $19;
  LANG_SANSKRIT    = $4f;
  LANG_SERBIAN     = $1a;
  LANG_SINDHI      = $59;
  LANG_SLOVAK      = $1b;
  LANG_SLOVENIAN   = $24;
  LANG_SPANISH     = $0a;
  LANG_SWAHILI     = $41;
  LANG_SWEDISH     = $1d;
  LANG_SYRIAC      = $5a;
  LANG_TAMIL       = $49;
  LANG_TATAR       = $44;
  LANG_TELUGU      = $4a;
  LANG_THAI        = $1e;
  LANG_TURKISH     = $1f;
  LANG_UKRAINIAN   = $22;
  LANG_URDU        = $20;
  LANG_UZBEK       = $43;
  LANG_VALENCIAN   = $03;
  LANG_VIETNAMESE  = $2a;

  LANG_USER_DEFAULT       = $0400;
  LANG_SYSTEM_DEFAULT     = $0800;
  LANG_ENGLISH_US         = LANG_ENGLISH  or LANG_USER_DEFAULT;
  LANG_CHINESE_SIMPLIFIED = LANG_CHINESE  or LANG_SYSTEM_DEFAULT;
  LANG_CROATIAN_NEUTRAL   = LANG_CROATIAN or LANG_USER_DEFAULT;
  LANG_BOSNIAN_CYRILLIC   = LANG_BOSNIAN  or $2000;
  LANG_SERBIAN_NEUTRAL    = LANG_SERBIAN  or $7c00;

  LANG_PRI: array[TLanguage] of byte = (LANG_NEUTRAL,
    LANG_AFRIKAANS,  LANG_ALBANIAN, LANG_ALSATIAN,   LANG_ARABIC,     LANG_ARMENIAN,
    LANG_ASSAMESE,   LANG_AZERI,    LANG_BASHKIR,    LANG_BASQUE,     LANG_BELARUSIAN,
    LANG_BENGALI,    LANG_BOSNIAN,  LANG_BRETON,     LANG_BULGARIAN,  LANG_CATALAN,
    LANG_CHINESE,    LANG_CORSICAN, LANG_CROATIAN,   LANG_CZECH,      LANG_DANISH,
    LANG_DARI,       LANG_DIVEHI,   LANG_DUTCH,      LANG_ENGLISH,    LANG_ESTONIAN,
    LANG_FAEROESE,   LANG_FARSI,    LANG_FINNISH,    LANG_FRENCH,     LANG_FRISIAN,
    LANG_GALICIAN,   LANG_GEORGIAN, LANG_GERMAN,     LANG_GREEK,      LANG_GREENLANDIC,
    LANG_GUJARATI,   LANG_HEBREW,   LANG_HINDI,      LANG_HUNGARIAN,  LANG_ICELANDIC,
    LANG_INDONESIAN, LANG_IRISH,    LANG_ITALIAN,    LANG_JAPANESE,   LANG_KANNADA,
    LANG_KASHMIRI,   LANG_KAZAK,    LANG_KONKANI,    LANG_KOREAN,     LANG_KYRGYZ,
    LANG_LAO,        LANG_LATVIAN,  LANG_LITHUANIAN, LANG_MACEDONIAN, LANG_MALAY,
    LANG_MALAYALAM,  LANG_MANIPURI, LANG_MARATHI,    LANG_MONGOLIAN,  LANG_NEPALI,
    LANG_NORWEGIAN,  LANG_OCCITAN,  LANG_ORIYA,      LANG_PASHTO,     LANG_POLISH,
    LANG_PORTUGUESE, LANG_PUNJABI,  LANG_ROMANIAN,   LANG_RUSSIAN,    LANG_SANSKRIT,
    LANG_SERBIAN,    LANG_SINDHI,   LANG_SLOVAK,     LANG_SLOVENIAN,  LANG_SPANISH,
    LANG_SWAHILI,    LANG_SWEDISH,  LANG_SYRIAC,     LANG_TAMIL,      LANG_TATAR,
    LANG_TELUGU,     LANG_THAI,     LANG_TURKISH,    LANG_UKRAINIAN,  LANG_URDU,
    LANG_UZBEK,      LANG_VIETNAMESE);

 /// ISO 639-1 compatible language abbreviations (not to be translated)
 LANG_ISO_SHORT: array[TLanguage] of array[0..1] of AnsiChar = ('',
   'af', 'sq', 'al', 'ar', 'hy',   'as', 'az', 'ba', 'eu', 'be',
   'bn', 'bs', 'br', 'bg', 'ca',   'zh', 'co', 'hr', 'cz', 'da',
   'ad', 'dv', 'nl', 'en', 'et',   'fo', 'fa', 'fi', 'fr', 'fy',
   'gl', 'ka', 'de', 'el', 'kl',   'gu', 'he', 'hi', 'hu', 'is',
   'id', 'ga', 'it', 'ja', 'kn',   'km', 'ki', 'kk', 'ko', 'ky',
   'lo', 'lv', 'lt', 'mk', 'ms',   'ml', 'mp', 'mr', 'mn', 'ne',
   'no', 'oc', 'or', 'ps', 'pl',   'pt', 'pa', 'ro', 'ru', 'sa',
   'sr', 'sd', 'sk', 'sl', 'es',   'sw', 'sv', 'sy', 'ta', 'tt',
   'te', 'th', 'tr', 'uk', 'ur',   'uz', 'vi');

var
  /// the 16-bit Windows Language Code Identifiers of each language enumerate
  // - e.g. LANG_LCID[lngEnglish] = 1033
  LANG_LCID: array[TLanguage] of word;
  /// ISO 639-1 compatible language abbreviations e.g. lngEnglish as 'en'
  LANG_ISO: array[TLanguage] of RawUtf8;
  /// internal lookup table filled by mormot.core.rtti as e.g. 'English'
  // - stored in alphabetical order
  LANG_TXT: array[TLanguage] of RawUtf8;

/// search a 16-bit Windows Language Code Identifier as TLanguage enumerate
function LcidToLanguage(lcid: cardinal): TLanguage;

/// return a 16-bit Windows Language Code Identifier into human-friendly text
// - e.g. 'English' for LCID = 1033
function LcidToText(lcid: cardinal): RawUtf8;

/// search a ISO 639-1 compatible language abbreviation
function IsoTextToLanguage(const Text: RawUtf8): TLanguage;


{ **************** UTF-8 / UTF-16 / Ansi Conversion Classes }

type
  /// Exception raised by this unit in case of fatal conversion issue
  ESynUnicode = class(ExceptionWithProps);

  /// an abstract class to handle Ansi to/from Unicode translation
  // - implementations of this class will handle efficiently all CharSets
  // - this default implementation will use the Operating System APIs
  // - NEVER call Create() constructor directly: use the Engine() factory instead
  TSynAnsiConvert = class
  protected
    fCodePage: cardinal;
    fAnsiCharMbcs: boolean;
    fAnsiCharShift: byte;
  public
    /// returns the engine corresponding to a given code page
    // - a global list of TSynAnsiConvert instances is handled by the unit -
    // therefore, caller should not release the returned instance
    // - will return nil in case of unhandled code page
    // - is aCodePage is 0, will return CurrentAnsiConvert value
    class function Engine(aCodePage: cardinal): TSynAnsiConvert;
      {$ifdef HASINLINE} static; {$endif}
    /// initialize the internal conversion engine
    // - NEVER call this constructor directly: use the Engine() factory instead
    constructor Create(aCodePage: cardinal); reintroduce; virtual;
    /// direct conversion of a PAnsiChar buffer into an Unicode buffer
    // - Dest^ buffer must be reserved with at least SourceChars*2 bytes
    // - this default implementation will use the Operating System APIs
    // - will append a #0 terminator to the returned PWideChar, unless
    // NoTrailingZero is set
    function AnsiBufferToUnicode(Dest: PWideChar; Source: PAnsiChar;
      SourceChars: cardinal; NoTrailingZero: boolean = false): PWideChar; overload; virtual;
    /// direct conversion of a PAnsiChar buffer into a UTF-8 encoded buffer
    // - Dest^ buffer must be reserved with at least SourceChars*3 bytes
    // - will append a #0 terminator to the returned PUtf8Char, unless
    // NoTrailingZero is set
    // - this default implementation will use the Operating System APIs
    function AnsiBufferToUtf8(Dest: PUtf8Char; Source: PAnsiChar;
      SourceChars: cardinal; NoTrailingZero: boolean = false): PUtf8Char; overload; virtual;
    {$ifndef PUREMORMOT2}
    /// convert any Ansi Text into an UTF-16 Unicode String
    // - returns a value using our RawUnicode kind of string
    function AnsiToRawUnicode(const AnsiText: RawByteString): RawUnicode; overload;
    /// convert any Ansi buffer into an Unicode String
    // - returns a value using our RawUnicode kind of string
    function AnsiToRawUnicode(
      Source: PAnsiChar; SourceChars: cardinal): RawUnicode; overload; virtual;
    {$endif PUREMORMOT2}
    /// convert any Ansi buffer into an Unicode String
    // - returns a SynUnicode, i.e. Delphi 2009+ UnicodeString or a WideString
    procedure AnsiToUnicodeStringVar(
      Source: PAnsiChar; SourceChars: cardinal; var Result: SynUnicode);
    /// convert any Ansi buffer into an Unicode String
    // - returns a SynUnicode, i.e. Delphi 2009+ UnicodeString or a WideString
    function AnsiToUnicodeString(const Source: RawByteString): SynUnicode;
      {$ifdef HASINLINE} inline; {$endif}
    /// convert any Ansi Text into an UTF-8 encoded String
    // - internally calls AnsiBufferToUtf8 virtual method
    function AnsiToUtf8(const AnsiText: RawByteString): RawUtf8; virtual;
    /// direct conversion of a PAnsiChar buffer into a UTF-8 encoded string
    // - will call AnsiBufferToUnicode() overloaded virtual method
    procedure AnsiBufferToRawUtf8(Source: PAnsiChar;
      SourceChars: cardinal; out Value: RawUtf8); overload; virtual;
    /// direct conversion of an Unicode buffer into a PAnsiChar buffer
    // - Dest^ buffer must be reserved with at least SourceChars * 3 bytes
    // - will detect and ignore any trailing UTF-16LE BOM marker
    // - this default implementation will rely on the Operating System for
    // all non ASCII-7 chars
    function UnicodeBufferToAnsi(Dest: PAnsiChar; Source: PWideChar;
      SourceChars: cardinal): PAnsiChar; virtual;
    /// direct conversion of an Unicode buffer into an Ansi Text
    procedure UnicodeBufferToAnsiVar(Source: PWideChar;
      SourceChars: cardinal; var Result: RawByteString); virtual;
    /// convert any Unicode-encoded String into Ansi Text
    // - internally calls UnicodeBufferToAnsi virtual method
    function UnicodeStringToAnsi(const Source: SynUnicode): RawByteString;
      {$ifdef HASINLINE}inline;{$endif}
    {$ifndef PUREMORMOT2}
    /// convert any Unicode-encoded String into Ansi Text
    // - internally calls UnicodeBufferToAnsi virtual method
    function RawUnicodeToAnsi(const Source: RawUnicode): RawByteString;
    {$endif PUREMORMOT2}
    /// direct conversion of an UTF-8 encoded buffer into a PAnsiChar buffer
    // - Dest^ buffer must be reserved with at least SourceChars bytes
    // - no #0 terminator is appended to the buffer
    function Utf8BufferToAnsi(Dest: PAnsiChar;
      Source: PUtf8Char; SourceChars: cardinal): PAnsiChar; overload; virtual;
    /// convert any UTF-8 encoded buffer into Ansi Text
    // - internally calls Utf8BufferToAnsi virtual method
    function Utf8BufferToAnsi(Source: PUtf8Char;
      SourceChars: cardinal): RawByteString; overload;
      {$ifdef HASINLINE}inline;{$endif}
    /// convert any UTF-8 encoded buffer into Ansi Text
    // - internally calls Utf8BufferToAnsi virtual method
    procedure Utf8BufferToAnsi(Source: PUtf8Char; SourceChars: cardinal;
      var result: RawByteString); overload; virtual;
    /// convert any UTF-8 encoded String into Ansi Text
    // - internally calls Utf8BufferToAnsi virtual method
    function Utf8ToAnsi(const u: RawUtf8): RawByteString; virtual;
    /// direct conversion of a UTF-8 encoded string into a WinAnsi <2KB buffer
    // - will truncate the destination string to DestSize bytes (including the
    // #0 terminator), with a maximum handled size of 2048 bytes
    // - returns the number of bytes stored in Dest^ (i.e. the position of #0)
    function Utf8ToAnsiBuffer2K(const S: RawUtf8;
      Dest: PAnsiChar; DestSize: integer): integer;
    /// convert any Ansi Text (providing a From converted) into Ansi Text
    function AnsiToAnsi(From: TSynAnsiConvert;
      const Source: RawByteString): RawByteString; overload;
    /// convert any Ansi buffer (providing a From converted) into Ansi Text
    function AnsiToAnsi(From: TSynAnsiConvert; Source: PAnsiChar;
      SourceChars: cardinal): RawByteString; overload;
    /// corresponding code page
    property CodePage: cardinal
      read fCodePage;
    /// corresponding length binary shift used for worst conversion case
    property AnsiCharShift: byte
      read fAnsiCharShift;
    /// detect complex MBCS asiatic charsets with escape codes
    // - e.g. CP_HZ with ~} ~{ or IEC-2022 with $1b ESC [I..] F
    // - i.e. to disable chars < $80 direct assignement optimization
    property AnsiCharMbcs: boolean
      read fAnsiCharMbcs;
  end;

  /// a class to handle Ansi to/from Unicode translation of fixed width encoding
  // - this class will handle efficiently all Code Page availables without MBCS
  // encoding - like WinAnsi (1252) or Russian (1251)
  // - it will use internal fast look-up tables for such encodings
  // - each instance will consume a bit more than 64 KB of memory
  // - this class has some additional methods (e.g. IsValid*) which take
  // advantage of the internal lookup tables to provide some fast process
  // - NEVER call Create() constructor directly: use the Engine() factory instead
  TSynAnsiFixedWidth = class(TSynAnsiConvert)
  protected
    fAnsiToWide: TWordDynArray;
    fWideToAnsi: TByteDynArray;
  public
    /// initialize the internal conversion engine
    // - NEVER call this constructor directly: use the Engine() factory instead
    constructor Create(aCodePage: cardinal); override;
    /// direct conversion of a PAnsiChar buffer into an Unicode buffer
    // - Dest^ buffer must be reserved with at least SourceChars*2 bytes
    // - will append a #0 terminator to the returned PWideChar, unless
    // NoTrailingZero is set
    function AnsiBufferToUnicode(Dest: PWideChar; Source: PAnsiChar;
      SourceChars: cardinal; NoTrailingZero: boolean = false): PWideChar; override;
    /// direct conversion of a PAnsiChar buffer into a UTF-8 encoded buffer
    // - Dest^ buffer must be reserved with at least SourceChars*3 bytes
    // - will append a #0 terminator to the returned PUtf8Char, unless
    // NoTrailingZero is set
    function AnsiBufferToUtf8(Dest: PUtf8Char; Source: PAnsiChar;
      SourceChars: cardinal; NoTrailingZero: boolean = false): PUtf8Char; override;
    {$ifndef PUREMORMOT2}
    /// convert any Ansi buffer into an Unicode String
    // - returns a value using our RawUnicode kind of string
    function AnsiToRawUnicode(Source: PAnsiChar;
      SourceChars: cardinal): RawUnicode; override;
    {$endif PUREMORMOT2}
    /// direct conversion of an Unicode buffer into a PAnsiChar buffer
    // - Dest^ buffer must be reserved with at least SourceChars * 3 bytes
    // - will detect and ignore any trailing UTF-16LE BOM marker
    // - this overridden version will use internal lookup tables for fast process
    function UnicodeBufferToAnsi(Dest: PAnsiChar;
      Source: PWideChar; SourceChars: cardinal): PAnsiChar; override;
    /// direct conversion of an UTF-8 encoded buffer into a PAnsiChar buffer
    // - Dest^ buffer must be reserved with at least SourceChars bytes
    // - no #0 terminator is appended to the buffer
    // - non Ansi compatible characters are replaced as '?'
    function Utf8BufferToAnsi(Dest: PAnsiChar; Source: PUtf8Char;
      SourceChars: cardinal): PAnsiChar; override;
    /// conversion of a wide char into the corresponding Ansi character
    // - return -1 for an unknown WideChar in the current code page
    function WideCharToAnsiChar(wc: cardinal): integer;
    /// return TRUE if the supplied unicode buffer only contains characters of
    // the corresponding Ansi code page
    // - i.e. if the text can be displayed using this code page
    function IsValidAnsi(WideText: PWideChar; Length: PtrInt): boolean; overload;
    /// return TRUE if the supplied unicode buffer only contains characters of
    // the corresponding Ansi code page
    // - i.e. if the text can be displayed using this code page
    function IsValidAnsi(WideText: PWideChar): boolean; overload;
    /// return TRUE if the supplied UTF-8 buffer only contains characters of
    // the corresponding Ansi code page
    // - i.e. if the text can be displayed using this code page
    function IsValidAnsiU(Utf8Text: PUtf8Char): boolean;
    /// return TRUE if the supplied UTF-8 buffer only contains 8-bit characters
    // of the corresponding Ansi code page
    // - i.e. if the text can be displayed with only 8-bit unicode characters
    // (e.g. no "tm" or such) within this code page
    function IsValidAnsiU8Bit(Utf8Text: PUtf8Char): boolean;
    /// direct access to the Ansi-To-Unicode lookup table
    // - use this array like AnsiToWide: array[byte] of word
    property AnsiToWide: TWordDynArray
      read fAnsiToWide;
    /// direct access to the UTF-16 to Ansi lookup table
    // - use this array like WideToAnsi: array[word] of byte
    // - any unhandled WideChar will return ord('?')
    property WideToAnsi: TByteDynArray
      read fWideToAnsi;
  end;

  /// a class to handle UTF-8 to/from Unicode translation
  // - this class is mostly a non-operation for conversion to/from UTF-8
  // - NEVER call Create() constructor directly: use the Engine() factory instead
  TSynAnsiUtf8 = class(TSynAnsiConvert)
  public
    /// initialize the internal conversion engine
    // - NEVER call this constructor directly: use the Engine() factory instead
    constructor Create(aCodePage: cardinal); override;
    /// direct conversion of a PAnsiChar UTF-8 buffer into an Unicode buffer
    // - Dest^ buffer must be reserved with at least SourceChars*2 bytes
    // - will append a #0 terminator to the returned PWideChar, unless
    // NoTrailingZero is set
    function AnsiBufferToUnicode(Dest: PWideChar; Source: PAnsiChar;
      SourceChars: cardinal; NoTrailingZero: boolean = false): PWideChar; override;
    /// direct conversion of a PAnsiChar UTF-8 buffer into a UTF-8 encoded buffer
    // - Dest^ buffer must be reserved with at least SourceChars*3 bytes
    // - will append a #0 terminator to the returned PUtf8Char, unless
    // NoTrailingZero is set
    function AnsiBufferToUtf8(Dest: PUtf8Char; Source: PAnsiChar;
      SourceChars: cardinal; NoTrailingZero: boolean = false): PUtf8Char; override;
    {$ifndef PUREMORMOT2}
    /// convert any UTF-8 Ansi buffer into an Unicode String
    // - returns a value using our RawUnicode kind of string
    function AnsiToRawUnicode(Source: PAnsiChar;
      SourceChars: cardinal): RawUnicode; override;
    {$endif PUREMORMOT2}
    /// direct conversion of an Unicode buffer into a PAnsiChar UTF-8 buffer
    // - will detect and ignore any trailing UTF-16LE BOM marker
    // - Dest^ buffer must be reserved with at least SourceChars * 3 bytes
    function UnicodeBufferToAnsi(Dest: PAnsiChar; Source: PWideChar;
      SourceChars: cardinal): PAnsiChar; override;
    /// direct conversion of an Unicode buffer into an Ansi Text
    procedure UnicodeBufferToAnsiVar(Source: PWideChar;
      SourceChars: cardinal; var Result: RawByteString); override;
    /// direct conversion of an UTF-8 encoded buffer into a PAnsiChar UTF-8 buffer
    // - Dest^ buffer must be reserved with at least SourceChars bytes
    // - no #0 terminator is appended to the buffer
    function Utf8BufferToAnsi(Dest: PAnsiChar; Source: PUtf8Char;
      SourceChars: cardinal): PAnsiChar; override;
    /// convert any UTF-8 encoded buffer into Ansi Text
    procedure Utf8BufferToAnsi(Source: PUtf8Char; SourceChars: cardinal;
      var result: RawByteString); override;
    /// convert any UTF-8 encoded String into Ansi Text
    // - directly assign the input as result, since no conversion is needed
    function Utf8ToAnsi(const u: RawUtf8): RawByteString; override;
    /// convert any Ansi Text into an UTF-8 encoded String
    // - directly assign the input as result, since no conversion is needed
    function AnsiToUtf8(const AnsiText: RawByteString): RawUtf8; override;
    /// direct conversion of a PAnsiChar buffer into a UTF-8 encoded string
    procedure AnsiBufferToRawUtf8(Source: PAnsiChar;
      SourceChars: cardinal; out Value: RawUtf8); override;
  end;

  /// a class to handle UTF-16 to/from Unicode translation
  // - even if UTF-16 is not an Ansi format, code page CP_UTF16 may have been
  // used to store UTF-16 encoded binary content
  // - this class is mostly a non-operation for conversion to/from Unicode
  // - NEVER call Create() constructor directly: use the Engine() factory instead
  TSynAnsiUtf16 = class(TSynAnsiConvert)
  public
    /// initialize the internal conversion engine
    // - NEVER call this constructor directly: use the Engine() factory instead
    constructor Create(aCodePage: cardinal); override;
    /// direct conversion of a PAnsiChar UTF-16 buffer into an Unicode buffer
    // - Dest^ buffer must be reserved with at least SourceChars*2 bytes
    // - will append a #0 terminator to the returned PWideChar, unless
    // NoTrailingZero is set
    function AnsiBufferToUnicode(Dest: PWideChar; Source: PAnsiChar;
      SourceChars: cardinal; NoTrailingZero: boolean = false): PWideChar; override;
    /// direct conversion of a PAnsiChar UTF-16 buffer into a UTF-8 encoded buffer
    // - Dest^ buffer must be reserved with at least SourceChars*3 bytes
    // - will append a #0 terminator to the returned PUtf8Char, unless
    // NoTrailingZero is set
    function AnsiBufferToUtf8(Dest: PUtf8Char; Source: PAnsiChar;
      SourceChars: cardinal; NoTrailingZero: boolean = false): PUtf8Char; override;
    {$ifndef PUREMORMOT2}
    /// convert any UTF-16 Ansi buffer into an Unicode String
    // - returns a value using our RawUnicode kind of string
    function AnsiToRawUnicode(Source: PAnsiChar;
      SourceChars: cardinal): RawUnicode; override;
    {$endif PUREMORMOT2}
    /// direct conversion of an Unicode buffer into a PAnsiChar UTF-16 buffer
    // - Dest^ buffer must be reserved with at least SourceChars * 3 bytes
    function UnicodeBufferToAnsi(Dest: PAnsiChar; Source: PWideChar;
      SourceChars: cardinal): PAnsiChar; override;
    /// direct conversion of an UTF-8 encoded buffer into a PAnsiChar UTF-16 buffer
    // - Dest^ buffer must be reserved with at least SourceChars bytes
    // - no #0 terminator is appended to the buffer
    function Utf8BufferToAnsi(Dest: PAnsiChar; Source: PUtf8Char;
      SourceChars: cardinal): PAnsiChar; override;
  end;

var
  /// global TSynAnsiConvert instance to handle WinAnsi encoding (code page 1252)
  // - this instance is global and created during this unit's initialization
  // - it will be created from hard-coded values, and not using the system API,
  // since it appeared that some systems (e.g. in Russia) did tweak the registry
  // so that 1252 code page maps 1251 code page
  WinAnsiConvert: TSynAnsiFixedWidth;

  /// global TSynAnsiConvert instance to handle current system encoding
  // - this instance is global and created during this unit's initialization
  // - this is the encoding as used by the AnsiString type, so will be used
  // before Delphi 2009 to speed-up RTL string handling (especially for UTF-8)
  CurrentAnsiConvert: TSynAnsiConvert;

  /// global TSynAnsiConvert instance to handle UTF-8 encoding (code page CP_UTF8)
  // - this instance is global and created during this unit's initialization
  Utf8AnsiConvert: TSynAnsiUtf8;

  /// global TSynAnsiConvert instance with no encoding (RawByteString/RawBlob)
  // - this instance is global and created during this unit's initialization
  RawByteStringConvert: TSynAnsiFixedWidth;


{ *************** Text File Loading with BOM/Unicode Support }

type
  /// text file layout, as returned by BomFile() and StringFromBomFile()
  // - bomNone means there was no BOM recognized (most common case, e.g. on POSIX)
  // - bomUtf16LE stands for UTF-16 Little-Endian encoding (as in Windows)
  // - bomUtf16BE stands for UTF-16 Big-Endian encoding (legacy/niche systems)
  // - bomUtf8 stands for a UTF-8 BOM (as on some Windows products)
  TBomFile = (
    bomNone,
    bomUtf16LE,
    bomUtf16BE,
    bomUtf8);

const
  /// UTF-8 BOM marker three bytes value, still common on Windows or CSV
  BOM_UTF8 = $bfbbef;
  /// UTF-16LE BOM WideChar marker, may appearing e.g. in some Windows files
  BOM_UTF16LE = #$feff;
  /// UTF-16BE BOM WideChar marker, seen only in legacy/niche systems
  BOM_UTF16BE = #$fffe;

/// check the file BOM at the beginning of a file buffer
// - BOM is common only with Microsoft products
// - returns bomNone if no BOM was recognized
// - returns bomUtf16LE or bomUtf8 if UTF-16LE or UTF-8 BOM were recognized:
// and will adjust Buffer/BufferSize to ignore the leading 2 or 3 bytes
function BomFile(var Buffer: pointer; var BufferSize: PtrInt): TBomFile;

/// read a file into a temporary variable, check the BOM, and adjust the buffer
// - bomUtf16LE and bomUtf16BE return BufferChars as WideChar count (not bytes)
function StringFromBomFile(const FileName: TFileName; var FileContent: RawByteString;
  out Buffer: pointer; out BufferChars: PtrInt): TBomFile;

/// read a File content into a RawUtf8, detecting any leading BOM
// - will assume text file with no BOM is already UTF-8 encoded
// - an alternative to StringFromFile() if you want to handle UTF-8 content
// and the files are likely to be natively UTF-8 encoded, or with a BOM
function RawUtf8FromFile(const FileName: TFileName): RawUtf8;
  {$ifdef HASINLINE} inline; {$endif}

/// read a File content into a RawUtf8, detecting any leading BOM
// - assume file with no BOM is encoded with the current Ansi code page, not
// UTF-8, unless AssumeUtf8IfNoBom is true and it behaves like RawUtf8FromFile()
function AnyTextFileToRawUtf8(const FileName: TFileName;
  AssumeUtf8IfNoBom: boolean = false): RawUtf8;

/// read a File content into a RTL string, detecting any leading BOM
// - assume file with no BOM is encoded with the current Ansi code page, not UTF-8
// - if ForceUtf8 is true, won't detect the BOM but assume whole file is UTF-8
function AnyTextFileToString(const FileName: TFileName;
  ForceUtf8: boolean = false): string;
  {$ifdef UNICODE} inline; {$endif}

/// read a File content into SynUnicode string, detecting any leading BOM
// - assume file with no BOM is encoded with the current Ansi code page, not UTF-8
// - if ForceUtf8 is true, won't detect the BOM but assume whole file is UTF-8
function AnyTextFileToSynUnicode(const FileName: TFileName;
  ForceUtf8: boolean = false): SynUnicode;


{ *************** Low-Level String Conversion Functions }

/// will fast replace all #0 chars as ~
// - could be used after UniqueRawUtf8() on a in-placed modified JSON buffer,
// in which all values have been ended with #0
// - you can optionally specify a maximum size, in bytes (this won't reallocate
// the string, but just add a #0 at some point in the UTF-8 buffer)
// - could allow logging of parsed input e.g. after an exception
procedure UniqueRawUtf8ZeroToTilde(var u: RawUtf8; MaxSize: PtrInt = maxInt);

/// convert a binary buffer into a fake ASCII/UTF-8 content without any #0 input
// - will use ~ char to escape any #0 as ~0 pair (and plain ~ as ~~ pair)
// - output is just a bunch of non 0 bytes, so not trully valid UTF-8 content
// - may be used as an alternative to Base64 encoding if 8-bit chars are allowed
// - call ZeroedRawUtf8() as reverse function
function UnZeroed(const bin: RawByteString): RawUtf8;

/// convert a fake UTF-8 buffer without any #0 input back into its original binary
// - may be used as an alternative to Base64 decoding if 8-bit chars are allowed
// - call UnZeroedRawUtf8() as reverse function
function Zeroed(const u: RawUtf8): RawByteString;

/// conversion of a wide char into a WinAnsi (CodePage 1252) char
// - return '?' for an unknown WideChar in code page 1252
function WideCharToWinAnsiChar(wc: cardinal): AnsiChar;
  {$ifdef HASINLINE}inline;{$endif}

/// conversion of a wide char into a WinAnsi (CodePage 1252) char index
// - return -1 for an unknown WideChar in code page 1252
function WideCharToWinAnsi(wc: cardinal): integer;
  {$ifdef HASINLINE}inline;{$endif}

/// return TRUE if the supplied unicode buffer only contains WinAnsi characters
// - i.e. if the text can be displayed using ANSI_CHARSET
function IsWinAnsi(WideText: PWideChar): boolean; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// return TRUE if the supplied unicode buffer only contains WinAnsi characters
// - i.e. if the text can be displayed using ANSI_CHARSET
function IsWinAnsi(WideText: PWideChar; Length: integer): boolean; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// return TRUE if the supplied UTF-8 buffer only contains WinAnsi characters
// - i.e. if the text can be displayed using ANSI_CHARSET
function IsWinAnsiU(Utf8Text: PUtf8Char): boolean;
  {$ifdef HASINLINE}inline;{$endif}

/// return TRUE if the supplied UTF-8 buffer only contains WinAnsi 8-bit characters
// - i.e. if the text can be displayed using ANSI_CHARSET with only 8-bit unicode
// characters (e.g. no "tm" or such)
function IsWinAnsiU8Bit(Utf8Text: PUtf8Char): boolean;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of an AnsiString with an unknown code page into an
// UTF-8 encoded String, as mainly used by VariantToUtf8() or VarRecToUtf8()
// - FPC and Unicode versions of Delphi will retrieve the code page from s
// - Delphi 7/2007 calls IsValidUtf8() then assume CurrentAnsiConvert.CodePage
procedure AnyAnsiToUtf8Var(const s: RawByteString; var result: RawUtf8);

/// direct conversion of an AnsiString with an unknown code page into an
// UTF-8 encoded String
// - FPC and Unicode versions of Delphi will retrieve the code page from s
// - Delphi 7/2007 calls IsValidUtf8() then assume CurrentAnsiConvert.CodePage
// - use AnsiToUtf8() if you want to specify the codepage
function AnyAnsiToUtf8(const s: RawByteString): RawUtf8;
  {$ifdef HASINLINE}inline;{$endif}

/// convert an AnsiString (of a given code page) into a UTF-8 string
// - use AnyAnsiToUtf8() if you want to use the codepage of the input string
// - wrapper around TSynAnsiConvert.Engine(CodePage).AnsiToUtf8()
function AnsiToUtf8(const Ansi: RawByteString; CodePage: integer): RawUtf8;
  {$ifdef HASINLINE}inline;{$endif}

/// convert an AnsiChar buffer (of a given code page) into a UTF-8 string
// - the destination code page should be supplied
// - wrapper around TSynAnsiConvert.Engine(CodePage).AnsiBufferToRawUtf8()
procedure AnsiCharToUtf8(P: PAnsiChar; L: integer; var result: RawUtf8;
  CodePage: integer);
  {$ifdef HASINLINE}inline;{$endif}

/// convert an AnsiString (of a given code page) into a RTL string
// - the destination code page should be supplied
// - wrapper around TSynAnsiConvert.Engine(CodePage) and string conversion
function AnsiToString(const Ansi: RawByteString; CodePage: integer): string;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a WinAnsi (CodePage 1252) string into a UTF-8 encoded String
// - faster than SysUtils: don't use Utf8Encode(WideString) -> no Windows.Global(),
// and use a fixed pre-calculated array for individual chars conversion
function WinAnsiToUtf8(const S: WinAnsiString): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a WinAnsi (CodePage 1252) string into a UTF-8 encoded String
// - faster than SysUtils: don't use Utf8Encode(WideString) -> no Windows.Global(),
// and use a fixed pre-calculated array for individual chars conversion
function WinAnsiToUtf8(WinAnsi: PAnsiChar; WinAnsiLen: PtrInt): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a WinAnsi PAnsiChar buffer into a UTF-8 encoded buffer
// - Dest^ buffer must be reserved with at least SourceChars*3
// - call internally WinAnsiConvert fast conversion class
function WinAnsiBufferToUtf8(Dest: PUtf8Char;
  Source: PAnsiChar; SourceChars: cardinal): PUtf8Char;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a WinAnsi ShortString into a UTF-8 text
// - call internally WinAnsiConvert fast conversion class
function ShortStringToUtf8(const source: ShortString): RawUtf8;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a WinAnsi (CodePage 1252) string into a Unicode buffer
// - very fast, by using a fixed pre-calculated array for individual chars conversion
// - text will be truncated if necessary to avoid buffer overflow in Dest[]
procedure WinAnsiToUnicodeBuffer(const S: WinAnsiString;
  Dest: PWordArray; DestLen: PtrInt);
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a UTF-8 encoded string into a WinAnsi String
function Utf8ToWinAnsi(const S: RawUtf8): WinAnsiString; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a UTF-8 encoded zero terminated buffer into a WinAnsi String
function Utf8ToWinAnsi(P: PUtf8Char): WinAnsiString; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a UTF-8 encoded zero terminated buffer into a RawUtf8 String
procedure Utf8ToRawUtf8(P: PUtf8Char; var result: RawUtf8);
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a UTF-8 encoded buffer into a WinAnsi PAnsiChar buffer
function Utf8ToWinPChar(dest: PAnsiChar; source: PUtf8Char; count: integer): integer;
  {$ifdef HASINLINE}inline;{$endif}

{$ifndef PUREMORMOT2}
/// direct conversion of a WinAnsi (CodePage 1252) string into a Unicode encoded String
// - very fast, by using a fixed pre-calculated array for individual chars conversion
function WinAnsiToRawUnicode(const S: WinAnsiString): RawUnicode;

/// convert a UTF-16 string into a WinAnsi (code page 1252) string
function RawUnicodeToWinAnsi(const Unicode: RawUnicode): WinAnsiString; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert a UTF-8 encoded buffer into a RawUnicode string
// - if L is 0, L is computed from zero terminated P buffer
// - RawUnicode is ended by a WideChar(#0)
// - faster than System.Utf8Decode() which uses slow widestrings
function Utf8DecodeToRawUnicode(P: PUtf8Char; L: integer): RawUnicode; overload;

/// convert a UTF-8 string into a RawUnicode string
function Utf8DecodeToRawUnicode(const S: RawUtf8): RawUnicode; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert a UTF-8 string into a RawUnicode string
// - this version doesn't resize the length of the result RawUnicode
// and is therefore useful before a Win32 Unicode API call (with nCount=-1)
// - if DestLen is not nil, the resulting length (in bytes) will be stored within
// - see also Utf8DecodeToUnicode() which uses a TSynTempBuffer for storage
function Utf8DecodeToRawUnicodeUI(const S: RawUtf8;
  DestLen: PInteger = nil): RawUnicode; overload;

/// convert a UTF-8 string into a RawUnicode string
// - returns the resulting length (in bytes) will be stored within Dest
// - see also Utf8DecodeToUnicode() which uses a TSynTempBuffer for storage
function Utf8DecodeToRawUnicodeUI(const S: RawUtf8;
  var Dest: RawUnicode): integer; overload;

/// convert a RawUnicode string into a UTF-8 string
function RawUnicodeToUtf8(const Unicode: RawUnicode): RawUtf8; overload;

/// convert any RawUnicode String into a generic SynUnicode Text
function RawUnicodeToSynUnicode(const Unicode: RawUnicode): SynUnicode; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any RTL string into a RawUnicode encoded String
// - it's prefered to use TLanguageFile.StringToUtf8() method in mORMoti18n,
// which will handle full i18n of your application
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
function StringToRawUnicode(const S: string): RawUnicode; overload;

/// convert any RTL string into a RawUnicode encoded String
// - it's prefered to use TLanguageFile.StringToUtf8() method in mORMoti18n,
// which will handle full i18n of your application
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
function StringToRawUnicode(P: PChar; L: integer): RawUnicode; overload;

/// convert any RawUnicode encoded string into a RTL string
// - uses StrLenW() and not length(U) to handle case when was used as buffer
function RawUnicodeToString(const U: RawUnicode): string; overload;
{$endif PUREMORMOT2}

/// convert a SynUnicode string into a UTF-8 string
function SynUnicodeToUtf8(const Unicode: SynUnicode): RawUtf8;

/// convert a WideString into a UTF-8 string
function WideStringToUtf8(const aText: WideString): RawUtf8;
  {$ifdef HASINLINE}inline;{$endif}

/// direct conversion of a UTF-16 encoded buffer into a WinAnsi PAnsiChar buffer
procedure RawUnicodeToWinPChar(dest: PAnsiChar;
  source: PWideChar; WideCharCount: integer);
  {$ifdef HASINLINE}inline;{$endif}

/// convert a UTF-16 PWideChar buffer into a WinAnsi (code page 1252) string
function RawUnicodeToWinAnsi(
  WideChar: PWideChar; WideCharCount: integer): WinAnsiString; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert a WideString into a WinAnsi (code page 1252) string
function WideStringToWinAnsi(const Wide: WideString): WinAnsiString;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any UTF-16 buffer into a generic SynUnicode Text
function RawUnicodeToSynUnicode(
  WideChar: PWideChar; WideCharCount: integer): SynUnicode; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert an Unicode buffer into a WinAnsi (code page 1252) string
procedure UnicodeBufferToWinAnsi(source: PWideChar; out Dest: WinAnsiString);

/// convert an Unicode buffer into a RTL string
function UnicodeBufferToString(source: PWideChar): string;

/// convert an Unicode buffer into a UTF-8 string
function UnicodeBufferToUtf8(source: PWideChar): RawUtf8;
  {$ifdef HASINLINE} inline; {$endif}

/// convert an Unicode buffer into a UTF-8 string, trimmed with all spaces
function UnicodeBufferTrimmedToUtf8(source: PWideChar): RawUtf8;

/// convert an Unicode buffer into a variant storing a UTF-8 string
// - could be used e.g. as TDocVariantData.AddValue() parameter
function UnicodeBufferToVariant(source: PWideChar): variant;

/// convert any RTL string into a variant storing a UTF-8 string
// - could be used e.g. as TDocVariantData.AddValue() parameter
function StringToVariant(const Txt: string): variant; overload;

/// convert any RTL string into a variant storing a UTF-8 string
// - could be used e.g. as TDocVariantData.AddValue() parameter
procedure StringToVariant(const Txt: string; var result: variant); overload;

{$ifdef HASVARUSTRING}

/// convert a Delphi 2009+ or FPC Unicode string into our UTF-8 string
function UnicodeStringToUtf8(const S: UnicodeString): RawUtf8; inline;

// this function is the same as direct RawUtf8=AnsiString(CP_UTF8) assignment
// but is faster, since it uses no Win32 API call
function Utf8DecodeToUnicodeString(const S: RawUtf8): UnicodeString; overload; inline;

/// convert an UTF-8 encoded buffer into a Delphi 2009+ or FPC Unicode string
// - this function is the same as direct assignment, since RawUtf8=AnsiString(CP_UTF8),
// but is faster, since use no Win32 API call
procedure Utf8DecodeToUnicodeString(P: PUtf8Char; L: integer;
  var result: UnicodeString); overload;

/// convert a Delphi 2009+ or FPC Unicode string into a WinAnsi (code page 1252) string
function UnicodeStringToWinAnsi(const S: UnicodeString): WinAnsiString; inline;

/// convert our UTF-8 encoded buffer into a Delphi 2009+ or FPC Unicode string
// - this function is the same as direct assignment, since RawUtf8=AnsiString(CP_UTF8),
// but is faster, since use no Win32 API call
function Utf8DecodeToUnicodeString(P: PUtf8Char; L: integer): UnicodeString; overload; inline;

/// convert a Win-Ansi encoded buffer into a Delphi 2009+ or FPC Unicode string
// - this function is faster than default RTL, since use no Win32 API call
function WinAnsiToUnicodeString(WinAnsi: PAnsiChar; WinAnsiLen: PtrInt): UnicodeString; overload;

/// convert a Win-Ansi string into a Delphi 2009+ or FPC Unicode string
// - this function is faster than default RTL, since use no Win32 API call
function WinAnsiToUnicodeString(const WinAnsi: WinAnsiString): UnicodeString; inline; overload;

{$endif HASVARUSTRING}

/// convert an UTF-8 encoded buffer into a UTF-16 encoded RawByteString buffer
// - could be used instead of deprecated RawUnicode when a temp UTF-16 buffer is needed
function Utf8DecodeToUnicodeRawByteString(P: PUtf8Char; L: integer): RawByteString; overload;

/// convert an UTF-8 encoded buffer into a UTF-16 encoded RawByteString buffer
// - could be used instead of deprecated RawUnicode when a temp UTF-16 buffer is needed
function Utf8DecodeToUnicodeRawByteString(const U: RawUtf8): RawByteString; overload;

/// convert an UTF-8 encoded buffer into a UTF-16 encoded stream of bytes
function Utf8DecodeToUnicodeStream(P: PUtf8Char; L: integer): TStream;

/// convert a Win-Ansi encoded buffer into a Delphi 2009+ or FPC Unicode string
// - this function is faster than default RTL, since use no Win32 API call
function WinAnsiToSynUnicode(WinAnsi: PAnsiChar; WinAnsiLen: PtrInt): SynUnicode; overload;

/// convert a Win-Ansi string into a Delphi 2009+ or FPC Unicode string
// - this function is faster than default RTL, since use no Win32 API call
function WinAnsiToSynUnicode(const WinAnsi: WinAnsiString): SynUnicode;
  {$ifdef HASINLINE}inline;{$endif} overload;

/// convert any RTL string into an UTF-8 encoded String
// - in the VCL context, it's prefered to use TLanguageFile.StringToUtf8()
//  method from mORMoti18n, which will handle full i18n of your application
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
function StringToUtf8(const Text: string): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any RTL string buffer into an UTF-8 encoded String
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
procedure StringToUtf8(Text: PChar; TextLen: PtrInt; var result: RawUtf8); overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any RTL string into an UTF-8 encoded String
// - this overloaded function use a faster by-reference parameter for the result
procedure StringToUtf8(const Text: string; var result: RawUtf8); overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any RTL string into an UTF-8 encoded String
function ToUtf8(const Text: string): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any RTL string into an UTF-8 encoded TSynTempBuffer
// - returns the number of UTF-8 bytes available in Temp.buf
// - this overloaded function use a TSynTempBuffer for the result to avoid any
// memory allocation for the shorter content
// - caller should call Temp.Done to release any heap-allocated memory
function StringToUtf8(const Text: string; var Temp: TSynTempBuffer): integer; overload;

/// convert any Ansi memory buffer into UTF-8, using a TSynTempBuffer if needed
// - caller should release any memory by calling Temp.Done
// - returns a pointer to the UTF-8 converted buffer - which may be buf
function AnsiBufferToTempUtf8(var Temp: TSynTempBuffer;
  Buf: PAnsiChar; BufLen, CodePage: cardinal): PUtf8Char;

/// convert any UTF-8 encoded ShortString Text into an UTF-8 encoded String
// - expects the supplied content to be already ASCII-7 or UTF-8 encoded, e.g.
// a RTTI type or property name: it won't work with Ansi-encoded strings
function ToUtf8(const Ansi7Text: ShortString): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any RTL string buffer into an UTF-8 encoded buffer
// - Dest must be able to receive at least SourceChars*3 bytes
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
function StringBufferToUtf8(Dest: PUtf8Char;
  Source: PChar; SourceChars: PtrInt): PUtf8Char; overload;

/// convert any RTL string 0-terminated Text buffer into an UTF-8 string
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
procedure StringBufferToUtf8(Source: PChar; out result: RawUtf8); overload;

/// convert any RTL string into a SynUnicode encoded String
// - it's prefered to use TLanguageFile.StringToUtf8() method in mORMoti18n,
// which will handle full i18n of your application
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
function StringToSynUnicode(const S: string): SynUnicode; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any RTL string into a SynUnicode encoded String
// - overloaded to avoid a copy to a temporary result string of a function
procedure StringToSynUnicode(const S: string; var result: SynUnicode); overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any UTF-16 encoded buffer into a RTL string
function RawUnicodeToString(P: PWideChar; L: integer): string; overload;

/// convert any UTF-16 encoded buffer into a RTL string
procedure RawUnicodeToString(P: PWideChar; L: integer; var result: string); overload;

/// convert any SynUnicode encoded string into a RTL string
function SynUnicodeToString(const U: SynUnicode): string;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any UTF-8 encoded String into a RTL string
// - it's prefered to use TLanguageFile.Utf8ToString() in mORMoti18n,
// which will handle full i18n of your application
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
function Utf8ToString(const Text: RawUtf8): string;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any UTF-8 encoded String into a RTL string
procedure Utf8ToStringVar(const Text: RawUtf8; var result: string);

/// convert any UTF-8 encoded String into a generic RTL file name string
procedure Utf8ToFileName(const Text: RawUtf8; var result: TFileName);

/// convert any UTF-8 encoded buffer into a RTL string
// - it's prefered to use TLanguageFile.Utf8ToString() in mORMoti18n,
// which will handle full i18n of your application
// - it will work as is with Delphi 2009+ (direct unicode conversion)
// - under older version of Delphi (no unicode), it will use the
// current RTL codepage, as with WideString conversion (but without slow
// WideString usage)
function Utf8DecodeToString(P: PUtf8Char; L: integer): string; overload;
  {$ifdef UNICODE}inline;{$endif}

/// convert any UTF-8 encoded buffer into a RTL string
procedure Utf8DecodeToString(P: PUtf8Char; L: integer; var result: string); overload;

/// convert any UTF-8 encoded String into a generic WideString Text
function Utf8ToWideString(const Text: RawUtf8): WideString; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any UTF-8 encoded String into a generic WideString Text
procedure Utf8ToWideString(const Text: RawUtf8; var result: WideString); overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any UTF-8 encoded String into a generic WideString Text
procedure Utf8ToWideString(Text: PUtf8Char; Len: PtrInt; var result: WideString); overload;

/// convert any UTF-8 encoded String into a generic SynUnicode Text
function Utf8ToSynUnicode(const Text: RawUtf8): SynUnicode; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any UTF-8 encoded String into a generic SynUnicode Text
procedure Utf8ToSynUnicode(const Text: RawUtf8; var result: SynUnicode); overload;

/// convert any UTF-8 encoded buffer into a generic SynUnicode Text
procedure Utf8ToSynUnicode(Text: PUtf8Char; Len: PtrInt; var result: SynUnicode); overload;

/// convert any UTF-8 encoded string into an UTF-16 temporary buffer
// - returns the number of WideChar stored in temp (not bytes)
// - caller should make temp.Done after temp.buf has been used
function Utf8DecodeToUnicode(const Text: RawUtf8; var temp: TSynTempBuffer): PtrInt; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any UTF-8 encoded buffer into an UTF-16 temporary buffer
function Utf8DecodeToUnicode(Text: PUtf8Char; Len: PtrInt; var temp: TSynTempBuffer): PtrInt; overload;

/// convert any Ansi 7-bit encoded String into a RTL string
// - the Text content must contain only 7-bit pure ASCII characters
function Ansi7ToString(const Text: RawByteString): string; overload;
  {$ifndef UNICODE}{$ifdef HASINLINE}inline;{$endif}{$endif}

/// convert any Ansi 7-bit encoded String into a RTL string
// - the Text content must contain only 7-bit pure ASCII characters
function Ansi7ToString(Text: PWinAnsiChar; Len: PtrInt): string; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert any Ansi 7-bit encoded String into a RTL string
// - the Text content must contain only 7-bit pure ASCII characters
procedure Ansi7ToString(Text: PWinAnsiChar; Len: PtrInt; var result: string); overload;

/// convert any RTL string into Ansi 7-bit encoded String
// - the Text content must contain only 7-bit pure ASCII characters
function StringToAnsi7(const Text: string): RawByteString;
  {$ifndef UNICODE}{$ifdef HASINLINE}inline;{$endif}{$endif}

/// convert any RTL string into WinAnsi (Win-1252) 8-bit encoded String
function StringToWinAnsi(const Text: string): WinAnsiString;
  {$ifdef UNICODE}inline;{$endif}


{ **************** Text Case-(in)sensitive Conversion and Comparison }

type
  /// lookup table used for fast case conversion
  TNormTable = TAnsiCharToAnsiChar;
  /// pointer to a lookup table used for fast case conversion
  PNormTable = ^TNormTable;

  /// lookup table used for fast case conversion
  TNormTableByte = TByteToByte;
  /// pointer to a lookup table used for fast case conversion
  PNormTableByte = ^TNormTableByte;

  /// type of a lookup table used for fast XML/HTML conversion or UTF-8 lookup
  TAnsiCharToByte = array[AnsiChar] of byte;
  PAnsiCharToByte = ^TAnsiCharToByte;

var
  /// lookup table used for fast case conversion to uppercase
  // - handle 8-bit upper chars as in WinAnsi / code page 1252 (e.g. 'e' or 'E'
  // with or without accents will be translated into plain 'E' without accent)
  // - is defined globally, since may be used from an inlined function
  NormToUpper: TNormTable;
  NormToUpperByte: TNormTableByte absolute NormToUpper;

  /// lookup table used for fast case conversion to lowercase
  // - handle 8-bit upper chars as in WinAnsi / code page 1252 (e.g. 'e' or 'E'
  // with or without accents will be translated into plain 'e' without accent)
  // - is defined globally, since may be used from an inlined function
  NormToLower: TNormTable;
  NormToLowerByte: TNormTableByte absolute NormToLower;

  /// this table will convert 'a'..'z' into 'A'..'Z'
  // - so it will work with UTF-8 without decoding, whereas NormToUpper[]
  // expects WinAnsi encoding to handle accents
  NormToUpperAnsi7: TNormTable;
  NormToUpperAnsi7Byte: TNormTableByte absolute NormToUpperAnsi7;

  /// this table will convert 'A'..'Z' into 'a'..'z'
  // - so it will work with UTF-8 without decoding, whereas NormToLower[]
  // expects WinAnsi encoding to handle accents
  NormToLowerAnsi7: TNormTable;
  NormToLowerAnsi7Byte: TNormTableByte absolute NormToLowerAnsi7;

  /// case sensitive NormToUpper[]/NormToLower[]-like table
  // - i.e. every item is itself, as NormToNorm[c] = c
  NormToNorm: TNormTable;
  NormToNormByte: TNormTableByte absolute NormToNorm;

const
  NORM2CASE: array[boolean] of PNormTable = (nil, @NormToUpperAnsi7);

type
  /// character categories for text linefeed/word/identifier/uri parsing
  // - using such a set compiles into TEST [MEM], IMM so is more efficient
  // than a regular set of AnsiChar which generates much slower BT [MEM], IMM
  // - the same 256-byte memory will also be reused from L1 CPU cache
  // during the parsing of complex input
  TTextChar = set of (
    tcNot01013,
    tc1013,
    tcCtrlNotLF,
    tcCtrlNot0Comma,
    tcWord,
    tcIdentifierFirstChar,
    tcIdentifier,
    tcUriUnreserved);

  /// defines an AnsiChar lookup table used for branch-less text parsing
  TTextCharSet = array[AnsiChar] of TTextChar;
  /// points to an AnsiChar lookup table used for branch-less text parsing
  PTextCharSet = ^TTextCharSet;

  /// defines an Ordinal lookup table used for branch-less text parsing
  TTextByteSet = array[byte] of TTextChar;
  /// points to an Ordinal lookup table used for branch-less text parsing
  PTextByteSet = ^TTextByteSet;

var
  /// lookup table for text linefeed/word/identifier/uri branch-less parsing
  TEXT_CHARS: TTextCharSet;
  TEXT_BYTES: TTextByteSet absolute TEXT_CHARS;

/// returns TRUE if the given text buffer contains a..z,A..Z,0..9,_ characters
// - should match most usual property names values or other identifier names
// in the business logic source code
// - i.e. can be tested via IdemPropName*() functions, and the MongoDB-like
// extended JSON syntax as generated by dvoSerializeAsExtendedJson
// - following classic pascal naming convention, first char must be alphabetical
// or '_' (i.e. not a digit), following chars can be alphanumerical or '_'
function PropNameValid(P: PUtf8Char): boolean;

/// returns TRUE if the given text buffers contains A..Z,0..9,_ characters
// - use it with property names values (i.e. only including A..Z,0..9,_ chars)
// - this function allows numbers as first char, so won't check the first char
// the same way than PropNameValid() which refuses digits as pascal convention
function PropNamesValid(const Values: array of RawUtf8): boolean;

/// try to generate a PropNameValid() output from an incoming text
// - will trim all spaces, and replace most special chars by '_'
// - if it is not PropNameValid() after those replacements, will return fallback
function PropNameSanitize(const text, fallback: RawUtf8): RawUtf8;

/// case insensitive comparison of ASCII 7-bit identifiers
// - use it with property names values (i.e. only including A..Z,0..9,_ chars)
// - behavior is undefined with UTF-8 encoding (some false positive may occur)
function IdemPropName(const P1, P2: ShortString): boolean; overload;
  {$ifdef HASINLINE}inline;{$endif}

  /// case insensitive comparison of ASCII 7-bit identifiers
  // - use it with property names values (i.e. only including A..Z,0..9,_ chars)
  // - behavior is undefined with UTF-8 encoding (some false positive may occur)
function IdemPropName(const P1: ShortString; P2: PUtf8Char; P2Len: PtrInt): boolean; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// case insensitive comparison of ASCII 7-bit identifiers
// - use it with property names values (i.e. only including A..Z,0..9,_ chars)
// - behavior is undefined with UTF-8 encoding (some false positive may occur)
// - this version expects P1 and P2 to be a PAnsiChar with specified lengths
function IdemPropName(P1, P2: PUtf8Char; P1Len, P2Len: PtrInt): boolean; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// case insensitive comparison of ASCII 7-bit identifiers
// - use it with property names values (i.e. only including A..Z,0..9,_ chars)
// - behavior is undefined with UTF-8 encoding (some false positive may occur)
// - this version expects P2 to be a PAnsiChar with specified length
function IdemPropNameU(const P1: RawUtf8; P2: PUtf8Char; P2Len: PtrInt): boolean; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// case insensitive comparison of ASCII 7-bit identifiers of same length
// - use it with property names values (i.e. only including A..Z,0..9,_ chars)
// - behavior is undefined with UTF-8 encoding (some false positive may occur)
// - this version expects P1 and P2 to be a PAnsiChar with an already checked
// identical length, so may be used for a faster process, e.g. in a loop
// - if P1 and P2 are RawUtf8, you should better call overloaded function
// IdemPropNameU(const P1,P2: RawUtf8), which would be slightly faster by
// using the length stored before the actual text buffer of each RawUtf8
function IdemPropNameUSameLenNotNull(P1, P2: PUtf8Char; P1P2Len: PtrInt): boolean;
  {$ifdef FPC}inline;{$endif} // Delphi does not like to inline goto

type
  TIdemPropNameUSameLen = function(P1, P2: pointer; P1P2Len: PtrInt): boolean;

var
  /// case (in)sensitive comparison of ASCII 7-bit identifiers of same length
  IdemPropNameUSameLen: array[{casesensitive=}boolean] of TIdemPropNameUSameLen;

/// case insensitive comparison of ASCII 7-bit identifiers
// - use it with property names values (i.e. only including A..Z,0..9,_ chars)
// - behavior is undefined with UTF-8 encoding (some false positive may occur)
// - is an alternative with PropNameEquals() to be used inlined e.g. in a loop
function IdemPropNameU(const P1, P2: RawUtf8): boolean; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// returns true if the beginning of p^ is the same as up^
// - ignore case - up^ must be already Upper
// - chars are compared as 7-bit Ansi only (no accentuated characters): but when
// you only need to search for field names e.g. IdemPChar() is prefered, because
// it'll be faster than IdemPCharU(), if UTF-8 decoding is not mandatory
// - if p is nil, will return FALSE
// - if up is nil, will return TRUE
function IdemPChar(p: PUtf8Char; up: PAnsiChar): boolean; overload;

/// returns true if the beginning of p^ is the same as up^
// - this overloaded function accept the uppercase lookup buffer as parameter
function IdemPChar(p: PUtf8Char; up: PAnsiChar; table: PNormTable): boolean; overload;

/// returns true if the beginning of p^ is the same as up^, ignoring white spaces
// - ignore case - up^ must be already Upper
// - any white space in the input p^ buffer is just ignored
// - chars are compared as 7-bit Ansi only (no accentuated characters): but when
// you only need to search for field names e.g. IdemPChar() is prefered, because
// it'll be faster than IdemPCharU(), if UTF-8 decoding is not mandatory
// - if p is nil, will return FALSE
// - if up is nil, will return TRUE
function IdemPCharWithoutWhiteSpace(p: PUtf8Char; up: PAnsiChar): boolean;

/// returns the index of a matching beginning of p^ in upArray[]
// - returns -1 if no item matched
// - ignore case - upArray^ must be already Upper
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
// - warning: this function expects upArray[] items to have AT LEAST TWO
// CHARS (it will use a fast 16-bit comparison of initial 2 bytes)
// - consider IdemPPChar() which is faster but a bit more verbose
function IdemPCharArray(p: PUtf8Char; const upArray: array of PAnsiChar): integer;

/// returns the index of a matching beginning of p^ in nil-terminated up^ array
// - returns -1 if no item matched
// - ignore case - each up^ must be already Upper
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
// - warning: this function expects up^ items to have AT LEAST TWO CHARS
// (it will use a fast 16-bit comparison of initial 2 bytes)
function IdemPPChar(p: PUtf8Char; up: PPAnsiChar): PtrInt;

/// returns the index of a matching beginning of p^ in '|' separated up^ array
// - returns -1 if no item matched
// - ignore case - up^ must be already Upper, delimited AND ENDED with '|'
// !  IdemPCharSep('tWo', 'ZERO|ONE|TWO|THREE|') = 2
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
// - warning: this function expects up^ items to have AT LEAST TWO CHARS
// (it will use a fast 16-bit comparison of initial 2 bytes)
// - slightly faster than IdemPPChar() since has better CPU L1 cache locality
function IdemPCharSep(p, up: PUtf8Char): PtrInt;

/// returns the index of a matching beginning of p^ in upArray two characters
// - returns -1 if no item matched
// - ignore case - upArray^ must be already Upper
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
function IdemPCharArrayBy2(p: PUtf8Char; const upArrayBy2Chars: RawUtf8): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// returns true if the beginning of p^ is the same as up^
// - ignore case - up^ must be already Upper
// - this version will decode the UTF-8 content before using NormToUpper[], so
// it will be slower than the IdemPChar() function above, but will handle
// WinAnsi accentuated characters (e.g. 'e' acute will be matched as plain 'E')
function IdemPCharU(p, up: PUtf8Char): boolean;

/// returns true if the beginning of p^ is same as up^
// - ignore case - up^ must be already Upper
// - this version expects p^ to point to an Unicode char array
function IdemPCharW(p: PWideChar; up: PUtf8Char): boolean;

/// check case-insensitive matching starting of text in upTextStart
// - returns true if the item matched
// - ignore case - upTextStart must be already in upper case
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
// - see StartWithExact() from this unit for a case-sensitive version
function StartWith(const text, upTextStart: RawUtf8): boolean;

/// check case-insensitive matching ending of text in upTextEnd
// - returns true if the item matched
// - ignore case - upTextEnd must be already in upper case
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
// - see EndWithExact() from this unit for a case-sensitive version
function EndWith(const text, upTextEnd: RawUtf8): boolean;

/// returns the index of a case-insensitive matching ending of p^ in upArray[]
// - returns -1 if no item matched
// - ignore case - upArray[] items must be already in upper case
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
function EndWithArray(const text: RawUtf8; const upArray: array of RawUtf8): integer;

/// returns true if the file name extension contained in p^ is the same same as extup^
// - ignore case - extup^ must be already Upper
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
// - could be used e.g. like IdemFileExt(aFileName,'.JP');
function IdemFileExt(p: PUtf8Char; extup: PAnsiChar; sepChar: AnsiChar = '.'): boolean;

/// returns matching file name extension index as extup^
// - ignore case - extup[] must be already Upper
// - chars are compared as 7-bit Ansi only (no accentuated chars, nor UTF-8)
// - could be used e.g. like IdemFileExts(aFileName,['.PAS','.INC']);
function IdemFileExts(p: PUtf8Char; const extup: array of PAnsiChar;
  sepChar: AnsiChar = '.'): integer;

/// fast retrieve the position of any value of a given set of characters
// - see also strspn() function which is likely to be faster
function PosCharAny(Str: PUtf8Char; Characters: PAnsiChar): PUtf8Char;

/// a non case-sensitive RawUtf8 version of Pos()
// - uppersubstr is expected to be already in upper case
// - this version handle only 7-bit ASCII (no accentuated characters)
// - see PosIU() if you want an UTF-8 version with WinAnsi accents support
function PosI(uppersubstr: PUtf8Char; const str: RawUtf8): PtrInt;

/// a non case-sensitive version of Pos()
// - uppersubstr is expected to be already in upper case
// - this version handle only 7-bit ASCII (no accentuated characters)
function StrPosI(uppersubstr, str: PUtf8Char): PUtf8Char;

/// a non case-sensitive RawUtf8 version of Pos()
// - substr is expected to be already in upper case
// - this version will decode the UTF-8 content before using NormToUpper[],
// and will remove WinAnsi (Code Page 1252) accents during its search
// - see PosI() for a non-accentuated, but faster version
function PosIU(substr: PUtf8Char; const str: RawUtf8): integer;

/// pure pascal version of strspn(), to be used with PUtf8Char/PAnsiChar
// - returns size of initial segment of s which appears in accept chars, e.g.
// ! strspn('abcdef','debca')=5
// - please note that this optimized version may read up to 3 bytes beyond
// accept but never after s end, so is safe e.g. over memory mapped files
function strspn(s, accept: pointer): integer;

/// pure pascal version of strcspn(), to be used with PUtf8Char/PAnsiChar
// - returns size of initial segment of s which doesn't appears in reject chars, e.g.
// ! strcspn('1234,6789',',')=4
// - please note that this optimized version may read up to 3 bytes beyond
// reject but never after s end, so is safe e.g. over memory mapped files
function strcspn(s, reject: pointer): integer;

/// our fast version of StrCompL(), to be used with PUtf8Char
// - i.e. make a binary comparison of two memory buffers, using supplied length
// - Default value is returned if both P1 and P2 buffers are equal
function StrCompL(P1, P2: pointer; L: PtrInt; Default: PtrInt = 0): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// our fast version of StrCompIL(), to be used with PUtf8Char
// - i.e. make a case-insensitive comparison of two memory buffers, using
// supplied length
// - Default value is returned if both P1 and P2 buffers are equal
function StrCompIL(P1, P2: pointer; L: PtrInt; Default: PtrInt = 0): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// our fast version of StrIComp(), to be used with PUtf8Char/PAnsiChar as TUtf8Compare
function StrIComp(Str1, Str2: pointer): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// StrIComp-like function with a lookup table and Str1/Str2 expected not nil
function StrICompNotNil(Str1, Str2: pointer; Up: PNormTableByte): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// StrIComp-like function with a length, lookup table and Str1/Str2 expected not nil
function StrICompLNotNil(Str1, Str2: pointer; Up: PNormTableByte; L: PtrInt): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// StrIComp function with a length, lookup table and Str1/Str2 expected not nil
// - returns L for whole match, or < L for a partial match
function StrILNotNil(Str1, Str2: pointer; Up: PNormTableByte; L: PtrInt): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

type
  /// function prototype used internally for UTF-8 buffer comparison
  // - also used e.g. in mormot.core.variants unit
  TUtf8Compare = function(P1, P2: PUtf8Char): PtrInt;
  /// function prototype used internally for UTF-8 buffer hashing
  TUtf8Hasher = function(P: PUtf8Char; L: PtrUInt): cardinal;

var
  /// a quick wrapper to StrComp or StrIComp comparison functions
  StrCompByCase: array[{CaseInsensitive=}boolean] of TUtf8Compare;

/// comparison function first by Int64 value, then by text, as TUtf8Compare
// - so plain numbers will appear first, then case-sensitive text values
function StrCompByNumber(Str1, Str2: pointer): PtrInt;

// POSIX-like case-sensitive TUtf8Compare version of SortDynArrayFileName()
function StrCompPosixFileName(P1, P2: PUtf8Char): PtrInt;

/// case-sensitive comparison function using the Operating System, as TUtf8Compare
// - "direct" StrComp() would follow UTF-8 byte order, i.e. UCS-4 CodePoint order,
// which may not be the same as the "human" expected order, especially on Windows
// - use OS and compiler specific Unicode_CompareString() API so may not be
// consistent between computers and platforms, as StrComp() is
// - will make a temporary conversion on stack, of up to 1023 UTF-16 code units
// - warning: potentially much slower than mORMot-native alternatives
function Utf8CompareOS(P1, P2: PUtf8Char): PtrInt;

/// case-insensitive comparison function using the Operating System, as TUtf8Compare
// - use OS and compiler specific Unicode_CompareString() API so may not be
// consistent between computers and platforms, as Utf8ICompReference() is
// - will make a temporary conversion on stack, of up to 1023 UTF-16 code units
// - warning: potentially much slower than mORMot-native alternatives
function Utf8CompareIOS(P1, P2: PUtf8Char): PtrInt;

/// retrieve the next UCS-4 CodePoint stored in U, then update the U pointer
// - this function will decode the UTF-8 content before using NormToUpper[],
// and will remove WinAnsi (Code Page 1252) accents during its conversion
// - will return '?' if the UCS-4 CodePoint is higher than 255: use this
// function only if you need to deal with ASCII characters (e.g. as used for
// Soundex or ContainsUtf8 process)
function GetNextUtf8Upper(var U: PUtf8Char): Ucs4CodePoint;

/// points to the beginning of the next word stored in U
// - returns nil if reached the end of U (i.e. #0 char)
// - here a "word" is a Win-Ansi word, i.e. '0'..'9', 'A'..'Z'
function FindNextUtf8WordBegin(U: PUtf8Char): PUtf8Char;

/// return true if UpperValue (Ansi) is contained in A^ (Ansi)
// - find UpperValue starting at word beginning, not inside words
function FindAnsi(A, UpperValue: PAnsiChar): boolean;

/// return true if UpperValue (Ansi) is contained in U^ (UTF-8 encoded)
// - find UpperValue starting at word beginning, not inside words
// - UTF-8 decoding is done on the fly (no temporary decoding buffer is used)
function FindUtf8(U: PUtf8Char; UpperValue: PAnsiChar): boolean;

/// return true if Upper (Unicode encoded) is contained in U^ (UTF-8 encoded)
// - will use the slow but accurate Operating System API (Win32 or ICU)
// to perform the comparison at Unicode-level
// - consider using StrPosIReference() for our faster Unicode 10.0 version
function FindUnicode(PW: PWideChar; Upper: PWideChar; UpperLen: PtrInt): boolean;

/// return true if up^ is contained inside the UTF-8 buffer p^
// - search up^ at the beginning of every UTF-8 word (aka in Soundex)
// - here a "word" is a Win-Ansi word, i.e. '0'..'9', 'A'..'Z'
// - up^ must be already Upper
function ContainsUtf8(p, up: PUtf8Char): boolean;

/// returns TRUE if the supplied uppercased text is contained in the text buffer
function GetLineContains(p, pEnd, up: PUtf8Char): boolean;
  {$ifdef FPC}inline;{$endif} // Delphi does not like inlining goto+label

/// copy source into a 256 chars dest^ buffer with 7-bit upper case conversion
// - used internally for short keys match or case-insensitive hash
// - returns final dest pointer
// - will copy up to 255 AnsiChar (expect the dest buffer to be defined e.g. as
// TByteToAnsiChar on the caller stack)
function UpperCopy255(dest: PAnsiChar; const source: RawUtf8): PAnsiChar; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// copy source^ into a 256 chars dest^ buffer with 7-bit upper case conversion
// - used internally for short keys match or case-insensitive hash
// - returns final dest pointer
// - will copy up to 255 AnsiChar (expect the dest buffer to be defined e.g. as
// TByteToAnsiChar on the caller stack)
function UpperCopy255Buf(dest: PAnsiChar; source: PUtf8Char; sourceLen: PtrInt): PAnsiChar;

/// copy source into dest^ with WinAnsi 8-bit upper case conversion
// - used internally for short keys match or case-insensitive hash
// - returns final dest pointer
// - will copy up to 255 AnsiChar (expect the dest buffer to be array[byte] of
// AnsiChar)
function UpperCopyWin255(dest: PWinAnsiChar; const source: RawUtf8): PWinAnsiChar;

/// copy UTF-16 source into dest^ with ASCII 7-bit upper case conversion
// - used internally for short keys match or case-insensitive hash
// - returns final dest pointer
// - will copy up to 255 AnsiChar (expect the dest buffer to be array[byte] of
// AnsiChar), replacing any non WinAnsi character by '?'
function UpperCopy255W(dest: PAnsiChar; const source: SynUnicode): PAnsiChar; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// copy WideChar source into dest^ with upper case conversion
// - used internally for short keys match or case-insensitive hash
// - returns final dest pointer
// - will copy up to 255 AnsiChar (expect the dest buffer to be array[byte] of
// AnsiChar), replacing any non WinAnsi character by '?'
function UpperCopy255W(dest: PAnsiChar; source: PWideChar; L: PtrInt): PAnsiChar; overload;

/// copy source into dest^ with ASCII 7-bit upper case conversion
// - returns final dest pointer
// - will copy up to the source buffer end: so Dest^ should be big enough -
// which will the case e.g. if Dest := pointer(source)
function UpperCopy(dest: PAnsiChar; const source: RawUtf8): PAnsiChar;

/// copy source into dest^ with ASCII 7-bit upper case conversion
// - returns final dest pointer
// - this special version expect source to be a ShortString
function UpperCopyShort(dest: PAnsiChar; const source: ShortString): PAnsiChar;

/// fast UTF-8 comparison handling WinAnsi CP-1252 case folding
// - this version expects u1 and u2 to be zero-terminated
// - decode the UTF-8 content before using NormToUpper[] lookup table,
// and will remove WinAnsi (Code Page 1252) accents during its comparison
// - match the our SYSTEMNOCASE custom (and default) SQLite 3 collation
// - consider Utf8ICompReference() for Unicode 10.0 support
function Utf8IComp(u1, u2: PUtf8Char): PtrInt;

/// fast UTF-8 comparison handling WinAnsi CP-1252 case folding
// - this version expects u1 and u2 not to be necessary zero-terminated, but
// uses L1 and L2 as length for u1 and u2 respectively
// - decode the UTF-8 content before using NormToUpper[] lookup table,
// and will remove WinAnsi (Code Page 1252) accents during its comparison
// - consider Utf8ILCompReference() for Unicode 10.0 support
function Utf8ILComp(u1, u2: PUtf8Char; L1, L2: cardinal): PtrInt;

/// copy UTF-8 buffer into dest^ handling WinAnsi CP-1252 NormToUpper[] folding
// - returns the final dest pointer
function Utf8UpperCopy(Dest, Source: PUtf8Char; SourceChars: cardinal): PUtf8Char;

/// copy UTF-8 buffer into dest^ handling WinAnsi CP-1252 NormToUpper[] folding
// - returns the final dest pointer
// - will copy up to 255 AnsiChar (expect the dest buffer to be array[byte] of
// AnsiChar), with UTF-8 encoding and WinAnsi accents removal
function Utf8UpperCopy255(dest: PAnsiChar; const source: RawUtf8): PUtf8Char;
  {$ifdef HASINLINE}inline;{$endif}

/// fast case-insensitive Unicode comparison handling ASCII 7-bit chars
// - use the NormToUpperAnsi7Byte[] array, i.e. compare 'a'..'z' as 'A'..'Z'
// - this version expects u1 and u2 to be zero-terminated
function AnsiICompW(u1, u2: PWideChar): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// compare two "array of AnsiString" elements, with no case sensitivity
// - just a wrapper around inlined StrIComp()
function SortDynArrayAnsiStringI(const A, B): integer;

/// compare two "array of PUtf8Char/PAnsiChar" elements, with no case sensitivity
// - just a wrapper around inlined StrIComp()
function SortDynArrayPUtf8CharI(const A, B): integer;

/// compare two "array of RTL string" elements, with no case sensitivity
// - the expected string type is the RTL string
// - just a wrapper around StrIComp() for AnsiString or AnsiICompW() for UNICODE
function SortDynArrayStringI(const A, B): integer;

/// compare two "array of WideString/UnicodeString" elements, with no case sensitivity
// - implemented here since would call AnsiICompW()
function SortDynArrayUnicodeStringI(const A, B): integer;

var
  /// a quick wrapper to SortDynArrayAnsiString or SortDynArrayAnsiStringI
  // comparison functions
  SortDynArrayAnsiStringByCase: array[{CaseInsensitive=}boolean] of TDynArraySortCompare;

/// SameText() overloaded function with proper UTF-8 decoding
// - fast version using NormToUpper[] array for all WinAnsi characters
// - this version will decode each UTF-8 glyph before using NormToUpper[],
// so will remove WinAnsi (Code Page 1252) accents during its comparison
function SameTextU(const S1, S2: RawUtf8): boolean;
  {$ifdef HASINLINE}inline;{$endif}

/// fast conversion of the supplied text into 8-bit uppercase
// - this will not only convert 'a'..'z' into 'A'..'Z', but also remove WinAnsi
// latin accents ('e' acute into plain 'E' e.g.), using NormToUpper[]
// - it will therefore decode the supplied UTF-8 content to handle more than
// 7-bit of ascii characters (so this function is dedicated to WinAnsi code page
// 1252 characters set)
function UpperCaseU(const S: RawUtf8): RawUtf8;

/// fast conversion of the supplied text into 8-bit lowercase
// - this will not only convert 'a'..'z' into 'A'..'Z', but also remove WinAnsi
// latin accents ('e' acute into plain 'e' e.g.), using NormToLower[]
// - it will therefore decode the supplied UTF-8 content to handle more than
// 7-bit of ascii characters
function LowerCaseU(const S: RawUtf8): RawUtf8;

/// fast conversion of the supplied text into 8-bit case sensitivity
// - convert the text from P into D, returns the resulting length
// - it will decode the supplied UTF-8 content to handle more than 7-bit
// of ascii characters during the conversion (leaving not WinAnsi characters
// untouched)
// - will not set the last char to #0 (caller must do that if necessary)
function ConvertCaseUtf8(P, D: PUtf8Char; const Table: TNormTableByte): PtrInt;

/// check if the supplied text has some case-insentitive 'a'..'z','A'..'Z' chars
// - will therefore be correct with true UTF-8 content, but only for 7-bit
function IsCaseSensitive(const S: RawUtf8): boolean; overload;

/// check if the supplied text has some case-insentitive 'a'..'z','A'..'Z' chars
// - will therefore be correct with true UTF-8 content, but only for 7-bit
function IsCaseSensitive(P: PUtf8Char; PLen: PtrInt): boolean; overload;

/// low-level function called when inlining UpperCase(Copy) and LowerCase(Copy)
procedure CaseCopy(Text: PUtf8Char; Len: PtrInt; Table: PNormTable;
  var Dest: RawUtf8);

/// low-level function called when inlining UpperCaseSelf and LowerCaseSelf
procedure CaseSelf(var S: RawUtf8; Table: PNormTable);

/// low-level function which could be called when S has RefCnt = 1
procedure CaseNew(var S: RawUtf8; Table: PNormTable);

/// fast conversion of the supplied text into uppercase
// - this will only convert 'a'..'z' into 'A'..'Z' (no NormToUpper use), and
// will therefore be correct with true UTF-8 content, but only for 7-bit
function UpperCase(const S: RawUtf8): RawUtf8;
  {$ifdef HASINLINE} inline; {$endif}

/// fast conversion of the supplied text into uppercase
// - this will only convert 'a'..'z' into 'A'..'Z' (no NormToUpper use), and
// will therefore be correct with true UTF-8 content, but only for 7-bit
procedure UpperCaseCopy(Text: PUtf8Char; Len: PtrInt; var Dest: RawUtf8); overload;
  {$ifdef HASINLINE} inline; {$endif}

/// fast conversion of the supplied text into uppercase
// - this will only convert 'a'..'z' into 'A'..'Z' (no NormToUpper use), and
// will therefore be correct with true UTF-8 content, but only for 7-bit
procedure UpperCaseCopy(const Source: RawUtf8; var Dest: RawUtf8); overload;
  {$ifdef HASINLINE} inline; {$endif}

/// fast in-place conversion of the supplied variable text into uppercase
// - this will only convert 'a'..'z' into 'A'..'Z' (no NormToUpper use), and
// will therefore be correct with true UTF-8 content, but only for 7-bit
procedure UpperCaseSelf(var S: RawUtf8);
  {$ifdef HASINLINE} inline; {$endif}

/// fast conversion of the supplied text into lowercase
// - this will only convert 'A'..'Z' into 'a'..'z' (no NormToLower use), and
// will therefore be correct with true UTF-8 content
function LowerCase(const S: RawUtf8): RawUtf8;
  {$ifdef HASINLINE} inline; {$endif}

/// fast conversion of the supplied text into lowercase
// - this will only convert 'A'..'Z' into 'a'..'z' (no NormToLower use), and
// will therefore be correct with true UTF-8 content
procedure LowerCaseCopy(Text: PUtf8Char; Len: PtrInt; var Dest: RawUtf8);
  {$ifdef HASINLINE} inline; {$endif}

/// fast in-place conversion of the supplied variable text into lowercase
// - this will only convert 'A'..'Z' into 'a'..'z' (no NormToLower use), and
// will therefore be correct with true UTF-8 content, but only for 7-bit
procedure LowerCaseSelf(var S: RawUtf8);
  {$ifdef HASINLINE} inline; {$endif}

/// fast in-place conversion of the supplied variable text into lowercase
procedure LowerCaseShort(var S: ShortString);

/// fast in-place conversion of the supplied variable text into uppercase
procedure UpperCaseShort(var S: ShortString);

/// check if a text variable content matches a given case conversion table
function IsCase(const S: RawUtf8; Table: PNormTable): boolean;

/// check if a text variable content is fully in upper case ('A' .. 'Z')
function IsUpper(const S: RawUtf8): boolean;
  {$ifdef HASINLINE} inline; {$endif}

/// check if a text variable content is fully in lower case ('a' .. 'z')
function IsLower(const S: RawUtf8): boolean;
  {$ifdef HASINLINE} inline; {$endif}

/// accurate conversion of the supplied UTF-8 content into the corresponding
// upper-case Unicode characters
// - will use the available API (e.g. Win32 or ICU), so may not be consistent on
// all systems - consider UpperCaseReference() to use our Unicode 10.0 tables
// - will temporary decode S into and from UTF-16 so is likely to be slower
function UpperCaseUnicode(const S: RawUtf8): RawUtf8;

/// accurate conversion of the supplied UTF-8 content into the corresponding
// lower-case Unicode characters
// - will use the available API (e.g. Win32 or ICU), so may not be consistent on
// all systems - and also slower than LowerCase/LowerCaseU versions
function LowerCaseUnicode(const S: RawUtf8): RawUtf8;

/// use the RTL to convert the SynUnicode text to UpperCase
function UpperCaseSynUnicode(const S: SynUnicode): SynUnicode;

/// use the RTL to convert the SynUnicode text to LowerCase
function LowerCaseSynUnicode(const S: SynUnicode): SynUnicode;

/// fast WinAnsi comparison using the NormToUpper[] array for all 8-bit values
// - i.e. will remove WinAnsi (Code Page 1252) accents during its comparison
function AnsiIComp(Str1, Str2: pointer): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// internal function used when inlining PosExI()
function PosExIPas(Sub, P: PUtf8Char; Offset: PtrUInt; Lookup: PNormTable): PtrInt;

/// a ASCII-7 case-insensitive version of PosEx()
// - use NormToUpperAnsi7 lookup table, i.e. compare 'a'..'z' as 'A'..'Z'
function PosExI(const SubStr, S: RawUtf8; Offset: PtrUInt = 1): PtrInt; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// a case-insensitive version of PosEx() with a specified lookup table
// - redirect to mormot.core.base PosEx() if Lookup = nil
function PosExI(const SubStr, S: RawUtf8; Offset: PtrUInt;
  Lookup: PNormTable): PtrInt; overload;
  {$ifdef HASINLINE}inline;{$endif}


{ ************ UTF-8 String Manipulation Functions }

type
  /// used to store a set of 8-bit encoded characters
  TSynAnsicharSet = set of AnsiChar;

  /// used to store a set of 8-bit unsigned integers
  TSynByteSet = set of byte;

  /// a generic callback, which can be used to translate some text on the fly
  // - maps procedure TLanguageFile.Translate(var English: string) signature
  // as defined in mORMoti18n.pas
  // - can be used e.g. for TSynMustache's {{"English text}} callback
  TOnStringTranslate = procedure(var English: string) of object;
  /// a generic callback, which can be used to translate some text on the fly
  // - if UTF-8 is enough you don't need the whole "string" type
  // - would render to any assigned Translated value, or fallback to English if ''
  // - can be used e.g. for TSynMustache's {{"English text}} callback
  TOnUtf8Translate = procedure(English: PUtf8Char; EnglishLen: integer;
    var Translated: RawUtf8) of object;


/// check case-sensitive matching starting of text in start
// - returns true if the item matched
// - see StartWith() from this unit for a case-insensitive version
function StartWithExact(const text, textStart: RawUtf8): boolean;
  {$ifdef HASINLINE} inline; {$endif}

/// check case-sensitive matching ending of text in ending
// - returns true if the item matched
// - see EndWith() from this unit for a case-insensitive version
function EndWithExact(const text, textEnd: RawUtf8): boolean;
  {$ifdef HASINLINE} inline; {$endif}

/// extract a line from source array of chars
// - next will contain the beginning of next line, or nil if source has ended
function GetNextLine(source: PUtf8Char; out next: PUtf8Char;
  andtrim: boolean = false): RawUtf8;

/// returns n leading characters
function LeftU(const S: RawUtf8; n: PtrInt): RawUtf8;
  {$ifdef HASINLINE} inline; {$endif}

/// returns n trailing characters
function RightU(const S: RawUtf8; n: PtrInt): RawUtf8;

/// trims leading whitespace characters from the string by removing
// new line, space, and tab characters
function TrimLeft(const S: RawUtf8): RawUtf8;

/// trims trailing whitespace characters from the string by removing trailing
// newline, space, and tab characters
function TrimRight(const S: RawUtf8): RawUtf8;

/// trims leading whitespaces of every lines of the UTF-8 text
// - also delete void lines
// - could be used e.g. before FindNameValue() call
// - modification is made in-place so S will be modified
procedure TrimLeftLines(var S: RawUtf8);

/// trim some trailing and ending chars
// - if S is unique (RefCnt=1), will modify the RawUtf8 in place
// - faster alternative to S := copy(S, Left + 1, length(S) - Left - Right)
procedure TrimChars(var S: RawUtf8; Left, Right: PtrInt);

/// returns the supplied text content, without any specified char
// - specify a custom char set to be excluded, e.g. as [#0 .. ' ']
function TrimChar(const text: RawUtf8; const exclude: TSynAnsicharSet): RawUtf8;

/// returns the supplied text content, without one specified char
function TrimOneChar(const text: RawUtf8; exclude: AnsiChar): RawUtf8;

/// returns the supplied text content, without any other char than specified
// - specify a custom char set to be included, e.g. as ['A'..'Z']
function OnlyChar(const text: RawUtf8; const only: TSynAnsicharSet): RawUtf8;

/// check if any of the supplied chars appears in the text
function HasAnyChar(const text: RawUtf8; const chars: TSynAnsicharSet): boolean;

/// check if any other than the supplied chars appears in the text
function HasOnlyChar(const text: RawUtf8; const chars: TSynAnsicharSet): boolean;

/// returns the supplied text content, without any control char
// - here control chars have an ASCII code in [#0 .. ' '], i.e. text[] <= ' '
function TrimControlChars(const text: RawUtf8): RawUtf8;

/// split a RawUtf8 string into two strings, according to SepStr separator
// - returns true and LeftStr/RightStr if they were separated by SepStr
// - if SepStr is not found, LeftStr=Str and RightStr='' and returns false
// - if ToUpperCase is TRUE, then LeftStr and RightStr will be made uppercase
function Split(const Str, SepStr: RawUtf8; var LeftStr, RightStr: RawUtf8;
  ToUpperCase: boolean = false): boolean; overload;

/// split a RawUtf8 string into two strings, according to SepStr separator
// - this overloaded function returns the right string as function result
// - if SepStr is not found, LeftStr=Str and result=''
// - if ToUpperCase is TRUE, then LeftStr and result will be made uppercase
function Split(const Str, SepStr: RawUtf8; var LeftStr: RawUtf8;
  ToUpperCase: boolean = false): RawUtf8; overload;

/// split a RawUtf8 string into several strings, according to SepStr separator
// - this overloaded function will fill a DestPtr[] array of PRawUtf8
// - if any DestPtr[]=nil, the item will be skipped
// - if input Str end before al SepStr[] are found, DestPtr[] is set to ''
// - returns the number of values extracted into DestPtr[]
function Split(const Str: RawUtf8; const SepStr: array of RawUtf8;
  const DestPtr: array of PRawUtf8): PtrInt; overload;

/// try to split a RawUtf8 into its two trimmed parts
// - return true and extract trimmed Left / Right values separated by Sep character
// - return false and keep Left / Right untouched if Sep if not found
function TrimSplit(const Str: RawUtf8; var Left, Right: RawUtf8; Sep: AnsiChar): boolean;

/// returns the last occurrence of the given SepChar separated context
// - e.g. SplitRight('01/2/34','/')='34'
// - if SepChar doesn't appear, will return Str, e.g. SplitRight('123','/')='123'
// - if LeftStr is supplied, the RawUtf8 it points to will be filled with
// the left part just before SepChar ('' if SepChar doesn't appear)
function SplitRight(const Str: RawUtf8; SepChar: AnsiChar; LeftStr: PRawUtf8 = nil): RawUtf8;

/// returns the last occurrence of the given SepChar separated context
// - e.g. SplitRight('path/one\two/file.ext','/\')='file.ext', i.e.
// SepChars='/\' will be like ExtractFileName() over RawUtf8 string
// - if SepChar doesn't appear, will return Str, e.g. SplitRight('123','/')='123'
function SplitRights(const Str, SepChar: RawUtf8): RawUtf8;

/// check all character within text are spaces or control chars
// - i.e. a faster alternative to  if TrimU(text)='' then
function IsVoid(const text: RawUtf8): boolean;

/// fill all bytes of this UTF-8 string with zeros, i.e. 'toto' -> #0#0#0#0
// - will write the memory buffer directly, if this string instance is not shared
// (i.e. has refcount = 1), to avoid zeroing still-used values
// - may be used to cleanup stack-allocated content
// ! ... finally FillZero(secret); end;
procedure FillZero(var secret: RawUtf8); overload;
  {$ifdef HASINLINE}inline;{$endif}

/// fill all bytes of this UTF-8 string with zeros, i.e. 'toto' -> #0#0#0#0
// - SpiUtf8 type has been defined explicitly to store Sensitive Personal
// Information
procedure FillZero(var secret: SpiUtf8); overload;
  {$ifdef HASINLINE}inline;{$endif}

/// fill all bytes of this dynamic array of bytes with zeros
// - will write the memory buffer directly, if this array instance is not shared
// (i.e. has refcount = 1), to avoid zeroing still-used values
procedure FillZero(var secret: TBytes); overload;

/// fill all bytes of this UTF-16 string with zeros, i.e. 'toto' -> #0#0#0#0
procedure FillZero(var secret: SynUnicode); overload;

/// actual replacement function called by StringReplaceAll() on first match
// - not to be called as such, but defined globally for proper inlining
function StringReplaceAllProcess(const S, OldPattern, NewPattern: RawUtf8;
  found: integer; Lookup: PNormTable): RawUtf8;

/// fast version of StringReplace(S, OldPattern, NewPattern, [rfReplaceAll]);
function StringReplaceAll(const S, OldPattern, NewPattern: RawUtf8;
  Lookup: PNormTable = nil): RawUtf8; overload;

/// case-sensitive (or not) StringReplace(S, OldPattern, NewPattern,[rfReplaceAll])
// - calls plain StringReplaceAll() version for CaseInsensitive = false
// - calls StringReplaceAll(.., NormToUpperAnsi7) if CaseInsensitive = true
function StringReplaceAll(const S, OldPattern, NewPattern: RawUtf8;
  CaseInsensitive: boolean): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// fast version of several cascaded StringReplaceAll()
function StringReplaceAll(const S: RawUtf8;
  const OldNewPatternPairs: array of RawUtf8;
  CaseInsensitive: boolean = false): RawUtf8; overload;

/// fast replace of a specified char by a given string
function StringReplaceChars(const Source: RawUtf8; OldChar, NewChar: AnsiChar): RawUtf8;

/// fast replace of all #9 chars by a given string
function StringReplaceTabs(const Source, TabText: RawUtf8): RawUtf8;

/// UTF-8 dedicated (and faster) alternative to StringOfChar((Ch,Count))
function RawUtf8OfChar(Ch: AnsiChar; Count: integer): RawUtf8;

/// format a text content with SQL/pascal-like quotes
// - this function implements what is specified in the official SQLite3
// documentation: "A string constant is formed by enclosing the string in single
// quotes ('). A single quote within the string can be encoded by putting two
// single quotes in a row - as in Pascal."
function QuotedStr(const S: RawUtf8; Quote: AnsiChar = ''''): RawUtf8; overload;

/// format a text content with SQL/pascal-like quotes
procedure QuotedStr(const S: RawUtf8; Quote: AnsiChar; var result: RawUtf8); overload;

/// format a text buffer with SQL/pascal-like quotes
procedure QuotedStr(P: PUtf8Char; PLen: PtrInt; Quote: AnsiChar;
  var result: RawUtf8); overload;

/// unquote a SQL-compatible string
// - the first character in P^ must be either ' or " then internal double quotes
// are transformed into single quotes
// - 'text '' end'   -> text ' end
// - "text "" end"   -> text " end
// - returns nil if P doesn't contain a valid SQL string
// - returns a pointer just after the quoted text otherwise
function UnQuoteSqlStringVar(P: PUtf8Char; out Value: RawUtf8): PUtf8Char;

/// unquote a SQL-compatible string
function UnQuoteSqlString(const Value: RawUtf8): RawUtf8;

/// unquote a SQL-compatible symbol name
// - e.g. '[symbol]' -> 'symbol' or '"symbol"' -> 'symbol'
function UnQuotedSqlSymbolName(const ExternalDBSymbol: RawUtf8): RawUtf8;

/// get the next character after a quoted buffer
// - the first character in P^ must be either ', either "
// - it will return the latest quote position, ignoring double quotes within
function GotoEndOfQuotedString(P: PUtf8Char): PUtf8Char;
  {$ifdef HASINLINE}inline;{$endif}

/// get the next character not in [#1..' ']
function GotoNextNotSpace(P: PUtf8Char): PUtf8Char;
  {$ifdef HASINLINE}inline;{$endif}

/// get the next character not in [#9,' ']
function GotoNextNotSpaceSameLine(P: PUtf8Char): PUtf8Char;
  {$ifdef HASINLINE}inline;{$endif}

/// get the next character in [#0..' ']
function GotoNextSpace(P: PUtf8Char): PUtf8Char;
  {$ifdef HASINLINE}inline;{$endif}

/// check if the next character not in [#1..' '] matchs a given value
// - first ignore any non space character
// - then returns TRUE if P^=ch, setting P to the character after ch
// - or returns FALSE if P^<>ch, leaving P at the level of the unexpected char
function NextNotSpaceCharIs(var P: PUtf8Char; ch: AnsiChar): boolean;
  {$ifdef HASINLINE}inline;{$endif}

/// retrieve the next SQL-like identifier within the UTF-8 buffer
// - will also trim any space (or line feeds) and trailing ';'
// - any comment like '/*nocache*/' will be ignored
// - returns true if something was set to Prop
function GetNextFieldProp(var P: PUtf8Char; var Prop: RawUtf8): boolean;

/// retrieve the next identifier within the UTF-8 buffer on the same line
// - GetNextFieldProp() will just handle line feeds (and ';') as spaces - which
// is fine e.g. for SQL, but not for regular config files with name/value pairs
// - returns true if something was set to Prop
function GetNextFieldPropSameLine(var P: PUtf8Char; var Prop: ShortString): boolean;

/// return true if IdemPChar(source,searchUp), and go to the next line of source
function IdemPCharAndGetNextLine(var source: PUtf8Char; searchUp: PAnsiChar): boolean;

/// search for a value from its uppercased named entry
// - i.e. iterate IdemPChar(source,UpperName) over every line of the source
// - returns the text just after UpperName if it has been found at line beginning
// - returns nil if UpperName was not found at any line beginning
// - could be used e.g. to efficently extract a value from HTTP headers, whereas
// FindIniNameValue() is tuned for [section]-oriented INI files
function FindNameValue(P: PUtf8Char; UpperName: PAnsiChar): PUtf8Char; overload;

/// search and returns a value from its uppercased named entry
// - i.e. iterate IdemPChar(source,UpperName) over every line of the source
// - returns true and the trimmed text just after UpperName into Value
// if it has been found at line beginning
// - returns false and set Value := '' if UpperName was not found (or leave
// Value untouched if KeepNotFoundValue is true)
// - could be used e.g. to efficently extract a value from HTTP headers, whereas
// FindIniNameValue() is tuned for [section]-oriented INI files
// - do TrimLeftLines(NameValuePairs) first if the lines start with spaces/tabs
function FindNameValue(const NameValuePairs: RawUtf8; UpperName: PAnsiChar;
  var Value: RawUtf8; KeepNotFoundValue: boolean = false;
  UpperNameSeparator: AnsiChar = #0): boolean; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// search and returns a PUtf8Char value from its uppercased named entry
// - as called when inlining FindNameValue()
// - won't make any memory allocation, so could be fine for a quick lookup
function FindNameValuePointer(NameValuePairs: PUtf8Char; UpperName: PAnsiChar;
  out FoundLen: PtrInt; UpperNameSeparator: AnsiChar = #0): PUtf8Char;

/// compute the line length from source array of chars
// - if PEnd = nil, end counting at either #0, #13 or #10
// - otherwise, end counting at either #13 or #10
// - just a wrapper around BufferLineLength() checking PEnd=nil case
function GetLineSize(P, PEnd: PUtf8Char): PtrUInt;
  {$ifdef HASINLINE}inline;{$endif}

/// returns true if the line length from source array of chars is not less than
// the specified count
function GetLineSizeSmallerThan(P, PEnd: PUtf8Char; aMinimalCount: integer): boolean;

{$ifndef PUREMORMOT2}
/// return next string delimited with #13#10 from P, nil if no more
// - this function returns a RawUnicode string type
function GetNextStringLineToRawUnicode(var P: PChar): RawUnicode;
{$endif PUREMORMOT2}

/// trim first lowercase chars ('otDone' will return 'Done' e.g.)
// - return a PUtf8Char to avoid any memory allocation
function TrimLeftLowerCase(const V: RawUtf8): PUtf8Char;

/// trim first lowercase chars ('otDone' will return 'Done' e.g.)
// - return an RawUtf8 string: enumeration names are pure 7-bit ANSI with Delphi 7
// to 2007, and UTF-8 encoded with Delphi 2009+
function TrimLeftLowerCaseShort(V: PShortString): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// trim first lowercase chars ('otDone' will return 'Done' e.g.)
procedure TrimLeftLowerCaseShort(V: PShortString; var U: RawUtf8); overload;

/// trim first lowercase chars ('otDone' will return 'Done' e.g.)
// - return a ShortString: enumeration names are pure 7-bit ANSI with Delphi 7
// to 2007, and UTF-8 encoded with Delphi 2009+
function TrimLeftLowerCaseToShort(V: PShortString): ShortString; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// trim first lowercase chars ('otDone' will return 'Done' e.g.)
// - return a ShortString: enumeration names are pure 7-bit ANSI with Delphi 7
// to 2007, and UTF-8 encoded with Delphi 2009+
procedure TrimLeftLowerCaseToShort(V: PShortString; out result: ShortString); overload;

/// fast append some UTF-8 text into a ShortString, with an ending ','
procedure AppendShortComma(text: PAnsiChar; len: PtrInt; var result: ShortString;
  trimlowercase: boolean);   {$ifdef FPC} inline; {$endif}

/// fast search of an exact case-insensitive match of a RTTI's PShortString array
function FindShortStringListExact(List: PShortString; MaxValue: integer;
  aValue: PUtf8Char; aValueLen: PtrInt): integer;

/// fast case-insensitive search of a left-trimmed lowercase match
// of a RTTI's PShortString array
function FindShortStringListTrimLowerCase(List: PShortString; MaxValue: integer;
  aValue: PUtf8Char; aValueLen: PtrInt): integer;

/// fast case-sensitive search of a left-trimmed lowercase match
// of a RTTI's PShortString array
function FindShortStringListTrimLowerCaseExact(List: PShortString; MaxValue: integer;
  aValue: PUtf8Char; aValueLen: PtrInt): integer;

/// convert a CamelCase string into a space separated one
// - 'OnLine' will return 'On line' e.g., and 'OnMyLINE' will return 'On my LINE'
// - will handle capital words at the beginning, middle or end of the text, e.g.
// 'KLMFlightNumber' will return 'KLM flight number' and 'GoodBBCProgram' will
// return 'Good BBC program'
// - will handle a number at the beginning, middle or end of the text, e.g.
// 'Email12' will return 'Email 12'
// - '_' char is transformed into ' - '
// - '__' chars are transformed into ': '
// - return an RawUtf8 string: enumeration names are pure 7-bit ANSI with Delphi
// up to 2007, and UTF-8 encoded with Delphi 2009+
function UnCamelCase(const S: RawUtf8): RawUtf8; overload;
  {$ifdef HASINLINE} inline; {$endif}

/// convert in-place a CamelCase string into a space separated one
procedure UnCamelCaseSelf(var S: RawUtf8);

/// convert a CamelCase string into a space separated one
// - 'OnLine' will return 'On line' e.g., and 'OnMyLINE' will return 'On my LINE'
// - will handle capital words at the beginning, middle or end of the text, e.g.
// 'KLMFlightNumber' will return 'KLM flight number' and 'GoodBBCProgram' will
// return 'Good BBC program'
// - will handle a number at the beginning, middle or end of the text, e.g.
// 'Email12' will return 'Email 12'
// - return the char count written into D^
// - D^ and P^ are expected to be UTF-8 encoded: enumeration and property names
// are pure 7-bit ANSI with Delphi 7 to 2007, and UTF-8 encoded with Delphi 2009+
// - '_' char is transformed into ' - '
// - '__' chars are transformed into ': '
function UnCamelCase(D, P: PUtf8Char): integer; overload;

/// convert a string into an human-friendly CamelCase identifier
// - replacing spaces or punctuations by an uppercase character
// - as such, it is not the reverse function to UnCamelCase()
// - will convert up to the first 256 AnsiChar of the buffer
procedure CamelCase(P: PAnsiChar; len: PtrInt; var s: RawUtf8;
  const isWord: TSynByteSet = [ord('0')..ord('9'), ord('a')..ord('z'), ord('A')..ord('Z')]); overload;

/// convert a string into an human-friendly CamelCase identifier
// - replacing spaces or punctuations by an uppercase character
// - as such, it is not the reverse function to UnCamelCase()
// - will convert up to the first 256 AnsiChar of text
procedure CamelCase(const text: RawUtf8; var s: RawUtf8;
  const isWord: TSynByteSet = [ord('0')..ord('9'), ord('a')..ord('z'), ord('A')..ord('Z')]); overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert a string into an human-friendly CamelCase identifier (as in Pascal)
// - replacing spaces or punctuations by an uppercase character
// - as such, it is not the reverse function to UnCamelCase()
// - will convert up to the first 256 AnsiChar of text
function CamelCase(const text: RawUtf8): RawUtf8; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// convert a string into an human-friendly lowerCamelCase identifier (as in Java)
// - just like CamelCase() but with the first letter forced in lowercase
function LowerCamelCase(const text: RawUtf8): RawUtf8; overload;

/// convert a string with the first letter forced in lowercase
function UriCase(const text: RawUtf8): RawUtf8;

type
  /// character categories e.g. for ASCII-7 identifier parsing
  TCharKind = (
    ckOther, ckLowerAlpha, ckUpperAlpha, ckDigit, ckUnderscore, ckPoint);
  /// efficient text-to-character lookup table for identifier parsing
  TCharKinds = array[AnsiChar] of TCharKind;
  /// pointer to a text-to-character lookup table for identifier parsing
  PCharKinds = ^TCharKinds;

var
  /// text-to-character lookup table for ASCII-7 identifier parsing
  IDENT_CHARS: TCharKinds;

/// convert a text buffer into a snake_case identifier (as in Python)
// - will convert up to the first 256 AnsiChar of the buffer
procedure SnakeCase(P: PAnsiChar; len: PtrInt; var s: RawUtf8); overload;

/// convert a string into a snake_case identifier (as in Python)
// - will convert up to the first 256 AnsiChar of text
function SnakeCase(const text: RawUtf8): RawUtf8; overload;

const
  // published for unit testing in TNetworkProtocols.OpenAPI (e.g. if sorted)
  RESERVED_KEYWORDS: array[0..91] of RawUtf8 = (
    'ABSOLUTE', 'ABSTRACT', 'ALIAS', 'AND', 'ARRAY', 'AS', 'ASM', 'ASSEMBLER',
    'BEGIN', 'CASE', 'CLASS', 'CONST', 'CONSTREF', 'CONSTRUCTOR', 'DESTRUCTOR',
    'DIV', 'DO', 'DOWNTO', 'ELSE', 'END', 'EXCEPT', 'EXPORT', 'EXTERNAL',
    'FALSE', 'FAR', 'FILE', 'FINALIZATION', 'FINALLY', 'FOR', 'FORWARD',
    'FUNCTION', 'GENERIC', 'GOTO', 'IF', 'IMPLEMENTATION', 'IN', 'INHERITED',
    'INITIALIZATION', 'INLINE', 'INTERFACE', 'IS', 'LABEL', 'LIBRARY', 'MOD',
    'NEAR', 'NEW', 'NIL', 'NOT', 'OBJECT', 'OF', 'ON', 'OPERATOR', 'OR', 'OUT',
    'OVERRIDE', 'PACKED', 'PRIVATE', 'PROCEDURE', 'PROGRAM', 'PROPERTY',
    'PROTECTED', 'PUBLIC', 'PUBLISHED', 'RAISE', 'READ', 'RECORD',
    'REINTRODUCE', 'REPEAT', 'RESOURCESTRING', 'SELF', 'SET', 'SHL', 'SHR',
    'STATIC', 'STRING', 'THEN', 'THREADVAR', 'TO', 'TRUE', 'TRY', 'TYPE',
    'UNIT', 'UNTIL', 'USES', 'VAR', 'VARIANT', 'VIRTUAL', 'WHILE', 'WITH',
    'WRITE', 'WRITELN', 'XOR');

/// quickly check if a text is a case-insensitive pascal code keyword
function IsReservedKeyWord(const aName: RawUtf8): boolean;

/// wrap CamelCase() and IsReservedKeyWord() to generate a valid pascal identifier
// - if aName is void after camel-casing, will raise an ESynUnicode
function SanitizePascalName(const aName: RawUtf8; KeyWordCheck: boolean): RawUtf8;

var
  /// these procedure type must be defined if a default system.pas is used
  // - expect generic "string" type, i.e. UnicodeString for Delphi 2009+
  LoadResStringTranslate: procedure(var Text: string) = nil;

/// UnCamelCase and translate a char buffer
// - P is expected to be #0 ended
// - return "string" type, i.e. UnicodeString for Delphi 2009+
procedure GetCaptionFromPCharLen(P: PUtf8Char; out result: string);


{ ************ TRawUtf8DynArray Processing Functions }

/// returns TRUE if Value is nil or all supplied Values[] equal ''
function IsZero(const Values: TRawUtf8DynArray): boolean; overload;

/// quick helper to initialize a dynamic array of RawUtf8 from some constants
// - can be used e.g. as:
// ! MyArray := TRawUtf8DynArrayFrom(['a','b','c']);
function TRawUtf8DynArrayFrom(const Values: array of RawUtf8): TRawUtf8DynArray;

/// low-level efficient search of Value in Values[]
// - CaseSensitive=false will use StrICmp() for A..Z / a..z equivalence
function FindRawUtf8(Values: PRawUtf8; const Value: RawUtf8; ValuesCount: integer;
  CaseSensitive: boolean): integer; overload;

/// return the index of Value in Values[], -1 if not found
// - CaseSensitive=false will use StrICmp() for A..Z / a..z equivalence
function FindRawUtf8(const Values: TRawUtf8DynArray; const Value: RawUtf8;
  CaseSensitive: boolean = true): integer; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// return the index of Value in Values[], -1 if not found
// - CaseSensitive=false will use StrICmp() for A..Z / a..z equivalence
function FindRawUtf8(const Values: array of RawUtf8; const Value: RawUtf8;
  CaseSensitive: boolean = true): integer; overload;

/// true if Value was added successfully in Values[]
function AddRawUtf8(var Values: TRawUtf8DynArray; const Value: RawUtf8;
  NoDuplicates: boolean; CaseSensitive: boolean = true): boolean; overload;

/// return the newly added Value index at the end of Values[]
function AddRawUtf8(var Values: TRawUtf8DynArray; const Value: RawUtf8): PtrInt; overload;

/// add the Value to Values[], with an external count variable, for performance
function AddRawUtf8(var Values: TRawUtf8DynArray; var ValuesCount: integer;
  const Value: RawUtf8): PtrInt; overload;

/// add Value[] items to Values[]
procedure AddRawUtf8(var Values: TRawUtf8DynArray; const Value: TRawUtf8DynArray); overload;

/// add Value[] items to Values[], with an external count variable, for performance
procedure AddRawUtf8(var Values: TRawUtf8DynArray; var ValuesCount: integer;
  const Value: TRawUtf8DynArray); overload;

/// true if both TRawUtf8DynArray are the same, in the very same order
// - comparison is case-sensitive
function RawUtf8DynArrayEquals(const A, B: TRawUtf8DynArray): boolean; overload;

/// true if both TRawUtf8DynArray are the same for a given number of items
// - A and B are expected to have at least Count items
// - comparison is case-sensitive
function RawUtf8DynArrayEquals(const A, B: TRawUtf8DynArray;
  Count: integer): boolean; overload;

/// true if all TRawUtf8DynArray items in A are in B (i.e. if A is included in B)
function RawUtf8DynArrayContains(const A, B: TRawUtf8DynArray;
  CaseInsensitive: boolean = false): boolean;

/// true if both TRawUtf8DynArray are the same, in any order
// - i.e. if all items in A are in B and all items in B are in A
function RawUtf8DynArraySame(const A, B: TRawUtf8DynArray;
  CaseInsensitive: boolean = false): boolean;

/// add the Value to Values[] string array
function AddString(var Values: TStringDynArray; const Value: string): PtrInt;

/// convert the string dynamic array into a dynamic array of UTF-8 strings
procedure StringDynArrayToRawUtf8DynArray(const Source: array of string;
  var result: TRawUtf8DynArray); overload;

/// convert the string dynamic array into a dynamic array of UTF-8 strings
function StringDynArrayToRawUtf8DynArray(
  const Source: array of string): TRawUtf8DynArray; overload;

/// convert the string list into a dynamic array of UTF-8 strings
procedure StringListToRawUtf8DynArray(Source: TStringList;
  var result: TRawUtf8DynArray);

/// retrieve the index where to insert a PUtf8Char in a sorted PUtf8Char array
// - R is the last index of available entries in P^ (i.e. Count-1)
// - string comparison is case-sensitive StrComp (so will work with any PAnsiChar)
// - returns -1 if the specified Value was found (i.e. adding will duplicate a value)
// - will use fast O(log(n)) binary search algorithm
function FastLocatePUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt;
  Value: PUtf8Char): PtrInt; overload;
  {$ifdef HASINLINE}inline;{$endif}

/// retrieve the index where to insert a PUtf8Char in a sorted PUtf8Char array
// - this overloaded function accept a custom comparison function for sorting
// - R is the last index of available entries in P^ (i.e. Count-1)
// - string comparison is case-sensitive (so will work with any PAnsiChar)
// - returns -1 if the specified Value was found (i.e. adding will duplicate a value)
// - will use fast O(log(n)) binary search algorithm
function FastLocatePUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt;
  Value: PUtf8Char; Compare: TUtf8Compare): PtrInt; overload;

/// retrieve the index where is located a PUtf8Char in a sorted PUtf8Char array
// - R is the last index of available entries in P^ (i.e. Count-1)
// - string comparison is case-sensitive StrComp (so will work with any PAnsiChar)
// - returns -1 if the specified Value was not found
// - will use inlined binary search algorithm with optimized x86_64 branchless asm
// - slightly faster than plain FastFindPUtf8CharSorted(P,R,Value,@StrComp)
function FastFindPUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt;
  Value: PUtf8Char): PtrInt; overload;

/// retrieve the index where is located a PUtf8Char in a sorted uppercase array
// - P[] array is expected to be already uppercased
// - searched Value is converted to uppercase before search via UpperCopy255Buf(),
// so is expected to be short, i.e. length < 250
// - R is the last index of available entries in P^ (i.e. Count-1)
// - returns -1 if the specified Value was not found
// - will use fast O(log(n)) binary search algorithm
// - slightly faster than plain FastFindPUtf8CharSorted(P,R,Value,@StrIComp)
function FastFindUpperPUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt;
  Value: PUtf8Char; ValueLen: PtrInt): PtrInt;
  {$ifdef HASINLINE}inline;{$endif}

/// retrieve the index where is located a PUtf8Char in a sorted PUtf8Char array
// - R is the last index of available entries in P^ (i.e. Count-1)
// - string comparison will use the specified Compare function
// - returns -1 if the specified Value was not found
// - will use fast O(log(n)) binary search algorithm
function FastFindPUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt;
  Value: PUtf8Char; Compare: TUtf8Compare): PtrInt; overload;

/// retrieve the index of a PUtf8Char in a PUtf8Char array via a sort indexed
// - will use fast O(log(n)) binary search algorithm
function FastFindIndexedPUtf8Char(P: PPUtf8CharArray; R: PtrInt;
  var SortedIndexes: TCardinalDynArray; Value: PUtf8Char;
  ItemComp: TUtf8Compare): PtrInt;

/// add a RawUtf8 value in an alphaticaly sorted dynamic array of RawUtf8
// - returns the index where the Value was added successfully in Values[]
// - returns -1 if the specified Value was already present in Values[]
//  (we must avoid any duplicate for O(log(n)) binary search)
// - if CoValues is set, its content will be moved to allow inserting a new
// value at CoValues[result] position - a typical usage of CoValues is to store
// the corresponding ID to each RawUtf8 item
// - if FastLocatePUtf8CharSorted() has been already called, this index can
// be set to optional ForceIndex parameter
// - by default, exact (case-sensitive) match is used; you can specify a custom
// compare function if needed in Compare optional parameter
function AddSortedRawUtf8(var Values: TRawUtf8DynArray;
  var ValuesCount: integer; const Value: RawUtf8;
  CoValues: PIntegerDynArray = nil; ForcedIndex: PtrInt = -1;
  Compare: TUtf8Compare = nil): PtrInt;

/// delete a RawUtf8 item in a dynamic array of RawUtf8
// - if CoValues is set, the integer item at the same index is also deleted
function DeleteRawUtf8(var Values: TRawUtf8DynArray; var ValuesCount: integer;
  Index: integer; CoValues: PIntegerDynArray = nil): boolean; overload;

/// delete a RawUtf8 item in a dynamic array of RawUtf8;
function DeleteRawUtf8(var Values: TRawUtf8DynArray;
  Index: PtrInt): boolean; overload;

/// sort a dynamic array of RawUtf8 items
// - if CoValues is set, the integer items are also synchronized
// - by default, exact (case-sensitive) match is used; you can specify a custom
// compare function if needed in Compare optional parameter
procedure QuickSortRawUtf8(var Values: TRawUtf8DynArray; ValuesCount: integer;
  CoValues: PIntegerDynArray = nil; Compare: TUtf8Compare = nil); overload;

/// sort a RawUtf8 array, low values first
procedure QuickSortRawUtf8(Values: PRawUtf8Array; L, R: PtrInt;
  caseInsensitive: boolean = false); overload;

/// compute the sum of all length(Values^[...))
function SumRawUtf8Length(Values: PRawUtf8; n: integer): TStrLen;

/// sort and remove any duplicated RawUtf8 from Values[]
procedure DeduplicateRawUtf8(var Values: TRawUtf8DynArray);

{$ifdef OSPOSIX}
type
  /// monitor a POSIX folder for all its file names, and allow efficient
  // case-insensitive search, as it would on a Windows file system
  // - will use our fast PosixFileNames() low-level API to read the names
  // and store them into its in-memory cache (until Flush or after FlushSeconds)
  TPosixFileCaseInsensitive = class
  protected
    fSafe: TRWLightLock;
    fFiles: TRawUtf8DynArray;
    fFolder: TFileName;
    fNextTix, fFlushSeconds: cardinal;
    fSubFolders: boolean;
    procedure SetFolder(const aFolder: TFileName);
    procedure SetSubFolders(aSubFolders: boolean);
  public
    /// initialize the file names lookup
    constructor Create(const aFolder: TFileName; aSubFolders: boolean); reintroduce;
    /// to be called on a regular pace (e.g. every second) to perform FlushSeconds
    procedure OnIdle(tix64: Int64);
    /// clear the internal list to force full reload of the directory
    procedure Flush;
    /// case-insensitive search for a given TFileName in the folder
    // - returns '' if not found, or the exact file name in the POSIX folder
    // - is thread-safe and non blocking during its lookup
    // - can optionally return micro seconds spent for actual filenames read on disk
    // - warning: aReadMs^ should be a 32-bit "integer" variable, not a PtrInt
    function Find(const aSearched: TFileName; aReadMs: PInteger = nil): TFileName;
    /// how many file entries are currently in the internal list
    function Count: PtrInt;
    /// make a dynamic array copy of the internal file names, sorted by StrIComp
    function Files: TRawUtf8DynArray;
    /// allow to change the monitored folder at runtime
    property Folder: TFileName
      read fFolder write SetFolder;
    /// define if sub-folders should also be included to the internal list
    property SubFolders: boolean
      read fSubFolders write SetSubFolders;
    /// after how many seconds OnIdle() should flush the internal cache
    // - default is 60, i.e. 1 minute
    // - you can set 0 to disable any auto-flush from OnIdle()
    property FlushSeconds: cardinal
      read fFlushSeconds write fFlushSeconds;
  end;
{$endif OSPOSIX}


{ ************** Operating-System Independent Unicode Process }

/// UpperCase conversion of a UTF-8 buffer using our Unicode 10.0 tables
// - won't call the Operating System, so is consistent on all platforms,
// whereas UpperCaseUnicode() may vary depending on each library implementation
// - some codepoints enhance in length, so D^ should be at least twice than S^
// - any invalid input is replaced by UNICODE_REPLACEMENT_CHARACTER=$fffd
// - won't use temporary UTF-16 decoding, and optimized for plain ASCII content
function Utf8UpperReference(S, D: PUtf8Char): PUtf8Char; overload;

/// UpperCase conversion of a UTF-8 buffer using our Unicode 10.0 tables
// - won't call the Operating System, so is consistent on all platforms,
// whereas UpperCaseUnicode() may vary depending on each library implementation
// - some codepoints enhance in length, so D^ should be at least twice than S^
// - any invalid input is replaced by UNICODE_REPLACEMENT_CHARACTER=$fffd
// - won't use temporary UTF-16 decoding, and optimized for plain ASCII content
// - knowing the Source length, this function will handle any ASCII 7-bit input
// by quad, for efficiency
function Utf8UpperReference(S, D: PUtf8Char; SLen: PtrUInt): PUtf8Char; overload;

/// UpperCase conversion of a UTF-8 string using our Unicode 10.0 tables
// - won't call the Operating System, so is consistent on all platforms,
// whereas UpperCaseUnicode() may vary depending on each library implementation
// - won't use temporary UTF-16 decoding, and optimized for plain ASCII content
function UpperCaseReference(const S: RawUtf8): RawUtf8;

/// UTF-8 comparison using our Unicode 10.0 tables
// - this version expects u1 and u2 to be zero-terminated
// - Utf8IComp() handles WinAnsi CP-1252 latin accents - this one is Unicode
// - won't call the Operating System, so is consistent on all platforms, and
// don't require any temporary UTF-16 decoding
// - has a branchless optimized process of 7-bit ASCII charset [a..z] -> [A..Z]
function Utf8ICompReference(u1, u2: PUtf8Char): PtrInt;

/// UTF-8 comparison using our Unicode 10.0 tables
// - this version expects u1 and u2 not to be necessary zero-terminated, but
// uses L1 and L2 as length for u1 and u2 respectively
// - Utf8ILComp() handles WinAnsi CP-1252 latin accents - this one is Unicode
// - won't call the Operating System, so is consistent on all platforms, and
// don't require any temporary UTF-16 decoding
// - has a branchless optimized process of 7-bit ASCII charset [a..z] -> [A..Z]
function Utf8ILCompReference(u1, u2: PUtf8Char; L1, L2: integer): PtrInt;

/// compare two UCS-4 strings
function Ucs4Compare(const a, b: RawUcs4): integer;
  {$ifdef HASINLINE} inline; {$endif}

/// compare two UCS-4 buffers using 32-bit CompareCardinal() function
function Ucs4Comp(a, b: PUcs4CodePoint): integer;

/// convert some UTF-8 buffer content into UCS-4
procedure Utf8ToRawUcs4(u: PUtf8Char; L: PtrInt; out ucs4: RawUcs4); overload;

/// convert some UTF-8 string content into UCS-4
function Utf8ToRawUcs4(const S: RawUtf8): RawUcs4; overload;

/// convert some UCS-4 buffer into UTF-8 string
procedure RawUcs4ToUtf8(u4: PUcs4CodePoint; L: PtrInt; out u: RawUtf8); overload;

/// convert some UCS-4 into UTF-8 string
function RawUcs4ToUtf8(const ucs4: RawUcs4): RawUtf8; overload;

/// UpperCase conversion of UTF-8 into UCS-4 using our Unicode 10.0 tables
// - won't call the Operating System, so is consistent on all platforms,
// whereas UpperCaseUnicode() may vary depending on each library implementation
function UpperCaseUcs4Reference(const S: RawUtf8): RawUcs4;

/// UTF-8 Unicode 10.0 case-insensitive Pattern search within UTF-8 buffer
// - returns nil if no match, or the Pattern position found inside U^
// - Up should have been already converted using UpperCaseUcs4Reference()
// - won't call the Operating System, so is consistent on all platforms, and
// don't require any temporary UTF-16 decoding
function StrPosIReference(U: PUtf8Char; const Up: RawUcs4): PUtf8Char;


implementation


{ *************** UTF-8 Efficient Encoding / Decoding }

{ TUtf8Table }

function TUtf8Table.GetHighUtf8Ucs4(var U: PUtf8Char): Ucs4CodePoint;
var
  p: PByte;
  x: ^TUtf8TableExtra;
  n, c: PtrUInt;
begin
  result := 0;
  p := pointer(U);
  inc(U); // move the U pointer to avoid infinite loop on exit / invalid input
  c := p^; // here c=U^>=#80
  n := Lookup[c];
  if n = UTF8_INVALID then
    exit; // returns 0 as invalid leading byte (allow full UTF-8/UCS-4 range)
  x := @Extra[n];
  inc(p);
  repeat
    if p^ and $c0 <> $80 then
      exit; // invalid input content
    c := (c shl 6) + p^;
    inc(p);
    dec(n);
  until n = 0;
  U := pointer(p);
  dec(c, x^.offset);
  if c >= x^.minimum then
    result := c; // valid range
end;

function GetHighUtf8Ucs4(var U: PUtf8Char): Ucs4CodePoint;
begin
  result := UTF8_TABLE.GetHighUtf8Ucs4(U);
end;

function GetUtf8WideChar(P: PUtf8Char): cardinal;
begin
  if P <> nil then
  begin
    result := byte(P^);
    if result > $7f then
    begin
      result := UTF8_TABLE.GetHighUtf8Ucs4(P);
      if result > $ffff then
        // surrogates can't be stored in a single UTF-16 WideChar
        result := UNICODE_REPLACEMENT_CHARACTER;
    end;
  end
  else
    result := PtrUInt(P);
end;

function NextUtf8Ucs4(var P: PUtf8Char): Ucs4CodePoint;
begin
  if P <> nil then
  begin
    result := byte(P[0]);
    if result <= $7f then
      inc(P)
    else
      if result and $20 = 0 then // $80..$7ff
      begin
        result := (result shl 6) + byte(P[1]) - UTF8_EXTRA1_OFFSET;
        inc(P, 2);
      end
      else
        result := UTF8_TABLE.GetHighUtf8Ucs4(P);
  end
  else
    result := 0;
end;

function IsoUcsToUtf8(c: cardinal; Dest: PUtf8Char): PtrInt;
begin
  if c <= $7f then
  begin
    Dest^ := AnsiChar(c);
    result := 1;
  end
  else if c <= $7ff then
  begin
    PWord(Dest)^ := (c shr 6) or ((c and $3f) shl 8) or UTF8_7FF;
    result := 2;
  end
  else if c <= $ffff then
  begin
    PCardinal(Dest)^ := (c shr 12) or (((c shr 6) and $3f) shl 8) or
                        ((c and $3f) shl 16) or UTF8_FFFF;
    result := 3;
  end
  else
  begin // c <= $1fffff (c <= UNICODE_MAX=$10ffff within ISO/IEC 10646)
    PCardinal(Dest)^ := (c shr 18) or (((c shr 12) and $3f) shl 8) or
      (((c shr 6) and $3f) shl 16) or ((c and $3f) shl 24) or UTF8_10FF;
    result := 4;
  end;
end;

function Ucs4ToUtf8(ucs4: Ucs4CodePoint; Dest: PUtf8Char): PtrInt;
begin
  if ucs4 <= $1fffff then // RFC 2279 original range (bigger than UNICODE_MAX)
    result := IsoUcsToUtf8(ucs4, Dest)
  else if ucs4 <= $3ffffff then // supported by original UTF-8 - not by RFC 3629
  begin
    Dest^ := AnsiChar((ucs4 shr 24) or $f8);
    PCardinal(Dest + 1)^ := ((ucs4 shr 18) and $3f) or (((ucs4 shr 12) and $3f) shl 8) or
      (((ucs4 shr 6) and $3f) shl 16) or ((ucs4 and $3f) shl 24) or $80808080;
    result := 5;
  end
  else // up to U+7FFFFFFF (2^32-1)
  begin
    PCardinal(Dest)^ := (ucs4 shr 30) or (((ucs4 shr 24) and $3f) shl 8) or $80fc;
    PCardinal(Dest + 2)^ := ((ucs4 shr 18) and $3f) or (((ucs4 shr 12) and $3f) shl 8) or
      (((ucs4 shr 6) and $3f) shl 16) or ((ucs4 and $3f) shl 24) or $80808080;
    result := 6;
  end;
end;

function Utf16SurrogateToUtf8(Dest: PUtf8Char; c1, c2: cardinal): PtrInt;
begin
  if c1 <= UTF16_HISURROGATE_MAX then
    c1 := ((c1 - UTF16_SURROGATE_OFFSET) shl 10) or
          (c2 xor UTF16_LOSURROGATE_MIN)
  else
    c1 := ((c2 - UTF16_SURROGATE_OFFSET) shl 10) or
          (c1 xor UTF16_LOSURROGATE_MIN);
  if (c1 >= UTF16_SURROGATE_MIN) and
     (c1 <= UTF16_SURROGATE_MAX) then // should be in U+10000 to U+10FFFF range
  begin
    PCardinal(Dest)^ := (c1 shr 18) or (((c1 shr 12) and $3f) shl 8) or
      (((c1 shr 6) and $3f) shl 16) or ((c1 and $3f) shl 24) or UTF8_10FF;
    result := 4;
  end
  else
  begin
    PCardinal(Dest)^ := UTF8_UNICODE_REPLACEMENT_CHARACTER; // U+fffd
    result := 3;
  end;
end;

function Utf16HiCharToUtf8(Dest: PUtf8Char; c: cardinal; var Source: PWord): PtrInt;
begin
  if c <= $7ff then // caller did process c <= $7f
  begin
    PWord(Dest)^ := (c shr 6) or ((c and $3f) shl 8) or UTF8_7FF;
    result := 2;
  end
  else if (c < UTF16_HISURROGATE_MIN) or
          (c > UTF16_LOSURROGATE_MAX) then
  begin // $800..$ffff but excluding $d800..$dfff UTF-16 surrogates
    PCardinal(Dest)^ := (c shr 12) or (((c shr 6) and $3f) shl 8) or
                        ((c and $3f) shl 16) or UTF8_FFFF;
    result := 3;
  end
  else // valid UTF-16 surrogates pair is always in range U+10000 to U+10FFFF
  begin
    result := Utf16SurrogateToUtf8(Dest, c, Source^);
    inc(Source);
  end;
end;

function RawUnicodeToUtf8(Dest: PUtf8Char; DestLen: PtrUInt; Source: PWideChar;
  SourceLen: PtrUInt; Flags: TCharConversionFlags): PtrUInt;
var
  c: cardinal;
begin
  result := PtrUInt(Dest);
  inc(DestLen, PtrUInt(Dest)); // PUtf8Char(DestLen) = end of Dest
  if (Source <> nil) and
     (PtrInt(SourceLen) > 0) and
     (Dest <> nil) then
  begin
    // ignore any trailing BOM (do exist on Windows files)
    if Source^ = BOM_UTF16LE then
    begin
      inc(Source);
      dec(SourceLen);
    end;
    // first handle 7-bit ASCII WideChars, by pairs (Sha optimization)
    SourceLen := PtrUInt(@Source[SourceLen - 2]);
    if (Dest < PUtf8Char(DestLen)) and
       (PtrUInt(Source) <= SourceLen) then
      repeat
        c := PCardinal(Source)^;
        if c and $ff80ff80 <> 0 then
          break; // break on first non ASCII pair
        inc(Source, 2);
        c := c shr 8 or c;
        PWord(Dest)^ := c;
        inc(Dest, 2);
      until (PtrUInt(Source) > SourceLen) or
            (Dest >= PUtf8Char(DestLen));
    inc(SourceLen, 4);
    // generic loop, handling one UCS-4 CodePoint per iteration
    repeat
      // inlined Utf16HiCharToUtf8() with buffer overlow check and $fffd unmatch
      if PtrUInt(Source) >= SourceLen then
        break;
      c := cardinal(Source^);
      inc(Source);
      if c <= $7f then // happens for the last odd byte
      begin
        if Dest >= PUtf8Char(DestLen) then
          break;
        Dest^ := AnsiChar(c);
        inc(Dest);
      end
      else if c <= $7ff then
      begin
        if @Dest[1] >= PUtf8Char(DestLen) then
          break;
        PWord(Dest)^ := (c shr 6) or ((c and $3f) shl 8) or UTF8_7FF;
        inc(Dest, 2);
      end
      else if (c < UTF16_HISURROGATE_MIN) or
              (c > UTF16_LOSURROGATE_MAX) then
      begin // $0800..$ffff but excluding $d800..$dfff UTF-16 surrogates
        if @Dest[2] >= PUtf8Char(DestLen) then
          break;
        PCardinal(Dest)^ := (c shr 12) or (((c shr 6) and $3f) shl 8) or
                            ((c and $3f) shl 16) or UTF8_FFFF;
        inc(Dest, 3);
      end
      else
      begin
        if (PtrUInt(Source) >= SourceLen) or
           (@Dest[3] >= PUtf8Char(DestLen)) then
          break;
        if c <= UTF16_HISURROGATE_MAX then // inlined Utf16SurrogateToUtf8()
          c := ((c - UTF16_SURROGATE_OFFSET) shl 10) or
               (cardinal(Source^) xor UTF16_LOSURROGATE_MIN)
        else
          c := ((cardinal(Source^) - UTF16_SURROGATE_OFFSET) shl 10) or
               (c xor UTF16_LOSURROGATE_MIN);
        inc(Source);
        if (c >= UTF16_SURROGATE_MIN) and
           (c <= UTF16_SURROGATE_MAX) then // in U+10000 to U+10FFFF range
        begin
          PCardinal(Dest)^ := (c shr 18) or (((c shr 12) and $3f) shl 8) or
            (((c shr 6) and $3f) shl 16) or ((c and $3f) shl 24) or UTF8_10FF;
          inc(Dest, 4);
        end
        else // invalid UTF-16 surrogate pairs
        begin
          if not (ccfReplacementCharacterForUnmatchedSurrogate in Flags) then
            break; // abort
          PCardinal(Dest)^ := UTF8_UNICODE_REPLACEMENT_CHARACTER; // U+fffd
          inc(Dest, 3);
        end;
      end;
    until false;
    if not (ccfNoTrailingZero in Flags) then
      Dest^ := #0;
  end;
  result := Dest - PUtf8Char(result);
end;

procedure RawUnicodeToUtf8(WideChar: PWideChar; WideCharCount: integer;
  var result: TSynTempBuffer; Flags: TCharConversionFlags);
begin
  if (WideChar = nil) or
     (WideCharCount <= 0) then
    result.Init(0)
  else
    result.Len := RawUnicodeToUtf8(result.Init(WideCharCount * 3),
      (WideCharCount * 3) + 16, WideChar, WideCharCount, Flags);
end;

procedure RawUnicodeToUtf8(WideChar: PWideChar; WideCharCount: integer;
  var result: RawUtf8; Flags: TCharConversionFlags);
var
  tmp: TSynTempBuffer;
begin
  RawUnicodeToUtf8(WideChar, WideCharCount, tmp, Flags);
  FastSetString(result, tmp.buf, tmp.len);
  tmp.Done;
end;

function RawUnicodeToUtf8(WideChar: PWideChar; WideCharCount: integer;
  Flags: TCharConversionFlags): RawUtf8;
begin
  RawUnicodeToUtf8(WideChar, WideCharCount, result, Flags);
end;

function RawUnicodeToUtf8(WideChar: PWideChar; WideCharCount: integer;
  out Utf8Length: integer): RawUtf8;
var
  lw: PtrInt;
begin
  result := ''; // somewhat faster if result is freed before any SetLength()
  if WideCharCount = 0 then
    exit;
  lw := WideCharCount * 3; // maximum resulting length
  SetLength(result, lw);
  Utf8Length := RawUnicodeToUtf8(pointer(result), lw + 1,
    WideChar, WideCharCount, [ccfNoTrailingZero]);
  if Utf8Length <= 0 then
    result := '';
end;

{$ifdef OSWINDOWS}
procedure _DoWin32PWideCharToUtf8(P: PWideChar; Len: PtrInt; var res: RawUtf8);
begin
  RawUnicodeToUtf8(P, Len, res); // our function is likely to be faster
end;
{$endif OSWINDOWS}

function Utf8ToWideChar(dest: PWideChar; source: PUtf8Char;
  MaxDestChars, sourceBytes: PtrUInt; NoTrailingZero: boolean): PtrInt;
var
  c: cardinal;
  begd: PWideChar;
  i, extra: PtrUInt;
label
  quit, nosource, by2;
begin // slightly slower overload with explicit destlen
  result := 0;
  if dest = nil then
    exit;
  if source = nil then
    goto nosource;
  if sourceBytes = 0 then
  begin
    if source^ = #0 then
      goto nosource;
    {$ifdef CPUX86}
    sourceBytes := StrLen(source);
    {$else} // better code generation without StrLen() call (almost never used)
    repeat
      inc(sourcebytes);
    until source[sourcebytes] = #0;
    {$endif CPUX86}
  end;
  inc(sourceBytes, PtrUInt(source)); // PUtf8Char(sourceBytes)  = endSource
  inc(MaxDestChars, PtrUInt(dest));  // PUtf8Char(MaxDestChars) = endDest
  begd := dest;
  repeat
    c := byte(source^);
    inc(source);
    if c <= $7f then
    begin
      if PtrUInt(dest) >= MaxDestChars then
        break; // avoid buffer overflow before writing
      PWord(dest)^ := c; // much faster than dest^ := WideChar(c) for FPC
      inc(dest);
      if PtrUInt(source) < sourceBytes then
        continue
      else
        break;
    end;
    extra := UTF8_TABLE.Lookup[c]; // a local variable won't help even on CPU64
    if PtrUInt(@source[extra]) > sourceBytes then
      break
    else if extra = 1 then // optimized for U+80..U+7FF common range
    begin
      if byte(source^) and $c0 <> $80 then
        break;
      c := (c shl 6) + cardinal(source^) - UTF8_EXTRA1_OFFSET; // c <= $ffff
      inc(source);
by2:  if PtrUInt(dest) >= MaxDestChars then
        break;
      PWord(dest)^ := c; // most simple encoding as a single WideChar
      inc(dest);
      if PtrUInt(source) < sourceBytes then
        continue
      else
        break;
    end
    else if extra > UTF8_MAX then // over RFC 3629 / Unicode range
      break;
    i := 0; // handle extra in 2..3 range
    repeat
      if byte(source[i]) and $c0 <> $80 then
        goto quit; // invalid input content
      c := (c shl 6) + cardinal(source[i]);
      inc(i);
    until i = extra;
    inc(source, extra);
    with UTF8_TABLE.Extra[extra] do
    begin
      dec(c, offset);
      if c < minimum then
        break; // stop at invalid input content
    end;
    if c < UTF16_HISURROGATE_MIN then
      goto by2 // U+800 .. U+D800: no surrogates needed
    else if c <= $ffff then
      if c > UTF16_LOSURROGATE_MAX then
        goto by2 // U+E000 .. U+FFFF: no surrogates needed
      else
        break; // c is a surrogate code! reject this malformed UTF-8 input
    dec(c, UTF16_SURROGATE_MIN); // store as UTF-16 surrogates
    if PtrUInt(@dest[1]) >= MaxDestChars then
      break;
    PCardinal(dest)^ := (c shr 10) or ((c and $3ff) shl 16) or
                        cardinal(UTF16_SURROGATE_FLAGS);
    inc(dest, 2);
    if PtrUInt(source) >= sourceBytes then
      break;
  until false;
quit:
  result := PtrUInt(dest) - PtrUInt(begd); // dest-begd return byte length
nosource:
  if not NoTrailingZero then
    dest^ := #0; // append a WideChar(0) to the end of the buffer
end;

function Utf8ToWideChar(dest: PWideChar; source: PUtf8Char; sourceBytes: PtrUInt;
  NoTrailingZero: boolean): PtrInt;
var
  c: cardinal;
  begd: PWideChar;
  endSourceBy4: PUtf8Char;
  i, extra: PtrInt;
label
  quit, nosource, by1, by4, next;
begin // expects dest to have source*3 bytes: more used than overload destlen
  result := 0;
  if dest = nil then
    exit;
  if source = nil then
    goto nosource;
  if sourceBytes = 0 then
  begin
    if source^ = #0 then
      goto nosource;
    {$ifdef CPUX86}
    sourceBytes := StrLen(source);
    {$else} // better code generation without StrLen() call (almost never used)
    repeat
      inc(sourcebytes);
    until source[sourcebytes] = #0;
    {$endif CPUX86}
  end;
  begd := dest;
  endSourceBy4 := @source[sourceBytes - 4];
  inc(sourceBytes, PtrUInt(source)); // PUtf8Char(sourceBytes) = endSource
  {$ifdef OSWINDOWS}
  if (source <= endSourceBy4) and
     (PCardinal(source)^ and $00ffffff = BOM_UTF8) then
    inc(source, 3); // ignore any UTF-8 BOM (may appear on Windows)
  {$endif OSWINDOWS}
  if source <= endSourceBy4 then
    repeat // handle 7-bit ASCII chars, by quad
      c := PCardinal(source)^;
      if c and $80808080 <> 0 then
        goto by1; // break on first non ASCII quad
by4:  inc(source, 4);
      PCardinal(dest)^ := (c shl 8 or (c and $ff)) and $00ff00ff;
      c := c shr 16;
      PCardinal(dest + 2)^ := (c shl 8 or c) and $00ff00ff;
      inc(dest, 4);
    until source > endSourceBy4;
  if PtrUInt(source) < sourceBytes then
    repeat
by1:  c := byte(source^);
      inc(source);
      if c <= $7f then // occurs for the last 1..3 remaining chars
      begin
        PWord(dest)^ := c; // much faster than dest^ := WideChar(c) for FPC
        inc(dest);
next:   if PtrUInt(source) >= sourceBytes then
          break
        else if source <= endSourceBy4 then
        begin
          c := PCardinal(source)^;
          if c and $80808080 = 0 then
            goto by4;
        end;
        continue;
      end;
      extra := UTF8_TABLE.Lookup[c]; // a local variable won't help even on CPU64
      if PtrUInt(source + extra) > sourceBytes then
        break
      else if extra = 1 then // optimized for U+80..U+7FF common range
      begin
        if byte(source^) and $c0 <> $80 then
          break;
        c := (c shl 6) + cardinal(source^) - UTF8_EXTRA1_OFFSET; // c <= $ffff
        inc(source);
        PWord(dest)^ := c;  // most simple encoding as a single WideChar
        inc(dest);
        goto next;
      end
      else if extra > UTF8_MAX then // over RFC 3629 / Unicode range
        break;
      i := 0; // handle extra in 2..3 range
      repeat
        if byte(source[i]) and $c0 <> $80 then
          goto quit; // invalid input content
        c := (c shl 6) + cardinal(source[i]);
        inc(i);
      until i = extra;
      inc(source, extra);
      with UTF8_TABLE.Extra[extra] do
      begin
        dec(c, offset);
        if c < minimum then
          break; // invalid input content
      end;
      if c <= $ffff then // check for surrogates code range
        if (c < UTF16_HISURROGATE_MIN) or    // U+800 .. U+D800
           (c > UTF16_LOSURROGATE_MAX) then  // U+E000 .. U+FFFF
        begin
          PWord(dest)^ := c;  // simple encoding as a single WideChar
          inc(dest);
          goto next;
        end
        else
          break; // c is a surrogate code! reject this malformed UTF-8 input
      dec(c, UTF16_SURROGATE_MIN); // store as UTF-16 surrogates
      PCardinal(dest)^ := (c shr 10) or ((c and $3ff) shl 16) or
                          cardinal(UTF16_SURROGATE_FLAGS);
      inc(dest, 2);
      goto next;
    until false;
quit:
  result := PtrUInt(dest) - PtrUInt(begd); // dest-begd returns bytes length
nosource:
  if not NoTrailingZero then
    dest^ := #0; // append a WideChar(0) to the end of the buffer
end;

function IsValidUtf8Pas(source: PUtf8Char; len: PtrInt): boolean;
var
  c: byte;
  utf8: PAnsiCharToByte;
label
  done;
begin
  inc(PtrUInt(len), PtrUInt(source) - 4);
  if source = nil then
    goto done;
  utf8 := @UTF8_TABLE.Lookup;
  repeat
    if source <= PUtf8Char(len) then
    begin
      if utf8[source[0]] = UTF8_ASCII then
        if utf8[source[1]] = UTF8_ASCII then
          if utf8[source[2]] = UTF8_ASCII then
            if utf8[source[3]] = UTF8_ASCII then
            begin
              inc(source, 4); // optimized for JSON-like content
              continue;
            end
            else
              inc(source, 3)
          else
            inc(source, 2)
        else
          inc(source);
    end
    else if source >= PUtf8Char(len) + 4 then
      break;
    c := utf8[source^]; // number of expected extra bytes (1..6)
    inc(source);
    if c = UTF8_ASCII then
      continue // last 1..3 chars
    else if c > UTF8_MAX then // RFC 3629 requirements as IsValidUtf8Avx2()
      if c = UTF8_ZERO then
        break // end of input - may be unexpected if not at source[len]
      else
      begin
        source := nil; // force result = false if does not follows RFC 3629
        break;
      end;
    repeat
      if byte(source^) and $c0 <> $80 then
        goto done;
      inc(source); // length check is done below - may read after source[len]
      dec(c);
    until c = 0;
  until false;
done:
  result := PtrUInt(source) = PtrUInt(len) + 4;
end;

function IsValidUtf8Ptr(source: PUtf8Char): boolean;
begin
  result := IsValidUtf8Buffer(source, StrLen(source));
end;

function IsValidUtf8Small(const source: RawByteString): boolean;
begin
  result := (source = '') or
    IsValidUtf8Pas(pointer(source), PStrLen(PAnsiChar(pointer(source)) - _STRLEN)^);
end;

function IsValidUtf8(const source: RawByteString): boolean;
begin
  result := (source = '') or
    IsValidUtf8Buffer(pointer(source), PStrLen(PAnsiChar(pointer(source)) - _STRLEN)^);
end;

{$ifdef ASMX64AVXNOCONST}
function IsValidUtf8NotVoid(source: PUtf8Char; len: PtrInt): boolean;
begin
  if (len >= 128) and // main AVX2 loop iterates on 64 bytes
     (cpuHaswell in X64CpuFeatures) then
    result := (ByteScanIndex(pointer(source), len, 0) < 0) and // detect #0
              IsValidUtf8Avx2(source, len)
  else
    result := IsValidUtf8Pas(source, len);
end;
{$else}
function IsValidUtf8NotVoid(source: PUtf8Char; len: PtrInt): boolean;
begin
  result := IsValidUtf8Pas(source, len);
end;
{$endif ASMX64AVXNOCONST}

function IsValidUtf8NotVoid(const source: RawByteString): boolean;
begin
  result := (source = '') or
    IsValidUtf8NotVoid(pointer(source), PStrLen(PAnsiChar(pointer(source)) - _STRLEN)^);
end;

procedure DetectRawUtf8(var source: RawByteString);
begin
  {$ifdef HASCODEPAGE} // do nothing on oldest Delphi
  if (source <> '') and
     IsValidUtf8Buffer(pointer(source), length(source)) then
    EnsureRawUtf8(source);
  {$endif HASCODEPAGE}
end;

function IsValidUtf8WithoutControlChars(source: PUtf8Char): boolean;
var
  c: byte;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
begin
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  result := false;
  if source <> nil then
    repeat
      c := byte(source^);
      inc(source);
      if c <= $7f then
        if c < 32 then
          if c = 0 then
            break // reached end of input
          else
            exit // disallow #1..#31 control char
        else
         continue;
      c := utf8.Lookup[c];
      if c > UTF8_MAX then // follow RFC 3629 expectations
        exit;
      // check valid UTF-8 content
      repeat
        if byte(source^) and $c0 <> $80 then
          exit;
        inc(source);
        dec(c);
      until c = 0;
    until false;
  result := true;
end;

function IsValidUtf8WithoutControlChars(const source: RawUtf8): boolean;
var
  s, len: PtrInt;
  c: byte;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
begin
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  result := false;
  s := 1;
  len := Length(source);
  while s <= len do
  begin
    c := byte(source[s]);
    inc(s);
    if c < 32 then
      exit // disallow #0..#31 control char within len
    else if c > $7f then
    begin
      c := utf8.Lookup[c];
      if c > UTF8_MAX then // follow RFC 3629 expectations
        exit;
      // check valid UTF-8 content
      repeat
        if byte(source[s]) and $c0 <> $80 then
          exit;
        inc(s);
        dec(c);
      until c = 0;
    end;
  end;
  result := true;
end;

function ContainsChars(const text, forbidden: RawUtf8): boolean;
begin
  result := (text <> '') and
            (forbidden <> '') and
            (strcspn(pointer(text), pointer(forbidden)) <>
               PStrLen(PAnsiChar(pointer(text)) - _STRLEN)^);
end;

function Utf8ToUnicodeLength(source: PUtf8Char): PtrUInt;
var
  c: byte;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
begin
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  result := 0;
  if source <> nil then
    repeat
      c := utf8.Lookup[byte(source^)]; // c = number of extra bytes
      inc(source);
      if c = UTF8_ASCII then
        inc(result)
      else if c > UTF8_MAX then
        exit // UTF8_ZERO or outside of RFC 3629 / Unicode range
      else
      begin
        inc(result, 1 + ord(c = UTF8_NEED_UTF16_SURROGATES));
        // check valid UTF-8 content
        repeat
          if byte(source^) and $c0 <> $80 then
            exit; // stop at invalid UTF-8 input
          inc(source);
          dec(c);
        until c = 0;
      end;
    until false;
end;

function Utf8TruncateToUnicodeLength(var text: RawUtf8; maxUtf16: integer): boolean;
var
  c: byte;
  source: PUtf8Char;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
label
  trunc;
begin
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  source := pointer(text);
  if (source <> nil) and
     (cardinal(maxUtf16) < cardinal(Length(text))) then
    repeat
      c := utf8.Lookup[byte(source^)];
      inc(source);
      if c = UTF8_ASCII then
      begin
        dec(maxUtf16);
        if maxUtf16 <> 0 then
          continue;
trunc:  SetLength(text, source - pointer(text));
        result := true;
        exit;
      end
      else if c > UTF8_MAX then
        break // UTF8_ZERO or outside of RFC 3629 / Unicode range
      else
      begin
        dec(maxUtf16, 1 + ord(c = UTF8_NEED_UTF16_SURROGATES));
        if maxUtf16 < 0 then
          goto trunc; // not enough place for this UTF-8 codepoint
        // check valid UTF-8 content
        repeat
          if byte(source^) and $c0 <> $80 then
            break;
          inc(source);
          dec(c);
        until c = 0;
        if maxUtf16 = 0 then
          goto trunc;
      end;
    until false;
  result := false;
end;

function Utf8TruncateToLength(var text: RawUtf8; maxBytes: PtrUInt): boolean;
begin
  if PtrUInt(Length(text)) < maxBytes then
  begin
    result := false;
    exit; // nothing to truncate
  end;
  while (maxBytes > 0) and
        (ord(text[maxBytes]) and $c0 = $80) do
    dec(maxBytes);
  if (maxBytes > 0) and
     (text[maxBytes] > #$7f) then
    dec(maxBytes);
  SetLength(text, maxBytes);
  result := true;
end;

function Utf8TruncatedLength(const text: RawUtf8; maxBytes: PtrUInt): PtrInt;
begin
  result := length(text);
  if PtrUInt(result) > maxBytes then
    result := Utf8TruncatedLength(pointer(text), result, maxBytes);
end;

function Utf8TruncatedLength(text: PAnsiChar; textlen, maxBytes: PtrUInt): PtrInt;
begin
  result := textlen;
  if textlen <= maxBytes then
    exit;
  dec(text);
  result := maxBytes;
  if (result = 0) or
     (text[result] <= #$7f) then // next byte is a new UTF-8 codepoint
    exit;
  while (result > 0) and
        (ord(text[result]) and $c0 = $80) do
    dec(result); // go just after the extra bytes
  if (result > 0) and
     (text[result] > #$7f) then
    dec(result); // go the end of previous UTF-8 codepoint
end;

function Utf8FirstLineToUtf16Length(source: PUtf8Char): PtrInt;
var
  c: PtrUInt;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
begin
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  result := 0;
  if source <> nil then
    repeat
      c := byte(source^);
      inc(source);
      if c <= $7f then
        if byte(c) in [0, 10, 13] then
          break // #0, #10 or #13 stop the count
        else
          inc(result)
      else
      begin
        c := utf8.Lookup[c];
        if c > UTF8_MAX then
          exit; // invalid leading byte for conversion to UTF-16
        inc(result, 1 + ord(c = UTF8_NEED_UTF16_SURROGATES));
        inc(source, c); // a bit less safe, but faster
      end;
    until false;
end;


{ ************** Cross-Platform Charset and CodePage Support }

function CharSetToCodePage(CharSet: integer): cardinal;
begin
  case CharSet of
    SHIFTJIS_CHARSET:
      result := 932;
    HANGEUL_CHARSET:
      result := 949;
    GB2312_CHARSET:
      result := 936;
    HEBREW_CHARSET:
      result := 1255;
    ARABIC_CHARSET:
      result := 1256;
    GREEK_CHARSET:
      result := 1253;
    TURKISH_CHARSET:
      result := 1254;
    VIETNAMESE_CHARSET:
      result := 1258;
    THAI_CHARSET:
      result := 874;
    EASTEUROPE_CHARSET:
      result := 1250;
    RUSSIAN_CHARSET:
      result := 1251;
    BALTIC_CHARSET:
      result := 1257;
  else
    result := CP_WINANSI; // default ANSI_CHARSET = iso-8859-1 = windows-1252
  end;
end;

function CodePageToCharSet(CodePage: cardinal): integer;
begin
  case CodePage of
    932:
      result := SHIFTJIS_CHARSET;
    949:
      result := HANGEUL_CHARSET;
    936:
      result := GB2312_CHARSET;
    1255:
      result := HEBREW_CHARSET;
    1256:
      result := ARABIC_CHARSET;
    1253:
      result := GREEK_CHARSET;
    1254:
      result := TURKISH_CHARSET;
    1258:
      result := VIETNAMESE_CHARSET;
    874:
      result := THAI_CHARSET;
    1250:
      result := EASTEUROPE_CHARSET;
    1251:
      result := RUSSIAN_CHARSET;
    1257:
      result := BALTIC_CHARSET;
  else
    result := ANSI_CHARSET; // default is iso-8859-1 = windows-1252
  end;
end;

function IsFixedWidthCodePage(aCodePage: cardinal): boolean;
begin
  result := ((aCodePage >= 1250) and
             (aCodePage <= 1258)) or
            (aCodePage = CP_LATIN1) or
            (aCodePage >= CP_RAWBLOB);
end;

function CodePageToText(aCodePage: cardinal): RawUtf8;
var
  tmp: TShort16;
begin
  Unicode_CodePageName(aCodePage, tmp);
  LowerCaseCopy(@tmp[1], ord(tmp[0]), result); // more convenient
end;

var
  _LcidToLanguage, _IsoTextToLanguage: cardinal; // naive but efficient cache

function LcidToLanguage(lcid: cardinal): TLanguage;
var
  i: PtrInt;
  last: cardinal;
begin
  last := _LcidToLanguage; // cache (accessing a 32-bit value is atomic)
  if last shr 8 = lcid then
  begin
    result := TLanguage(ToByte(last));
    exit;
  end;
  result := lngUndefined;
  i := ByteScanIndex(@LANG_PRI, length(LANG_PRI), lcid and 255);
  if i <= 0 then
    exit;
  result := TLanguage(i);
  if result = lngBosnian then
    case lcid shr 8 of
      $00, $04, $10:
        result := lngCroatian;
      $14, $20:
        result := lngBosnian;
    else
      result := lngSerbian;
    end;
  _LcidToLanguage := (lcid shl 8) + byte(result); // cache
end;

function LcidToText(lcid: cardinal): RawUtf8;
var
  lng: TLanguage;
begin
  lng := LcidToLanguage(lcid);
  if lng = lngUndefined then
    result := ''
  else
    result := LANG_TXT[lng]; // as set by mormot.core.rtti
end;

function IsoTextToLanguage(const Text: RawUtf8): TLanguage;
var
  last, lower: cardinal;
  i: PtrInt;
begin
  result := lngUndefined;
  if length(Text) <> 2 then
    exit;
  last := _IsoTextToLanguage; // atomic cache
  lower := PWord(Text)^ or $2020;
  if last shr 8 = lower then
  begin
    result := TLanguage(ToByte(last));
    exit;
  end;
  i := WordScanIndex(@LANG_ISO_SHORT[succ(low(result))], ord(high(result)), lower);
  if i < 0 then
    exit;
  result := TLanguage(i + 1);
  _IsoTextToLanguage := (lower shl 8) + byte(result); // cache
end;


{ **************** UTF-8 / Unicode / Ansi Conversion Classes }

{ TSynAnsiConvert }

function TSynAnsiConvert.AnsiBufferToUnicode(Dest: PWideChar;
  Source: PAnsiChar; SourceChars: cardinal; NoTrailingZero: boolean): PWideChar;
var
  c: cardinal;
begin
  if not fAnsiCharMbcs then
  begin
    // first handle trailing 7-bit ASCII chars, by quad (Sha optimization)
    if SourceChars >= 4 then
      repeat
        c := PCardinal(Source)^;
        if c and $80808080 <> 0 then
          break; // break on first non ASCII quad
        dec(SourceChars, 4);
        inc(Source, 4);
        PCardinal(Dest)^ := (c shl 8 or (c and $ff)) and $00ff00ff;
        c := c shr 16;
        PCardinal(Dest + 2)^ := (c shl 8 or c) and $00ff00ff;
        inc(Dest, 4);
      until SourceChars < 4;
    if (SourceChars > 0) and
       (ord(Source^) < 128) then
      repeat
        dec(SourceChars);
        PWord(Dest)^ := ord(Source^); // faster than dest^ := WideChar(c) on FPC
        inc(Source);
        inc(Dest);
      until (SourceChars = 0) or
            (ord(Source^) >= 128);
  end;
  if SourceChars > 0 then
    // rely on the Operating System for all remaining ASCII characters
    inc(Dest,
      Unicode_AnsiToWide(Source, Dest, SourceChars, SourceChars + 8, fCodePage));
  if not NoTrailingZero then
    Dest^ := #0;
  result := Dest;
end;

function TSynAnsiConvert.AnsiBufferToUtf8(Dest: PUtf8Char; Source: PAnsiChar;
  SourceChars: cardinal; NoTrailingZero: boolean): PUtf8Char;
var
  tmp: TSynTempBuffer;
  c: cardinal;
  u: PWideChar;
begin
  if not fAnsiCharMbcs then
  begin
    // first handle trailing 7-bit ASCII chars, by quad (Sha optimization)
    if SourceChars >= 4 then
      repeat
        c := PCardinal(Source)^;
        if c and $80808080 <> 0 then
          break; // break on first non ASCII quad
        PCardinal(Dest)^ := c;
        dec(SourceChars, 4);
        inc(Source, 4);
        inc(Dest, 4);
      until SourceChars < 4;
    if (SourceChars > 0) and
       (ord(Source^) < 128) then
      repeat
        Dest^ := Source^;
        dec(SourceChars);
        inc(Source);
        inc(Dest);
      until (SourceChars = 0) or
            (ord(Source^) >= 128);
  end;
  // rely on the Operating System for all remaining ASCII characters
  if SourceChars <= 0 then
    result := Dest
  else
  begin
    u := AnsiBufferToUnicode(tmp.Init(SourceChars * 2), Source, SourceChars);
    result := Dest + RawUnicodeToUtf8(Dest, SourceChars * 3, tmp.buf,
      (PtrUInt(u) - PtrUInt(tmp.buf)) shr 1, [ccfNoTrailingZero]);
    tmp.Done;
  end;
  if not NoTrailingZero then
    result^ := #0;
end;

// UTF-8 is AT MOST 50% bigger than UTF-16 in bytes in range U+0800..U+FFFF
// see http://stackoverflow.com/a/7008095 -> bytes=WideCharCount*3 below

{$ifndef PUREMORMOT2}

function TSynAnsiConvert.AnsiToRawUnicode(const AnsiText: RawByteString): RawUnicode;
begin
  result := AnsiToRawUnicode(pointer(AnsiText), length(AnsiText));
end;

function TSynAnsiConvert.AnsiToRawUnicode(Source: PAnsiChar;
  SourceChars: cardinal): RawUnicode;
var
  u: PWideChar;
  tmp: TSynTempBuffer;
begin
  if SourceChars = 0 then
    result := ''
  else
  begin
    u := AnsiBufferToUnicode(tmp.Init(SourceChars * 2), Source, SourceChars);
    u^ := #0;
    SetString(result, PAnsiChar(tmp.buf), PtrUInt(u) - PtrUInt(tmp.buf) + 1);
    tmp.Done;
  end;
end;

{$endif PUREMORMOT2}

procedure TSynAnsiConvert.AnsiToUnicodeStringVar(Source: PAnsiChar;
  SourceChars: cardinal; var Result: SynUnicode);
var
  tmp: TSynTempBuffer;
  u: PWideChar;
begin
  if SourceChars = 0 then
    Result := ''
  else
  begin
    u := AnsiBufferToUnicode(tmp.Init(SourceChars * 2), Source, SourceChars);
    FastSynUnicode(Result, tmp.buf, (PtrUInt(u) - PtrUInt(tmp.buf)) shr 1);
    tmp.Done;
  end;
end;

function TSynAnsiConvert.AnsiToUnicodeString(const Source: RawByteString): SynUnicode;
begin
  AnsiToUnicodeStringVar(pointer(Source), length(Source), result);
end;

function TSynAnsiConvert.AnsiToUtf8(const AnsiText: RawByteString): RawUtf8;
begin
  AnsiBufferToRawUtf8(pointer(AnsiText), length(AnsiText), result);
end;

procedure TSynAnsiConvert.AnsiBufferToRawUtf8(Source: PAnsiChar;
  SourceChars: cardinal; out Value: RawUtf8);
var
  tmp: TSynTempBuffer;
  p: PUtf8Char;
begin
  if (Source = nil) or
     (SourceChars = 0) then
    exit;
  p := AnsiBufferToUtf8(tmp.Init(SourceChars * 3), Source, SourceChars);
  FastSetString(Value, tmp.buf, p - tmp.buf);
  tmp.Done;
end;

constructor TSynAnsiConvert.Create(aCodePage: cardinal);
begin
  fCodePage := aCodePage;
  fAnsiCharShift := 1; // default is safe
  case aCodePage of
    CP_HZ,          // RFC 1842 defines ~} GB2312 escape mode
    50220 .. 52000: // rough IEC-2022 detection with $1b ESC [I..] F
      fAnsiCharMbcs := true;
  end;
  RegisterGlobalShutdownRelease(self);
end;

type
  // maintain the thread-safe internal list of TSynAnsiConvert instances
  TSynAnsiConvertList = record
    Last: TSynAnsiConvert;
    Lock: TRWLightLock;
    Count: integer;
    CodePage: TWordDynArray; // for (SSE2) fast lookup in CPU L1 cache
    Engine: array of TSynAnsiConvert;
  end;
var
  SynAnsiConvertList: TSynAnsiConvertList;

function GetEngine(var List: TSynAnsiConvertList; CodePage: cardinal): TSynAnsiConvert;
var
  i: PtrInt;
begin
  result := List.Last; // atomic cache
  if result <> nil then
    if result.CodePage = CodePage then
      exit // very common case
    else
      result := nil;
  List.Lock.ReadLock; // concurrent read lock
  i := WordScanIndex(pointer(List.CodePage), List.Count, CodePage);
  if i >= 0 then
    result := List.Engine[i];
  List.Lock.ReadUnLock;
  if result = nil then // thread-safe register a new TSynAnsiConvert instance
  begin
    List.Lock.WriteLock;
    try
      i := WordScanIndex(pointer(List.CodePage), List.Count, CodePage);
      if i < 0 then // really need to create
      begin
        if CodePage = CP_UTF16 then // hardly used: no global variable
          result := TSynAnsiUtf16.Create(CP_UTF16)
        else if IsFixedWidthCodePage(CodePage) then
          result := TSynAnsiFixedWidth.Create(CodePage) // use lookup table
        else
          result := TSynAnsiConvert.Create(CodePage); // use system API
        ObjArrayAdd(List.Engine, result);
        AddWord(List.CodePage, List.Count, CodePage);
      end
      else
        result := List.Engine[i];
    finally
      List.Lock.WriteUnLock;
    end;
  end;
  List.Last := result;
end;

class function TSynAnsiConvert.Engine(aCodePage: cardinal): TSynAnsiConvert;
begin
  if aCodePage <> CP_ACP then
    if aCodePage < CP_RAWBLOB then
      if aCodePage <> CP_UTF8 then
        if aCodePage <> CP_WINANSI then
          result := GetEngine(SynAnsiConvertList, aCodePage) // from list
        else
          result := WinAnsiConvert
      else
        result := Utf8AnsiConvert
    else
      result := RawByteStringConvert // CP_RAWBLOB is internal -> no engine
  else
    result := CurrentAnsiConvert;
end;

function TSynAnsiConvert.UnicodeBufferToAnsi(Dest: PAnsiChar;
  Source: PWideChar; SourceChars: cardinal): PAnsiChar;
var
  c: cardinal;
begin
  if (Source <> nil) and
     (SourceChars <> 0) then
  begin
    // ignore any trailing BOM (do exist on Windows files)
    if Source^ = BOM_UTF16LE then
    begin
      inc(Source);
      dec(SourceChars);
    end;
    if not fAnsiCharMbcs then
    begin
      // first handle trailing 7-bit ASCII chars, by pairs (Sha optimization)
      if SourceChars >= 2 then
        repeat
          c := PCardinal(Source)^;
          if c and $ff80ff80 <> 0 then
            break; // break on first non ASCII pair
          dec(SourceChars, 2);
          inc(Source, 2);
          c := c shr 8 or c;
          PWord(Dest)^ := c;
          inc(Dest, 2);
        until SourceChars < 2;
      if (SourceChars > 0) and
         (ord(Source^) < 128) then
        repeat
          Dest^ := AnsiChar(ord(Source^));
          dec(SourceChars);
          inc(Source);
          inc(Dest);
        until (SourceChars = 0) or
              (ord(Source^) >= 128);
    end;
    // rely on the Operating System for all remaining ASCII characters
    if SourceChars <> 0 then
      inc(Dest,
        Unicode_WideToAnsi(Source, Dest, SourceChars, SourceChars * 3 + 4, fCodePage));
  end;
  result := Dest;
end;

function TSynAnsiConvert.Utf8BufferToAnsi(Dest: PAnsiChar;
  Source: PUtf8Char; SourceChars: cardinal): PAnsiChar;
var
  tmp: TSynTempBuffer;
begin
  if (Source = nil) or
     (SourceChars = 0) then
    result := Dest
  else
  begin
    tmp.Init((SourceChars + 1) shl fAnsiCharShift);
    result := UnicodeBufferToAnsi(Dest, tmp.buf,
      Utf8ToWideChar(tmp.buf, Source, SourceChars) shr 1);
    tmp.Done;
  end;
end;

function TSynAnsiConvert.Utf8BufferToAnsi(
  Source: PUtf8Char; SourceChars: cardinal): RawByteString;
begin
  Utf8BufferToAnsi(Source, SourceChars, result);
end;

procedure TSynAnsiConvert.Utf8BufferToAnsi(Source: PUtf8Char; SourceChars: cardinal;
  var result: RawByteString);
var
  tmp: array[word] of AnsiChar;
  max: PtrInt;
begin
  if (Source = nil) or
     (SourceChars = 0) then
    result := ''
  else
  begin
    max := (SourceChars + 1) shl fAnsiCharShift;
    if max < SizeOf(tmp) then
      // use a temporary stack buffer up to 64KB
      FastSetStringCP(result, @tmp,
        Utf8BufferToAnsi(@tmp, Source, SourceChars) - PAnsiChar(@tmp), fCodePage)
    else
    begin
      // huge strings will be allocated once and truncated, not resized
      FastSetStringCP(result, nil, max, fCodePage);
      FakeLength(result,
        Utf8BufferToAnsi(pointer(result), Source, SourceChars) - pointer(result));
    end;
  end;
end;

function TSynAnsiConvert.Utf8ToAnsi(const u: RawUtf8): RawByteString;
begin
  if (u = '') or
     {$ifdef HASCODEPAGE} (GetCodePage(u) = fCodePage) {$else}
     IsAnsiCompatible(PAnsiChar(pointer(u)), Length(u)) {$endif HASCODEPAGE} then
    result := u
  else
    Utf8BufferToAnsi(pointer(u), length(u), result);
end;

function TSynAnsiConvert.Utf8ToAnsiBuffer2K(const S: RawUtf8;
  Dest: PAnsiChar; DestSize: integer): integer;
var
  tmp: array[0..2047] of AnsiChar; // truncated to 2KB as documented
begin
  if (DestSize <= 0) or
     (Dest = nil) then
  begin
    result := 0;
    exit;
  end;
  result := length(S);
  if result > 0 then
  begin
    if result > SizeOf(tmp) then
      result := SizeOf(tmp);
    result := Utf8BufferToAnsi(tmp{%H-}, pointer(S), result) - {%H-}tmp;
    if result >= DestSize then
      result := DestSize - 1;
    MoveFast(tmp, Dest^, result);
  end;
  Dest[result] := #0;
end;

procedure TSynAnsiConvert.UnicodeBufferToAnsiVar(Source: PWideChar;
  SourceChars: cardinal; var Result: RawByteString);
var
  tmp: TSynTempBuffer;
begin
  if (Source = nil) or
     (SourceChars = 0) then
    Result := ''
  else
  begin
    tmp.Init(SourceChars * 3);
    FastSetStringCP(Result, tmp.buf, UnicodeBufferToAnsi(
      tmp.buf, Source, SourceChars) - PAnsiChar(tmp.buf), fCodePage);
    tmp.Done;
  end;
end;

function TSynAnsiConvert.UnicodeStringToAnsi(const Source: SynUnicode): RawByteString;
begin
  UnicodeBufferToAnsiVar(pointer(Source), length(Source), result);
end;

{$ifndef PUREMORMOT2}
function TSynAnsiConvert.RawUnicodeToAnsi(const Source: RawUnicode): RawByteString;
begin
  UnicodeBufferToAnsiVar(pointer(Source), length(Source) shr 1, result);
end;
{$endif PUREMORMOT2}

function TSynAnsiConvert.AnsiToAnsi(From: TSynAnsiConvert;
  const Source: RawByteString): RawByteString;
begin
  if From = self then
    result := Source
  else
    result := AnsiToAnsi(From, pointer(Source), length(Source));
end;

function TSynAnsiConvert.AnsiToAnsi(From: TSynAnsiConvert;
  Source: PAnsiChar; SourceChars: cardinal): RawByteString;
var
  tmp: TSynTempBuffer;
  u: PWideChar;
begin
  if From.fCodePage = fCodePage then
    FastSetStringCP(result, Source, SourceChars, fCodePage)
  else if (Source = nil) or
          (SourceChars = 0) then
    result := ''
  else
  begin
    u := tmp.Init(SourceChars * 2);
    UnicodeBufferToAnsiVar(u,
      From.AnsiBufferToUnicode(u, Source, SourceChars) - u, result);
    tmp.Done;
  end;
end;


{ TSynAnsiFixedWidth }

function TSynAnsiFixedWidth.AnsiBufferToUnicode(Dest: PWideChar;
  Source: PAnsiChar; SourceChars: cardinal; NoTrailingZero: boolean): PWideChar;
var
  i: integer;
  tab: PWordArray;
begin
  // PWord*(Dest)[] is much faster than dest^ := WideChar(c) for FPC
  tab := pointer(fAnsiToWide);
  for i := 1 to SourceChars shr 2 do
  begin
    PWordArray(Dest)[0] := tab[Ord(Source[0])];
    PWordArray(Dest)[1] := tab[Ord(Source[1])];
    PWordArray(Dest)[2] := tab[Ord(Source[2])];
    PWordArray(Dest)[3] := tab[Ord(Source[3])];
    inc(Source, 4);
    inc(Dest, 4);
  end;
  for i := 1 to SourceChars and 3 do
  begin
    PWord(Dest)^ := tab[Ord(Source^)];
    inc(Dest);
    inc(Source);
  end;
  if not NoTrailingZero then
    Dest^ := #0;
  result := Dest;
end;

function TSynAnsiFixedWidth.AnsiBufferToUtf8(Dest: PUtf8Char;
  Source: PAnsiChar; SourceChars: cardinal; NoTrailingZero: boolean): PUtf8Char;
var
  srcEnd, srcEndBy4: PAnsiChar;
  c: cardinal;
label
  by4, by1; // ugly but faster
begin
  if (self = nil) or
     (Dest = nil) then
  begin
    result := nil;
    exit;
  end
  else if (Source <> nil) and
          (SourceChars > 0) then
  begin
    // handle 7-bit ASCII WideChars, by quads
    srcEnd := Source + SourceChars;
    srcEndBy4 := srcEnd - 4;
    if Source <= srcEndBy4 then
      repeat
        c := PCardinal(Source)^;
        if c and $80808080 <> 0 then
          goto by1; // break on first non ASCII quad
by4:    inc(Source, 4);
        PCardinal(Dest)^ := c;
        inc(Dest, 4);
      until Source > srcEndBy4;
    // generic loop, handling one WideChar per iteration
    if Source < srcEnd then
      repeat
by1:    c := byte(Source^);
        inc(Source);
        if c <= $7f then
        begin
          Dest^ := AnsiChar(c); // 0..127 don't need any translation
          Inc(Dest);
          if Source <= srcEndBy4 then
         begin
           c := PCardinal(Source)^;
           if c and $80808080 = 0 then
             goto by4;
           continue;
         end;
          if Source < srcEnd then
            continue
          else
            break;
        end
        else
        begin // cut-down version of Ucs4ToUtf8() with no surrogate expected
          c := fAnsiToWide[c]; // convert FixedAnsi char into Unicode char
          if c > $7ff then
          begin
            PCardinal(Dest)^ := (c shr 12) or (((c shr 6) and $3f) shl 8) or
                                ((c and $3f) shl 16) or UTF8_FFFF;
            Inc(Dest, 3);
            if Source <= srcEndBy4 then
            begin
              c := PCardinal(Source)^;
              if c and $80808080 = 0 then
                goto by4;
              continue;
            end;
            if Source < srcEnd then
              continue
            else
              break;
          end
          else
          begin
            PWord(Dest)^ := (c shr 6) or ((c and $3f) shl 8) or UTF8_7FF;
            Inc(Dest, 2);
            if Source < srcEndBy4 then
            begin
              c := PCardinal(Source)^;
              if c and $80808080 = 0 then
                goto by4;
              continue;
            end;
            if Source < srcEnd then
              continue
            else
              break;
          end;
        end;
      until false;
  end;
  if not NoTrailingZero then
    Dest^ := #0;
  {$ifdef ISDELPHI104}
  exit(Dest); // circumvent Delphi 10.4 optimizer bug
  {$else}
  result := Dest;
  {$endif ISDELPHI104}
end;

{$ifndef PUREMORMOT2}
function TSynAnsiFixedWidth.AnsiToRawUnicode(Source: PAnsiChar;
  SourceChars: cardinal): RawUnicode;
begin
  if SourceChars = 0 then
    result := ''
  else
  begin
    SetString(result, nil, SourceChars * 2 + 1);
    AnsiBufferToUnicode(pointer(result), Source, SourceChars);
  end;
end;
{$endif PUREMORMOT2}

const
  /// reference set for WinAnsi to Unicode conversion
  // - this table contains all the Unicode codepoints corresponding to
  // the Ansi Code Page 1252 (i.e. WinAnsi), which Unicode value are > 255
  // - values taken from MultiByteToWideChar(1252,0,@Tmp,256,@WinAnsiTable,256)
  // so are available outside the Windows platforms (e.g. Linux/BSD) and even
  // if the system has been tweaked as such:
  // http://www.fas.harvard.edu/~chgis/data/chgis/downloads/v4/howto/cyrillic.html
  WinAnsiUnicodeChars: packed array[128..159] of word = (
    8364, 129, 8218, 402, 8222, 8230, 8224, 8225, 710, 8240, 352, 8249, 338,
    141, 381, 143, 144, 8216, 8217, 8220, 8221, 8226, 8211, 8212, 732, 8482,
    353, 8250, 339, 157, 382, 376);

constructor TSynAnsiFixedWidth.Create(aCodePage: cardinal);
var
  i, len, c: PtrInt;
  a: array[0..255] of AnsiChar;
  u: array[0..255] of WideChar;
begin
  inherited;
  if not IsFixedWidthCodePage(aCodePage) then
    // warning: CreateUtf8() uses Utf8ToString() -> call CreateFmt() here
    raise ESynUnicode.CreateFmt('%s.Create - Invalid code page %d',
      [ClassNameShort(self)^, fCodePage]);
  // create internal look-up tables
  SetLength(fAnsiToWide, 256);
  if (aCodePage = CP_WINANSI) or
     (aCodePage = CP_LATIN1) or
     (aCodePage >= CP_RAWBLOB) then
  begin
    // Win1252 has its own table, LATIN1 and RawByteString map 8-bit Unicode
    for i := 0 to 255 do
      fAnsiToWide[i] := i;
    if aCodePage = CP_WINANSI then
      // do not trust the Windows API for the 1252 code page :(
      for i := low(WinAnsiUnicodeChars) to high(WinAnsiUnicodeChars) do
        fAnsiToWide[i] := WinAnsiUnicodeChars[i];
  end
  else
  begin
    // initialize table from Operating System returned values
    for i := 0 to 255 do
      a[i] := AnsiChar(i);
    FillcharFast(u, SizeOf(u), 0);
    // call mormot.core.os cross-platform Unicode_AnsiToWide()
    len := PtrUInt(inherited AnsiBufferToUnicode(u, a, 256)) - PtrUInt(@u);
    if (len < 500) or
       (len > 512) then
      // warning: CreateUtf8() uses Utf8ToString() -> call CreateFmt() now
      raise ESynUnicode.CreateFmt('OS error for %s.Create(%d) [%d]',
        [ClassNameShort(self)^, aCodePage, len]);
    MoveFast(u[0], fAnsiToWide[0], 512);
  end;
  SetLength(fWideToAnsi, 65536);
  for i := 1 to 126 do
    fWideToAnsi[i] := i;
  FillcharFast(fWideToAnsi[127], 65536 - 127, ord('?')); // '?' for unknown char
  for i := 127 to 255 do
  begin
    c := fAnsiToWide[i];
    if c <> 0 then
      fWideToAnsi[c] := i;
  end;
  // fixed width Ansi will never be bigger than UTF-8
  fAnsiCharShift := 0;
end;

function TSynAnsiFixedWidth.IsValidAnsi(WideText: PWideChar; Length: PtrInt): boolean;
var
  i: PtrInt;
  wc: PtrUInt;
begin
  result := false;
  if WideText <> nil then
    for i := 0 to Length - 1 do
    begin
      wc := PtrUInt(WideText[i]);
      if wc = 0 then
        break
      else if wc < 256 then
        if fAnsiToWide[wc] < 256 then
          continue
        else
          exit
      else if fWideToAnsi[wc] = ord('?') then
        exit
      else
        continue;
    end;
  result := true;
end;

function TSynAnsiFixedWidth.IsValidAnsi(WideText: PWideChar): boolean;
var
  wc: PtrUInt;
begin
  result := false;
  if WideText <> nil then
    repeat
      wc := PtrUInt(WideText^);
      inc(WideText);
      if wc = 0 then
        break
      else if wc < 256 then
        if fAnsiToWide[wc] < 256 then
          continue
        else
          exit
      else if fWideToAnsi[wc] = ord('?') then
        exit
      else
        continue;
    until false;
  result := true;
end;

function TSynAnsiFixedWidth.IsValidAnsiU(Utf8Text: PUtf8Char): boolean;
var
  extra: byte;
  c, n: cardinal;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
begin
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  result := false;
  if Utf8Text <> nil then
    repeat
      extra := utf8.Lookup[ord(Utf8Text^)];
      inc(Utf8Text);
      if extra = UTF8_ASCII then
        continue
      else if extra > UTF8_MAX then
        if extra = UTF8_ZERO then
          break // end of input
        else
          exit // invalid
      else
      begin
        n := extra;
        c := ord(Utf8Text[-1]);
        repeat
          if byte(Utf8Text^) and $c0 <> $80 then
            exit; // invalid UTF-8 content
          c := (c shl 6) + byte(Utf8Text^);
          inc(Utf8Text);
          dec(n)
        until n = 0;
        dec(c, utf8.Extra[extra].offset);
        if (c > $ffff) or
           (fWideToAnsi[c] = ord('?')) then
          exit; // invalid char in the WinAnsi code page
      end;
    until false;
  result := true;
end;

function TSynAnsiFixedWidth.IsValidAnsiU8Bit(Utf8Text: PUtf8Char): boolean;
var
  extra: byte;
  c: cardinal;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
begin
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  result := false;
  if Utf8Text <> nil then
    repeat
      extra := utf8.Lookup[ord(Utf8Text^)];
      inc(Utf8Text);
      if extra = UTF8_ASCII then
        continue
      else if extra > 1 then
        if extra = UTF8_ZERO then
          break // end of input
        else
          exit // invalid
      else
      begin // here extra = 1 for 00000080 - 000007FF range
        c := ord(Utf8Text[-1]);
        if byte(Utf8Text^) and $c0 <> $80 then
          exit; // invalid UTF-8 content
        c := (c shl 6) + byte(Utf8Text^);
        inc(Utf8Text);
        dec(c, UTF8_EXTRA1_OFFSET);
        if (c > 255) or
           (fAnsiToWide[c] > 255) then
          exit; // not 8-bit char (like "tm" or such) is marked invalid
      end;
    until false;
  result := true;
end;

function TSynAnsiFixedWidth.UnicodeBufferToAnsi(Dest: PAnsiChar;
  Source: PWideChar; SourceChars: cardinal): PAnsiChar;
var
  c: cardinal;
  tab: PAnsiChar;
begin
  if (Source <> nil) and
     (SourceChars <> 0) then
  begin
    // ignore any trailing BOM (do exist on Windows files)
    if Source^ = BOM_UTF16LE then
    begin
      inc(Source);
      dec(SourceChars);
    end;
    // first handle trailing 7-bit ASCII chars, by pairs (Sha optimization)
    if SourceChars >= 2 then
      repeat
        c := PCardinal(Source)^;
        if c and $ff80ff80 <> 0 then
          break; // break on first non ASCII pair
        dec(SourceChars, 2);
        inc(Source, 2);
        c := c shr 8 or c;
        PWord(Dest)^ := c;
        inc(Dest, 2);
      until SourceChars < 2;
    // use internal lookup tables for fast process of remaining chars
    tab := pointer(fWideToAnsi);
    for c := 1 to SourceChars shr 2 do
    begin
      Dest[0] := tab[Ord(Source[0])];
      Dest[1] := tab[Ord(Source[1])];
      Dest[2] := tab[Ord(Source[2])];
      Dest[3] := tab[Ord(Source[3])];
      inc(Source, 4);
      inc(Dest, 4);
    end;
    for c := 1 to SourceChars and 3 do
    begin
      Dest^ := tab[Ord(Source^)];
      inc(Dest);
      inc(Source);
    end;
  end;
  result := Dest;
end;

function TSynAnsiFixedWidth.Utf8BufferToAnsi(Dest: PAnsiChar;
  Source: PUtf8Char; SourceChars: cardinal): PAnsiChar;
var
  c: cardinal;
  srcEnd, srcEndBy4: PUtf8Char;
  i, extra: PtrInt;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
label
  by1, by4, quit; // ugly but faster
begin
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  // first handle trailing 7-bit ASCII chars, by quad (Sha optimization)
  srcEnd := Source + SourceChars;
  srcEndBy4 := srcEnd - 4;
  {$ifdef OSWINDOWS}
  if (Source <= srcEndBy4) and
     (PCardinal(Source)^ and $00ffffff = BOM_UTF8) then
    inc(Source, 3); // ignore any UTF-8 BOM (may appear on Windows)
  {$endif OSWINDOWS}
  if Source <= srcEndBy4 then
    repeat
      c := PCardinal(Source)^;
      if c and $80808080 <> 0 then
        goto by1; // break on first non ASCII quad
by4:  PCardinal(Dest)^ := c;
      inc(Source, 4);
      inc(Dest, 4);
    until Source > srcEndBy4;
  // generic loop, handling one UTF-8 code per iteration
  if Source < srcEnd then
  begin
    repeat
by1:  c := byte(Source^);
      inc(Source);
      if ord(c) <= $7f then
      begin
        Dest^ := AnsiChar(c);
        inc(Dest);
        if Source <= srcEndBy4 then
        begin
          c := PCardinal(Source)^;
          if c and $80808080 = 0 then
            goto by4;
          continue;
        end;
        if Source < srcEnd then
          continue
        else
          break;
      end
      else
      begin
        extra := utf8.Lookup[c];
        if (extra > UTF8_MAX) or
           (Source + extra > srcEnd) then
          break;
        i := extra;
        repeat
          if byte(Source^) and $c0 <> $80 then
            goto quit; // invalid UTF-8 content
          c := (c shl 6) + byte(Source^);
          inc(Source);
          dec(i);
        until i = 0;
        dec(c, utf8.Extra[extra].offset);
        if c > $ffff then
          Dest^ := '?' // '?' as in unknown fWideToAnsi[] items
        else
          Dest^ := AnsiChar(fWideToAnsi[c]);
        inc(Dest);
        if Source <= srcEndBy4 then
        begin
          c := PCardinal(Source)^;
          if c and $80808080 = 0 then
            goto by4;
          continue;
        end;
        if Source < srcEnd then
          continue
        else
          break;
      end;
    until false;
  end;
quit:
  result := Dest;
end;

function TSynAnsiFixedWidth.WideCharToAnsiChar(wc: cardinal): integer;
begin
  if wc < 256 then
    if fAnsiToWide[wc] < 256 then
      result := wc
    else
      result := -1
  else if wc <= 65535 then
  begin
    result := fWideToAnsi[wc];
    if result = ord('?') then
      result := -1;
  end
  else
    result := -1;
end;


{ TSynAnsiUtf8 }

function TSynAnsiUtf8.AnsiBufferToUnicode(Dest: PWideChar;
  Source: PAnsiChar; SourceChars: cardinal; NoTrailingZero: boolean): PWideChar;
begin
  result := Dest + (Utf8ToWideChar(Dest,
    PUtf8Char(Source), SourceChars, NoTrailingZero) shr 1);
end;

function TSynAnsiUtf8.AnsiBufferToUtf8(Dest: PUtf8Char;
  Source: PAnsiChar; SourceChars: cardinal; NoTrailingZero: boolean): PUtf8Char;
begin
  MoveFast(Source^, Dest^, SourceChars);
  if not NoTrailingZero then
    Dest[SourceChars] := #0;
  result := Dest + SourceChars;
end;

{$ifndef PUREMORMOT2}
function TSynAnsiUtf8.AnsiToRawUnicode(Source: PAnsiChar;
  SourceChars: cardinal): RawUnicode;
begin
  result := Utf8DecodeToRawUniCode(PUtf8Char(Source), SourceChars);
end;
{$endif PUREMORMOT2}

constructor TSynAnsiUtf8.Create(aCodePage: cardinal);
begin
  if aCodePage <> CP_UTF8 then
    raise ESynUnicode.CreateFmt('%s.Create(%d)', [ClassNameShort(self)^, aCodePage]);
  inherited Create(aCodePage);
end;

function TSynAnsiUtf8.UnicodeBufferToAnsi(Dest: PAnsiChar;
  Source: PWideChar; SourceChars: cardinal): PAnsiChar;
begin
  result := Dest + RawUnicodeToUtf8(PUtf8Char(Dest), SourceChars * 3,
    Source, SourceChars, [ccfNoTrailingZero]);
end;

procedure TSynAnsiUtf8.UnicodeBufferToAnsiVar(Source: PWideChar;
  SourceChars: cardinal; var Result: RawByteString);
var
  tmp: TSynTempBuffer;
begin
  if (Source = nil) or
     (SourceChars = 0) then
    Result := ''
  else
  begin
    tmp.Init(SourceChars * 3);
    FastSetStringCP(Result, tmp.buf, RawUnicodeToUtf8(tmp.buf,
      SourceChars * 3, Source, SourceChars, [ccfNoTrailingZero]), fCodePage);
    tmp.Done;
  end;
end;

function TSynAnsiUtf8.Utf8BufferToAnsi(Dest: PAnsiChar;
  Source: PUtf8Char; SourceChars: cardinal): PAnsiChar;
begin
  MoveFast(Source^, Dest^, SourceChars);
  result := Dest + SourceChars;
end;

procedure TSynAnsiUtf8.Utf8BufferToAnsi(Source: PUtf8Char; SourceChars: cardinal;
  var result: RawByteString);
begin
  FastSetString(RawUtf8(result), Source, SourceChars);
end;

function TSynAnsiUtf8.Utf8ToAnsi(const u: RawUtf8): RawByteString;
begin
  result := u; // may be read-only: no FastAssignUtf8/FakeCodePage
  EnsureRawUtf8(result);
end;

function TSynAnsiUtf8.AnsiToUtf8(const AnsiText: RawByteString): RawUtf8;
begin
  result := AnsiText; // may be read-only: no FastAssignUtf8/FakeCodePage
  EnsureRawUtf8(result);
end;

procedure TSynAnsiUtf8.AnsiBufferToRawUtf8(
  Source: PAnsiChar; SourceChars: cardinal; out Value: RawUtf8);
begin
  FastSetString(Value, Source, SourceChars);
end;


{ TSynAnsiUtf16 }

function TSynAnsiUtf16.AnsiBufferToUnicode(Dest: PWideChar;
  Source: PAnsiChar; SourceChars: cardinal; NoTrailingZero: boolean): PWideChar;
begin
  MoveFast(Source^, Dest^, SourceChars);
  result := pointer(PtrUInt(Dest) + SourceChars);
  if not NoTrailingZero then
    result^ := #0;
end;

const
  NOTRAILING: array[boolean] of TCharConversionFlags = (
    [], [ccfNoTrailingZero]);

function TSynAnsiUtf16.AnsiBufferToUtf8(Dest: PUtf8Char;
  Source: PAnsiChar; SourceChars: cardinal; NoTrailingZero: boolean): PUtf8Char;
begin
  SourceChars := SourceChars shr 1; // from byte count to WideChar count
  result := Dest + RawUnicodeToUtf8(Dest,
    SourceChars * 3, PWideChar(Source), SourceChars, NOTRAILING[NoTrailingZero]);
end;

{$ifndef PUREMORMOT2}
function TSynAnsiUtf16.AnsiToRawUnicode(Source: PAnsiChar;
  SourceChars: cardinal): RawUnicode;
begin
  SetString(result, Source, SourceChars); // byte count
end;
{$endif PUREMORMOT2}

constructor TSynAnsiUtf16.Create(aCodePage: cardinal);
begin
  if aCodePage <> CP_UTF16 then
    raise ESynUnicode.CreateFmt('%s.Create(%d)', [ClassNameShort(self)^, aCodePage]);
  inherited Create(aCodePage);
end;

function TSynAnsiUtf16.UnicodeBufferToAnsi(Dest: PAnsiChar;
  Source: PWideChar; SourceChars: cardinal): PAnsiChar;
begin
  SourceChars := SourceChars shl 1; // from WideChar count to byte count
  MoveFast(Source^, Dest^, SourceChars);
  result := Dest + SourceChars;
end;

function TSynAnsiUtf16.Utf8BufferToAnsi(Dest: PAnsiChar;
  Source: PUtf8Char; SourceChars: cardinal): PAnsiChar;
begin
  result := Dest + Utf8ToWideChar(PWideChar(Dest), Source, SourceChars, true);
end;


{ *************** Text File Loading with BOM/Unicode Support }

function BomFile(var Buffer: pointer; var BufferSize: PtrInt): TBomFile;
begin
  result := bomNone;
  if (Buffer <> nil) and
     (BufferSize >= 2) then
    case cardinal(PWord(Buffer)^) of
      ord(BOM_UTF16LE):
        begin
          inc(PByte(Buffer), 2);
          dec(BufferSize, 2);
          result := bomUtf16LE; // UTF-16 LE
        end;
      ord(BOM_UTF16BE):
        begin
          inc(PByte(Buffer), 2);
          dec(BufferSize, 2);
          result := bomUtf16BE; // UTF-16 BE
        end;
      BOM_UTF8 and $ffff:
        if (BufferSize >= 3) and
           (PByteArray(Buffer)[2] = (BOM_UTF8 shr 16)) then // UTF-8
        begin
          inc(PByte(Buffer), 3);
          dec(BufferSize, 3);
          result := bomUtf8;
        end;
    end;
end;

function StringFromBomFile(const FileName: TFileName; var FileContent: RawByteString;
  out Buffer: pointer; out BufferChars: PtrInt): TBomFile;
begin
  FileContent := StringFromFile(FileName);
  Buffer := pointer(FileContent);
  BufferChars := length(FileContent);
  result := BomFile(Buffer, BufferChars); // recognize most BOMs and adjust
  if BufferChars = 0 then
    result := bomNone
  else if result in [bomUtf16LE, bomUtf16BE] then
    BufferChars := BufferChars shr 1; // UTF-16 BOMs return size in WideChar
end;

function RawUtf8FromFile(const FileName: TFileName): RawUtf8;
begin
  result := AnyTextFileToRawUtf8(FileName, {AssumeUtf8IfNoBom=}true);
end;

procedure RawUnicodeSwapEndian(buf: PWord; len: PtrInt);
begin // internal function used with len > 0
  repeat
    buf^ := bswap16(buf^); // fast enough for our purpose (hardly used)
    inc(buf);
    dec(len)
  until len = 0;
end;

function AnyTextFileToRawUtf8(const FileName: TFileName; AssumeUtf8IfNoBom: boolean): RawUtf8;
var
  tmp: RawByteString;
  buf: pointer;
  chars: PtrInt;
begin
  case StringFromBomFile(FileName, tmp, buf, chars) of
    bomNone: // most common case, especially on POSIX
      if chars = 0 then
        FastAssignNew(result)
      else if AssumeUtf8IfNoBom or
              IsValidUtf8Buffer(buf, chars) then // may use AVX2 on Haswell
        FastAssignUtf8(result, tmp) // forced or detected CP_UTF8
      else
        CurrentAnsiConvert.AnsiBufferToRawUtf8(buf, chars, result);
    bomUtf16LE: // here chars = WideChar length
      RawUnicodeToUtf8(PWideChar(buf), chars, result);
    bomUtf16BE: // here chars = WideChar length
      begin
        RawUnicodeSwapEndian(buf, chars); // in-place conversion from Big-Endian
        RawUnicodeToUtf8(PWideChar(buf), chars, result);
      end;
    bomUtf8: // may appear on Windows
      begin
        MoveFast(buf^, pointer(tmp)^, chars); // fast in-place delete(bom)
        FakeLength(tmp, chars);
        FastAssignUtf8(result, tmp); // force CP_UTF8
      end;
  end;
end;

function AnyTextFileToSynUnicode(const FileName: TFileName; ForceUtf8: boolean): SynUnicode;
var
  tmp: RawByteString;
  buf: pointer;
  chars: PtrInt;
begin
  case StringFromBomFile(FileName, tmp, buf, chars) of
    bomNone: // most common case, especially on POSIX
      if (chars = 0) or
         ForceUtf8 or
         IsValidUtf8Buffer(buf, chars) then  // may use AVX2 on Haswell
        Utf8ToSynUnicode(buf, chars, result) // forced or detected CP_UTF8
      else
        CurrentAnsiConvert.AnsiToUnicodeStringVar(buf, chars, result);
    bomUtf16LE: // here chars = WideChar length
      FastSynUnicode(result, buf, chars);
    bomUtf16BE: // here chars = WideChar length
      begin
        RawUnicodeSwapEndian(buf, chars); // in-place conversion from Big-Endian
        FastSynUnicode(result, buf, chars);
      end;
    bomUtf8: // may appear on Windows
      Utf8ToSynUnicode(buf, chars, result);
  end;
end;

{$ifdef UNICODE}
function AnyTextFileToString(const FileName: TFileName; ForceUtf8: boolean): string;
begin
  result := AnyTextFileToSynUnicode(FileName, ForceUtf8);
end;
{$else}
function AnyTextFileToString(const FileName: TFileName; ForceUtf8: boolean): string;
var
  tmp: RawByteString;
  buf: pointer;
  chars: PtrInt;
begin
  case StringFromBomFile(FileName, tmp, buf, chars) of
    bomNone: // most common case, especially on POSIX
      if chars = 0 then
        result := ''
      else if IsAnsiCompatible(buf, chars) or
              not (ForceUtf8 or IsValidUtf8Buffer(buf, chars)) then // AVX2
      begin
        FakeCodePage(tmp, Unicode_CodePage); // StringFromFile() forced CP_UTF8
        result := tmp; // no need to convert anything
      end
      else // need a full charset conversion
        CurrentAnsiConvert.Utf8BufferToAnsi(buf, chars, RawByteString(result));
    bomUtf16LE: // here chars = WideChar length
      CurrentAnsiConvert.UnicodeBufferToAnsiVar(buf, chars, RawByteString(result));
    bomUtf16BE: // here chars = WideChar length
      begin
        RawUnicodeSwapEndian(buf, chars); // in-place conversion from Big-Endian
        CurrentAnsiConvert.UnicodeBufferToAnsiVar(buf, chars, RawByteString(result));
      end;
    bomUtf8: // may appear on Windows
      CurrentAnsiConvert.Utf8BufferToAnsi(buf, chars, RawByteString(result));
  end;
end;
{$endif UNICODE}


{ *************** Low-Level String Conversion Functions }

{$ifdef HASCODEPAGE}
procedure AnyAnsiToUtf8Var(const s: RawByteString; var result: RawUtf8);
var
  sr: PStrRec;
  cp: cardinal;
begin
  if result <> '' then
    FastAssignNew(result);
  if s = '' then
    exit;
  sr := PStrRec(PAnsiChar(pointer(s)) - _STRRECSIZE);
  cp := sr^.codePage;
  if cp = CP_UTF8 then
  begin
    if sr^.refCnt >= 0 then // inlined result := s of this RawUtf8 string
      StrCntAdd(sr^.refCnt);
    pointer(result) := pointer(s);
    exit;
  end;
  if cp = CP_ACP then
    cp := Unicode_CodePage; // most likely on FPC
  if (cp >= CP_RAWBLOB) or
     (cp = CP_UTF8) then
      if sr^.refCnt >= 0 then
      begin
        sr^.codePage := cp; // fix CP_ACP code page of s in-place
        StrCntAdd(sr^.refCnt);
        pointer(result) := pointer(s);
      end
      else // constant string: no convert, just copy as new CP_UTF8
        FastSetString(result, pointer(s), sr^.length)
  else // need a full charset conversion
    TSynAnsiConvert.Engine(cp).AnsiBufferToRawUtf8(pointer(s), sr^.length, result);
end;
{$else}
procedure AnyAnsiToUtf8Var(const s: RawByteString; var result: RawUtf8);
begin
  if (s = '') or
     IsValidUtf8Buffer(pointer(s), length(s)) then // slower but safe
    result := s
  else
    CurrentAnsiConvert.AnsiBufferToRawUtf8(pointer(s), length(s), result);
end;
{$endif HASCODEPAGE}

function AnyAnsiToUtf8(const s: RawByteString): RawUtf8;
begin
  AnyAnsiToUtf8Var(s, result);
end;

function WinAnsiBufferToUtf8(Dest: PUtf8Char;
  Source: PAnsiChar; SourceChars: cardinal): PUtf8Char;
begin
  result := WinAnsiConvert.AnsiBufferToUtf8(Dest, Source, SourceChars);
end;

function ShortStringToUtf8(const source: ShortString): RawUtf8;
begin
  WinAnsiConvert.AnsiBufferToRawUtf8(@source[1], ord(source[0]), result);
end;

procedure WinAnsiToUnicodeBuffer(const S: WinAnsiString; Dest: PWordArray; DestLen: PtrInt);
var
  len: PtrInt;
begin
  len := length(S);
  if len <> 0 then
  begin
    if len >= DestLen then
      len := DestLen - 1; // truncate to avoid buffer overflow
    WinAnsiConvert.AnsiBufferToUnicode(PWideChar(Dest), pointer(S), len);
    // including last #0
  end
  else
    Dest^[0] := 0;
end;

{$ifndef PUREMORMOT2}
function WinAnsiToRawUnicode(const S: WinAnsiString): RawUnicode;
begin
  result := WinAnsiConvert.AnsiToRawUnicode(S);
end;
{$endif PUREMORMOT2}

function WinAnsiToUtf8(const S: WinAnsiString): RawUtf8;
begin
  WinAnsiConvert.AnsiBufferToRawUtf8(pointer(S), length(S), result);
end;

function WinAnsiToUtf8(WinAnsi: PAnsiChar; WinAnsiLen: PtrInt): RawUtf8;
begin
  WinAnsiConvert.AnsiBufferToRawUtf8(WinAnsi, WinAnsiLen, result);
end;

function WideCharToWinAnsiChar(wc: cardinal): AnsiChar;
begin
  wc := WinAnsiConvert.WideCharToAnsiChar(wc);
  if integer(wc) = -1 then
    result := '?'
  else
    result := AnsiChar(wc);
end;

function WideCharToWinAnsi(wc: cardinal): integer;
begin
  result := WinAnsiConvert.WideCharToAnsiChar(wc);
end;

function IsWinAnsi(WideText: PWideChar; Length: integer): boolean;
begin
  result := WinAnsiConvert.IsValidAnsi(WideText, Length);
end;

function IsWinAnsi(WideText: PWideChar): boolean;
begin
  result := WinAnsiConvert.IsValidAnsi(WideText);
end;

function IsWinAnsiU(Utf8Text: PUtf8Char): boolean;
begin
  result := WinAnsiConvert.IsValidAnsiU(Utf8Text);
end;

function IsWinAnsiU8Bit(Utf8Text: PUtf8Char): boolean;
begin
  result := WinAnsiConvert.IsValidAnsiU8Bit(Utf8Text);
end;

function Utf8ToWinPChar(dest: PAnsiChar; source: PUtf8Char; count: integer): integer;
begin
  result := WinAnsiConvert.Utf8BufferToAnsi(dest, source, count) - dest;
end;

function Utf8ToWinAnsi(const S: RawUtf8): WinAnsiString;
begin
  result := WinAnsiConvert.Utf8ToAnsi(S);
end;

function Utf8ToWinAnsi(P: PUtf8Char): WinAnsiString;
begin
  result := WinAnsiConvert.Utf8ToAnsi(P);
end;

procedure Utf8ToRawUtf8(P: PUtf8Char; var result: RawUtf8);
begin
  // fast and Delphi 2009+ ready
  FastSetString(result, P, StrLen(P));
end;

{$ifndef PUREMORMOT2}

function Utf8DecodeToRawUnicode(P: PUtf8Char; L: integer): RawUnicode;
var
  tmp: TSynTempBuffer;
begin
  result := ''; // somewhat faster if result is freed before any SetLength()
  if L = 0 then
    L := StrLen(P);
  if L = 0 then
    exit;
  // +1 below is for #0 ending -> true WideChar(#0) ending
  tmp.Init(L * 3); // maximum posible unicode size (if all <#128)
  SetString(result, PAnsiChar(tmp.buf), Utf8ToWideChar(tmp.buf, P, L) + 1);
  tmp.Done;
end;

function Utf8DecodeToRawUnicode(const S: RawUtf8): RawUnicode;
begin
  if S = '' then
    result := ''
  else
    result := Utf8DecodeToRawUnicode(pointer(S), Length(S));
end;

function Utf8DecodeToRawUnicodeUI(const S: RawUtf8; DestLen: PInteger): RawUnicode;
var
  len: integer;
begin
  len := Utf8DecodeToRawUnicodeUI(S, result);
  if DestLen <> nil then
    DestLen^ := len;
end;

function Utf8DecodeToRawUnicodeUI(const S: RawUtf8; var Dest: RawUnicode): integer;
begin
  Dest := ''; // somewhat faster if Dest is freed before any SetLength()
  if S = '' then
  begin
    result := 0;
    exit;
  end;
  result := Length(S);
  SetLength(Dest, result * 2 + 2);
  result := Utf8ToWideChar(pointer(Dest), pointer(S), result);
end;

function RawUnicodeToUtf8(const Unicode: RawUnicode): RawUtf8;
begin
  RawUnicodeToUtf8(pointer(Unicode), Length(Unicode) shr 1, result);
end;

function RawUnicodeToSynUnicode(const Unicode: RawUnicode): SynUnicode;
begin
  FastSynUnicode(result, pointer(Unicode), Length(Unicode) shr 1);
end;

function RawUnicodeToWinAnsi(const Unicode: RawUnicode): WinAnsiString;
begin
  WinAnsiConvert.UnicodeBufferToAnsiVar(pointer(Unicode), Length(Unicode) shr 1,
    RawByteString(result));
end;

{$endif PUREMORMOT2}

function SynUnicodeToUtf8(const Unicode: SynUnicode): RawUtf8;
begin
  RawUnicodeToUtf8(pointer(Unicode), Length(Unicode), result);
end;

function RawUnicodeToSynUnicode(WideChar: PWideChar; WideCharCount: integer): SynUnicode;
begin
  FastSynUnicode(result, WideChar, WideCharCount);
end;

procedure RawUnicodeToWinPChar(dest: PAnsiChar; source: PWideChar; WideCharCount: integer);
begin
  WinAnsiConvert.UnicodeBufferToAnsi(dest, source, WideCharCount);
end;

function RawUnicodeToWinAnsi(WideChar: PWideChar; WideCharCount: integer): WinAnsiString;
begin
  WinAnsiConvert.UnicodeBufferToAnsiVar(WideChar, WideCharCount, RawByteString(result));
end;

function WideStringToWinAnsi(const Wide: WideString): WinAnsiString;
begin
  WinAnsiConvert.UnicodeBufferToAnsiVar(pointer(Wide), Length(Wide), RawByteString(result));
end;

procedure UnicodeBufferToWinAnsi(source: PWideChar; out Dest: WinAnsiString);
var
  len: PtrInt;
begin
  len := StrLenW(source);
  SetLength(Dest, len);
  WinAnsiConvert.UnicodeBufferToAnsi(pointer(Dest), source, len);
end;

function UnicodeBufferToString(source: PWideChar): string;
begin
  result := RawUnicodeToString(source, StrLenW(source));
end;

function UnicodeBufferToUtf8(source: PWideChar): RawUtf8;
begin
  RawUnicodeToUtf8(source, StrLenW(source), result);
end;

function UnicodeBufferTrimmedToUtf8(source: PWideChar): RawUtf8;
var
  l: PtrInt;
begin
  l := StrLenW(source);
  while (l <> 0) and
        (source[l - 1] <= ' ') do
    dec(l);
  RawUnicodeToUtf8(source, l, result);
end;

function UnicodeBufferToVariant(source: PWideChar): variant;
begin
  ClearVariantForString(result);
  if source <> nil then
    RawUnicodeToUtf8(source, StrLenW(source), RawUtf8(TVarData(result).VAny));
end;

function StringToVariant(const Txt: string): variant;
begin
  StringToVariant(Txt, result);
end;

procedure StringToVariant(const Txt: string; var result: variant);
begin
  ClearVariantForString(result);
  if Txt <> '' then
    {$ifndef UNICODE}
    if (Unicode_CodePage = CP_UTF8) or
       IsValidUtf8Buffer(pointer(Txt), length(Txt)) then
    begin
      RawByteString(TVarData(result).VAny) := Txt;
      EnsureRawUtf8(RawByteString(TVarData(result).VAny));
    end
    else
    {$endif UNICODE}
      StringToUtf8(Txt, RawUtf8(TVarData(result).VAny));
end;

procedure AnsiCharToUtf8(P: PAnsiChar; L: integer; var result: RawUtf8;
  CodePage: integer);
begin
  TSynAnsiConvert.Engine(CodePage).AnsiBufferToRawUtf8(P, L, result);
end;

function AnsiToUtf8(const Ansi: RawByteString; CodePage: integer): RawUtf8;
begin
  if Ansi = '' then
    result := ''
  else
    result := TSynAnsiConvert.Engine(CodePage).AnsiToUtf8(Ansi);
end;

function AnsiToString(const Ansi: RawByteString; CodePage: integer): string;
begin
  if Ansi = '' then
    result := ''
  else
    {$ifdef UNICODE}
    TSynAnsiConvert.Engine(CodePage).AnsiToUnicodeStringVar(
      pointer(Ansi), length(Ansi), result);
    {$else}
    result := CurrentAnsiConvert.AnsiToAnsi(TSynAnsiConvert.Engine(CodePage), Ansi);
    {$endif UNICODE}
end;

function AnsiBufferToTempUtf8(var Temp: TSynTempBuffer; Buf: PAnsiChar; BufLen,
  CodePage: cardinal): PUtf8Char;
begin
  if (BufLen = 0) or
     (CodePage = CP_UTF8) or
     (CodePage >= CP_RAWBLOB) or
     IsAnsiCompatible(Buf, BufLen) then
  begin
    temp.Buf := nil;
    temp.len := BufLen;
    result := PUtf8Char(Buf);
  end
  else
  begin
    temp.Init(BufLen * 3);
    Buf := pointer(TSynAnsiConvert.Engine(CodePage).
      AnsiBufferToUtf8(temp.Buf, Buf, BufLen));
    temp.len := Buf - PAnsiChar(temp.Buf);
    result := temp.Buf;
  end;
end;

{$ifdef UNICODE}

function Ansi7ToString(const Text: RawByteString): string;
var
  i: PtrInt;
begin
  FastSynUnicode(result, nil, Length(Text));
  for i := 0 to Length(Text) - 1 do
    PWordArray(result)[i] := cardinal(PByteArray(Text)[i]); // 7-bit assign
end;

function Ansi7ToString(Text: PWinAnsiChar; Len: PtrInt): string;
begin
  Ansi7ToString(Text, Len, result);
end;

procedure Ansi7ToString(Text: PWinAnsiChar; Len: PtrInt; var result: string);
var
  i: PtrInt;
begin
  FastSynUnicode(result, nil, Len);
  for i := 0 to Len - 1 do
    PWordArray(result)[i] := cardinal(PByteArray(Text)[i]); // 7-bit assign
end;

function StringToAnsi7(const Text: string): RawByteString;
var
  i: PtrInt;
begin
  FastSetString(RawUtf8(result), nil, Length(Text));
  for i := 0 to Length(Text) - 1 do
    PByteArray(result)[i] := PWordArray(Text)[i]; // no conversion for 7-bit
end;

function StringToWinAnsi(const Text: string): WinAnsiString;
begin
  result := RawUnicodeToWinAnsi(pointer(Text), Length(Text));
end;

function StringBufferToUtf8(Dest: PUtf8Char; Source: PChar; SourceChars: PtrInt): PUtf8Char;
begin
  result := Dest + RawUnicodeToUtf8(Dest, SourceChars * 3, PWideChar(Source), SourceChars, []);
end;

procedure StringBufferToUtf8(Source: PChar; out result: RawUtf8);
begin
  RawUnicodeToUtf8(Source, StrLenW(Source), result);
end;

function StringToUtf8(const Text: string): RawUtf8;
begin
  RawUnicodeToUtf8(pointer(Text), Length(Text), result);
end;

procedure StringToUtf8(Text: PChar; TextLen: PtrInt; var result: RawUtf8);
begin
  RawUnicodeToUtf8(Text, TextLen, result);
end;

procedure StringToUtf8(const Text: string; var result: RawUtf8);
begin
  RawUnicodeToUtf8(pointer(Text), Length(Text), result);
end;

function StringToUtf8(const Text: string; var Temp: TSynTempBuffer): integer;
var
  len: integer;
begin
  len := length(Text);
  Temp.Init(len * 3);
  result := RawUnicodeToUtf8(Temp.buf, Temp.len + 1, pointer(Text), len, []);
end;

function ToUtf8(const Text: string): RawUtf8;
begin
  RawUnicodeToUtf8(pointer(Text), Length(Text), result);
end;

{$ifndef PUREMORMOT2}

function StringToRawUnicode(const S: string): RawUnicode;
begin
  SetString(result, PAnsiChar(pointer(S)), length(S) * 2 + 1); // +1 for last wide #0
end;

function StringToRawUnicode(P: PChar; L: integer): RawUnicode;
begin
  SetString(result, PAnsiChar(P), L * 2 + 1); // +1 for last wide #0
end;

function RawUnicodeToString(const U: RawUnicode): string;
begin
  // uses StrLenW() and not length(U) to handle case when was used as buffer
  FastSynUnicode(result, pointer(U), StrLenW(pointer(U)));
end;

{$endif PUREMORMOT2}

function StringToSynUnicode(const S: string): SynUnicode;
begin
  result := S;
end;

procedure StringToSynUnicode(const S: string; var result: SynUnicode);
begin
  result := S;
end;

function RawUnicodeToString(P: PWideChar; L: integer): string;
begin
  FastSynUnicode(result, P, L);
end;

procedure RawUnicodeToString(P: PWideChar; L: integer; var result: string);
begin
  FastSynUnicode(result, P, L);
end;

function SynUnicodeToString(const U: SynUnicode): string;
begin
  result := U;
end;

function Utf8DecodeToString(P: PUtf8Char; L: integer): string;
begin
  Utf8DecodeToUnicodeString(P, L, result);
end;

procedure Utf8DecodeToString(P: PUtf8Char; L: integer; var result: string);
begin
  Utf8DecodeToUnicodeString(P, L, result);
end;

function Utf8ToString(const Text: RawUtf8): string;
begin
  Utf8DecodeToUnicodeString(pointer(Text), length(Text), result);
end;

procedure Utf8ToStringVar(const Text: RawUtf8; var result: string);
begin
  Utf8DecodeToUnicodeString(pointer(Text), length(Text), result);
end;

procedure Utf8ToFileName(const Text: RawUtf8; var result: TFileName);
begin
  Utf8DecodeToUnicodeString(pointer(Text), length(Text), string(result));
end;

{$else}

function Ansi7ToString(const Text: RawByteString): string;
begin
  result := Text; // if we are SURE this text is 7-bit Ansi -> direct assign
  {$ifdef FPC} // if Text is CP_RAWBYTESTRING then FPC won't handle it properly
  SetCodePage(RawByteString(result), Unicode_CodePage, false);
  {$endif FPC} // no FakeCodePage() since Text may be read-only
end;

function Ansi7ToString(Text: PWinAnsiChar; Len: PtrInt): string;
begin
  SetString(result, PAnsiChar(Text), Len);
end;

procedure Ansi7ToString(Text: PWinAnsiChar; Len: PtrInt; var result: string);
begin
  SetString(result, PAnsiChar(Text), Len);
end;

function StringToAnsi7(const Text: string): RawByteString;
begin
  result := Text; // if we are SURE this text is 7-bit Ansi -> direct assign
end;

function StringToWinAnsi(const Text: string): WinAnsiString;
begin
  result := WinAnsiConvert.AnsiToAnsi(CurrentAnsiConvert, Text);
end;

function StringBufferToUtf8(Dest: PUtf8Char; Source: PChar; SourceChars: PtrInt): PUtf8Char;
begin
  result := CurrentAnsiConvert.AnsiBufferToUtf8(Dest, Source, SourceChars);
end;

procedure StringBufferToUtf8(Source: PChar; out result: RawUtf8);
begin
  CurrentAnsiConvert.AnsiBufferToRawUtf8(Source, StrLen(Source), result);
end;

function StringToUtf8(const Text: string): RawUtf8;
begin
  result := CurrentAnsiConvert.AnsiToUtf8(Text);
end;

procedure StringToUtf8(Text: PChar; TextLen: PtrInt; var result: RawUtf8);
begin
  CurrentAnsiConvert.AnsiBufferToRawUtf8(Text, TextLen, result);
end;

procedure StringToUtf8(const Text: string; var result: RawUtf8);
begin
  result := CurrentAnsiConvert.AnsiToUtf8(Text);
end;

function StringToUtf8(const Text: string; var Temp: TSynTempBuffer): integer;
var
  len: PtrInt;
begin
  len := length(Text);
  Temp.Init(len * 3);
  if len <> 0 then
    result := CurrentAnsiConvert.
      AnsiBufferToUtf8(Temp.buf, pointer(Text), len) - PUtf8Char(Temp.buf)
  else
    result := 0;
end;

function ToUtf8(const Text: string): RawUtf8;
begin
  result := CurrentAnsiConvert.AnsiToUtf8(Text);
end;

{$ifndef PUREMORMOT2}

function StringToRawUnicode(const S: string): RawUnicode;
begin
  result := CurrentAnsiConvert.AnsiToRawUnicode(S);
end;

function StringToRawUnicode(P: PChar; L: integer): RawUnicode;
begin
  result := CurrentAnsiConvert.AnsiToRawUnicode(P, L);
end;

function RawUnicodeToString(const U: RawUnicode): string;
begin
  // uses StrLenW() and not length(U) to handle case when was used as buffer
  CurrentAnsiConvert.UnicodeBufferToAnsiVar(pointer(U), StrLenW(pointer(U)),
    RawByteString(result));
end;

{$endif PUREMORMOT2}

function StringToSynUnicode(const S: string): SynUnicode;
begin
  CurrentAnsiConvert.AnsiToUnicodeStringVar(pointer(S), length(S), result);
end;

procedure StringToSynUnicode(const S: string; var result: SynUnicode);
begin
  CurrentAnsiConvert.AnsiToUnicodeStringVar(pointer(S), length(S), result);
end;

function RawUnicodeToString(P: PWideChar; L: integer): string;
begin
  CurrentAnsiConvert.UnicodeBufferToAnsiVar(P, L, RawByteString(result));
end;

procedure RawUnicodeToString(P: PWideChar; L: integer; var result: string);
begin
  CurrentAnsiConvert.UnicodeBufferToAnsiVar(P, L, RawByteString(result));
end;

function SynUnicodeToString(const U: SynUnicode): string;
begin
  CurrentAnsiConvert.UnicodeBufferToAnsiVar(pointer(U), length(U), RawByteString(result));
end;

function Utf8DecodeToString(P: PUtf8Char; L: integer): string;
begin
  CurrentAnsiConvert.Utf8BufferToAnsi(P, L, RawByteString(result));
end;

procedure Utf8DecodeToString(P: PUtf8Char; L: integer; var result: string);
begin
  CurrentAnsiConvert.Utf8BufferToAnsi(P, L, RawByteString(result));
end;

function Utf8ToString(const Text: RawUtf8): string;
begin
  result := CurrentAnsiConvert.Utf8ToAnsi(Text);
end;

procedure Utf8ToStringVar(const Text: RawUtf8; var result: string);
begin
  result := CurrentAnsiConvert.Utf8ToAnsi(Text);
end;

procedure Utf8ToFileName(const Text: RawUtf8; var result: TFileName);
begin
  result := CurrentAnsiConvert.Utf8ToAnsi(Text);
end;

{$endif UNICODE}

function ToUtf8(const Ansi7Text: ShortString): RawUtf8;
begin
  FastSetString(result, @Ansi7Text[1], ord(Ansi7Text[0]));
end;

{$ifdef HASVARUSTRING} // some UnicodeString dedicated functions

function UnicodeStringToUtf8(const S: UnicodeString): RawUtf8;
begin
  RawUnicodeToUtf8(pointer(S), Length(S), result);
end;

function Utf8DecodeToUnicodeString(const S: RawUtf8): UnicodeString;
begin
  Utf8DecodeToUnicodeString(pointer(S), Length(S), result);
end;

procedure Utf8DecodeToUnicodeString(P: PUtf8Char; L: integer; var result: UnicodeString);
var
  tmp: TSynTempBuffer;
begin
  if (P = nil) or
     (L = 0) then
    result := ''
  else
  begin
    tmp.Init(L * 3); // maximum posible unicode size (if all <#128)
    FastSynUnicode(result, tmp.buf, Utf8ToWideChar(tmp.buf, P, L) shr 1);
    tmp.Done;
  end;
end;

function UnicodeStringToWinAnsi(const S: UnicodeString): WinAnsiString;
begin
  WinAnsiConvert.UnicodeBufferToAnsiVar(pointer(S), Length(S), RawByteString(result));
end;

function Utf8DecodeToUnicodeString(P: PUtf8Char; L: integer): UnicodeString;
begin
  Utf8DecodeToUnicodeString(P, L, result);
end;

function WinAnsiToUnicodeString(WinAnsi: PAnsiChar; WinAnsiLen: PtrInt): UnicodeString;
begin
  FastSynUnicode(result, nil, WinAnsiLen);
  WinAnsiConvert.AnsiBufferToUnicode(pointer(result), WinAnsi, WinAnsiLen);
end;

function WinAnsiToUnicodeString(const WinAnsi: WinAnsiString): UnicodeString;
begin
  result := WinAnsiToUnicodeString(pointer(WinAnsi), Length(WinAnsi));
end;

{$endif HASVARUSTRING}

function Utf8DecodeToUnicodeRawByteString(P: PUtf8Char; L: integer): RawByteString;
begin
  if (P <> nil) and
     (L <> 0) then
    FakeSetLength(result, Utf8ToWideChar(FastNewRawByteString(result, L * 3), P, L))
  else
    result := '';
end;

function Utf8DecodeToUnicodeRawByteString(const U: RawUtf8): RawByteString;
begin
  result := Utf8DecodeToUnicodeRawByteString(pointer(U), length(U));
end;

function Utf8DecodeToUnicodeStream(P: PUtf8Char; L: integer): TStream;
begin
  result := TRawByteStringStream.Create(Utf8DecodeToUnicodeRawByteString(P, L));
end;

function WinAnsiToSynUnicode(WinAnsi: PAnsiChar; WinAnsiLen: PtrInt): SynUnicode;
begin
  FastSynUnicode(result, nil, WinAnsiLen);
  WinAnsiConvert.AnsiBufferToUnicode(pointer(result), WinAnsi, WinAnsiLen);
end;

function WinAnsiToSynUnicode(const WinAnsi: WinAnsiString): SynUnicode;
begin
  result := WinAnsiToSynUnicode(pointer(WinAnsi), Length(WinAnsi));
end;

procedure UniqueRawUtf8ZeroToTilde(var u: RawUtf8; MaxSize: PtrInt);
var
  i: PtrInt;
begin
  i := length(u);
  if i > MaxSize then
    PByteArray(u)[MaxSize] := 0
  else
    MaxSize := i;
  for i := 0 to MaxSize - 1 do
    if PByteArray(u)[i] = 0 then
      PByteArray(u)[i] := ord('~');
end;

const
  ZEROED_CW = '~'; // any byte would do - followed by ~ or 0

function UnZeroed(const bin: RawByteString): RawUtf8;
var
  len, z, c: PtrInt;
  a: AnsiChar;
  s, d: PAnsiChar;
begin
  result := '';
  len := length(bin);
  if len = 0 then
    exit;
  s := pointer(bin);
  z := StrLen(s);
  c := ByteScanIndex(pointer(s), len, ord(ZEROED_CW));
  if (z = len) and
     (c < 0) then
  begin
    result := bin; // nothing to convert
    exit;
  end;
  if (c < 0) or
     (z < c) then
    c := z;
  d := FastSetString(result, len shl 1);
  MoveFast(s^, d^, c);
  inc(s, c);
  inc(d, c);
  dec(len, c);
  repeat
    a := s^;
    if a = #0 then
    begin
      d^ := ZEROED_CW;
      inc(d);
      a := '0';
    end
    else if a = ZEROED_CW then
    begin
      d^ := ZEROED_CW;
      inc(d);
    end;
    d^ := a;
    inc(d);
    inc(s);
    dec(len);
  until len = 0;
  FakeLength(result, d - pointer(result));
end;

function Zeroed(const u: RawUtf8): RawByteString;
var
  len, c: PtrInt;
  a: AnsiChar;
  s, d: PAnsiChar;
begin
  result := '';
  len := length(u);
  if len = 0 then
    exit;
  s := pointer(u);
  c := ByteScanIndex(pointer(s), len, ord(ZEROED_CW));
  if c < 0 then
  begin
    result := u;
    exit;
  end;
  d := FastNewString(len);
  pointer(result) := d;
  MoveFast(s^, d^, c);
  inc(s, c);
  inc(d, c);
  dec(len, c);
  repeat
    a := s^;
    if a = ZEROED_CW then
    begin
      inc(s);
      dec(len);
      if s^ = '0' then
        a := #0;
    end;
    d^ := a;
    inc(d);
    inc(s);
    dec(len);
  until len = 0;
  FakeLength(result, d - pointer(result));
end;

procedure Utf8ToWideString(const Text: RawUtf8; var result: WideString);
begin
  Utf8ToWideString(pointer(Text), Length(Text), result);
end;

function Utf8ToWideString(const Text: RawUtf8): WideString;
begin
  {$ifdef FPC}
  Finalize(result);
  {$endif FPC}
  Utf8ToWideString(pointer(Text), Length(Text), result);
end;

procedure Utf8ToWideString(Text: PUtf8Char; Len: PtrInt; var result: WideString);
var
  tmp: TSynTempBuffer;
begin
  if (Text = nil) or
     (Len = 0) then
    result := ''
  else
  begin
    tmp.Init(Len * 3); // maximum posible unicode size (if all <#128)
    SetString(result, PWideChar(tmp.buf), Utf8ToWideChar(tmp.buf, Text, Len) shr 1);
    tmp.Done;
  end;
end;

function WideStringToUtf8(const aText: WideString): RawUtf8;
begin
  RawUnicodeToUtf8(pointer(aText), length(aText), result);
end;

function Utf8ToSynUnicode(const Text: RawUtf8): SynUnicode;
begin
  Utf8ToSynUnicode(pointer(Text), length(Text), result);
end;

procedure Utf8ToSynUnicode(const Text: RawUtf8; var result: SynUnicode);
begin
  Utf8ToSynUnicode(pointer(Text), length(Text), result);
end;

procedure Utf8ToSynUnicode(Text: PUtf8Char; Len: PtrInt; var result: SynUnicode);
var
  tmp: TSynTempBuffer;
  n: PtrInt;
begin
  n := Utf8DecodeToUnicode(Text, Len, tmp);
  FastSynUnicode(result, tmp.buf, n);
  tmp.Done;
end;

function Utf8DecodeToUnicode(const Text: RawUtf8; var temp: TSynTempBuffer): PtrInt;
begin
  result := Utf8DecodeToUnicode(pointer(Text), length(Text), temp);
end;

function Utf8DecodeToUnicode(Text: PUtf8Char; Len: PtrInt; var temp: TSynTempBuffer): PtrInt;
begin
  if (Text = nil) or
     (Len <= 0) then
  begin
    temp.buf := nil;
    temp.len := 0;
    result := 0;
  end
  else
  begin
    temp.Init(Len * 3); // maximum posible unicode size (if all <#128)
    result := Utf8ToWideChar(temp.buf, Text, Len) shr 1; // as WideChar count
  end;
end;


{ **************** Text Case-(in)sensitive Conversion and Comparison }

function IdemPropNameUSameLenNotNull(P1, P2: PUtf8Char; P1P2Len: PtrInt): boolean;
label
  zero;
begin
  {$ifndef CPUX86}
  result := false;
  {$endif CPUX86}
  pointer(P1P2Len) := @P1[P1P2Len - SizeOf(cardinal)];
  dec(PtrUInt(P2), PtrUInt(P1));
  while PtrUInt(P1P2Len) >= PtrUInt(P1) do
    // compare 4 Bytes per loop
    if (PCardinal(P1)^ xor PCardinal(@P2[PtrUInt(P1)])^) and $dfdfdfdf <> 0 then
      goto zero
    else
      inc(PCardinal(P1));
  inc(P1P2Len, SizeOf(cardinal));
  while PtrUInt(P1) < PtrUInt(P1P2Len) do
    if (ord(P1^) xor ord(P2[PtrUInt(P1)])) and $df <> 0 then
      goto zero
    else
      inc(PByte(P1));
  result := true;
  exit;
zero:
  {$ifdef CPUX86}
  result := false;
  {$endif CPUX86}
end;

function PropNameValid(P: PUtf8Char): boolean;
var
  tab: PTextCharSet;
{%H-}begin
  tab := @TEXT_CHARS;
  if (P <> nil) and
     (tcIdentifierFirstChar in tab[P^]) then
    // first char must be in ['_', 'a'..'z', 'A'..'Z']
    repeat
      inc(P); // following chars can be ['_', '0'..'9', 'a'..'z', 'A'..'Z']
      if tcIdentifier in tab[P^] then
        continue;
      result := P^ = #0;
      exit;
    until false
  else
    result := false;
end;

function PropNamesValid(const Values: array of RawUtf8): boolean;
var
  i, j: PtrInt;
  tab: PTextCharSet;
begin
  result := false;
  tab := @TEXT_CHARS;
  for i := 0 to high(Values) do
    for j := 1 to length(Values[i]) do
      if not (tcIdentifier in tab[Values[i][j]]) then
        exit; // not ['_', '0'..'9', 'a'..'z', 'A'..'Z']
  result := true;
end;

function PropNameSanitize(const text, fallback: RawUtf8): RawUtf8;
var
  i: PtrInt;
begin
  result := text;
  for i := length(result) downto 1 do
    if result[i] in [#0 .. ' ', '#', '"', '''', '*'] then
      delete(result, i, 1);
  for i := 1 to length(result) do
    if result[i] in ['[', ']', '/', '\', '&', '@', '+', '-', '.'] then
      result[i] := '_';
  if not PropNameValid(pointer(result)) then
    result := fallback; // it was not good enough
end;

function IdemPropName(const P1, P2: ShortString): boolean;
begin
  result := (P1[0] = P2[0]) and
            ((P1[0] = #0) or
             (((ord(P1[1]) xor ord(P2[1])) and $df = 0) and
              IdemPropNameUSameLenNotNull(@P1[1], @P2[1], ord(P2[0]))));
end;

function IdemPropName(const P1: ShortString; P2: PUtf8Char; P2Len: PtrInt): boolean;
begin
  result := (ord(P1[0]) = P2Len) and
            ((P2Len = 0) or
             IdemPropNameUSameLenNotNull(@P1[1], P2, P2Len));
end;

function IdemPropName(P1, P2: PUtf8Char; P1Len, P2Len: PtrInt): boolean;
begin
  result := (P1Len = P2Len) and
            ((P1Len = 0) or
             IdemPropNameUSameLenNotNull(P1, P2, P1Len));
end;

function IdemPropNameU(const P1: RawUtf8; P2: PUtf8Char; P2Len: PtrInt): boolean;
begin
  if PtrUInt(P1) <> 0 then
    result := (PStrLen(PAnsiChar(pointer(P1)) - _STRLEN)^ = P2Len) and
              ((PByte(P1)^ xor PByte(P2)^) and $df = 0) and
              IdemPropNameUSameLenNotNull(pointer(P1), pointer(P2), P2Len)
  else
    result := P2Len = 0;
end;

function IdemPropNameU(const P1, P2: RawUtf8): boolean;
var
  len: TStrLen;
begin
  if PtrUInt(P1) <> PtrUInt(P2) then
    if (PtrUInt(P1) <> 0) and
       (PtrUInt(P2) <> 0) then
    begin
      len := PStrLen(PAnsiChar(pointer(P1)) - _STRLEN)^;
      result := (PStrLen(PAnsiChar(pointer(P2)) - _STRLEN)^ = len) and
                ((PByte(P1)^ xor PByte(P2)^) and $df = 0) and
                IdemPropNameUSameLenNotNull(pointer(P1), pointer(P2), len);
    end
    else
      result := false
  else
    result := true;
end;

function IdemPChar(p: PUtf8Char; up: PAnsiChar): boolean;
var
  {$ifdef CPUX86NOTPIC}
  table: TNormTable absolute NormToUpperAnsi7;
  {$else}
  table: PNormTable; // faster on PIC/ARM and x86_64
  {$endif CPUX86NOTPIC}
begin
  result := false;
  if p = nil then
    exit;
  if up <> nil then
  begin
    dec(PtrUInt(p), PtrUInt(up));
    {$ifndef CPUX86NOTPIC}
    table := @NormToUpperAnsi7;
    {$endif CPUX86NOTPIC}
    while true do
      if up^ = #0 then
        break
      else if table[up[PtrUInt(p)]] <> up^ then
        exit
      else
        inc(up);
  end;
  result := true;
end;

function IdemPChar(p: PUtf8Char; up: PAnsiChar; table: PNormTable): boolean;
begin
  result := false;
  if p = nil then
    exit;
  if up <> nil then
  begin
    dec(PtrUInt(p), PtrUInt(up));
    while true do
      if up^ = #0 then
        break
      else if table[up[PtrUInt(p)]] <> up^ then
        exit
      else
        inc(up);
  end;
  result := true;
end;

function IdemPCharAnsi(
  {$ifdef CPUX86NOTPIC}
  const table: TNormTable;
  {$else}
  const table: PNormTable;
  {$endif CPUX86NOTPIC}
  p: PUtf8Char; up: PAnsiChar): boolean; {$ifdef HASINLINE}inline;{$endif}
begin
  // in this local IdemPChar() version, p and up are expected to be <> nil
  dec(PtrUInt(p), PtrUInt(up));
  while true do
    if up^ = #0 then
      break
    else if table[up[PtrUInt(p)]] <> up^ then
    begin
      result := false;
      exit;
    end
    else
      inc(up);
  result := true;
end;

function IdemPCharByte(
  {$ifdef CPUX86NOTPIC}
  const table: TNormTableByte;
  {$else}
  const table: PByteArray;
  {$endif CPUX86NOTPIC}
  p: PUtf8Char; up: PAnsiChar): boolean; {$ifdef HASINLINE}inline;{$endif}
begin
  // in this local IdemPChar() version, p and up are expected to be <> nil
  dec(PtrUInt(p), PtrUInt(up));
  while true do
    if up^ = #0 then
      break
    else if table[PtrInt(up[PtrUInt(p)])] <> PByte(up)^ then
    begin
      result := false;
      exit;
    end
    else
      inc(up);
  result := true;
end;

function IdemPCharWithoutWhiteSpace(p: PUtf8Char; up: PAnsiChar): boolean;
begin
  result := false;
  if p = nil then
    exit;
  if up <> nil then
    while up^ <> #0 do
    begin
      while p^ <= ' ' do // trim white space
        if p^ = #0 then
          exit
        else
          inc(p);
      if up^ <> NormToUpperAnsi7[p^] then
        exit;
      inc(up);
      inc(p);
    end;
  result := true;
end;

function IdemPCharArray(p: PUtf8Char; const upArray: array of PAnsiChar): integer;
var
  w: word;
  up: ^PAnsiChar;
  {$ifdef CPUX86NOTPIC}
  tab: TNormTableByte absolute NormToUpperAnsi7;
  {$else}
  tab: PByteArray; // faster on PIC/ARM and x86_64
  {$endif CPUX86NOTPIC}
begin
  if p <> nil then
  begin
    {$ifndef CPUX86NOTPIC}
    tab := @NormToUpperAnsi7;
    {$endif CPUX86NOTPIC}
    w := PtrUInt(tab[ord(p[0])]) + PtrUInt(tab[ord(p[1])]) shl 8;
    up := @upArray[0];
    for result := 0 to high(upArray) do
      if (PWord(up^)^ = w) and
         IdemPCharByte(tab, p + 2, up^ + 2) then
        exit
      else
        inc(up);
  end;
  result := -1;
end;

function IdemPPChar(p: PUtf8Char; up: PPAnsiChar): PtrInt;
var
  w: word;
  u: PAnsiChar;
  p2: PtrUInt;
  c: byte;
  {$ifdef CPUX86NOTPIC}
  tab: TNormTableByte absolute NormToUpperAnsi7;
  {$else}
  tab: PByteArray; // faster on PIC/ARM and x86_64
  {$endif CPUX86NOTPIC}
begin
  if p <> nil then
  begin
    // uppercase the first two p^ chars
    {$ifndef CPUX86NOTPIC}
    tab := @NormToUpperAnsi7;
    {$endif CPUX86NOTPIC}
    w := PtrUInt(tab[ord(p[0])]) + PtrUInt(tab[ord(p[1])]) shl 8;
    result := 0;
    repeat
      // quickly check the first 2 up^[result] chars
      u := PPointerArray(up)[result];
      if u = nil then
        break
      else if PWord(u)^ <> w then
      begin
        inc(result);
        continue;
      end;
      // inlined if IdemPCharByte(tab, p + 2, up^ + 2) then exit
      p2 := PtrUInt(p);
      dec(p2, PtrUInt(u));
      inc(u, 2);
      repeat
        c := PByte(u)^;
        if c = 0 then
          exit   // found IdemPChar(p^, up^[result])
        else if tab[PtrUInt(u[p2])] <> c then
          break; // at least one char doesn't match
        inc(u);
      until false;
      inc(result);
    until false;
  end;
  result := -1;
end;

function IdemPCharSep(p, up: PUtf8Char): PtrInt;
var
  w: word;
  p2: PtrUInt;
  c: byte;
  {$ifdef CPUX86NOTPIC}
  tab: TNormTableByte absolute NormToUpperAnsi7;
  {$else}
  tab: PByteArray; // faster on PIC/ARM and x86_64
  {$endif CPUX86NOTPIC}
begin
  if p <> nil then
  begin
    // uppercase the first two p^ chars
    {$ifndef CPUX86NOTPIC}
    tab := @NormToUpperAnsi7;
    {$endif CPUX86NOTPIC}
    w := PtrUInt(tab[ord(p[0])]) + PtrUInt(tab[ord(p[1])]) shl 8;
    result := 0;
    repeat
      if PWord(up)^ = w then // quickly check the first 2 up chars
      begin
        p2 := PtrUInt(p); // = if IdemPCharByte(tab, p + 2, up^ + 2) then exit
        dec(p2, PtrUInt(up));
        inc(up, 2);
        repeat
          c := PByte(up)^;
          if c = ord('|') then
            exit   // found IdemPChar(p^, up^[result])
          else if tab[PtrUInt(up[p2])] <> c then
            break; // at least one char doesn't match
          inc(up);
        until false;
      end
      else
        inc(up);
      repeat
        inc(up);
      until up^ = '|';
      inc(result);
      inc(up);
    until up^ = #0;
  end;
  result := -1;
end;

function IdemPCharArrayBy2(p: PUtf8Char; const upArrayBy2Chars: RawUtf8): PtrInt;
begin
  if p <> nil then
    result := WordScanIndex(pointer(upArrayBy2Chars), length(upArrayBy2Chars) shr 1,
      NormToUpperAnsi7Byte[ord(p[0])] + NormToUpperAnsi7Byte[ord(p[1])] shl 8)
  else
    result := -1;
end;

function IdemPCharU(p, up: PUtf8Char): boolean;
begin
  result := false;
  if (p = nil) or
     (up = nil) then
    exit;
  while up^ <> #0 do
  begin
    if GetNextUtf8Upper(p) <> ord(up^) then
      exit;
    inc(up);
  end;
  result := true;
end;

function IdemPCharW(p: PWideChar; up: PUtf8Char): boolean;
begin
  result := false;
  if (p = nil) or
     (up = nil) then
    exit;
  while up^ <> #0 do
  begin
    if (p^ > #255) or
       (up^ <> AnsiChar(NormToUpperByte[ord(p^)])) then
      exit;
    inc(up);
    inc(p);
  end;
  result := true;
end;

function StartWith(const text, upTextStart: RawUtf8): boolean;
begin
  result := (PtrUInt(text) <> 0) and
            (PtrUInt(upTextStart) <> 0) and
            (PStrLen(PAnsiChar(pointer(text)) - _STRLEN)^ >=
              PStrLen(PAnsiChar(pointer(upTextStart)) - _STRLEN)^) and
            IdemPCharAnsi({$ifndef CPUX86NOTPIC}@{$endif}NormToUpperAnsi7,
              pointer(text), pointer(upTextStart));
end;

function EndWith(const text, upTextEnd: RawUtf8): boolean;
var
  o: PtrInt;
begin
  o := length(text) - length(upTextEnd);
  result := (o >= 0) and
            (text <> '') and
            IdemPCharAnsi({$ifndef CPUX86NOTPIC}@{$endif}NormToUpperAnsi7,
              PUtf8Char(pointer(text)) + o, pointer(upTextEnd));
end;

function EndWithArray(const text: RawUtf8; const upArray: array of RawUtf8): integer;
var
  t, o: PtrInt;
  {$ifdef CPUX86NOTPIC}
  tab: TNormTableByte absolute NormToUpperAnsi7;
  {$else}
  tab: PByteArray; // faster on PIC/ARM and x86_64
  {$endif CPUX86NOTPIC}
begin
  t := length(text);
  if t > 0 then
  begin
    {$ifndef CPUX86NOTPIC}
    tab := @NormToUpperAnsi7;
    {$endif CPUX86NOTPIC}
    for result := 0 to high(upArray) do
    begin
      o := t - length(upArray[result]);
      if (o >= 0) and
         ((upArray[result] = '') or
          IdemPCharByte(tab, PUtf8Char(pointer(text)) + o,
            pointer(upArray[result]))) then
        exit;
    end;
  end;
  result := -1;
end;

function FileExt(p: PUtf8Char; sepChar: AnsiChar): PUtf8Char;
  {$ifdef HASINLINE} inline; {$endif}
begin
  result := nil;
  repeat
    if p^ = sepChar then
      result := p; // get last '.' position from p into ext
    inc(p);
  until p^ = #0;
end;

function IdemFileExt(p: PUtf8Char; extup: PAnsiChar; sepChar: AnsiChar): boolean;
begin
  if (p <> nil) and
     (extup <> nil) then
    result := IdemPChar(FileExt(p, sepChar), extup)
  else
    result := false;
end;

function IdemFileExts(p: PUtf8Char; const extup: array of PAnsiChar;
  sepChar: AnsiChar): integer;
begin
  if (p <> nil) and
     (high(extup) > 0) then
    result := IdemPCharArray(FileExt(p, sepChar), extup)
  else
    result := -1;
end;

function PosCharAny(Str: PUtf8Char; Characters: PAnsiChar): PUtf8Char;
var
  s: PAnsiChar;
  c: AnsiChar;
begin
  if (Str <> nil) and
     (Characters <> nil) and
     (Characters^ <> #0) then
    repeat
      c := Str^;
      if c = #0 then
        break;
      result := Str;
      s := Characters;
      repeat
        if s^ = c then
          exit;
        inc(s);
      until s^ = #0;
      inc(Str);
    until false;
  result := nil;
end;

function PosI(uppersubstr: PUtf8Char; const str: RawUtf8): PtrInt;
var
  u: AnsiChar;
  {$ifdef CPUX86NOTPIC}
  table: TNormTable absolute NormToUpperAnsi7;
  {$else}
  table: PNormTable;
  {$endif CPUX86NOTPIC}
begin
  if uppersubstr <> nil then
  begin
    {$ifndef CPUX86NOTPIC}
    table := @NormToUpperAnsi7;
    {$endif CPUX86NOTPIC}
    u := uppersubstr^;
    for result := 1 to Length(str) do
      if table[str[result]] = u then
        if IdemPCharAnsi(table, @PUtf8Char(pointer(str))[result],
             PAnsiChar(uppersubstr) + 1) then
          exit;
  end;
  result := 0;
end;

function StrPosI(uppersubstr, str: PUtf8Char): PUtf8Char;
var
  u: AnsiChar;
  {$ifdef CPUX86NOTPIC}
  table: TNormTable absolute NormToUpperAnsi7;
  {$else}
  table: PNormTable;
  {$endif CPUX86NOTPIC}
begin
  if (uppersubstr <> nil) and
     (str <> nil) then
  begin
    {$ifndef CPUX86NOTPIC}
    table := @NormToUpperAnsi7;
    {$endif CPUX86NOTPIC}
    u := uppersubstr^;
    inc(uppersubstr);
    result := str;
    while result^ <> #0 do
    begin
      if table[result^] = u then
        if IdemPCharAnsi(table, result + 1, PAnsiChar(uppersubstr)) then
          exit;
      inc(result);
    end;
  end;
  result := nil;
end;

function PosIU(substr: PUtf8Char; const str: RawUtf8): integer;
var
  p: PUtf8Char;
begin
  if (substr <> nil) and
     (str <> '') then
  begin
    p := pointer(str);
    repeat
      if GetNextUtf8Upper(p) = ord(substr^) then
        if IdemPCharU(p, substr + 1) then
        begin
          result := p - pointer(str);
          exit;
        end;
    until p^ = #0;
  end;
  result := 0;
end;

function strspn(s, accept: pointer): integer;
// FPC is efficient at compiling this code, but is SLOWER when inlined
var
  p: PCardinal;
  c: AnsiChar;
  d: cardinal;
begin
  // returns size of initial segment of s which are in accept
  result := 0;
  repeat
    c := PAnsiChar(s)[result];
    if c = #0 then
      break;
    p := accept;
    repeat // stop as soon as we find any character not from accept
      d := p^;
      inc(p);
      if AnsiChar(d) = c then
        break
      else if AnsiChar(d) = #0 then
        exit;
      d := d shr 8;
      if AnsiChar(d) = c then
        break
      else if AnsiChar(d) = #0 then
        exit;
      d := d shr 8;
      if AnsiChar(d) = c then
        break
      else if AnsiChar(d) = #0 then
        exit;
      d := d shr 8;
      if AnsiChar(d) = c then
        break
      else if AnsiChar(d) = #0 then
        exit;
    until false;
    inc(result);
  until false;
end;

function strcspn(s, reject: pointer): integer;
// FPC is efficient at compiling this code, but is SLOWER when inlined
var
  p: PCardinal;
  c: AnsiChar;
  d: cardinal;
begin
  // returns size of initial segment of s which are not in reject
  result := 0;
  repeat
    c := PAnsiChar(s)[result];
    if c = #0 then
      break;
    p := reject;
    repeat // stop as soon as we find any character from reject
      d := p^;
      inc(p);
      if AnsiChar(d) = c then
        exit
      else if AnsiChar(d) = #0 then
        break;
      d := d shr 8;
      if AnsiChar(d) = c then
        exit
      else if AnsiChar(d) = #0 then
        break;
      d := d shr 8;
      if AnsiChar(d) = c then
        exit
      else if AnsiChar(d) = #0 then
        break;
      d := d shr 8;
      if AnsiChar(d) = c then
        exit
      else if AnsiChar(d) = #0 then
        break;
    until false;
    inc(result);
  until false;
end;

function StrCompL(P1, P2: pointer; L, Default: PtrInt): PtrInt;
var
  i: PtrInt;
begin
  i := 0;
  repeat
    result := PByteArray(P1)[i] - PByteArray(P2)[i];
    if result = 0 then
    begin
      inc(i);
      if i < L then
        continue
      else
        break;
    end;
    exit;
  until false;
  result := Default;
end;

function StrCompIL(P1, P2: pointer; L, Default: PtrInt): PtrInt;
var
  i: PtrInt;
  {$ifdef CPUX86NOTPIC}
  tab: TNormTableByte absolute NormToUpperAnsi7Byte;
  {$else}
  tab: PByteArray; // faster on PIC/ARM and x86_64
  {$endif CPUX86NOTPIC}
begin
  i := 0;
  {$ifndef CPUX86NOTPIC}
  tab := @NormToUpperAnsi7Byte;
  {$endif CPUX86NOTPIC}
  repeat
    if tab[PByteArray(P1)[i]] = tab[PByteArray(P2)[i]] then
    begin
      inc(i);
      if i < L then
        continue
      else
        break;
    end;
    result := PByteArray(P1)[i] - PByteArray(P2)[i];
    exit;
  until false;
  result := Default;
end;

function StrICompNotNil(Str1, Str2: pointer; Up: PNormTableByte): PtrInt;
var
  c1, c2: byte; // integer/PtrInt are actually slower on FPC
begin
  result := PtrInt(PtrUInt(Str2)) - PtrInt(PtrUInt(Str1));
  if result <> 0 then
  begin
    repeat
      c1 := Up[PByteArray(Str1)[0]];
      c2 := Up[PByteArray(Str1)[result]];
      inc(PByte(Str1));
    until (c1 = 0) or
          (c1 <> c2);
    result := c1 - c2;
  end;
end;

function StrICompLNotNil(Str1, Str2: pointer; Up: PNormTableByte; L: PtrInt): PtrInt;
begin
  result := 0;
  repeat
    if Up[PByteArray(Str1)[result]] = Up[PByteArray(Str2)[result]] then
    begin
      inc(result);
      if result < L then
        continue
      else
        break;
    end;
    result := PByteArray(Str1)[result] - PByteArray(Str2)[result];
    exit;
  until false;
  result := 0;
end;

function StrILNotNil(Str1, Str2: pointer; Up: PNormTableByte; L: PtrInt): PtrInt;
begin
  result := 0;
  repeat
    if Up[PByteArray(Str1)[result]] <> Up[PByteArray(Str2)[result]] then
      exit;
    inc(result);
  until result = L;
end;

function StrIComp(Str1, Str2: pointer): PtrInt;
var
  c1, c2: byte; // integer/PtrInt are actually slower on FPC
  {$ifdef CPUX86NOTPIC}
  table: TNormTableByte absolute NormToUpperAnsi7Byte;
  {$else}
  table: PByteArray;
  {$endif CPUX86NOTPIC}
begin
  result := PtrInt(PtrUInt(Str2)) - PtrInt(PtrUInt(Str1));
  if result <> 0 then
    if Str1 <> nil then
      if Str2 <> nil then
      begin
        {$ifndef CPUX86NOTPIC}
        table := @NormToUpperAnsi7Byte;
        {$endif CPUX86NOTPIC}
        repeat
          c1 := table[PByteArray(Str1)[0]];
          c2 := table[PByteArray(Str1)[result]];
          inc(PByte(Str1));
        until (c1 = 0) or
              (c1 <> c2);
        result := c1 - c2;
      end
      else
        // Str2=''
        result := 1
    else
      // Str1=''
      result := -1;
end;

function StrCompByNumber(Str1, Str2: pointer): PtrInt;
var
  v1, v2: Int64;
  err: integer;
begin
  v1 := GetInt64(Str1, err);
  if err = 0 then
    v2 := GetInt64(Str2, err)
  else
    v2 := 0; // to please the Delphi compiler
  if err = 0 then
    result := CompareInt64(v1, v2)
  else
    result := StrComp(Str1, Str2);
end;

function PosExtChar(P: PUtf8Char): PUtf8Char; // expects P to be a RawUtf8
var
  i: PtrInt;
begin // see POSIX-mode PosExtString() in mormot.core.os
  result := nil;
  if P <> nil then // excludes '.' at first position e.g. for '.htdigest'
    for i := PStrLen(P - _STRLEN)^ - 1 downto 1 do
      case P[i] of
        '/':
          exit; // reached end of filename
        '.':
          begin
            result := P + i + 1; // compare extension just after '.'
            exit;
          end;
      end;
end;

function StrCompPosixFileName(P1, P2: PUtf8Char): PtrInt;
begin // efficient case-sensitive comparison of the extension, then the name
  result := 0;
  if P1 = P2 then
    exit;
  result := StrComp(PosExtChar(P1), PosExtChar(P2));
  if result = 0 then
    result := StrComp(P1, P2);
end;

function _Utf8CompareOS(P1, P2: PUtf8Char; IgnoreCase: boolean): PtrInt;
var // use temporary UTF-16 conversion on stack
  w1, w2: PtrInt;
  t1, t2: array[0 .. 1023] of WideChar; // convert+compare up to 1023 widechars
begin // here P1<>nil and P2<>nil
  w1 := Utf8ToWideChar(@t1, p1, high(t1), StrLen(P1)) shr 1;
  w2 := Utf8ToWideChar(@t2, p2, high(t2), StrLen(P2)) shr 1;
  result := Unicode_CompareString(@t1, @t2, w1, w2, IgnoreCase) - 2; // OS API
  if (result = 0) and
     ((w1 >= high(t1) - 2) or // t1[]/t2[] buffer overflow of identical content?
      (w2 >= high(t2) - 2)) then // fallback to natural/byte order if too big
    if IgnoreCase then
      result := StrIComp(P1, P2) // support at least A-Z ASCII case
    else
      result := StrComp(P1, P2); // binary collation
end;

function Utf8CompareOS(P1, P2: PUtf8Char): PtrInt;
begin
  result := 0;
  if P1 <> P2 then
    if P1 <> nil then
      if P2 <> nil then
        result := _Utf8CompareOS(P1, P2, {ignorecase=}false)
      else
        inc(result) // P2=''
    else
      dec(result);  // P1=''
end;

function Utf8CompareIOS(P1, P2: PUtf8Char): PtrInt;
begin
  result := 0;
  if P1 <> P2 then
    if P1 <> nil then
      if P2 <> nil then
        result := _Utf8CompareOS(P1, P2, {ignorecase=}true)
      else
        inc(result) // P2=''
    else
      dec(result);  // P1=''
end;

function GetLineContains(p, pEnd, up: PUtf8Char): boolean;
var
  i: PtrInt;
  {$ifdef CPUX86NOTPIC}
  table: TNormTable absolute NormToUpperAnsi7Byte;
  {$else}
  table: PNormTable;
  {$endif CPUX86NOTPIC}
label
  fnd1, lf1, fnd2, lf2, ok; // ugly but fast
begin
  if (p <> nil) and
     (up <> nil) then
  begin
    {$ifndef CPUX86NOTPIC}
    table := @NormToUpperAnsi7;
    {$endif CPUX86NOTPIC}
    if pEnd = nil then
      repeat
        if p^ <= #13 then // p^ into a temp var is slower
          goto lf1
        else if table[p^] = up^ then
          goto fnd1;
        inc(p);
        continue;
lf1:    if (p^ = #0) or
           (p^ = #13) or
           (p^ = #10) then
          break;
        inc(p);
        continue;
fnd1:   i := 0;
        repeat
          inc(i);
          if up[i] <> #0 then
            if up[i] = table[p[i]] then
              continue
            else
              break
          else
          begin
ok:         result := true; // found
            exit;
          end;
        until false;
        inc(p);
      until false
    else
      repeat
        if p >= pEnd then
          break;
        if p^ <= #13 then
          goto lf2
        else if table[p^] = up^ then
          goto fnd2;
        inc(p);
        continue;
lf2:    if (p^ = #13) or
           (p^ = #10) then
          break;
        inc(p);
        continue;
fnd2:   i := 0;
        repeat
          inc(i);
          if up[i] = #0 then
            goto ok;
          if p + i >= pEnd then
            break;
        until up[i] <> table[p[i]];
        inc(p);
      until false;
  end;
  result := false;
end;

function ContainsUtf8(p, up: PUtf8Char): boolean;
var
  u: PByte;
begin
  if (p <> nil) and
     (up <> nil) and
     (up^ <> #0) then
  begin
    result := true;
    repeat
      u := pointer(up);
      repeat
        if GetNextUtf8Upper(p) <> u^ then
          break
        else
          inc(u);
        if u^ = 0 then
          exit; // up^ was found inside p^
      until false;
      p := FindNextUtf8WordBegin(p);
    until p = nil;
  end;
  result := false;
end;

function GetNextUtf8Upper(var U: PUtf8Char): Ucs4CodePoint;
begin
  result := ord(U^);
  if result = 0 then
    exit;
  if result <= $7f then
  begin
    inc(U);
    result := NormToUpperByte[result];
    exit;
  end;
  result := UTF8_TABLE.GetHighUtf8Ucs4(U);
  if (result <= 255) and
     (WinAnsiConvert.AnsiToWide[result] <= 255) then
    result := NormToUpperByte[result];
end;

function FindNextUtf8WordBegin(U: PUtf8Char): PUtf8Char;
var
  c: cardinal;
  v: PUtf8Char;
begin
  result := nil;
  repeat
    c := GetNextUtf8Upper(U);
    if c = 0 then
      exit;
  until (c >= 127) or
        not (tcWord in TEXT_BYTES[c]); // not ['0'..'9', 'a'..'z', 'A'..'Z']
  repeat
    v := U;
    c := GetNextUtf8Upper(U);
    if c = 0 then
      exit;
  until (c < 127) and
        (tcWord in TEXT_BYTES[c]);
  result := v;
end;

function AnsiICompW(u1, u2: PWideChar): PtrInt;
var
  c1, c2: PtrInt;
  {$ifdef CPUX86NOTPIC}
  table: TNormTableByte absolute NormToUpperAnsi7Byte;
  {$else}
  table: PByteArray;
  {$endif CPUX86NOTPIC}
begin
  if u1 <> u2 then
    if u1 <> nil then
      if u2 <> nil then
      begin
        {$ifndef CPUX86NOTPIC}
        table := @NormToUpperAnsi7Byte;
        {$endif CPUX86NOTPIC}
        repeat
          c1 := PtrInt(u1^);
          c2 := PtrInt(u2^);
          result := c1 - c2;
          if result <> 0 then
          begin
            if (c1 > 255) or
               (c2 > 255) then
              exit;
            result := table[c1] - table[c2];
            if result <> 0 then
              exit;
          end;
          if (c1 = 0) or
             (c2 = 0) then
            break;
          inc(u1);
          inc(u2);
        until false;
      end
      else
        result := 1
    else  // u2=''
      result := -1
  else // u1=''
    result := 0;      // u1=u2
end;

function AnsiIComp(Str1, Str2: pointer): PtrInt;
var
  c1, c2: byte; // integer/PtrInt are actually slower on FPC
  lookupper: PByteArray; // better x86-64 / PIC asm generation
begin
  result := PtrInt(PtrUInt(Str2)) - PtrInt(PtrUInt(Str1));
  if result <> 0 then
    if Str1 <> nil then
      if Str2 <> nil then
      begin
        lookupper := @NormToUpperByte;
        repeat
          c1 := lookupper[PByteArray(Str1)[0]];
          c2 := lookupper[PByteArray(Str1)[result]];
          inc(PByte(Str1));
        until (c1 = 0) or
              (c1 <> c2);
        result := c1 - c2;
      end
      else
        result := 1
    else  // Str2=''
      result := -1;     // Str1=''
end;

function SortDynArrayAnsiStringI(const A, B): integer;
begin
  result := StrIComp(PUtf8Char(A), PUtf8Char(B)); // very agressively inlined
end;

function SortDynArrayPUtf8CharI(const A, B): integer;
begin
  result := StrIComp(PUtf8Char(A), PUtf8Char(B));
end;

function SortDynArrayStringI(const A, B): integer;
begin
  {$ifdef UNICODE}
  result := AnsiICompW(PWideChar(A), PWideChar(B));
  {$else}
  result := StrIComp(PUtf8Char(A), PUtf8Char(B));
  {$endif UNICODE}
end;

function SortDynArrayUnicodeStringI(const A, B): integer;
begin
  result := AnsiICompW(PWideChar(A), PWideChar(B));
end;

function ConvertCaseUtf8(P, D: PUtf8Char; const Table: TNormTableByte): PtrInt;
var
  s: PUtf8Char;
  c: PtrUInt;
  extra, i: PtrInt;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
begin
  result := 0;
  if P = nil then
    exit;
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  repeat
    c := byte(P[0]);
    inc(P);
    if c = 0 then
      break;
    if c <= $7f then
    begin
      D[result] := AnsiChar(Table[c]);
      inc(result);
    end
    else
    begin
      extra := utf8.Lookup[c];
      if extra = UTF8_INVALID then
        exit; // invalid leading byte (allow full UTF-8/UCS-4 range)
      i := 0;
      repeat
        if byte(P[i]) and $c0 <> $80 then
          exit; // invalid input content
        c := (c shl 6) + byte(P[i]);
        inc(i);
      until i = extra;
      with utf8.Extra[extra] do
      begin
        dec(c, offset);
        if c < minimum then
          exit; // invalid input content
      end;
      if (c <= 255) and
         (Table[c] <= $7f) then
      begin
        D[result] := AnsiChar(Table[c]);
        inc(result);
        inc(P, extra);
        continue;
      end;
      s := P - 1;
      inc(P, extra);
      inc(extra);
      MoveByOne(s, D + result, extra);
      inc(result, extra);
    end;
  until false;
end;

function UpperCaseU(const S: RawUtf8): RawUtf8;
var
  ls, ld: PtrInt;
begin
  ls := length(S);
  ld := ConvertCaseUtf8(pointer(S), FastSetString(result, ls), NormToUpperByte);
  if ls <> ld then
    FakeLength(result, ld);
end;

function LowerCaseU(const S: RawUtf8): RawUtf8;
var
  ls, ld: PtrInt;
begin
  ls := length(S);
  ld := ConvertCaseUtf8(pointer(S), FastSetString(result, ls), NormToLowerByte);
  if ls <> ld then
    FakeLength(result, ld);
end;

function Utf8IComp(u1, u2: PUtf8Char): PtrInt;
var
  c2: PtrInt;
  {$ifdef CPUX86NOTPIC}
  table: TNormTableByte absolute NormToUpperByte;
  {$else}
  table: PByteArray;
  {$endif CPUX86NOTPIC}
label
  c2low;
begin
  // fast UTF-8 comparison using the NormToUpper[] array for all 8-bit values
  {$ifndef CPUX86NOTPIC}
  table := @NormToUpperByte;
  {$endif CPUX86NOTPIC}
  if u1 <> u2 then
    if u1 <> nil then
      if u2 <> nil then
        repeat
          result := ord(u1^);
          c2 := ord(u2^);
          if result <= $7f then
            if result <> 0 then
            begin
              inc(u1);
              result := table[result];
              if c2 <= $7f then
              begin
c2low:          if c2 = 0 then
                  exit; // u1>u2 -> return u1^
                inc(u2);
                dec(result, table[c2]);
                if result <> 0 then
                  exit;
                continue;
              end;
            end
            else
            begin
              // u1^=#0 -> end of u1 reached
              if c2 <> 0 then    // end of u2 reached -> u1=u2 -> return 0
                result := -1;    // u1<u2
              exit;
            end
          else
          begin
            if result and $20 = 0 then // fast $0..$7ff process
            begin
              result := (result shl 6) + byte(u1[1]) - UTF8_EXTRA1_OFFSET;
              inc(u1, 2);
            end
            else
              result := UTF8_TABLE.GetHighUtf8Ucs4(u1);
            if result <= 255 then
              result := table[result]; // 8-bit to upper, 32-bit as is
          end;
          if c2 <= $7f then
            goto c2low
          else if c2 and $20 = 0 then // fast $0..$7ff process
          begin
            c2 := (c2 shl 6) + byte(u2[1]) - UTF8_EXTRA1_OFFSET;
            inc(u2, 2);
          end
          else
            c2 := UTF8_TABLE.GetHighUtf8Ucs4(u2);
          if c2 <= 255 then
            c2 := table[c2]; // 8-bit to upper
          dec(result, c2);
          if result <> 0 then
            exit;
        until false
      else
        result := 1 // u2=''
    else
      result := -1  // u1=''
  else
    result := 0;    // u1=u2
end;

function Utf8ILComp(u1, u2: PUtf8Char; L1, L2: cardinal): PtrInt;
var
  c2: PtrInt;
  extra, i: integer;
  {$ifdef CPUX86NOTPIC}
  table: TNormTableByte absolute NormToUpperByte;
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  table: PByteArray;
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
label
  neg, pos;
begin
  // fast UTF-8 comparison using the NormToUpper[] array for all 8-bit values
  {$ifndef CPUX86NOTPIC}
  table := @NormToUpperByte;
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  if u1 <> u2 then
    if (u1 <> nil) and
       (L1 <> 0) then
      if (u2 <> nil) and
         (L2 <> 0) then
        repeat
          result := ord(u1^);
          c2 := ord(u2^);
          inc(u1);
          dec(L1);
          if result <= $7f then
          begin
            result := table[result];
            if c2 <= $7f then
            begin
              // 'a'..'z' / 'A'..'Z' case insensitive comparison
              dec(result, table[c2]);
              dec(L2);
              inc(u2);
              if result <> 0 then
                // found unmatching char
                exit
              else if L1 <> 0 then
                if L2 <> 0 then
                  // L1>0 and L2>0 -> next char
                  continue
                else
                  // L1>0 and L2=0 -> u1>u2
                  goto pos
              else
              if L2 <> 0 then
                // L1=0 and L2>0 -> u1<u2
                goto neg
              else
                // L1=0 and L2=0 -> u1=u2 -> returns 0
                exit;
            end;
          end
          else
          begin
            // Win-1252 case insensitive comparison
            extra := utf8.Lookup[result];
            if extra = UTF8_INVALID then
              goto neg; // invalid leading byte (allow full UTF-8/UCS-4 range)
            dec(L1, extra);
            if integer(L1) < 0 then
              goto neg;
            i := 0;
            repeat
              result := result shl 6;
              inc(result, ord(u1[i]));
              inc(i);
            until i = extra;
            inc(u1, extra);
            dec(result, utf8.Extra[extra].offset);
            if result and $ffffff00 = 0 then
              // 8-bit to upper conversion, 32-bit as is
              result := table[result];
          end;
          // here result=NormToUpper[u1^]
          inc(u2);
          dec(L2);
          if c2 <= $7f then
          begin
            dec(result, table[c2]);
            if result <> 0 then
              // found unmatching char
              exit;
          end
          else
          begin
            extra := utf8.Lookup[c2];
            if extra = UTF8_INVALID then
              goto pos; // invalid leading byte (allow full UTF-8/UCS-4 range)
            dec(L2, extra);
            if integer(L2) < 0 then
              goto pos;
            i := 0;
            repeat
              c2 := c2 shl 6;
              inc(c2, ord(u2[i]));
              inc(i);
            until i = extra;
            inc(u2, extra);
            dec(c2, utf8.Extra[extra].offset);
            if c2 and $ffffff00 = 0 then
              // 8-bit to upper
              dec(result, table[c2])
            else
              // returns 32-bit diff
              dec(result, c2);
            if result <> 0 then
              // found unmatching char
              exit;
          end;
          // here we have result=NormToUpper[u2^]-NormToUpper[u1^]=0
          if L1 = 0 then
            // test if we reached end of u1 or end of u2
            if L2 = 0 then
              // u1=u2
              exit
            else
              // u1<u2
              goto neg
          else
          if L2 = 0 then
            // u1>u2
            goto pos;
        until false
      else
pos:    // u2='' or u1>u2
        result := 1
    else
neg:  // u1='' or u1<u2
      result := -1
  else
    // u1=u2
    result := 0;
end;

function SameTextU(const S1, S2: RawUtf8): boolean;
// checking UTF-8 lengths is not accurate: surrogates may be confusing
begin
  result := Utf8IComp(pointer(S1), pointer(S2)) = 0;
end;

function FindAnsi(A, UpperValue: PAnsiChar): boolean;
var
  beg: PAnsiChar;
begin
  result := false;
  if (A = nil) or
     (UpperValue = nil) then
    exit;
  beg := UpperValue;
  repeat
    // test beginning of word
    repeat
      if A^ = #0 then
        exit
      else if tcWord in TEXT_CHARS[NormToUpper[A^]] then
        break
      else
        inc(A);
    until false;
    // check if this word is the UpperValue
    UpperValue := beg;
    repeat
      if NormToUpper[A^] <> UpperValue^ then
        break;
      inc(UpperValue);
      if UpperValue^ = #0 then
      begin
        result := true; // UpperValue found!
        exit;
      end;
      inc(A);
      if A^ = #0 then
        exit;
    until false;
    // find beginning of next word
    repeat
      if A^ = #0 then
        exit
      else if not (tcWord in TEXT_CHARS[NormToUpper[A^]]) then
        break
      else
        inc(A);
    until false;
  until false;
end;

function FindUnicode(PW, Upper: PWideChar; UpperLen: PtrInt): boolean;
var
  beg: PWideChar;
  w: PtrUInt;
begin
  result := false;
  if (PW = nil) or
     (Upper = nil) then
    exit;
  repeat
    // go to beginning of next word
    repeat
      w := ord(PW^);
      if w = 0 then
        exit
      else if (w > 126) or
              (tcWord in TEXT_BYTES[w]) then
        break;
      inc(PW);
    until false;
    beg := PW;
    // search end of word matching UpperLen characters
    repeat
      inc(PW);
      w := ord(PW^);
    until (PW - beg >= UpperLen) or
          (w = 0) or
          ((w < 127) and
           not (tcWord in TEXT_BYTES[w]));
    if PW - beg >= UpperLen then
      if Unicode_CompareString(beg, Upper, UpperLen, UpperLen,
           {ignorecase=}true) = 2 then
      begin
        result := true; // case-insensitive match found
        exit;
      end;
    // not found: go to end of current word
    repeat
      w := ord(PW^);
      if w = 0 then
        exit
      else if ((w < 127) and
              not (tcWord in TEXT_BYTES[w])) then
        break;
      inc(PW);
    until false;
  until false;
end;

function FindUtf8(U: PUtf8Char; UpperValue: PAnsiChar): boolean;
var
  beg: PAnsiChar;
  c: PtrUInt;
  first: AnsiChar;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
label
  Next;
begin
  result := false;
  if (U = nil) or
     (UpperValue = nil) then
    exit;
  // handles 8-bits WinAnsi chars inside UTF-8 encoded data
  {$ifndef CPUX86NOTPIC}
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  first := UpperValue^;
  beg := UpperValue + 1;
  repeat
    // test beginning of word
    repeat
      c := byte(U^);
      inc(U);
      if c = 0 then
        exit;
      if c <= $7f then
      begin
        if tcWord in TEXT_BYTES[c] then
          if PAnsiChar(@NormToUpper)[c] <> first then
            goto Next
          else
            break;
      end
      else if c and $20 = 0 then
      begin
        // fast direct process of $0..$7ff codepoints including accents
        c := ((c shl 6) + byte(U^)) - UTF8_EXTRA1_OFFSET;
        inc(U);
        if c <= 255 then
        begin
          c := NormToUpperByte[c];
          if tcWord in TEXT_BYTES[c] then
            if AnsiChar(c) <> first then
              goto Next
            else
              break;
        end;
      end
      else
      begin
        c := utf8.Lookup[c];
        if c = UTF8_INVALID then
          exit // invalid leading byte (allow full UTF-8/UCS-4 range)
        else
          // just ignore surrogates for soundex
          inc(U, c);
      end;
      until false;
    // here we had the first char match -> check if this word match UpperValue
    UpperValue := beg;
    repeat
      if UpperValue^ = #0 then
      begin
        result := true; // UpperValue found!
        exit;
      end;
      c := byte(U^);
      inc(U); // next chars
      if c = 0 then
        exit
      else if c <= $7f then
      begin
        if PAnsiChar(@NormToUpper)[c] <> UpperValue^ then
          break;
      end
      else if c and $20 = 0 then
      begin
        c := ((c shl 6) + byte(U^)) - UTF8_EXTRA1_OFFSET;
        inc(U);
        if (c > 255) or
           (PAnsiChar(@NormToUpper)[c] <> UpperValue^) then
          break;
      end
      else
      begin
        c := utf8.Lookup[c];
        if c = UTF8_INVALID then
          exit // invalid leading byte (allow full UTF-8/UCS-4 range)
        else
          inc(U, c);
        break;
      end;
      inc(UpperValue);
    until false;
Next: // find beginning of next word
    U := FindNextUtf8WordBegin(U);
  until U = nil;
end;

function UpperCopy255(dest: PAnsiChar; const source: RawUtf8): PAnsiChar;
begin
  if source <> '' then
    result := UpperCopy255Buf(
      dest, pointer(source), PStrLen(PAnsiChar(pointer(source)) - _STRLEN)^)
  else
    result := dest;
end;

function UpperCopy255Buf(dest: PAnsiChar; source: PUtf8Char; sourceLen: PtrInt): PAnsiChar;
var
  i, c, d {$ifdef CPU64}, _80, _61, _7b {$endif}: PtrUInt;
begin
  if sourceLen <> 0 then
  begin
    if sourceLen > 248 then
      sourceLen := 248; // avoid buffer overflow
    // we allow to copy up to 3/7 more chars in Dest^ since its size is 255
    {$ifdef CPU64}
    // unbranched uppercase conversion of 8 chars blocks
    _80 := PtrUInt($8080808080808080); // use registers for constants
    _61 := $6161616161616161;
    _7b := $7b7b7b7b7b7b7b7b;
    for i := 0 to (sourceLen - 1) shr 3 do
    begin
      c := PPtrUIntArray(source)^[i];
      d := c or _80;
      PPtrUIntArray(dest)^[i] := c - ((d - _61) and
        not (d - _7b)) and ((not c) and _80) shr 2;
    end;
    {$else}
    // unbranched uppercase conversion of 4 chars blocks
    for i := 0 to (sourceLen - 1) shr 2 do
    begin
      c := PPtrUIntArray(source)^[i];
      d := c or PtrUInt($80808080);
      PPtrUIntArray(dest)^[i] := c - ((d - PtrUInt($61616161)) and
        not(d - PtrUInt($7b7b7b7b))) and ((not c) and PtrUInt($80808080)) shr 2;
    end;
    {$endif CPU64}
  end;
  result := dest + sourceLen; // return the exact size
end;

function UpperCopyWin255(dest: PWinAnsiChar; const source: RawUtf8): PWinAnsiChar;
var
  i, len: PtrInt;
  {$ifdef CPUX86NOTPIC}
  tab: TNormTableByte absolute NormToUpperByte;
  {$else}
  tab: PByteArray; // faster on PIC/ARM and x86_64
  {$endif CPUX86NOTPIC}
begin
  if source = '' then
    result := dest
  else
  begin
    len := PStrLen(PAnsiChar(pointer(source)) - _STRLEN)^;
    if len > 250 then
      len := 250; // avoid buffer overflow
    result := dest + len;
    {$ifndef CPUX86NOTPIC}
    tab := @NormToUpperByte;
    {$endif CPUX86NOTPIC}
    for i := 0 to len - 1 do
      dest[i] := AnsiChar(tab[PByteArray(source)[i]]);
  end;
end;

function Utf8UpperCopy(Dest, Source: PUtf8Char; SourceChars: cardinal): PUtf8Char;
var
  c: cardinal;
  srcEnd, srcEndBy4, up: PUtf8Char;
  extra, i: PtrInt;
  {$ifdef CPUX86NOTPIC}
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
label
  by1, by4, set1; // ugly but faster
begin
  if (Source <> nil) and
     (Dest <> nil) then
  begin
    {$ifndef CPUX86NOTPIC}
    utf8 := @UTF8_TABLE;
    {$endif CPUX86NOTPIC}
    // first handle trailing 7-bit ASCII chars, by quad (Sha optimization)
    srcEnd := Source + SourceChars;
    srcEndBy4 := srcEnd - 4;
    up := @NormToUpper;
    if Source <= srcEndBy4 then
      repeat
        c := PCardinal(Source)^;
        if c and $80808080 <> 0 then
          goto by1; // break on first non ASCII quad
by4:    inc(Source, 4);
        Dest[0] := up[ToByte(c)];
        Dest[1] := up[ToByte(c shr 8)];
        Dest[2] := up[ToByte(c shr 16)];
        Dest[3] := up[ToByte(c shr 24)];
        inc(Dest, 4);
      until Source > srcEndBy4;
    // generic loop, handling one UCS-4 CodePoint per iteration
    if Source < srcEnd then
      repeat
by1:    c := byte(Source^);
        inc(Source);
        if c <= $7f then
        begin
          Dest^ := up[c];
set1:     inc(Dest);
          if Source <= srcEndBy4 then
          begin
            c := PCardinal(Source)^;
            if c and $80808080 = 0 then
              goto by4;
            continue;
          end
          else if Source < srcEnd then
            continue
          else
            break;
        end
        else
        begin
          extra := utf8.Lookup[c];
          if (extra = UTF8_INVALID) or // allow full UTF-8/UCS-4 range
             (Source + extra > srcEnd) then
            break;
          i := 0;
          repeat
            c := (c shl 6) + byte(Source[i]);
            inc(i)
          until i = extra;
          with utf8.Extra[extra] do
          begin
            dec(c, offset);
            if c < minimum then
              break; // invalid input content
          end;
          if (c <= 255) and
             (up[c] <= #127) then
          begin
            Dest^ := up[c];
            inc(Source, extra);
            goto set1;
          end;
          Dest^ := Source[-1];
          repeat // here we now extra>0 - just copy UTF-8 input untouched
            inc(Dest);
            Dest^ := Source^;
            inc(Source);
            dec(extra);
            if extra = 0 then
              goto set1;
          until false;
        end;
      until false;
  end;
  result := Dest;
end;

function Utf8UpperCopy255(dest: PAnsiChar; const source: RawUtf8): PUtf8Char;
var
  len: PtrInt;
begin
  len := length(source);
  if len > 0 then
  begin
    if len > 250 then
      len := 250; // avoid buffer overflow
    result := Utf8UpperCopy(pointer(dest), pointer(source), len);
  end
  else
    result := pointer(dest);
end;

function UpperCopy255W(dest: PAnsiChar; const source: SynUnicode): PAnsiChar;
begin
  result := UpperCopy255W(dest, pointer(source), length(source));
end;

function UpperCopy255W(dest: PAnsiChar; source: PWideChar; L: PtrInt): PAnsiChar;
var
  c: PtrUInt;
  d: byte;
  lookupper: PByteArray; // better x86-64 / PIC asm generation
begin
  if L > 0 then
  begin
    if L > 250 then
      L := 250; // avoid buffer overflow
    lookupper := @NormToUpperAnsi7Byte;
    repeat
      c := PWord(source)^;
      d := ord('?');
      if c < 255 then
        d := lookupper[c];
      dest^ := AnsiChar(d);
      inc(dest);
      inc(source);
      dec(L);
    until L = 0;
  end;
  result := dest;
end;

function UpperCopy(dest: PAnsiChar; const source: RawUtf8): PAnsiChar;
var
  s: PAnsiChar;
  c: byte;
  lookupper: PByteArray; // better x86-64 / PIC asm generation
begin
  s := pointer(source);
  if s <> nil then
  begin
    lookupper := @NormToUpperAnsi7Byte;
    repeat
      c := lookupper[ord(s^)];
      if c = 0 then
        break;
      dest^ := AnsiChar(c);
      inc(s);
      inc(dest);
    until false;
  end;
  result := dest;
end;

function UpperCopyShort(dest: PAnsiChar; const source: ShortString): PAnsiChar;
var
  s: PByteArray;
  i: PtrInt;
  lookupper: PByteArray; // better x86-64 / PIC asm generation
begin
  s := @source;
  lookupper := @NormToUpperAnsi7Byte;
  for i := 1 to s[0] do
  begin
    dest^ := AnsiChar(lookupper[s[i]]);
    inc(dest);
  end;
  result := dest;
end;

function UpperCaseUnicode(const S: RawUtf8): RawUtf8;
var
  tmp: TSynTempBuffer;
  len: integer;
begin
  if S = '' then
  begin
    result := '';
    exit;
  end;
  tmp.Init(length(s) * 2);
  len := Utf8ToWideChar(tmp.buf, pointer(S), length(S)) shr 1;
  RawUnicodeToUtf8(tmp.buf, Unicode_InPlaceUpper(tmp.buf, len), result);
  tmp.Done;
end;

function UpperCaseSynUnicode(const S: SynUnicode): SynUnicode;
begin
  {$ifdef UNICODE}
  result := SysUtils.UpperCase(S);
  {$else}
  {$ifdef HASVARUSTRING}
  result := UnicodeUpperCase(S);
  {$else}
  result := WideUpperCase(s);
  {$endif HASVARUSTRING}
  {$endif UNICODE}
end;

function LowerCaseSynUnicode(const S: SynUnicode): SynUnicode;
begin
  {$ifdef UNICODE}
  result := SysUtils.LowerCase(S);
  {$else}
  {$ifdef HASVARUSTRING}
  result := UnicodeLowerCase(S);
  {$else}
  result := WideLowerCase(s);
  {$endif HASVARUSTRING}
  {$endif UNICODE}
end;

function LowerCaseUnicode(const S: RawUtf8): RawUtf8;
var
  tmp: TSynTempBuffer;
  len: PtrInt;
begin
  if S = '' then
  begin
    result := '';
    exit;
  end;
  tmp.Init(length(s) * 2);
  len := Utf8ToWideChar(tmp.buf, pointer(S), length(S)) shr 1;
  RawUnicodeToUtf8(tmp.buf, Unicode_InPlaceLower(tmp.buf, len),result);
  tmp.Done;
end;

function IsCaseSensitive(const S: RawUtf8): boolean;
begin
  result := IsCaseSensitive(pointer(S), length(S));
end;

function IsCaseSensitive(P: PUtf8Char; PLen: PtrInt): boolean;
begin
  result := true;
  if (P <> nil) and
     (PLen > 0) then
    repeat
      if ord(P^) in [ord('a')..ord('z'), ord('A')..ord('Z')] then
        exit;
      inc(P);
      dec(PLen);
    until PLen = 0;
  result := false;
end;

procedure CaseCopy(Text: PUtf8Char; Len: PtrInt; Table: PNormTable;
  var Dest: RawUtf8);
var
  i: PtrInt;
  tmp: PAnsiChar;
begin
  tmp := FastNewString(Len, CP_UTF8);
  for i := 0 to Len - 1 do
    tmp[i] := Table[Text[i]]; // branchless conversion
  FastAssignNew(Dest, tmp);
end;

procedure CaseConvert(p: PUtf8Char; l: integer; Table: PNormTable);
  {$ifdef HASINLINE} inline; {$endif}
begin
  if l <> 0 then
    repeat
      p^ := Table[p^]; // branchless conversion
      inc(p);
      dec(l)
    until l = 0;
end;

procedure CaseSelf(var S: RawUtf8; Table: PNormTable);
begin
  CaseConvert(UniqueRawUtf8(S), length(S), Table);
end;

procedure CaseNew(var S: RawUtf8; Table: PNormTable);
begin
  CaseConvert(pointer(S), length(S), Table);
end;

function UpperCase(const S: RawUtf8): RawUtf8;
begin
  CaseCopy(pointer(S), length(S), @NormToUpperAnsi7, result);
end;

procedure UpperCaseCopy(Text: PUtf8Char; Len: PtrInt; var Dest: RawUtf8);
begin
  CaseCopy(Text, Len, @NormToUpperAnsi7, Dest);
end;

procedure UpperCaseCopy(const Source: RawUtf8; var Dest: RawUtf8);
begin
  CaseCopy(pointer(Source), length(Source), @NormToUpperAnsi7, Dest);
end;

procedure UpperCaseSelf(var S: RawUtf8);
begin
  CaseSelf(S, @NormToUpperAnsi7);
end;

function LowerCase(const S: RawUtf8): RawUtf8;
begin
  CaseCopy(pointer(S), length(S), @NormToLowerAnsi7, result);
end;

procedure LowerCaseCopy(Text: PUtf8Char; Len: PtrInt; var Dest: RawUtf8);
begin
  CaseCopy(Text, Len, @NormToLowerAnsi7, Dest);
end;

procedure LowerCaseSelf(var S: RawUtf8);
begin
  CaseSelf(S, @NormToLowerAnsi7);
end;

procedure UpperCaseShort(var S: ShortString);
begin
  CaseConvert(@S[1], ord(S[0]), @NormToUpperAnsi7);
end;

procedure LowerCaseShort(var S: ShortString);
begin
  CaseConvert(@S[1], ord(S[0]), @NormToLowerAnsi7);
end;

function IsCase(const S: RawUtf8; Table: PNormTable): boolean;
var
  i: PtrInt;
begin
  result := false;
  for i := 1 to length(S) do
    if Table[S[i]] <> S[i] then
      exit;
  result := true;
end;

function IsUpper(const S: RawUtf8): boolean;
begin
  result := IsCase(S, @NormToUpperAnsi7);
end;

function IsLower(const S: RawUtf8): boolean;
begin
  result := IsCase(S, @NormToLowerAnsi7);
end;

function PosExIPas(Sub, P: PUtf8Char; Offset: PtrUInt; Lookup: PNormTable): PtrInt;
var
  len, lenSub: PtrInt;
  ch: AnsiChar;
  start, stop: PUtf8Char;
label
  s2, s6, tt, t0, t1, t2, t3, t4, s0, s1, fnd, quit;
begin
  result := 0;
  if (P = nil) or
     (Sub = nil) or
     (PtrInt(Offset) <= 0) or
     (Lookup = nil) then
    goto quit;
  len := PStrLen(P - _STRLEN)^;
  lenSub := PStrLen(Sub - _STRLEN)^ - 1;
  if (len < lenSub + PtrInt(Offset)) or
     (lenSub < 0) then
    goto quit;
  stop := P + len;
  inc(P, lenSub);
  inc(Sub, lenSub);
  start := P;
  P := @P[Offset + 3];
  ch := Lookup[Sub[0]];
  lenSub := -lenSub;
  if P < stop then
    goto s6;
  dec(P, 4);
  goto s2;
s6: // check 6 chars per loop iteration with O(1) case comparison
  if ch = Lookup[P[-4]] then
    goto t4;
  if ch = Lookup[P[-3]] then
    goto t3;
  if ch = Lookup[P[-2]] then
    goto t2;
  if ch = Lookup[P[-1]] then
    goto t1;
s2:if ch = Lookup[P[0]] then
    goto t0;
s1:if ch = Lookup[P[1]] then
    goto tt;
s0:inc(P, 6);
  if P < stop then
    goto s6;
  dec(P, 4);
  if P >= stop then
    goto quit;
  goto s2;
t4:dec(P, 2);
t2:dec(P, 2);
  goto t0;
t3:dec(P, 2);
t1:dec(P, 2);
tt:len := lenSub;
  if lenSub <> 0 then
    repeat
      if (Lookup[Sub[len]] <> Lookup[P[len + 1]]) or
         (Lookup[Sub[len + 1]] <> Lookup[P[len + 2]]) then
        goto s0;
      inc(len, 2);
    until len >= 0;
  inc(P, 2);
  if P <= stop then
    goto fnd;
  goto quit;
t0:len := lenSub;
  if lenSub <> 0 then
    repeat
      if (Lookup[Sub[len]] <> Lookup[P[len]]) or
         (Lookup[Sub[len + 1]] <> Lookup[P[len + 1]]) then
        goto s1;
      inc(len, 2);
    until len >= 0;
  inc(P);
fnd:
  result := P - start;
quit:
end;

function PosExI(const SubStr, S: RawUtf8; Offset: PtrUInt): PtrInt;
begin
  result := PosExIPas(pointer(SubStr), pointer(S), Offset, @NormToUpperAnsi7);
end;

function PosExI(const SubStr, S: RawUtf8; Offset: PtrUInt; Lookup: PNormTable): PtrInt;
begin
  if (Lookup = nil) or
     (Lookup = @NormToNorm) then
    {$ifdef CPUX86}
    result := PosEx(SubStr, S, Offset)
    {$else}
    result := PosExPas(pointer(SubStr), pointer(S), Offset)
    {$endif CPUX86}
  else
    result := PosExIPas(pointer(SubStr), pointer(S), Offset, Lookup);
end;


{ ************ UTF-8 String Manipulation Functions }

function StartWithExact(const text, textStart: RawUtf8): boolean;
var
  l: PtrInt;
begin
  l := length(textStart);
  result := (length(text) >= l) and
    mormot.core.base.CompareMem(pointer(text), pointer(textStart), l);
end;

function EndWithExact(const text, textEnd: RawUtf8): boolean;
var
  l, o: PtrInt;
begin
  l := length(textEnd);
  o := length(text) - l;
  result := (o >= 0) and
    mormot.core.base.CompareMem(PUtf8Char(pointer(text)) + o, pointer(textEnd), l);
end;

function GetNextLine(source: PUtf8Char; out next: PUtf8Char; andtrim: boolean): RawUtf8;
var
  beg: PUtf8Char;
begin
  if source = nil then
  begin
    {$ifdef FPC}
    FastAssignNew(result);
    {$else}
    result := '';
    {$endif FPC}
    next := source;
    exit;
  end;
  if andtrim then // optional trim left
    while source^ in [#9, ' '] do
      inc(source);
  beg := source;
  repeat // just here to avoid a goto
    if source[0] > #13 then
      if source[1] > #13 then
        if source[2] > #13 then
          if source[3] > #13 then
          begin
            inc(source, 4); // fast process 4 chars per loop
            continue;
          end
          else
            inc(source, 3)
        else
          inc(source, 2)
      else
        inc(source);
    case source^ of
      #0:
        next := nil;
      #10:
        next := source + 1;
      #13:
        if source[1] = #10 then
          next := source + 2
        else
          next := source + 1;
    else
      begin
        inc(source);
        continue;
      end;
    end;
    if andtrim then // optional trim right
      while (source > beg) and
            (source[-1] in [#9, ' ']) do
        dec(source);
    FastSetString(result, beg, source - beg);
    exit;
  until false;
end;

function LeftU(const S: RawUtf8; n: PtrInt): RawUtf8;
begin
  result := Copy(S, 1, n);
end;

function RightU(const S: RawUtf8; n: PtrInt): RawUtf8;
var
  len: PtrInt;
begin
  len := length(S);
  if n > len then
    n := len;
  result := Copy(S, len + 1 - n, n);
end;

function TrimLeft(const S: RawUtf8): RawUtf8;
var
  i, len: PtrInt;
begin
  len := Length(S);
  i := 0;
  while (i < len) and
        (PByteArray(S)[i] <= ord(' ')) do
    inc(i);
  if i = 0 then
    result := S
  else
    FastSetString(result, @PByteArray(S)[i], len - i);
end;

function TrimRight(const S: RawUtf8): RawUtf8;
var
  i, len: PtrInt;
begin
  len := Length(S);
  i := len;
  while (i > 0) and
        (S[i] <= ' ') do
    dec(i);
  if i = len then
    result := S
  else
    FastSetString(result, pointer(S), i);
end;

procedure TrimLeftLines(var S: RawUtf8);
var
  p, d: PUtf8Char;
begin
  if S = '' then
    exit;
  p := UniqueRawUtf8(S);
  d := p; // in-place process
  repeat
    while (p^ <= ' ') and
          (p^ <> #0) do
      inc(p);
    while not (p^ in [#0, #10, #13]) do
    begin
      d^ := p^;
      inc(p);
      inc(d);
    end;
    if p^ = #0 then
      break;
    d^ := #10;
    inc(d);
  until false;
  if d = pointer(S) then
    S := ''
  else
    FakeLength(S, d); // no SetLength needed
end;

procedure TrimChars(var S: RawUtf8; Left, Right: PtrInt);
var
  p: PUtf8Char;
begin
  p := pointer(S);
  if p = nil then
    exit;
  if Left < 0 then
    Left := 0;
  if Right < 0 then
    Right := 0;
  inc(Right, Left);
  if Right = 0 then
    exit; // nothing to trim
  Right := PStrLen(p - _STRLEN)^ - Right; // compute new length
  if Right > 0 then
    if PStrCnt(p - _STRCNT)^ = 1 then // RefCnt=1 ?
    begin
      PStrLen(p - _STRLEN)^ := Right; // we can modify it in-place
      if Left <> 0 then
        MoveFast(p[Left], p^, Right);
      p[Right] := #0;
    end
    else
      FastSetString(S, p + Left, Right) // create a new unique string
  else
    FastAssignNew(S);
end;

function SplitRight(const Str: RawUtf8; SepChar: AnsiChar; LeftStr: PRawUtf8): RawUtf8;
var
  i: PtrInt;
begin
  for i := length(Str) downto 1 do
    if Str[i] = SepChar then
    begin
      FastSetString(result, @PByteArray(Str)[i], length(Str) - i);
      if LeftStr <> nil then
        FastSetString(LeftStr^, pointer(Str), i - 1);
      exit;
    end;
  result := Str;
  if LeftStr <> nil then
    FastAssignNew(LeftStr^);
end;

function SplitRights(const Str, SepChar: RawUtf8): RawUtf8;
var
  i: PtrInt;
begin
  if SepChar <> '' then
    if length(SepChar) = 1 then
    begin
      result := SplitRight(Str, SepChar[1]);
      exit;
    end
    else
      for i := length(Str) downto 1 do
        if PosExChar(Str[i], SepChar) <> 0 then
        begin
          FastSetString(result, @PByteArray(Str)[i], length(Str) - i);
          exit;
        end;
  result := Str;
end;

function Split(const Str, SepStr: RawUtf8; var LeftStr, RightStr: RawUtf8;
  ToUpperCase: boolean): boolean;
var
  i: PtrInt;
  tmp: pointer; // may be called as Split(Str,SepStr,Str,RightStr)
begin
  if length(SepStr) = 1 then
    i := PosExChar(SepStr[1], Str) // may use SSE2 on i386/x86_64
  else
    i := PosEx(SepStr, Str);
  if i = 0 then
  begin
    LeftStr := Str;
    RightStr := '';
    result := false;
  end
  else
  begin
    dec(i);
    tmp := nil;
    FastSetString(RawUtf8(tmp), pointer(Str), i);
    inc(i, length(SepStr));
    FastSetString(RightStr, @PByteArray(Str)[i], length(Str) - i);
    FastAssignNew(LeftStr, tmp);
    result := true;
  end;
  if ToUpperCase then
  begin
    UpperCaseSelf(LeftStr);
    UpperCaseSelf(RightStr);
  end;
end;

function Split(const Str, SepStr: RawUtf8; var LeftStr: RawUtf8;
  ToUpperCase: boolean): RawUtf8;
begin
  Split(Str, SepStr, LeftStr, result, ToUpperCase);
end;

function Split(const Str: RawUtf8; const SepStr: array of RawUtf8;
  const DestPtr: array of PRawUtf8): PtrInt;
var
  s, i, j: PtrInt;
  p: pointer;
begin
  j := 1;
  result := 0;
  s := 0;
  if high(SepStr) >= 0 then
    while result <= high(DestPtr) do
    begin
      p := @PByteArray(Str)[j - 1];
      i := PosEx(SepStr[s], Str, j);
      if i = 0 then
      begin
        if DestPtr[result] <> nil then
          FastSetString(DestPtr[result]^, p, length(Str) - j + 1);
        inc(result);
        break;
      end;
      if DestPtr[result] <> nil then
        FastSetString(DestPtr[result]^, p, i - j);
      inc(result);
      if s < high(SepStr) then
        inc(s);
      j := i + 1;
    end;
  for i := result to high(DestPtr) do
    if DestPtr[i] <> nil then
      FastAssignNew(DestPtr[i]^);
end;

function TrimSplit(const Str: RawUtf8; var Left, Right: RawUtf8; Sep: AnsiChar): boolean;
var
  i: PtrInt;
begin
  result := false;
  i := PosExChar(Sep, Str);
  if i = 0 then
    exit;
  TrimCopy(Str, i + 1, maxInt, Right);
  TrimCopy(Str, 1, i - 1, Left); // Left is likely to be Str
  result := true;
end;

function IsVoid(const text: RawUtf8): boolean;
var
  i: PtrInt;
begin
  result := false;
  for i := 1 to length(text) do
    if text[i] > ' ' then
      exit;
  result := true;
end;

function TrimControlChars(const text: RawUtf8): RawUtf8;
var
  len, i, j, n: PtrInt;
  p: PAnsiChar;
begin
  len := length(text);
  for i := 1 to len do
    if text[i] <= ' ' then
    begin
      n := i - 1;
      p := FastSetString(result, len);
      if n > 0 then
        MoveFast(pointer(text)^, p^, n);
      for j := i + 1 to len do
        if text[j] > ' ' then
        begin
          p[n] := text[j];
          inc(n);
        end;
      FakeSetLength(result, n);
      exit;
    end;
  result := text; // no control char found
end;

function TrimChar(const text: RawUtf8; const exclude: TSynAnsicharSet): RawUtf8;
var
  len, i, j, n: PtrInt;
  p: PAnsiChar;
begin
  len := length(text);
  for i := 1 to len do
    if text[i] in exclude then
    begin
      n := i - 1;
      p := FastSetString(result, len - 1);
      if n > 0 then
        MoveFast(pointer(text)^, p^, n);
      for j := i + 1 to len do
        if not (text[j] in exclude) then
        begin
          p[n] := text[j];
          inc(n);
        end;
      FakeSetLength(result, n);
      exit;
    end;
  result := text; // no exclude char found
end;

function TrimOneChar(const text: RawUtf8; exclude: AnsiChar): RawUtf8;
var
  first, len, i: PtrInt;
  c: AnsiChar;
  p: PAnsiChar;
begin
  len := length(text);
  first := ByteScanIndex(pointer(text), len, ord(exclude));
  if first < 0 then
  begin
    result := text; // no exclude char found
    exit;
  end;
  p := FastSetString(result, len - 1);
  MoveFast(pointer(text)^, p^, first);
  inc(p, first);
  for i := first + 1 to len do
  begin
    c := text[i];
    if c <> exclude then
    begin
      p^ := c;
      inc(p);
    end;
  end;
  FakeSetLength(result, p - pointer(result));
end;

function OnlyChar(const text: RawUtf8; const only: TSynAnsicharSet): RawUtf8;
var
  i: PtrInt;
  exclude: array[0..(SizeOf(only) shr POINTERSHR) - 1] of PtrInt;
begin // reverse bits in local stack copy before calling TrimChar()
  for i := 0 to (SizeOf(only) shr POINTERSHR) - 1 do
    exclude[i] := not PPtrIntArray(@only)[i];
  result := TrimChar(text, TSynAnsicharSet(exclude));
end;

function HasAnyChar(const text: RawUtf8; const chars: TSynAnsicharSet): boolean;
var
  p: PUtf8Char;
begin
  result := true;
  p := pointer(text);
  if p <> nil then
    repeat
      if p^ in chars then
        exit;
      inc(p);
    until p^ = #0;
  result := false;
end;

function HasOnlyChar(const text: RawUtf8; const chars: TSynAnsicharSet): boolean;
var
  p: PUtf8Char;
begin
  result := false;
  p := pointer(text);
  if p <> nil then
    repeat
      if not (p^ in chars) then
        exit;
      inc(p);
    until p^ = #0;
  result := true;
end;

procedure FillZero(var secret: RawUtf8);
begin
  FillZero(RawByteString(secret));
end;

procedure FillZero(var secret: SpiUtf8);
begin
  FillZero(RawByteString(secret));
end;

procedure FillZero(var secret: SynUnicode);
begin
  if secret = '' then
    exit;
  {$ifdef HASVARUSTRING}
  with PStrRec(pointer(PtrInt(secret) - _STRRECSIZE))^ do
    if refCnt = 1 then // avoid GPF if constant UnicodeString
      FillCharFast(pointer(secret)^, length * SizeOf(WideChar), 0);
  {$else} // BSTR have no reference counting
  FillCharFast(pointer(secret)^, length(secret) * SizeOf(WideChar), 0);
  {$endif HASVARUSTRING}
  secret := '';
end;

procedure FillZero(var secret: TBytes);
begin
  if secret <> nil then
    with PDynArrayRec(pointer(PtrInt(secret) - _DARECSIZE))^ do
      if refCnt = 1 then // avoid GPF if const
        FillCharFast(pointer(secret)^, length, 0);
  secret := nil; // dec refCnt
end;

function StringReplaceAllProcess(const S, OldPattern, NewPattern: RawUtf8;
  found: integer; Lookup: PNormTable): RawUtf8;
var
  i, last, oldlen, newlen, sharedlen: PtrInt;
  posCount: integer;
  pos: TIntegerDynArray;
  src, dst: PAnsiChar;
begin
  oldlen := length(OldPattern);
  newlen := length(NewPattern);
  SetLength(pos, 64);
  pos[0] := found;
  posCount := 1;
  repeat
    found := PosExI(OldPattern, S, found + oldlen, Lookup);
    if found = 0 then
      break;
    AddInteger(pos, posCount, found);
  until false;
  dst := FastSetString(result, Length(S) + (newlen - oldlen) * posCount);
  last := 1;
  src := pointer(S);
  for i := 0 to posCount - 1 do
  begin
    sharedlen := pos[i] - last;
    MoveFast(src^, dst^, sharedlen);
    inc(src, sharedlen + oldlen);
    inc(dst, sharedlen);
    if newlen > 0 then
    begin
      MoveByOne(pointer(NewPattern), dst, newlen);
      inc(dst, newlen);
    end;
    last := pos[i] + oldlen;
  end;
  MoveFast(src^, dst^, length(S) - last + 1);
end;

function StringReplaceAll(const S, OldPattern, NewPattern: RawUtf8;
  Lookup: PNormTable): RawUtf8;
var
  first: PtrInt;
begin
  if (S = '') or
     (OldPattern = '') or
     (OldPattern = NewPattern) then
    result := S
  else
  begin
    if (Lookup = nil) and
       (length(OldPattern) = 1) then
      first := ByteScanIndex(pointer(S), {%H-}PStrLen(PtrUInt(S) - _STRLEN)^,
        byte(OldPattern[1])) + 1
    else
      first := PosExI(OldPattern, S, 1, Lookup); // handle Lookup=nil
    if first = 0 then
      result := S
    else
      result := StringReplaceAllProcess(S, OldPattern, NewPattern, first, Lookup);
  end;
end;

function StringReplaceAll(const S, OldPattern, NewPattern: RawUtf8;
  CaseInsensitive: boolean): RawUtf8;
begin
  result := StringReplaceAll(S, OldPattern, NewPattern, NORM2CASE[CaseInsensitive]);
end;

function StringReplaceAll(const S: RawUtf8;
  const OldNewPatternPairs: array of RawUtf8; CaseInsensitive: boolean): RawUtf8;
var
  n, i: PtrInt;
  tab: PNormTable;
begin
  result := S;
  n := high(OldNewPatternPairs);
  if (n <= 0) or
     (n and 1 <> 1) then
    exit;
  tab := NORM2CASE[CaseInsensitive];
  for i := 0 to n shr 1 do
    result := StringReplaceAll(result,
      OldNewPatternPairs[i * 2], OldNewPatternPairs[i * 2 + 1], tab);
end;

function StringReplaceChars(const Source: RawUtf8; OldChar, NewChar: AnsiChar): RawUtf8;
var
  i, j, n: PtrInt;
  p: PAnsiChar;
begin
  if (OldChar <> NewChar) and
     (Source <> '') then
  begin
    n := length(Source);
    i := ByteScanIndex(pointer(Source), n, ord(OldChar));
    if i >= 0 then
    begin
      FastSetString(result, pointer(Source), n);
      p := pointer(result);
      for j := i to n - 1 do
        if p[j] = OldChar then
          p[j] := NewChar;
      exit;
    end;
  end;
  result := Source;
end;

procedure StringReplaceTabsProcess(s, d, t: PAnsiChar; tlen: PtrInt);
begin
  repeat
    if s^ = #0 then
      break
    else if s^ <> #9 then
    begin
      d^ := s^;
      inc(d);
      inc(s);
    end
    else
    begin
      if tlen > 0 then
      begin
        MoveByOne(t, d, tlen);
        inc(d, tlen);
      end;
      inc(s);
    end;
  until false;
end;

function StringReplaceTabs(const Source, TabText: RawUtf8): RawUtf8;
var
  len, i, n, ttl: PtrInt;
begin
  ttl := length(TabText);
  len := length(Source);
  n := 0;
  if ttl <> 0 then
    for i := 1 to len do
      if Source[i] = #9 then
        inc(n);
  if n = 0 then
  begin
    result := Source;
    exit;
  end;
  StringReplaceTabsProcess(pointer(Source),
    FastSetString(result, len + n * pred(ttl)), pointer(TabText), ttl);
end;

function RawUtf8OfChar(Ch: AnsiChar; Count: integer): RawUtf8;
begin
  if Count <= 0 then
    FastAssignNew(result)
  else
    FillCharFast(FastSetString(result, Count)^, Count, byte(Ch));
end;

function QuotedStr(const S: RawUtf8; Quote: AnsiChar): RawUtf8;
begin
  QuotedStr(pointer(S), length(S), Quote, result);
end;

procedure QuotedStr(const S: RawUtf8; Quote: AnsiChar; var result: RawUtf8);
var
  p: PUtf8Char;
  tmp: pointer; // will hold a RawUtf8 with no try..finally exception block
begin
  tmp := nil;
  p := pointer(S);
  if (p <> nil) and
     (p = pointer(result)) then
  begin
    RawUtf8(tmp) := S; // make private ref-counted copy for QuotedStr(U,'"',U)
    p := pointer(tmp);
  end;
  QuotedStr(p, length(S), Quote, result);
  if tmp <> nil then
    {$ifdef FPC}
    FastAssignNew(tmp);
    {$else}
    RawUtf8(tmp) := '';
    {$endif FPC}
end;

procedure QuotedStr(P: PUtf8Char; PLen: PtrInt; Quote: AnsiChar;
  var result: RawUtf8);
var
  i, quote1, nquote: PtrInt;
  r: PUtf8Char;
  c: AnsiChar;
begin
  nquote := 0;
  quote1 := ByteScanIndex(pointer(P), PLen, byte(Quote)); // asm if available
  if quote1 >= 0 then
    for i := quote1 to PLen - 1 do
      if P[i] = Quote then
        inc(nquote);
  r := FastSetString(result, PLen + nquote + 2);
  r^ := Quote;
  inc(r);
  if nquote = 0 then
  begin
    MoveFast(P^, r^, PLen); // most common case is "some text" with no " within
    r[PLen] := Quote;
  end
  else
  begin
    MoveFast(P^, r^, quote1);
    inc(r, quote1);
    inc(PLen, PtrInt(PtrUInt(P))); // efficient use of registers on FPC
    inc(quote1, PtrInt(PtrUInt(P)));
    repeat
      if quote1 = PLen then
        break;
      c := PAnsiChar(quote1)^;
      inc(quote1);
      r^ := c;
      inc(r);
      if c <> Quote then
        continue;
      r^ := c;
      inc(r);
    until false;
    r^ := Quote;
  end;
end;

function GotoEndOfQuotedString(P: PUtf8Char): PUtf8Char;
var
  quote: AnsiChar;
begin
  // P^='"' or P^='''' at function call
  quote := P^;
  inc(P);
  repeat
    if P^ = #0 then
      break
    else if P^ <> quote then
      inc(P)
    else if P[1] = quote then // allow double quotes inside string
      inc(P, 2)
    else
      break; // end quote
  until false;
  result := P;
end; // P^='"' or P^=#0 at function return

function GotoNextNotSpace(P: PUtf8Char): PUtf8Char;
begin
  {$ifdef FPC}
  while (P^ <= ' ') and
        (P^ <> #0) do
    inc(P);
  {$else}
  if P^ in [#1..' '] then
    repeat
      inc(P)
    until not (P^ in [#1..' ']);
  {$endif FPC}
  result := P;
end;

function GotoNextNotSpaceSameLine(P: PUtf8Char): PUtf8Char;
begin
  while P^ in [#9, ' '] do
    inc(P);
  result := P;
end;

function GotoNextSpace(P: PUtf8Char): PUtf8Char;
begin
  if P^ > ' ' then
    repeat
      inc(P)
    until P^ <= ' ';
  result := P;
end;

function NextNotSpaceCharIs(var P: PUtf8Char; ch: AnsiChar): boolean;
begin
  while (P^ <= ' ') and
        (P^ <> #0) do
    inc(P);
  if P^ = ch then
  begin
    inc(P);
    result := true;
  end
  else
    result := false;
end;

function GotoNextSqlIdentifier(P: PUtf8Char; tab: PTextCharSet): PUtf8Char;
  {$ifdef HASINLINE} inline; {$endif}
begin
  while tcCtrlNot0Comma in tab[P^] do // in [#1..' ', ';']
    inc(P);
  if PWord(P)^ = ord('/') + ord('*') shl 8 then
  begin
    // detect and ignore e.g. '/*nocache*/'
    repeat
      inc(P);
      if PWord(P)^ = ord('*') + ord('/') shl 8 then
      begin
        inc(P, 2);
        break;
      end;
    until P^ = #0;
    while tcCtrlNot0Comma in tab[P^] do
      inc(P);
  end;
  result := P;
end;

function GetNextFieldProp(var P: PUtf8Char; var Prop: RawUtf8): boolean;
var
  b: PUtf8Char;
  tab: PTextCharSet;
begin
  tab := @TEXT_CHARS;
  P := GotoNextSqlIdentifier(P, tab); // handle /*comment*/
  b := P;
  while tcIdentifier in tab[P^] do
    inc(P); // go to end of ['_', '0'..'9', 'a'..'z', 'A'..'Z'] chars
  FastSetString(Prop, b, P - b);
  P := GotoNextSqlIdentifier(P, tab);
  result := Prop <> '';
end;

function GetNextFieldPropSameLine(var P: PUtf8Char; var Prop: ShortString): boolean;
var
  b: PUtf8Char;
  tab: PTextCharSet;
begin
  tab := @TEXT_CHARS;
  while tcCtrlNotLF in tab[P^] do
    inc(P); // ignore [#1..#9, #11, #12, #14..' ']
  b := P;
  while tcIdentifier in tab[P^] do
    inc(P); // go to end of field name
  SetString(Prop, PAnsiChar(b), P - b);
  while tcCtrlNotLF in TEXT_CHARS[P^] do
    inc(P);
  result := Prop <> '';
end;

function UnQuoteSqlStringVar(P: PUtf8Char; out Value: RawUtf8): PUtf8Char;
var
  quote: AnsiChar;
  beg, ps: PUtf8Char;
  internalquote: PtrInt;
begin
  result := nil;
  if P = nil then
    exit;
  quote := P^; // " or '
  inc(P);
  // compute unquoted string length
  beg := P;
  internalquote := 0;
  P := PosChar(P, quote); // fast SSE2 search on x86_64
  if P = nil then
    exit; // we need at least an ending quote
  while true do
    if P^ = #0 then
      exit // where is my quote?
    else if P^ <> quote then
      inc(P)
    else if P[1] = quote then
    begin
      inc(P, 2); // allow double quotes inside string
      inc(internalquote);
    end
    else
      break; // end quote
  // create unquoted string
  if internalquote = 0 then
    // no quote within
    FastSetString(Value, beg, P - beg)
  else
  begin
    // unescape internal quotes
    pointer(Value) := FastNewString(P - beg - internalquote, CP_UTF8);
    P := beg;
    ps := pointer(Value);
    repeat
      if P[0] = quote then
        if P[1] = quote then
          // allow double quotes inside string
          inc(P)
        else
          // end quote
          break;
      ps^ := P[0];
      inc(ps);
      inc(P);
    until false;
  end;
  result := P + 1;
end;

function UnQuoteSqlString(const Value: RawUtf8): RawUtf8;
begin
  UnQuoteSqlStringVar(pointer(Value), result);
end;

function UnQuotedSqlSymbolName(const ExternalDBSymbol: RawUtf8): RawUtf8;
begin
  if (ExternalDBSymbol <> '') and
     (ExternalDBSymbol[1] in ['[', '"', '''', '(']) then
    // e.g. for ZDBC's GetFields()
    result := copy(ExternalDBSymbol, 2, length(ExternalDBSymbol) - 2)
  else
    result := ExternalDBSymbol;
end;

function IdemPCharAndGetNextLine(var source: PUtf8Char; searchUp: PAnsiChar): boolean;
begin
  if (source = nil) or
     (searchUp = nil) then
    result := false
  else
  begin
    result := IdemPCharAnsi({$ifndef CPUX86NOTPIC}@{$endif}NormToUpperAnsi7,
                source, searchUp);
    source := GotoNextLine(source);
  end;
end;

function FindNameValue(P: PUtf8Char; UpperName: PAnsiChar): PUtf8Char;
var
  table: PNormTable; // faster even on i386
  u: PAnsiChar;
label
  eof, eol;
begin
  if (P = nil) or
     (UpperName = nil) then
    goto eof;
  table := @NormToUpperAnsi7;
  repeat
    if table[P^] <> UpperName^ then // first character is likely not to match
      repeat // quickly go to end of current line
        repeat
eol:      if P^ <= #13 then
            break;
          inc(P);
        until false;
        if (P^ = #13) or
           (P^ = #10) then
        begin
          repeat
            inc(P);
          until (P^ <> #10) and
                (P^ <> #13);
          if P^ = #0 then
            goto eof;
          break; // handle next line
        end
        else if P^ <> #0 then
        begin
          inc(P); // e.g. #9
          continue;
        end;
eof:    result := nil; // reached P^=#0 -> not found
        exit;
      until false
    else
    begin
      // first char did match -> try other chars
      inc(P);
      u := UpperName + 1;
      repeat
        if u^ = #0 then
          break
        else if u^ <> table[P^] then
          goto eol;
        inc(P);
        inc(u);
      until false;
      result := P; // if found, points just after UpperName
      exit;
    end;
  until false;
end;

function FindNameValuePointer(NameValuePairs: PUtf8Char; UpperName: PAnsiChar;
  out FoundLen: PtrInt; UpperNameSeparator: AnsiChar): PUtf8Char;
var
  p: PUtf8Char;
  len: PtrInt;
begin
  p := FindNameValue(NameValuePairs, UpperName);
  if p <> nil then
    repeat
      if UpperNameSeparator <> #0 then
        if p^ = UpperNameSeparator then
          inc(p) // e.g. THttpSocket.HeaderGetValue uses UpperNameSeparator=':'
        else
          break;
      while p^ in [#9, ' '] do // trim left
        inc(p);
      len := 0;
      while p[len] > #13 do // end of line/value
        inc(len);
      while p[len - 1] = ' ' do  // trim right
        dec(len);
      FoundLen := len;
      break;
    until false;
  result := p;
end;

function FindNameValue(const NameValuePairs: RawUtf8; UpperName: PAnsiChar;
  var Value: RawUtf8; KeepNotFoundValue: boolean; UpperNameSeparator: AnsiChar): boolean;
var
  p: PUtf8Char;
  len: PtrInt;
begin
  p := FindNameValuePointer(pointer(NameValuePairs), UpperName, len, UpperNameSeparator);
  if p <> nil then
  begin
    FastSetString(Value, p, len);
    result := true;
    exit;
  end;
  if not KeepNotFoundValue then
    {$ifdef FPC}
    FastAssignNew(Value);
    {$else}
    Value := '';
    {$endif FPC}
  result := false;
end;

function GetLineSize(P, PEnd: PUtf8Char): PtrUInt;
var
  c: byte;
begin
  if PEnd <> nil then
  begin
    result := BufferLineLength(P, PEnd); // use branchless SSE2 on x86_64
    exit;
  end;
  result := PtrUInt(P) - 1;
  repeat // inlined BufferLineLength() ending at #0 for PEnd=nil
    inc(result);
    c := PByte(result)^;
    if (c > 13) or
       ((c <> 0) and (c <> 10) and (c <> 13)) then
      continue;
    break;
  until false;
  dec(result, PtrUInt(P)); // returns length
end;

function GetLineSizeSmallerThan(P, PEnd: PUtf8Char; aMinimalCount: integer): boolean;
begin
  result := false;
  if P <> nil then
    while (P < PEnd) and
          (P^ <> #10) and
          (P^ <> #13) do
      if aMinimalCount = 0 then
        exit
      else
      begin
        dec(aMinimalCount);
        inc(P);
      end;
  result := true;
end;

{$ifndef PUREMORMOT2}
function GetNextStringLineToRawUnicode(var P: PChar): RawUnicode;
var
  S: PChar;
begin
  if P = nil then
    result := ''
  else
  begin
    S := P;
    while S^ >= ' ' do
      inc(S);
    result := StringToRawUnicode(P, S - P);
    while (S^ <> #0) and
          (S^ < ' ') do
      inc(S); // ignore e.g. #13 or #10
    if S^ <> #0 then
      P := S
    else
      P := nil;
  end;
end;
{$endif PUREMORMOT2}

function TrimLeftLowerCase(const V: RawUtf8): PUtf8Char;
begin
  result := pointer(V);
  if result <> nil then
  begin
    while result^ in ['a'..'z'] do
      inc(result);
    if result^ = #0 then
      result := pointer(V);
  end;
end;

function TrimLeftLowerCaseToShort(V: PShortString): ShortString;
begin
  TrimLeftLowerCaseToShort(V, result);
end;

procedure TrimLeftLowerCaseToShort(V: PShortString; out result: ShortString);
var
  p: PAnsiChar;
  len: PtrInt;
begin
  len := length(V^);
  p := @V^[1];
  while (len > 0) and
        (p^ in ['a'..'z']) do
  begin
    inc(p);
    dec(len);
  end;
  if len = 0 then
    result := V^
  else
    SetString(result, p, len);
end;

function TrimLeftLowerCaseShort(V: PShortString): RawUtf8;
begin
  TrimLeftLowerCaseShort(V, result);
end;

procedure TrimLeftLowerCaseShort(V: PShortString; var U: RawUtf8);
var
  p: PAnsiChar;
  len: PtrInt;
begin
  len := length(V^);
  p := @V^[1];
  if len > 0 then
    while p^ in ['a'..'z'] do
    begin
      inc(p);
      dec(len);
      if len = 0 then
      begin
        p := @V^[1]; // nothing to trim
        len := length(V^);
        break;
      end;
    end;
  FastSetString(U, p, len);
end;

procedure AppendShortComma(text: PAnsiChar; len: PtrInt; var result: ShortString;
  trimlowercase: boolean);
begin
  if trimlowercase then
    while text^ in ['a'..'z'] do
      if len = 1 then
        exit
      else
      begin
        inc(text);
        dec(len);
      end;
  if integer(ord(result[0])) + len >= 255 then
    exit;
  if len > 0 then
    MoveByOne(text, @result[ord(result[0]) + 1], len);
  inc(result[0], len + 1);
  result[ord(result[0])] := ',';
end;

function IdemPropNameUSmallNotVoid(P1, P2, P1P2Len: PtrInt): boolean;
  {$ifdef HASINLINE}inline;{$endif}
begin
  inc(P1P2Len, P1);
  dec(P2, P1);
  repeat
    result := (PByte(P1)^ xor ord(PAnsiChar(P1)[P2])) and $df = 0;
    if not result then
      exit;
    inc(P1);
  until P1 >= P1P2Len;
end;

function FindShortStringListExact(List: PShortString; MaxValue: integer;
  aValue: PUtf8Char; aValueLen: PtrInt): integer;
var
  len: PtrInt;
begin
  if aValueLen <> 0 then
    for result := 0 to MaxValue do
    begin
      len := PByte(List)^;
      if (len = aValueLen) and
         IdemPropNameUSmallNotVoid(PtrInt(@List^[1]), PtrInt(aValue), len) then
        exit;
      List := pointer(@PAnsiChar(len)[PtrUInt(List) + 1]); // next
    end;
  result := -1;
end;

function FindShortStringListTrimLowerCase(List: PShortString; MaxValue: integer;
  aValue: PUtf8Char; aValueLen: PtrInt): integer;
var
  len: PtrInt;
begin
  if aValueLen <> 0 then
    for result := 0 to MaxValue do
    begin
      len := ord(List^[0]);
      inc(PUtf8Char(List));
      repeat // trim lower case
        if not (PUtf8Char(List)^ in ['a'..'z']) then
          break;
        inc(PUtf8Char(List));
        dec(len);
      until len = 0;
      if (len = aValueLen) and
         IdemPropNameUSmallNotVoid(PtrInt(aValue), PtrInt(List), len) then
        exit;
      inc(PUtf8Char(List), len); // next
    end;
  result := -1;
end;

function FindShortStringListTrimLowerCaseExact(List: PShortString;
  MaxValue: integer; aValue: PUtf8Char; aValueLen: PtrInt): integer;
var
  len: PtrInt;
begin
  if aValueLen <> 0 then
    for result := 0 to MaxValue do
    begin
      len := ord(List^[0]);
      inc(PUtf8Char(List));
      repeat
        if not (PUtf8Char(List)^ in ['a'..'z']) then
          break;
        inc(PUtf8Char(List));
        dec(len);
      until len = 0;
      if (len = aValueLen) and
         CompareMemSmall(aValue, List, len) then
        exit;
      inc(PUtf8Char(List), len);
    end;
  result := -1;
end;

function UnCamelCase(const S: RawUtf8): RawUtf8;
begin
  result := S;
  UnCamelCaseSelf(result);
end;

procedure UnCamelCaseSelf(var S: RawUtf8);
var
  tmp: TSynTempBuffer;
  destlen: PtrInt;
begin
  if S = '' then
    exit;
  destlen := UnCamelCase(tmp.Init(length(S) * 2), pointer(S));
  tmp.Done(PAnsiChar(tmp.buf) + destlen, S);
end;

function UnCamelCase(D, P: PUtf8Char): integer;
var
  Space, SpaceBeg, DBeg: PUtf8Char;
  CapitalCount: integer;
  Number: boolean;
label
  Next;
begin
  DBeg := D;
  if (D <> nil) and
     (P <> nil) then
  begin
    // avoid GPF
    Space := D;
    SpaceBeg := D;
    repeat
      CapitalCount := 0;
      Number := P^ in ['0'..'9'];
      if Number then
        repeat
          inc(CapitalCount);
          D^ := P^;
          inc(P);
          inc(D);
        until not (P^ in ['0'..'9'])
      else
        repeat
          inc(CapitalCount);
          D^ := P^;
          inc(P);
          inc(D);
        until not (P^ in ['A'..'Z']);
      if P^ = #0 then
        break; // no lowercase conversion of last fully uppercased word
      if (CapitalCount > 1) and
         not Number then
      begin
        dec(P);
        dec(D);
      end;
      while P^ in ['a'..'z'] do
      begin
        D^ := P^;
        inc(D);
        inc(P);
      end;
      if P^ = '_' then
        if P[1] = '_' then
        begin
          D^ := ':';
          inc(P);
          inc(D);
          goto Next;
        end
        else
        begin
          PWord(D)^ := ord(' ') + ord('-') shl 8;
          inc(D, 2);
Next:     if Space = SpaceBeg then
            SpaceBeg := D + 1;
          inc(P);
          Space := D + 1;
        end
      else
        Space := D;
      if P^ = #0 then
        break;
      D^ := ' ';
      inc(D);
    until false;
    if Space > DBeg then
      dec(Space);
    while Space > SpaceBeg do
    begin
      if Space^ in ['A'..'Z'] then
        if not (Space[1] in ['A'..'Z', ' ']) then
          inc(Space^, 32); // lowercase conversion of not last fully uppercased word
      dec(Space);
    end;
  end;
  result := D - DBeg;
end;

procedure CamelCase(P: PAnsiChar; len: PtrInt; var s: RawUtf8; const isWord: TSynByteSet);
var
  i: PtrInt;
  d: PAnsiChar;
  tmp: TByteToAnsiChar;
begin
  if len > SizeOf(tmp) then
    len := SizeOf(tmp);
  for i := 0 to len - 1 do
    if not (ord(P[i]) in isWord) then
    begin
      if i > 0 then
      begin
        MoveFast(P^, tmp, i);
        inc(P, i);
        dec(len, i);
      end;
      d := @tmp[i];
      while len > 0 do
      begin
        while (len > 0) and
              not (ord(P^) in isWord) do
        begin
          inc(P);
          dec(len);
        end;
        if len = 0 then
          break;
        d^ := NormToUpperAnsi7[P^];
        inc(d);
        repeat
          inc(P);
          dec(len);
          if not (ord(P^) in isWord) then
            break;
          d^ := P^;
          inc(d);
        until len = 0;
      end;
      P := @tmp;
      len := d - tmp;
      break;
    end;
  FastSetString(s, P, len);
end;

procedure CamelCase(const text: RawUtf8; var s: RawUtf8; const isWord: TSynByteSet);
begin
  CamelCase(pointer(text), length(text), s, isWord);
end;

function CamelCase(const text: RawUtf8): RawUtf8; overload;
begin
  CamelCase(pointer(text), length(text), result);
end;

function LowerCamelCase(const text: RawUtf8): RawUtf8;
begin
  CamelCase(pointer(text), length(text), result);
  if result <> '' then
    if IsUpper(result) then
      LowerCaseSelf(result)
    else
      PByte(result)^ := NormToLowerAnsi7Byte[PByte(result)^];
end;

function UriCase(const text: RawUtf8): RawUtf8;
begin
  FastSetString(result, pointer(text), length(text));
  if result <> '' then
    PByte(result)^ := NormToLowerAnsi7Byte[PByte(result)^];
end;

type // SnakeCase() state machine
  TSnakeCase = set of (scDigit, scUp, scLow, sc_, scNext_);
var
  SNAKE_CHARS: array[AnsiChar] of TSnakeCase;

procedure SnakeCase(P: PAnsiChar; len: PtrInt; var s: RawUtf8);
var
  tmp: TByteToAnsiChar;
  d: PAnsiChar;
  flags, last: TSnakeCase;
begin
  if len > SizeOf(tmp) then
    len := SizeOf(tmp);
  flags := [];
  d := @tmp;
  while len <> 0 do
  begin
    last := flags;
    flags := SNAKE_CHARS[P^];
    if flags * [scDigit, scUp, scLow, sc_] = [] then
      include(flags, scNext_)
    else
    begin
      if (d <> @tmp) and
         not (sc_ in last) and
         ((scNext_ in last) or
          ((scUp in flags) and ((scLow in last) or (scDigit in last)) or
          ((scLow in flags) and (scDigit in last)) or
          ((scDigit in flags) and not (scDigit in last)) or
          ((scUp in flags) and (not (scLow in last)) and (len > 0) and
           (P[1] in ['a' .. 'z'])))) then
      begin
        d^ := '_';
        inc(d);
        include(flags, sc_);
      end;
      if not ((sc_ in last) and (sc_ in flags)) then
      begin
        d^ := NormToLowerAnsi7[P^];
        inc(d);
      end;
      exclude(flags, scNext_);
    end;
    inc(P);
    dec(len);
  end;
  FastSetString(s, @tmp, d - PAnsiChar(@tmp));
end;

function SnakeCase(const text: RawUtf8): RawUtf8;
begin
  SnakeCase(pointer(text), length(text), result);
end;

function IsReservedKeyWord(const aName: RawUtf8): boolean;
var
  up: TByteToAnsiChar;
begin
  UpperCopy255Buf(@up, pointer(aName), length(aName))^ := #0;
  result := FastFindPUtf8CharSorted(
    @RESERVED_KEYWORDS, high(RESERVED_KEYWORDS), @up) >= 0; // O(log(n)) search
end;

function SanitizePascalName(const aName: RawUtf8; KeyWordCheck: boolean): RawUtf8;
begin
  CamelCase(aName, result);
  if result = '' then
    raise ESynUnicode.CreateFmt('Unexpected SanitizePascalName(%s)', [aName]);
  result[1] := UpCase(result[1]);
  if KeyWordCheck and
     IsReservedKeyWord(result) then
    result := '_' + result; // avoid identifier name collision
end;

procedure GetCaptionFromPCharLen(P: PUtf8Char; out result: string);
var
  tmp: TByteToAnsiChar;
begin
  if P = nil then
    exit;
  {$ifdef UNICODE}
  Utf8DecodeToUnicodeString(tmp, UnCamelCase(@tmp, P), result);
  {$else}
  SetString(result, PAnsiChar(@tmp), UnCamelCase(@tmp, P));
  {$endif UNICODE}
  if Assigned(LoadResStringTranslate) then
    LoadResStringTranslate(result);
end;


{ ************ TRawUtf8DynArray Processing Functions }

function IsZero(const Values: TRawUtf8DynArray): boolean;
var
  i: PtrInt;
begin
  result := false;
  for i := 0 to length(Values) - 1 do
    if Values[i] <> '' then
      exit;
  result := true;
end;

function TRawUtf8DynArrayFrom(const Values: array of RawUtf8): TRawUtf8DynArray;
var
  i: PtrInt;
begin
  Finalize(result);
  SetLength(result, length(Values));
  for i := 0 to high(Values) do
    result[i] := Values[i];
end;

function FindRawUtf8(Values: PRawUtf8; const Value: RawUtf8; ValuesCount: integer;
  CaseSensitive: boolean): integer;
var
  len: TStrLen;
begin
  dec(ValuesCount);
  len := length(Value);
  if len = 0 then
    for result := 0 to ValuesCount do
      if Values^ = '' then
        exit
      else
        inc(Values)
  else if CaseSensitive then
    for result := 0 to ValuesCount do
      if (PtrUInt(Values^) <> 0) and
         ({%H-}PStrLen(PtrUInt(Values^) - _STRLEN)^ = len) and
         CompareMemFixed(pointer(PtrInt(Values^)), pointer(Value), len) then
        exit
      else
        inc(Values)
  else
    for result := 0 to ValuesCount do
      if (PtrUInt(Values^) <> 0) and // StrIComp() won't change length
         ({%H-}PStrLen(PtrUInt(Values^) - _STRLEN)^ = len) and
         (StrIComp(pointer(Values^), pointer(Value)) = 0) then
        exit
      else
        inc(Values);
  result := -1;
end;

function FindRawUtf8(const Values: TRawUtf8DynArray; const Value: RawUtf8;
  CaseSensitive: boolean): integer;
begin
  result := FindRawUtf8(pointer(Values), Value, length(Values), CaseSensitive);
end;

function FindRawUtf8(const Values: array of RawUtf8; const Value: RawUtf8;
  CaseSensitive: boolean): integer;
begin
  result := high(Values);
  if result >= 0 then
    result := FindRawUtf8(@Values[0], Value, result + 1, CaseSensitive);
end;

function AddRawUtf8(var Values: TRawUtf8DynArray; const Value: RawUtf8): PtrInt;
begin
  result := length(Values);
  SetLength(Values, result + 1);
  Values[result] := Value;
end;

function AddRawUtf8(var Values: TRawUtf8DynArray; const Value: RawUtf8;
  NoDuplicates, CaseSensitive: boolean): boolean;
begin
  result := false;
  if NoDuplicates then
    if FindRawUtf8(Values, Value, CaseSensitive) >= 0 then
      exit;
  AddRawUtf8(Values, Value);
  result := true;
end;

function AddRawUtf8(var Values: TRawUtf8DynArray; var ValuesCount: integer;
  const Value: RawUtf8): PtrInt;
begin
  result := ValuesCount;
  if result = Length(Values) then
    SetLength(Values, NextGrow(result));
  Values[result] := Value;
  inc(ValuesCount);
end;

procedure AddRawUtf8(var Values: TRawUtf8DynArray; const Value: TRawUtf8DynArray);
var
  n, o, i: PtrInt;
begin
  n := length(Value);
  if n = 0 then
    exit;
  o := length(Values);
  SetLength(Values, o + n);
  for i := 0 to n - 1 do
    Values[o + i] := Value[i];
end;

procedure AddRawUtf8(var Values: TRawUtf8DynArray; var ValuesCount: integer;
  const Value: TRawUtf8DynArray);
var
  n, o, i: PtrInt;
begin
  n := length(Value);
  o := ValuesCount;
  inc(ValuesCount, n);
  if ValuesCount > Length(Values) then
    SetLength(Values, NextGrow(ValuesCount));
  for i := 0 to n - 1 do
    Values[o + i] := Value[i];
end;

function RawUtf8DynArrayEquals(const A, B: TRawUtf8DynArray): boolean;
var
  n, i: PtrInt;
begin
  result := (A = B);
  if result then
    exit; // same pointer
  n := length(A);
  if n <> length(B) then
    exit;
  for i := 0 to n - 1 do
    if A[i] <> B[i] then
      exit;
  result := true;
end;

function RawUtf8DynArrayEquals(const A, B: TRawUtf8DynArray; Count: integer): boolean;
var
  i: PtrInt;
begin
  result := false;
  if A <> B then // same pointer
    for i := 0 to Count - 1 do
      if A[i] <> B[i] then
        exit;
  result := true;
end;

function RawUtf8DynArrayContains(const A, B: TRawUtf8DynArray;
  CaseInsensitive: boolean): boolean;
var
  i: PtrInt;
begin
  result := false;
  if A <> B then
    for i := 0 to length(A) - 1 do
      if FindRawUtf8(B, A[i], not CaseInsensitive) < 0 then
        exit; // one missing item is enough to fail
  result := true;
end;

function RawUtf8DynArraySame(const A, B: TRawUtf8DynArray;
  CaseInsensitive: boolean): boolean;
begin
  result := (length(A) = length(B)) and
            RawUtf8DynArrayContains(A, B, CaseInsensitive) and
            RawUtf8DynArrayContains(B, A, CaseInsensitive);
end;

function AddString(var Values: TStringDynArray; const Value: string): PtrInt;
begin
  result := length(Values);
  SetLength(Values, result + 1);
  Values[result] := Value;
end;

procedure StringDynArrayToRawUtf8DynArray(const Source: array of string;
  var Result: TRawUtf8DynArray);
var
  i: PtrInt;
begin
  Finalize(Result);
  SetLength(Result, length(Source));
  for i := 0 to length(Source) - 1 do
    StringToUtf8(Source[i], Result[i]);
end;

function StringDynArrayToRawUtf8DynArray(
  const Source: array of string): TRawUtf8DynArray;
begin
  StringDynArrayToRawUtf8DynArray(Source, result);
end;

procedure StringListToRawUtf8DynArray(Source: TStringList; var Result: TRawUtf8DynArray);
var
  i: PtrInt;
begin
  Finalize(Result);
  SetLength(Result, Source.Count);
  for i := 0 to Source.Count - 1 do
    StringToUtf8(Source[i], Result[i]);
end;

function FastLocatePUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt; Value: PUtf8Char): PtrInt;
begin
  result := FastLocatePUtf8CharSorted(P, R, Value, TUtf8Compare(@StrComp));
end;

function FastLocatePUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt;
  Value: PUtf8Char; Compare: TUtf8Compare): PtrInt;
var
  L, i, cmp: PtrInt;
begin
  // fast O(log(n)) binary search
  if (not Assigned(Compare)) or
     (R < 0) then
    result := 0
  else if Compare(P^[R], Value) < 0 then // quick return if already sorted
    result := R + 1
  else
  begin
    L := 0;
    result := -1; // return -1 if found
    repeat
      {$ifdef CPUX64}
      i := L + R;
      i := i shr 1;
      {$else}
      i := (L + R) shr 1;
      {$endif CPUX64}
      cmp := Compare(P^[i], Value);
      if cmp = 0 then
        exit;
      if cmp < 0 then
        L := i + 1
      else
        R := i - 1;
    until L > R;
    while (i >= 0) and (Compare(P^[i], Value) >= 0) do
      dec(i);
    result := i + 1; // return the index where to insert
  end;
end;

function FastFindPUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt;
  Value: PUtf8Char; Compare: TUtf8Compare): PtrInt;
var
  L, cmp: PtrInt;
begin
  // fast O(log(n)) binary search
  L := 0;
  if Assigned(Compare) and (R >= 0) then
    repeat
      {$ifdef CPUX64}
      result := L + R;
      result := result shr 1;
      {$else}
      result := (L + R) shr 1;
      {$endif CPUX64}
      cmp := Compare(P^[result], Value);
      if cmp = 0 then
        exit;
      if cmp < 0 then
      begin
        L := result + 1;
        if L <= R then
          continue;
        break;
      end;
      R := result - 1;
      if L <= R then
        continue;
      break;
    until false;
  result := -1;
end;

{$ifdef CPUX64}

function FastFindPUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt; Value: PUtf8Char): PtrInt;
{$ifdef FPC} assembler; nostackframe; asm {$else} asm .noframe {$endif}
        {$ifdef win64}  // P=rcx/rdi R=rdx/rsi Value=r8/rdx
        push    rdi
        mov     rdi, P  // P=rdi
        {$endif win64}
        push    r12
        push    r13
        xor     r9, r9  // L=r9
        test    R, R
        jl      @err
        test    Value, Value
        jz      @void
        mov     cl, byte ptr [Value]  // to check first char (likely diverse)
{$ifdef FPC} align 16 {$else} .align 16 {$endif}
@s:     lea     rax, qword ptr [r9 + R]
        shr     rax, 1
        lea     r12, qword ptr [rax - 1]  // branchless main loop
        lea     r13, qword ptr [rax + 1]
        mov     r10, qword ptr [rdi + rax * 8]
        test    r10, r10
        jz      @lt
        cmp     cl, byte ptr [r10]
        je      @eq
        cmovc   R, r12
        cmovnc  r9, r13
@nxt:   cmp     r9, R
        jle     @s
@err:   mov     rax, -1
@found: pop     r13
        pop     r12
        {$ifdef win64}
        pop     rdi
        {$endif win64}
        ret
@void:  mov     rax, -1
        cmp     qword ptr [P], 0
        cmove   rax, Value
        jmp     @found
@lt:    mov     r9, r13 // very unlikely P[rax]=nil
        jmp     @nxt
@eq:    mov     r11, Value // first char equal -> check others
@sub:   mov     cl, byte ptr [r10]
        add     r10, 1
        add     r11, 1
        test    cl, cl
        jz      @found
        mov     cl, byte ptr [r11]
        cmp     cl, byte ptr [r10]
        je      @sub
        mov     cl, byte ptr [Value]  // reset first char
        cmovc   R, r12
        cmovnc  r9, r13
        cmp     r9, R
        jle     @s
        jmp     @err
end;

{$else}

function FastFindPUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt; Value: PUtf8Char): PtrInt;
var
  L: PtrInt;
  c: byte;
  piv, val: PByte;
begin
  // fast O(log(n)) binary search using inlined StrCompFast()
  if R >= 0 then
    if Value <> nil then
    begin
      L := 0;
      repeat
        result := L + R;
        result := result shr 1;
        piv := pointer(P^[result]);
        if piv <> nil then
        begin
          val := pointer(Value);
          c := piv^;
          if c = val^ then
            repeat
              if c = 0 then
                exit;  // StrComp(P^[result],Value)=0
              inc(piv);
              inc(val);
              c := piv^;
            until c <> val^;
          if c > val^ then
          begin
            R := result - 1;  // StrComp(P^[result],Value)>0
            if L <= R then
              continue;
            break;
          end;
        end;
        L := result + 1;  // StrComp(P^[result],Value)<0
        if L <= R then
          continue;
        break;
      until false;
    end
    else if P^[0] = nil then
    begin
      // '' should be in lowest P[] slot
      result := 0;
      exit;
    end;
  result := -1;
end;

{$endif CPUX64}

function FastFindUpperPUtf8CharSorted(P: PPUtf8CharArray; R: PtrInt;
  Value: PUtf8Char; ValueLen: PtrInt): PtrInt;
var
  tmp: TByteToAnsiChar;
begin
  UpperCopy255Buf(@tmp, Value, ValueLen)^ := #0;
  result := FastFindPUtf8CharSorted(P, R, @tmp);
end;

function FastFindIndexedPUtf8Char(P: PPUtf8CharArray; R: PtrInt;
  var SortedIndexes: TCardinalDynArray; Value: PUtf8Char;
  ItemComp: TUtf8Compare): PtrInt;
var
  L, cmp: PtrInt;
begin
  // fast O(log(n)) binary search
  L := 0;
  if 0 <= R then
    repeat
      {$ifdef CPUX64}
      result := L + R;
      result := result shr 1;
      {$else}
      result := (L + R) shr 1;
      {$endif CPUX64}
      cmp := ItemComp(P^[SortedIndexes[result]], Value);
      if cmp = 0 then
      begin
        result := SortedIndexes[result];
        exit;
      end;
      if cmp < 0 then
      begin
        L := result + 1;
        if L <= R then
          continue;
        break;
      end;
      R := result - 1;
      if L <= R then
        continue;
      break;
    until false;
  result := -1;
end;

function AddSortedRawUtf8(var Values: TRawUtf8DynArray; var ValuesCount: integer;
  const Value: RawUtf8; CoValues: PIntegerDynArray; ForcedIndex: PtrInt;
  Compare: TUtf8Compare): PtrInt;
var
  n: PtrInt;
begin
  if ForcedIndex >= 0 then
    result := ForcedIndex
  else
  begin
    if not Assigned(Compare) then
      Compare := @StrComp;
    result := FastLocatePUtf8CharSorted(pointer(Values), ValuesCount - 1,
      pointer(Value), Compare);
    if result < 0 then
      exit; // Value exists -> fails
  end;
  n := Length(Values);
  if ValuesCount = n then
  begin
    n := NextGrow(n);
    SetLength(Values, n);
    if CoValues <> nil then
      SetLength(CoValues^, n);
  end;
  n := ValuesCount;
  if result < n then
  begin
    n := (n - result) * SizeOf(pointer);
    MoveFast(pointer(Values[result]), pointer(Values[result + 1]), n);
    PtrInt(Values[result]) := 0; // avoid GPF
    if CoValues <> nil then
    begin
      {$ifdef CPU64} n := n shr 1; {$endif} // 64-bit pointer to 32-bit integer
      MoveFast(CoValues^[result], CoValues^[result + 1], n);
    end;
  end
  else
    result := n;
  Values[result] := Value;
  inc(ValuesCount);
end;

type
  /// used internally for faster quick sort
  {$ifdef USERECORDWITHMETHODS}
  TQuickSortRawUtf8 = record
  {$else}
  TQuickSortRawUtf8 = object
  {$endif USERECORDWITHMETHODS}
  public
    Compare: TUtf8Compare;
    CoValues: PIntegerArray;
    pivot: pointer;
    procedure Sort(Values: PPointerArray; L, R: PtrInt);
  end;

procedure TQuickSortRawUtf8.Sort(Values: PPointerArray; L, R: PtrInt);
var
  i, j, p: PtrInt;
  tmp: pointer;
  int: integer;
begin
  if L < R then
    repeat
      i := L;
      j := R;
      p := (L + R) shr 1;
      repeat
        pivot := Values^[p];
        while Compare(Values^[i], pivot) < 0 do
          inc(i);
        while Compare(Values^[j], pivot) > 0 do
          dec(j);
        if i <= j then
        begin
          tmp := Values^[j];
          Values^[j] := Values^[i];
          Values^[i] := tmp;
          if CoValues <> nil then
          begin
            int := CoValues^[j];
            CoValues^[j] := CoValues^[i];
            CoValues^[i] := int;
          end;
          if p = i then
            p := j
          else if p = j then
            p := i;
          inc(i);
          dec(j);
        end;
      until i > j;
      if j - L < R - i then // use recursion only for smaller range
      begin
        if L < j then
          Sort(Values, L, j);
        L := i;
      end
      else
      begin
        if i < R then
          Sort(Values, i, R);
        R := j;
      end;
    until L >= R;
end;

procedure QuickSortRawUtf8(var Values: TRawUtf8DynArray; ValuesCount: integer;
  CoValues: PIntegerDynArray; Compare: TUtf8Compare);
var
  qs: TQuickSortRawUtf8;
begin
  if Assigned(Compare) then
    qs.Compare := Compare
  else
    qs.Compare := @StrComp;
  if CoValues = nil then
    qs.CoValues := nil
  else
    qs.CoValues := pointer(CoValues^);
  qs.Sort(pointer(Values), 0, ValuesCount - 1);
end;

procedure QuickSortRawUtf8(Values: PRawUtf8Array; L, R: PtrInt;
  caseInsensitive: boolean);
var
  qs: TQuickSortRawUtf8;
begin
  qs.Compare := StrCompByCase[caseInsensitive];
  qs.CoValues := nil;
  qs.Sort(pointer(Values), L, R);
end;

function SumRawUtf8Length(Values: PRawUtf8; n: integer): TStrLen;
begin
  result := 0;
  if n > 0 then
    repeat
      inc(result, length(Values^));
      inc(Values);
      dec(n);
    until n = 0;
end;

function DeduplicateRawUtf8Sorted(val: PPointerArray; last: PtrInt): PtrInt;
var
  i: PtrInt;
begin
  // sub-function for better code generation
  i := 0;
  repeat // here last>0 so i<last
    if RawUtf8(val[i]) = RawUtf8(val[i + 1]) then
      break;
    inc(i);
    if i <> last then
      continue;
    result := i;
    exit;
  until false;
  result := i;
  inc(i);
  if i = last then
    exit;
  repeat
    if RawUtf8(val[i]) <> RawUtf8(val[i + 1]) then
    begin
      FastAssignNew(val[result], val[i]);
      val[i] := nil;
      inc(result);
    end;
    inc(i);
  until i = last;
  FastAssignNew(val[result], val[i]);
  val[i] := nil;
end;

procedure DeduplicateRawUtf8(var Values: TRawUtf8DynArray);
var
  c, n: PtrInt;
begin
  c := length(Values);
  if c <= 1 then
    exit; // nothing to search
  QuickSortRawUtf8(Values, c);
  n := DeduplicateRawUtf8Sorted(pointer(Values), c - 1) + 1;
  if n <> c then
    SetLength(Values, n);
end;

procedure MakeUniqueRawUtf8DynArray(var Values: TRawUtf8DynArray);
begin
  Values := copy(Values); // sub-proc to avoid try..finally
end;

function DeleteRawUtf8(var Values: TRawUtf8DynArray; Index: PtrInt): boolean;
var
  n: PtrInt;
begin
  n := length(Values);
  if PtrUInt(Index) >= PtrUInt(n) then
    result := false
  else
  begin
    dec(n);
    if PDACnt(PAnsiChar(pointer(Values)) - _DACNT)^ > 1 then
      MakeUniqueRawUtf8DynArray(Values);
    Values[Index] := ''; // avoid GPF
    if n > Index then
    begin
      MoveFast(pointer(Values[Index + 1]), pointer(Values[Index]),
        (n - Index) * SizeOf(pointer));
      PtrUInt(Values[n]) := 0; // avoid GPF
    end;
    SetLength(Values, n);
    result := true;
  end;
end;

function DeleteRawUtf8(var Values: TRawUtf8DynArray; var ValuesCount: integer;
  Index: integer; CoValues: PIntegerDynArray): boolean;
var
  n: integer;
begin
  n := ValuesCount;
  if cardinal(Index) >= cardinal(n) then
    result := false
  else
  begin
    dec(n);
    ValuesCount := n;
    if PDACnt(PAnsiChar(pointer(Values)) - _DACNT)^ > 1 then
      MakeUniqueRawUtf8DynArray(Values);
    Values[Index] := ''; // avoid GPF
    dec(n, Index);
    if n > 0 then
    begin
      if CoValues <> nil then
        MoveFast(CoValues^[Index + 1], CoValues^[Index], n * SizeOf(integer));
      MoveFast(pointer(Values[Index + 1]), pointer(Values[Index]), n * SizeOf(pointer));
      PtrUInt(Values[ValuesCount]) := 0; // avoid GPF
    end;
    result := true;
  end;
end;

{$ifdef OSPOSIX}

{ TPosixFileCaseInsensitive }

constructor TPosixFileCaseInsensitive.Create(
  const aFolder: TFileName; aSubFolders: boolean);
begin
  fFolder := aFolder;
  fSubFolders := aSubFolders;
  fFlushSeconds := 60;
end;

procedure TPosixFileCaseInsensitive.SetFolder(const aFolder: TFileName);
begin
  if self = nil then
    exit;
  fSafe.WriteLock;
  try
    fFiles := nil; // force list refresh
    fFolder := aFolder;
  finally
    fSafe.WriteUnLock;
  end;
end;

procedure TPosixFileCaseInsensitive.SetSubFolders(aSubFolders: boolean);
begin
  if (self = nil) or
     (fSubFolders = aSubFolders) then
    exit;
  fSubFolders := aSubFolders;
  Flush;
end;

procedure TPosixFileCaseInsensitive.OnIdle(tix64: Int64);
var
  tix32: cardinal;
begin
  if (self = nil) or
     (fFiles = nil) or
     (fFlushSeconds = 0) then
    exit;
  if tix64 = 0 then
    tix32 := GetTickSec
  else
    tix32 := tix64 div MilliSecsPerSec;
  if tix32 < fNextTix then
    exit;
  fSafe.WriteLock;
  try
    fFiles := nil; // force list refresh
  finally
    fSafe.WriteUnLock;
  end;
end;

procedure TPosixFileCaseInsensitive.Flush;
begin
  SetFolder(fFolder);
end;

function TPosixFileCaseInsensitive.Find(const aSearched: TFileName;
  aReadMs: PInteger): TFileName;
var
  start, stop: Int64;
  i: PtrInt;
  fn: RawUtf8;
begin
  result := '';
  if aReadMs <> nil then
    aReadMs^ := 0;
  if (self = nil) or
     (fFolder = '') or
     (aSearched = '') then
    exit;
  if fFiles = nil then // need to refresh the cache
  begin
    fSafe.WriteLock;
    try
      if fFiles = nil then // use efficient getdents64() syscall
      begin
        if aReadMs <> nil then
          QueryPerformanceMicroSeconds(start);
        fFiles := PosixFileNames(fFolder, fSubFolders, nil, nil, {excldir=}true);
        QuickSortRawUtf8(fFiles, length(fFiles), nil, @StrIComp);
        if aReadMs <> nil then
        begin
          QueryPerformanceMicroSeconds(stop);
          aReadMs^ := stop - start;
        end;
        if fFlushSeconds <> 0 then
          fNextTix := GetTickSec + fFlushSeconds;
      end;
    finally
      fSafe.WriteUnLock;
    end;
  end;
  StringToUtf8(aSearched, fn);
  fSafe.ReadLock; // non-blocking lookup
  try
    i := FastFindPUtf8CharSorted( // efficient O(log(n)) binary search
      pointer(fFiles), high(fFiles), pointer(fn), @StrIComp);
    if i >= 0 then
      Utf8ToFileName(fFiles[i], result); // use exact file name case from OS
  finally
    fSafe.ReadUnLock;
  end;
end;

function TPosixFileCaseInsensitive.Count: PtrInt;
begin
  if self = nil then
    result := 0
  else
    result := length(fFiles);
end;

function TPosixFileCaseInsensitive.Files: TRawUtf8DynArray;
begin
  result := nil;
  if (self = nil) or
     (fFiles = nil) then
    exit;
  fSafe.ReadLock;
  try
    result := copy(fFiles); // make a copy for thread safety
  finally
    fSafe.ReadUnLock;
  end;
end;

{$endif OSPOSIX}


{ ************** Operating-System Independent Unicode Process }

// freely inspired by Bero's PUCU library, released under zlib license
//  https://github.com/BeRo1985/pucu  (C)2016-2020 Benjamin Rosseaux

{$define UU_COMPRESSED}
// 1KB compressed static table in the exe renders into our 20KB UU[] array :)

const
  UU_BLOCK_HI = 7;
  UU_BLOCK_LO = 127;
  UU_INDEX_HI = 5;
  UU_INDEX_LO = 31;

type
  // 20,016 bytes for full Unicode 10.0 case folding branchless conversion
  {$ifdef USERECORDWITHMETHODS}
  TUnicodeUpperTable = record
  {$else}
  TUnicodeUpperTable = object
  {$endif USERECORDWITHMETHODS}
  public
    Block: array[0..37, 0..127] of integer;
    IndexHi: array[0..271] of byte;
    IndexLo: array[0..8, 0..31] of byte;
    // branchless Unicode 10.0 uppercase folding using our internal tables,
    // expecting c <= UNICODE_MAX, as requested from any standard UTF-8/UTF-16
    function UnicodeUpper(c: PtrUInt): PtrUInt;
      {$ifdef HASINLINE} inline; {$endif}
  end;
  {$ifndef CPUX86NOTPIC}
  PUnicodeUpperTable = ^TUnicodeUpperTable;
  {$endif CPUX86NOTPIC}

var
  {$ifdef UU_COMPRESSED}
  UU: TUnicodeUpperTable;
  {$else}
  UU: TUnicodeUpperTable = (
    Block: (
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32,
      -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 743, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -32, -32, -
      32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32,
      -32, -32, -32, -32, -32, -32, 0, -32, -32, -32, -32, -32, -32, -32, 121),
     (0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -232, 0, -1, 0, -1, 0, -1, 0, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, 0, -1, 0, -1, 0, -1, -300),
     (195, 0, 0, -1, 0, -1, 0, 0, -1, 0, 0, 0, -1, 0, 0, 0, 0, 0, -1, 0,
      0, 97, 0, 0, 0, -1, 163, 0, 0, 0, 130, 0, 0, -1, 0, -1, 0, -1, 0, 0, -1, 0,
      0, 0, 0, -1, 0, 0, -1, 0, 0, 0, -1, 0, -1, 0, 0, -1, 0, 0, 0, -1, 0, 56, 0,
      0, 0, 0, 0, -1, -2, 0, -1, -2, 0, -1, -2, 0, -1, 0, -1, 0, -1, 0, -1, 0, -
      1, 0, -1, 0, -1, 0, -1, -79, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, 0, -1, -2, 0, -1, 0, 0, 0, -1, 0, -1, 0, -1, 0, -1),
     (0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, 0, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 10815,
      10815, 0, -1, 0, 0, 0, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 10783, 10780,
      10782, -210, -206, 0, -205, -205, 0, -202, 0, -203, 42319, 0, 0, 0, -205,
      42315, 0, -207, 0, 42280, 42308, 0, -209, -211, 42308, 10743, 42305, 0, 0,
      -211, 0, 10749, -213, 0, 0, -214, 0, 0, 0, 0, 0, 0, 0, 10727, 0, 0),
     (-218, 0, 0, -218, 0, 0, 0, 42282, -218, -69, -217, -217, -71, 0, 0, 0, 0, 0,
      -219, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 42261, 42258, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 84, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, -1, 0, -1, 0, 0, 0, -1, 0, 0, 0, 130, 130, 130, 0, 0),
     (0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -38, -37, -37, -37, 0, -32,
      -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32,
      -32, -31, -32, -32, -32, -32, -32, -32, -32, -32, -32, -64, -63, -63, 0,
      -62, -57, 0, 0, 0, -47, -54, -8, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, -86, -80, 7, -116, 0, -96, 0, 0,
      -1, 0, 0, -1, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32,
      -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32,
      -32, -32, -32, -32, -32, -32, -80, -80, -80, -80, -80, -80, -80, -80, -80,
      -80, -80, -80, -80, -80, -80, -80, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1),
     (0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, -15, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1),
     (0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48,
      -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48,
      -48, -48, -48, -48, -48),
     (-48, -48, -48, -48, -48, -48, -48, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -8, -8, -8,
      -8, -8, -8, 0, 0),
     (-6254, -6253, -6244, -6242, -6242, -6243, -6236, -6181, 35266, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35332, 0, 0, 0, 3814, 0, 0),
     (0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1),
     (0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, 0, 0, 0, 0, -59, 0, 0, 0, 0, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1),
     (8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8, 8, 8, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0,
      8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8, 8, 8, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 8, 0, 8, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8,
      8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 74, 74, 86, 86, 86, 86, 100, 100,
      128, 128, 112, 112, 126, 126, 0, 0),
     (8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0,
      0, 0, 0, 0, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8, 8,
      8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      -7205, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -28, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, -16, -16, -16, -16, -16, -16, -16, -16, -16, -16, -16,
      -16, -16, -16, -16, -16),
     (0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -26, -26, -26, -26,
      -26, -26, -26, -26, -26, -26, -26, -26, -26, -26, -26, -26, -26, -26, -26,
      -26, -26, -26, -26, -26, -26, -26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48,
      -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48,
      -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48, -48,
      -48, -48, -48, -48, -48, -48, -48, 0, 0, -1, 0, 0, 0, -10795, -10792, 0, -1,
      0, -1, 0, -1, 0, 0, 0, 0, 0, 0, -1, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, 0, 0, 0, 0, 0, 0,
      0, -1, 0, -1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (-7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264,
      -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264,
      -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264, -7264,
      -7264, -7264, -7264, -7264, -7264, 0, -7264, 0, 0, 0, 0, 0, -7264, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, 0, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, -1, 0, 0, -1),
     (0, -1, 0, -1, 0,  -1, 0, -1, 0, 0, 0, 0, -1, 0, 0, 0, 0, -1, 0, -1, 0, 0,
      0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -928, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -38864, -38864,
      -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864,
      -38864, -38864, -38864, -38864, -38864),
     (-38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864,
      -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864,
      -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864,
      -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864,
      -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864,
      -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864,
      -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864, -38864,
      -38864, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -32, -32, -32, -32, -32, -32,
      -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32,
      -32, -32, -32, -32, -32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -40, -40, -40, -40,
      -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40,
      -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40,
      -40, -40, -40, -40, -40, -40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -40, -40,
      -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40,
      -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40, -40,
      -40, -40, -40, -40, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64,
      -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64,
      -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64, -64,
      -64, -64, -64, -64, -64, -64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -32, -32, -32, -32, -32, -32, -32,
      -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, -32,
      -32, -32, -32, -32, -32, -32, -32, -32, -32, -32, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, -34, -34, -34, -34, -34, -34, -34, -34, -34, -34,
      -34, -34, -34, -34, -34, -34, -34, -34, -34, -34, -34, -34, -34, -34, -34,
      -34, -34, -34, -34, -34, -34, -34, -34, -34, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    );
    IndexHi: (0, 1, 2, 3, 3, 3, 3, 3, 3, 3, 4, 3, 3, 3, 3, 5, 6, 7, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 8, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3);
    IndexLo: ((0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 12, 12, 12, 12, 12,
      12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12), (12, 12, 12, 12, 12,
      12, 12, 13, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
      12, 14, 15, 12, 16, 17, 18, 19), (12, 12, 20, 21, 12, 12, 12, 12, 12, 22,
      12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 23, 24, 25, 12, 12,
      12, 12, 12), (12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
      12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12), (12,
      12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 26, 27, 28, 29, 12, 12, 12, 12,
      12, 12, 30, 31, 12, 12, 12, 12, 12, 12, 12, 12), (12, 12, 12, 12, 12, 12,
      12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
      12, 12, 12, 12, 12, 32, 12), (12, 12, 12, 12, 12, 12, 12, 12, 33, 34, 12,
      12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 35, 12, 12, 12, 12,
      12, 12), (12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
      12, 36, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12), (12, 12,
      12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 37, 12, 12,
      12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12));
  );
  {$endif UU_COMPRESSED}

function TUnicodeUpperTable.UnicodeUpper(c: PtrUInt): PtrUInt;
var
  i: PtrUInt;
begin
  // branchless conversion in range [0 .. UNICODE_MAX = $10ffff]
  i := c shr UU_BLOCK_HI;
  result := PtrInt(c) +
            Block[IndexLo[IndexHi[i shr UU_INDEX_HI], i and UU_INDEX_LO],
                  c and UU_BLOCK_LO];
end;

function Utf8UpperReference(S, D: PUtf8Char): PUtf8Char;
var
  c: PtrUInt;
  s2: PUtf8Char;
  {$ifdef CPUX86NOTPIC}
  tab: TUnicodeUpperTable absolute UU;
  {$else}
  tab: PUnicodeUpperTable;
  {$endif CPUX86NOTPIC}
begin
  {$ifndef CPUX86NOTPIC}
  tab := @UU;
  {$endif CPUX86NOTPIC}
  if S <> nil then
    repeat
      c := ord(S^);
      if c <= $7f then
        if c = 0 then
          break
        else
        begin
          inc(c, tab.Block[0, c]); // branchless a..z -> A..Z
          D^ := AnsiChar(c);
          inc(S);
          inc(D);
          continue;
        end
      else if c and $20 = 0 then
      begin
        c := (c shl 6) + byte(S[1]) - UTF8_EXTRA1_OFFSET; // process $0..$7ff
        inc(S, 2);
      end
      else
      begin
        s2 := S;
        c := UTF8_TABLE.GetHighUtf8Ucs4(s2); // handle even surrogates
        S := s2;
        if c = 0 then
          c := UNICODE_REPLACEMENT_CHARACTER; // =$fffd for invalid input
      end;
      inc(D, IsoUcsToUtf8(tab.UnicodeUpper(c), D)); // assume <= UNICODE_MAX
    until false;
  D^ := #0;
  result := D;
end;

function Utf8UpperReference(S, D: PUtf8Char; SLen: PtrUInt): PUtf8Char;
var
  c: PtrUInt;
  endSBy4: PUtf8Char;
  extra, i: PtrInt;
  {$ifdef CPUX86NOTPIC}
  tab: TUnicodeUpperTable absolute UU;
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  tab: PUnicodeUpperTable;
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
label
  by1, by4; // ugly but faster
begin
  if (S <> nil) and
     (D <> nil) then
  begin
    {$ifndef CPUX86NOTPIC}
    tab := @UU;
    utf8 := @UTF8_TABLE;
    {$endif CPUX86NOTPIC}
    // first handle trailing 7-bit ASCII chars, by quad
    inc(SLen, PtrUInt(S));
    endSBy4 := PUtf8Char(SLen) - 4;
    if S <= endSBy4 then
      repeat
        if PCardinal(S)^ and $80808080 <> 0 then
          goto by1; // break on first non ASCII quad
by4:    i := byte(S[0]);
        inc(i, tab.Block[0, i]); // branchless a..z -> A..Z
        D[0] := AnsiChar(i);
        i := byte(S[1]);
        inc(i, tab.Block[0, i]);
        D[1] := AnsiChar(i);
        i := byte(S[2]);
        inc(i, tab.Block[0, i]);
        D[2] := AnsiChar(i);
        i := byte(S[3]);
        inc(i, tab.Block[0, i]);
        D[3] := AnsiChar(i);
        inc(S, 4);
        inc(D, 4);
      until S > endSBy4;
    // generic loop, handling one UCS-4 CodePoint per iteration
    if S < PUtf8Char(SLen) then
      repeat
by1:    c := byte(S^);
        inc(S);
        if c <= $7f then
        begin
          inc(c, tab.Block[0, c]); // branchless a..z -> A..Z
          D^ := AnsiChar(c);
          inc(D);
          if S <= endSBy4 then
            if PCardinal(S)^ and $80808080 = 0 then
              goto By4
            else
              continue
          else if S < PUtf8Char(SLen) then
            continue
          else
            break;
        end
        else
        begin
          extra := utf8.Lookup[c];
          if (extra = UTF8_INVALID) or // allow full UTF-8/UCS-4 range
             (S + extra > PUtf8Char(SLen)) then
            break;
          i := 0;
          repeat
            c := (c shl 6) + byte(S[i]);
            inc(i)
          until i = extra;
          inc(S, extra);
          with utf8.Extra[extra] do
          begin
            dec(c, offset);
            if c < minimum then
              break; // invalid input content
          end;
          inc(D, IsoUcsToUtf8(tab.UnicodeUpper(c), D)); // assume <= UNICODE_MAX
          if S < PUtf8Char(SLen) then
            continue
          else
            break;
        end;
      until false;
    D^ := #0;
  end;
  result := D;
end;

function UpperCaseReference(const S: RawUtf8): RawUtf8;
var
  len: integer;
  tmp: TSynTempBuffer;
begin
  len := length(S);
  tmp.Init(len * 2); // some codepoints enhance in length
  tmp.Done(Utf8UpperReference(pointer(S), tmp.buf, len), result);
end;

function Ucs4Comp(a, b: PUcs4CodePoint): integer;
var
  c: Ucs4CodePoint;
begin
  result := 0;
  if a <> b then
    if a <> nil then
      if b <> nil then
      begin
        repeat
          c := a^;
          if c <> b^ then
            break
          else if c = 0 then
            exit; // a = b
          inc(a);
          inc(b);
        until false;
        result := CompareCardinal(c, b^);
      end
      else
        inc(result) // b = ''
    else
      dec(result);  // a = ''
end;

function Ucs4Compare(const a, b: RawUcs4): integer;
begin
  result := Ucs4Comp(pointer(a), pointer(b));
end;

procedure Utf8ToRawUcs4(u: PUtf8Char; L: PtrInt; out ucs4: RawUcs4);
var
  p: PUcs4CodePoint;
begin
  if (u = nil) or
     (L <= 0) then
    exit;
  SetLength(ucs4, L + 1); // + 1 for an ending 0
  inc(L, PtrUInt(u));
  p := pointer(ucs4);
  repeat
    p^ := NextUtf8Ucs4(u); // allow conversion of #0 within the input
    inc(p);
  until PtrUInt(u) >= PtrUInt(L);
  p^ := 0; // always end with a 0
  DynArrayFakeLength(ucs4, (PAnsiChar(p) - pointer(ucs4)) shr 2); // no realloc
end;

function Utf8ToRawUcs4(const S: RawUtf8): RawUcs4;
begin
  Utf8ToRawUcs4(pointer(S), length(S), result);
end;

procedure RawUcs4ToUtf8(u4: PUcs4CodePoint; L: PtrInt; out u: RawUtf8);
var
  p: PUtf8Char;
begin
  if (u4 = nil) or
     (L <= 0) then
    exit;
  p := FastSetString(u, L * 6); // prepare for the worse (paranoid)
  repeat
    inc(p, Ucs4ToUtf8(u4^, p)); // here u4^ is a UTF-32/UCS-4 code point
    inc(u4);
    dec(L);
  until L = 0;
  FakeLength(u, p - pointer(u)); // no realloc
end;

function RawUcs4ToUtf8(const ucs4: RawUcs4): RawUtf8;
begin
  RawUcs4ToUtf8(pointer(ucs4), length(ucs4), result);
end;

function UpperCaseUcs4Reference(const S: RawUtf8): RawUcs4;
var
  c, n: PtrUInt;
  p: PUtf8Char;
begin
  result := nil;
  if S = '' then
    exit;
  SetLength(result, length(S) + 1);
  p := pointer(S);
  n := 0;
  repeat
    c := NextUtf8Ucs4(p);
    if c = 0 then
      break;
    result[n] := UU.UnicodeUpper(c);
    inc(n);
  until false;
  if n = 0 then
    result := nil
  else
  begin
    result[n] := 0; // always end with a 0
    DynArrayFakeLength(result, n); // faster than SetLength()
  end;
end;

function Utf8ICompReference(u1, u2: PUtf8Char): PtrInt;
var
  c2: PtrInt;
  {$ifdef CPUX86NOTPIC}
  tab: TUnicodeUpperTable absolute UU;
  {$else}
  tab: PUnicodeUpperTable;
  {$endif CPUX86NOTPIC}
label
  c2low;
begin
  {$ifndef CPUX86NOTPIC}
  tab := @UU;
  {$endif CPUX86NOTPIC}
  if u1 <> u2 then
    if u1 <> nil then
      if u2 <> nil then
        repeat
          result := ord(u1^);
          c2 := ord(u2^);
          if result <= $7f then
            if result <> 0 then
            begin
              inc(u1);
              inc(result, tab.Block[0, result]); // branchless a..z -> A..Z
              if c2 <= $7f then
              begin
c2low:          if c2 = 0 then
                  exit; // u1>u2 -> return u1^
                inc(u2);
                inc(c2, tab.Block[0, c2]);
                dec(result, c2);
                if result <> 0 then
                  exit;
                continue;
              end;
            end
            else
            begin
              // result=u1^=#0 -> end of u1 reached
              if c2 <> 0 then    // end of u2 reached -> u1=u2 -> return 0
                result := -1;    // u1<u2
              exit;
            end
          else
          begin
            // fast Unicode 10.0 uppercase conversion
            if result and $20 = 0 then // $0..$7ff common case
            begin
              result := (result shl 6) + byte(u1[1]) - UTF8_EXTRA1_OFFSET;
              inc(u1, 2);
            end
            else
              result := UTF8_TABLE.GetHighUtf8Ucs4(u1);
            result := tab.UnicodeUpper(result);
          end;
          if c2 <= $7f then
            goto c2low
          else if c2 and $20 = 0 then // $0..$7ff common case
          begin
            c2 := (c2 shl 6) + byte(u2[1]) - UTF8_EXTRA1_OFFSET;
            inc(u2, 2);
          end
          else
            c2 := UTF8_TABLE.GetHighUtf8Ucs4(u2);
          c2 := tab.UnicodeUpper(c2);
          dec(result, c2);
          if result <> 0 then
            exit;
        until false
      else
        result := 1 // u2=''
    else
      result := -1  // u1=''
  else
    result := 0;    // u1=u2
end;

function Utf8ILCompReference(u1, u2: PUtf8Char; L1, L2: integer): PtrInt;
var
  c2: PtrUInt;
  extra, i: integer;
  {$ifdef CPUX86NOTPIC}
  tab: TUnicodeUpperTable absolute UU;
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  tab: PUnicodeUpperTable;
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
label
  neg, pos;
begin
  {$ifndef CPUX86NOTPIC}
  tab := @UU;
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  if u1 <> u2 then
    if (u1 <> nil) and
       (L1 <> 0) then
      if (u2 <> nil) and
         (L2 <> 0) then
        repeat
          result := ord(u1^);
          c2 := ord(u2^);
          inc(u1);
          dec(L1);
          if result <= $7f then
          begin
            inc(result, tab.Block[0, result]); // branchless a..z -> A..Z
            if c2 <= $7f then
            begin
              inc(c2, tab.Block[0, c2]);
              dec(L2);
              inc(u2);
              dec(result, c2);
              if result <> 0 then
                // found unmatching char
                exit
              else if L1 <> 0 then
                if L2 <> 0 then
                  // L1>0 and L2>0 -> next char
                  continue
                else
                  // L1>0 and L2=0 -> u1>u2
                  goto pos
              else
              if L2 <> 0 then
                // L1=0 and L2>0 -> u1<u2
                goto neg
              else
                // L1=0 and L2=0 -> u1=u2 -> returns 0
                exit;
            end;
          end
          else
          begin
            // fast Unicode 10.0 uppercase conversion
            extra := utf8.Lookup[result];
            if extra = UTF8_INVALID then
              goto neg; // invalid leading byte (allow full UTF-8/UCS-4 range)
            dec(L1, extra);
            if L1 < 0 then
              goto neg;
            i := 0;
            repeat
              result := result shl 6;
              inc(result, ord(u1[i]));
              inc(i);
            until i = extra;
            inc(u1, extra);
            result := tab.UnicodeUpper(PtrUInt(result) - utf8.Extra[extra].offset);
          end;
          // here result=NormToUpper[u1^]
          inc(u2);
          dec(L2);
          if c2 <= $7f then
          begin
            inc(c2, tab.Block[0, c2]);
            dec(result, c2);
            if result <> 0 then
              // found unmatching codepoint
              exit;
          end
          else
          begin
            extra := utf8.Lookup[c2];
            if extra = UTF8_INVALID then
              goto pos; // invalid leading byte (allow full UTF-8/UCS-4 range)
            dec(L2, extra);
            if L2 < 0 then
              goto pos;
            i := 0;
            repeat
              c2 := c2 shl 6;
              inc(c2, ord(u2[i]));
              inc(i);
            until i = extra;
            inc(u2, extra);
            c2 := tab.UnicodeUpper(c2 - utf8.Extra[extra].offset);
            dec(result, PtrInt(c2));
            if result <> 0 then
              // found unmatching codepoint
              exit;
          end;
          // here we have result=0
          if L1 = 0 then
            // test if we reached end of u1 or end of u2
            if L2 = 0 then
              // u1=u2
              exit
            else
              // u1<u2
              goto neg
          else
          if L2 = 0 then
            // u1>u2
            goto pos;
        until false
      else
pos:    // u2='' or u1>u2
        result := 1
    else
neg:  // u1='' or u1<u2
      result := -1
  else
    // u1=u2
    result := 0;
end;

function StrPosIReference(U: PUtf8Char; const Up: RawUcs4): PUtf8Char;
var
  c, extra, i: PtrUInt;
  u0, u2: PUtf8Char;
  up2: PUcs4CodePoint;
  {$ifdef CPUX86NOTPIC}
  tab: TUnicodeUpperTable absolute UU;
  utf8: TUtf8Table absolute UTF8_TABLE;
  {$else}
  tab: PUnicodeUpperTable;
  utf8: PUtf8Table;
  {$endif CPUX86NOTPIC}
label
  nxt;
begin
  result := nil;
  if (U = nil) or
     (Up = nil) then
    exit;
  {$ifndef CPUX86NOTPIC}
  tab := @UU;
  utf8 := @UTF8_TABLE;
  {$endif CPUX86NOTPIC}
  repeat
    // fast search for the first character
nxt:u0 := U;
    c := byte(U^);
    inc(U);
    if c <= $7f then
    begin
      if c = 0 then
        exit; // not found -> return nil
      inc(c, tab.Block[0, c]); // branchless a..z -> A..Z
      if c <> Up[0] then
        continue;
    end
    else
    begin
      extra := utf8.Lookup[c];
      if extra = UTF8_INVALID then
        exit; // invalid leading byte (allow full UTF-8/UCS-4 range)
      i := 0;
      repeat
        c := c shl 6;
        inc(c, ord(U[i]));
        inc(i);
      until i = extra;
      inc(U, extra);
      c := tab.UnicodeUpper(c - utf8.Extra[extra].offset);
      if c <> Up[0] then
        continue;
    end;
    // if we reached here, U^ and Up^ first UCS-4 CodePoint do match
    u2 := U;
    up2 := @Up[1];
    repeat
      if up2^ = 0 then
      begin
        result := u0; // found -> return position in U
        exit;
      end;
      c := byte(u2^);
      inc(u2);
      if c <= $7f then
      begin
        if c = 0 then
          exit; // not found -> return nil
        inc(c, tab.Block[0, c]);
        if c <> up2^ then
          goto nxt;
        inc(up2);
      end
      else
      begin
        extra := utf8.Lookup[c];
        if extra = UTF8_INVALID then
          exit; // invalid leading byte (allow full UTF-8/UCS-4 range)
        i := 0;
        repeat
          c := c shl 6;
          inc(c, ord(u2[i]));
          inc(i);
        until i = extra;
        inc(u2, extra);
        c := tab.UnicodeUpper(c - utf8.Extra[extra].offset);
        if c <> up2^ then
          goto nxt;
        inc(up2);
      end;
    until false;
  until false;
end;


const
  // reference 8-bit upper chars as in WinAnsi/CP1252 for NormToUpper/Lower[]
  // - UU[] would convert accents into upper accents: this one to upper plain
  // (e.g. e acute to E)
  {%H-}WinAnsiToUp: array[138..255] of byte = (
    83,  139, 140, 141, 90,  143, 144, 145, 146, 147, 148, 149, 150, 151, 152,
    153, 83,  155, 140, 157,  90,  89, 160, 161, 162, 163, 164, 165, 166, 167,
    168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182,
    183, 184, 185, 186, 187, 188, 189, 190, 191, 65,  65,  65,  65,  65,  65,
    198, 67,  69,  69,  69,  69,  73,  73,  73,  73,  68,  78,  79,  79,  79,
    79,  79,  215, 79,  85,  85,  85,  85,  89,  222, 223, 65,  65,  65,  65,
    65,  65,  198, 67,  69,  69,  69,  69,  73,  73,  73,  73,  68,  78,  79,
    79,  79,  79,  79,  247, 79,  85,  85,  85,  85,  89,  222, 89);

{$ifdef UU_COMPRESSED}

  // 1KB compressed buffer which renders into our 20,016 bytes UU[] array
  UU_: array[byte] of cardinal = (
    $040019fd, $ff5a6024, $00855a00, $ffffffe0, $5a5201f0, $02e700e8, $ffe0aa5a,
    $e0045a4b, $5a790bff, $045a0007, $a045a1ff, $db1878ba, $01a82b01, $0145a000,
    $1da45008, $041e5a80, $401da450, $5a8f185a, $fffffed4, $590b5ac3, $0c5a84a4,
    $5314a453, $610008a4, $a4520f5a, $82f5a1a3, $f1ebb5ab, $5a44ddf7, $52105a84,
    $5a845aa4, $5a4a5ac4, $5a385ac6, $11a45217, $10aba500, $45a00200, $4f5a4401,
    $0000b15a, $a05a4f04, $5a830145, $c65a0018, $5ebaa05a, $20245ac0, $85a1a452,
    $5bb55700, $00002a3f, $065a2a3f, $5b04a453, $1f055a40, $a11c02a1, $02a11e02,
    $3200012e, $45a10001, $c2000133, $3645a10c, $45a10001, $4f000135, $00550690,
    $000e5aa5, $a54b0cc2, $013165a1, $2845a100, $440000a5, $012fac02, $00012d00,
    $f70a5144, $41000029, $000a5aa5, $2ac4a16b, $45a10d22, $2b0291fd, $85a10001,
    $1c00022a, $a129e700, $000226a5, $0d930008, $512a000c, $bb0d920a, $05270001,
    $0001b900, $0644145a, $25000107, $00280002, $120a5115, $f1f552a5, $54009c55,
    $a453af5a, $5ac45a44, $0082000c, $5a208400, $ffda00bb, $ad6effff, $09db15d5,
    $f045a100, $01e13201, $1201f000, $c10001c0, $45a10005, $c70001c2, $c5a10001,
    $ca0001d1, $01f80001, $a045a100, $01aa33ba, $0001b000, $d0000007, $001efbfb,
    $a2ffff8c, $0002a0ab, $85a15a83, $e0d0baa2, $01f00bff, $2e01f012, $04f004f2,
    $3645a02a, $240d45a0, $5a44a459, $847e5a40, $115a405a, $400002f1, $45a0115a,
    $cc5a400d, $1fd000c4, $01255507, $8202f000, $55f1f555, $00c955f4, $700001f8,
    $85a10200, $ffffe792, $9c018193, $859e0181, $01819d01, $db0181a4, $89c20181,
    $00c5f558, $3c90f1e4, $e5a18a04, $e5a10ee6, $5a40baa2, $cc5a40cc, $01c50014,
    $a045b100, $45aaffba, $00000008, $5a070080, $04800023, $80002b5a, $80000604,
    $00000635, $bc2f5a0e, $00f75b6d, $d875a108, $050a30a7, $014a0009, $5604a200,
    $056a0001, $42000164, $00018006, $01700802, $7e070200, $a17e0001, $070080b5,
    $80080001, $00022635, $35860002, $c4304825, $810975a1, $01e3dbb5, $090010a5,
    $8004335a, $80053b5a, $5a07000f, $f1ca0137, $e4006c55, $84a501ff, $0001f000,
    $8e2a00f0, $5aedc05b, $55f15b04, $002f55f4, $900001e6, $f5525201, $87ffd019,
    $5a1202f0, $000c5a84, $ffffd5d5, $aa02a1d8, $1845a545, $5a84a453, $40a45328,
    $5a40cc5a, $fb5fc736, $445804bf, $305b045a, $01c1a000, $a182c5e0, $b1c5e245,
    $f4c5e345, $a4504e55, $a4504c77, $1e55f441, $c417a450, $405a445a, $588a9c5a,
    $5a405a84, $045b0406, $c05a445b, $592c2a5a, $c6f021a4, $6e55f49b, $01fc6000,
    $300070a5, $60ffff68, $0970ff7c, $f1f55219, $ffe00655, $35f55257, $0001d800,
    $528a0270, $2255f1f5, $527f7fd0, $f20011f5, $00063b03, $b603f000, $e035f552,
    $01f057ff, $09f55206, $0001de00, $5a720210, $020100f1, $0403075a, $0503045a,
    $0c5a0706, $f15a0803, $00000012, $03120103, $08675104, $5a0b0a09, $5a0d0c1b,
    $0f0e0c11, $1211100c, $140c0c13, $0c055a15, $00005a16, $0c0e0000, $5a191817,
    $1b1a0c31, $065a1d1c, $5a1f1e0c, $5a200c26, $22210c09, $230c0f5a, $0000175a,
    $240c0000, $250c205a, $000c0d5a, $00000000);

procedure InitializeUU;
var
  tmp: array[0..7000] of byte; // need only 6653 bytes
begin
  // Uppercase Unicode table RLE + SynLZ decompression from 1KB to 20KB :)
  if (RleUnCompress(@tmp, @UU, SynLZdecompress1(@UU_, 1019, @tmp)) <> SizeOf(UU)) or
     (crc32c(0, @UU, SizeOf(UU)) <> $7343D053) then
    raise ESynUnicode.Create('UU Table Decompression Failed'); // paranoid
end;

{$endif UU_COMPRESSED}

(*
procedure doUU;
var
  tmp1, tmp2: array[0..5500] of cardinal;
  rle, lz, i: PtrInt;
  l: RawUtf8;
begin
  rle := RleCompress(@UU, @tmp1, SizeOf(UU), SizeOf(tmp1));
  lz := SynLZCompress1(@tmp1, rle, @tmp2);
  writeln(SizeOf(UU)); writeln(rle); writeln(lz);
  writeln('UU_ = array[byte] of cardinal = ('); l := '  ';
  for i := 0 to 255 do
  begin
    l := l + '$' + HexStr(tmp2[i], 8) + ',';
    if length(l) > 70 then
    begin
      writeln(l);
      l := '  ';
    end;
  end;
  writeln(l, ');');
end;
*)

procedure InitializeUnit;
var
  i: PtrInt;
  c: AnsiChar;
  ck: TCharKind;
  sc: TSnakeCase;
  lng: TLanguage;
begin
  // decompress 1KB static in the exe into 20KB UU[] array for Unicode Uppercase
  {$ifdef UU_COMPRESSED}
  InitializeUU;
  {$endif UU_COMPRESSED}
  // initialize internal lookup tables for various text conversions
  for i := 0 to 255 do
    NormToNormByte[i] := i;
  NormToUpperAnsi7Byte := NormToNormByte;
  for i := ord('a') to ord('z') do
    dec(NormToUpperAnsi7Byte[i], 32);
  NormToLowerAnsi7Byte := NormToNormByte;
  for i := ord('A') to ord('Z') do
    inc(NormToLowerAnsi7Byte[i], 32);
  MoveFast(NormToUpperAnsi7, NormToUpper, 138);
  MoveFast(WinAnsiToUp, NormToUpperByte[138], SizeOf(WinAnsiToUp));
  for i := 0 to 255 do
  begin
    c := NormToUpper[AnsiChar(i)];
    if c in ['A'..'Z'] then
      inc(c, 32); // manual lower
    NormToLower[AnsiChar(i)] := c;
  end;
  for c := low(c) to high(c) do
  begin
    if not (c in [#0, #10, #13]) then
      include(TEXT_CHARS[c], tcNot01013);
    if c in [#10, #13] then
      include(TEXT_CHARS[c], tc1013);
    if c in ['0'..'9', 'a'..'z', 'A'..'Z'] then
      include(TEXT_CHARS[c], tcWord);
    if c in ['_', 'a'..'z', 'A'..'Z'] then
      include(TEXT_CHARS[c], tcIdentifierFirstChar);
    if c in ['_', '0'..'9', 'a'..'z', 'A'..'Z'] then
      include(TEXT_CHARS[c], tcIdentifier);
    if c in ['_', '-', '.', '0'..'9', 'a'..'z', 'A'..'Z'] then
      // '~' is part of the RFC 3986 but should be escaped in practice
      // see https://blog.synopse.info/?post/2020/08/11/The-RFC%2C-The-URI%2C-and-The-Tilde
      include(TEXT_CHARS[c], tcUriUnreserved);
    if c in [#1..#9, #11, #12, #14..' '] then
      include(TEXT_CHARS[c], tcCtrlNotLF);
    if c in [#1..' ', ';'] then
      include(TEXT_CHARS[c], tcCtrlNot0Comma);
    case c of
      'a'..'z':
        ck := ckLowerAlpha;
      'A'..'Z':
        ck := ckUpperAlpha;
      '0'..'9':
        ck := ckDigit;
      '_':
        ck := ckUnderscore;
      '.', ',', ';':
        ck := ckPoint;
    else
      ck := ckOther;
    end;
    IDENT_CHARS[c] := ck;
    case c of
      '0' .. '9':
        sc := [scDigit];
      'A' .. 'Z':
        sc := [scUp];
      'a' .. 'z':
        sc := [scLow];
      '_':
        sc := [sc_];
    else
      sc := [];
    end;
    SNAKE_CHARS[c] := sc;
  end;
  for lng := succ(low(lng)) to high(lng) do
  begin
    FastSetString(LANG_ISO[lng], @LANG_ISO_SHORT[lng], 2);
    LANG_LCID[lng] := LANG_PRI[lng] or LANG_USER_DEFAULT;
  end;
  LANG_LCID[lngUndefined] := LANG_ENGLISH_US;
  LANG_LCID[lngChinese]   := LANG_CHINESE_SIMPLIFIED;
  LANG_LCID[lngBosnian]   := LANG_BOSNIAN_CYRILLIC;
  LANG_LCID[lngSerbian]   := LANG_SERBIAN_NEUTRAL;
  // setup proper functions redirection
  StrCompByCase[false] := @StrComp;
  StrCompByCase[true]  := @StrIComp;
  {$ifdef CPUINTEL}
  SortDynArrayAnsiStringByCase[false] := @SortDynArrayAnsiString;
  {$else}
  SortDynArrayAnsiStringByCase[false] := @SortDynArrayRawByteString;
  {$endif CPUINTEL}
  SortDynArrayAnsiStringByCase[true]  := @SortDynArrayAnsiStringI;
  IdemPropNameUSameLen[false]         := @IdemPropNameUSameLenNotNull;
  IdemPropNameUSameLen[true]          := @mormot.core.base.CompareMem;
  {$ifdef OSWINDOWS}
  DoWin32PWideCharToUtf8              := _DoWin32PWideCharToUtf8;
  {$endif OSWINDOWS}
  // setup basic/global Unicode conversion engines
  WinAnsiConvert         := TSynAnsiFixedWidth.Create(CP_WINANSI);
  Utf8AnsiConvert        := TSynAnsiUtf8.Create(CP_UTF8);
  RawByteStringConvert   := TSynAnsiFixedWidth.Create(CP_RAWBYTESTRING);
  CurrentAnsiConvert     := TSynAnsiConvert.Engine(Unicode_CodePage);
  // setup optimized ASM functions
  IsValidUtf8Buffer := @IsValidUtf8Pas;
  {$ifdef ASMX64AVXNOCONST}
  if cpuHaswell in X64CpuFeatures then
    // Haswell CPUs can use simdjson AVX2 asm for IsValidUtf8()
    IsValidUtf8Buffer := @IsValidUtf8Avx2;
  {$endif ASMX64AVXNOCONST}
end;


initialization
  InitializeUnit;


end.
