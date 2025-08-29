/// Simple Network DNS Client
// - this unit is a part of the Open Source Synopse mORMot framework 2,
// licensed under a MPL/GPL/LGPL three license - see LICENSE.md
unit mormot.net.dns;

{
  *****************************************************************************

   Simple DNS Protocol Client
    - Low-Level DNS Protocol Definitions
    - High-Level DNS Query

  *****************************************************************************
}

interface

{$I ..\mormot.defines.inc}

uses
  sysutils,
  classes,
  mormot.core.base,
  mormot.core.os,
  mormot.core.unicode,
  mormot.core.text,
  mormot.core.buffers,
  mormot.net.sock;


{ **************** Low-Level DNS Protocol Definitions }


type
  /// most known Dns Resource Record (RR) Types
  // - from http://www.iana.org/assignments/dns-parameters
  // - main values are e.g. drrA for a host address, drrNS for an authoritative
  // name server, or drrCNAME for the alias canonical name
  // - this enumerate has no RTTI because it is mapped to the integer values
  TDnsResourceRecord = (
    drrEmpty,
    drrA,
    drrNS,
    drrMD,
    drrMF,
    drrCNAME,
    drrSOA,
    drrMB,
    drrMG,
    drrMR,
    drrNULL,
    drrWKS,
    drrPTR,
    drrHINFO,
    drrMINFO,
    drrMX,
    drrTXT,
    drrRP,
    drrAFSDB,
    drrX25,
    drrISDN,
    drrRT,
    drrNSAP,
    drrNSAP_P,
    drrSIG,
    drrKEY,
    drrPX,
    drrGPOS,
    drrAAAA,
    drrLOC,
    drrNXT,
    drrEID,
    drrNIMLOC,
    drrSRV,
    drrATMA,
    drrNAPTR,
    drrKX,
    drrCERT,
    drrA6,
    drrDNAME,
    drrSINK,
    drrOPT,
    drrAPL,
    drrDS,
    drrSSHFP,
    drrIPSECK,
    drrRRSIG,
    drrNSEC,
    drrDNSKEY,
    drrDHCID,
    drrNSEC3,
    drrNSEC3PARAM,
    drrTLSA,
    drrSMIMEA,
    drrHIP = 55,
    drrNINFO,
    drrRKEY,
    drrTALINK,
    drrCDS,
    drrCDNSKEY,
    drrOPENPGPKEY,
    drrCSYNC,
    drrZONEMD,
    drrSVCB,
    drrHTTPS,
    drrSPF = 99,
    drrUINFO,
    drrUID,
    drrGID,
    drrUNSPEC,
    drrNID,
    drrL32,
    drrL64,
    drrLP,
    drrEUI48,
    drrEUI64,
    drrTKEY = 249,
    drrTSIG,
    drrIXFR,
    drrAXFR,
    drrMAILB,
    drrMAILA,
    drrALL,
    drrURI,
    drrCAA,
    drrAVC,
    drrDOA,
    drrAMTRELAY,
    drrTA = 32768,
    drrDLV);


const
  DnsPort = '53';

  /// Internet DNS Question Class
  QC_INET = 1;


{$A-} // every record (or object) is packed from now on

type
  /// map a DNS header binary record
  // - with some easy getter/setter for the bit-oriented flags
  {$ifdef USERECORDWITHMETHODS}
  TDnsHeader = record
  {$else}
  TDnsHeader = object
  {$endif USERECORDWITHMETHODS}
  private
    function GetAA: boolean;
      {$ifdef FPC} inline; {$endif}
    function GetOpCode: byte;
      {$ifdef FPC} inline; {$endif}
    function GetQR: boolean;
      {$ifdef FPC} inline; {$endif}
    function GetRA: boolean;
      {$ifdef FPC} inline; {$endif}
    function GetRCode: byte;
      {$ifdef FPC} inline; {$endif}
    function GetRD: boolean;
      {$ifdef FPC} inline; {$endif}
    function GetTC: boolean;
      {$ifdef FPC} inline; {$endif}
    function GetZ: byte;
    procedure SetOpCode(AValue: byte);
    procedure SetQR(AValue: boolean);
    procedure SetRD(AValue: boolean);
    procedure SetZ(AValue: byte);
  public
    Xid: word;
    Flags: byte;
    Flags2: byte;
    QuestionCount: word;
    AnswerCount: word;
    NameServerCount: word;
    AdditionalCount: word;
    property IsResponse: boolean
      read GetQR write SetQR;
    property OpCode: byte
      read GetOpCode write SetOpCode;
    property AuthorativeAnswer: boolean
      read GetAA;
    property Truncation: boolean
      read GetTC;
    property RecursionDesired: boolean
      read GetRD write SetRD;
    property RecursionAvailable: boolean
      read GetRA;
    property Z: byte
      read GetZ write SetZ;
    property ResponseCode: byte
      read GetRCode;
  end;
  PDnsHeader = ^TDnsHeader;

/// parse a DNS string entry
// - return 0 on error, or the next 0-based position in Answer
// - will actually decompress the input from its repeated patterns
function DnsParseString(const Answer: RawByteString; Pos: PtrInt;
  var Text: RawUtf8): PtrInt;

/// parse a DNS 16-bit big endian value
function DnsParseWord(p: PByteArray; var pos: PtrInt): cardinal;
  {$ifdef HASINLINE} inline; {$endif}

/// parse a DNS 32-bit big endian value
function DnsParseCardinal(p: PByteArray; var pos: PtrInt): cardinal;
  {$ifdef HASINLINE} inline; {$endif}

/// raw parsing of best-known DNS record data into human readable text
// - as used by DnsParseRecord() to fill the TDnsAnswer.Text field
// - only recognize A AAAA CNAME TXT NS PTR MX SOA SRV Resource Records
procedure DnsParseData(RR: TDnsResourceRecord;
  const Answer: RawByteString; Pos, Len: PtrInt; var Text: RawUtf8);

/// raw computation of a DNS query message
function DnsBuildQuestion(const QName: RawUtf8; RR: TDnsResourceRecord;
  QClass: cardinal = QC_INET): RawByteString;

/// raw sending and receiving of DNS query message over UDP
// - Address is expected to be an IPv4 address, maybe prefixed as 'tcp@1.2.3.4'
// to force use TCP connection instead of UDP
function DnsSendQuestion(const Address, Port: RawUtf8;
  const Request: RawByteString; out Answer: RawByteString;
  out TimeElapsed: cardinal; TimeOutMS: integer = 2000): boolean;

var
  /// global setting to force DNS resolution over TCP instead of UDP
  // - if 'tcp@1.2.3.4' is not enough, you can set TRUE to this global variable
  // to force TCP for all DnsSendQuestion/DnsLookup/DnsServices calls
  // - some DNS servers (e.g. most Internet provider boxes) won't support TCP
  // - a 1 minute internal cache will avoid sending requests on DNS servers
  // for which DnsSendQuestion() did previously block
  DnsSendOverTcp: boolean;


{ **************** High-Level DNS Query }

{$A+}

type
  /// one decoded DNS record as stored by DnsQuery() in TDnsResult
  TDnsAnswer = record
    /// the Name of this record
    QName: RawUtf8;
    /// the known type of this record
    QType: TDnsResourceRecord;
    /// after how many seconds this record information is deprecated
    TTL: cardinal;
    /// 0-based position of the raw binary of the record content
    // - pointing into TDnsResult.RawAnswer binary buffer
    Position: integer;
    /// encoded length of the raw binary of the record content
    Len: integer;
    /// main text information decoded from Data binary
    // - only best-known DNS resource record QType are recognized, i.e.
    // A AAAA CNAME TXT NS PTR MX SOA SRV as decoded by DnsParseData()
    Text: RawUtf8;
  end;
  PDnsAnswer = ^TDnsAnswer;
  TDnsAnswers = array of TDnsAnswer;

  /// the resultset of a DnsQuery() process
  TDnsResult = record
    /// the decoded DNS header of this query
    Header: TDnsHeader;
    /// the time needed for this DNS server lookup
    ElapsedMicroSec: cardinal;
    /// the Answers records
    Answer: TDnsAnswers;
    /// the Authorities records
    Authority: TDnsAnswers;
    /// the Additionals records
    Additional: TDnsAnswers;
    /// the raw binary UDP response frame, needed for DnsParseString() decoding
    RawAnswer: RawByteString;
  end;

/// parse a DNS answer record entry
function DnsParseRecord(const Answer: RawByteString; var Pos: PtrInt;
  var Dest: TDnsAnswer; QClass: cardinal): boolean;

const
  /// DnsQuery() and related functions do expect a response within 200 ms delay
  DNSQUERY_TIMEOUT = 200;

/// send a DNS query and parse the answer
// - if no NameServer is supplied, will use GetDnsAddresses list from OS
// - default NameServers = '' will call GetDnsAddresses - but NameServers could
// be IPv4 address(es) CSV, maybe prefixed as 'tcp@1.2.3.4' to force TCP
// - the TDnsResult output gives access to all returned DNS records
// - use DnsLookup/DnsReverseLookup/DnsServices() for most simple requests
function DnsQuery(const QName: RawUtf8; out Res: TDnsResult;
  RR: TDnsResourceRecord = drrA; const NameServers: RawUtf8 = '';
  TimeOutMS: integer = DNSQUERY_TIMEOUT; QClass: cardinal = QC_INET): boolean;

/// retrieve the IPv4 address of a DNS host name - using DnsQuery(drrA)
// - e.g. DnsLookup('synopse.info') currently returns '62.210.254.173'
// - for aliases, the CNAME is ignored and only the first A is returned, e.g.
// DnsLookup('blog.synopse.info') would simply return '62.210.254.173'
// - will also recognize obvious values like 'localhost' or an IPv4 address
// - this unit will register this function to mormot.net.sock's NewSocketIP4Lookup
// - default NameServers = '' will call GetDnsAddresses - but NameServers could
// be IPv4 address(es) CSV, maybe prefixed as 'tcp@1.2.3.4' to force TCP
// - warning: executes a raw DNS query, so hosts system file is not used,
// and no cache is involved: use TNetAddr.SetFrom() instead if you can
function DnsLookup(const HostName: RawUtf8; const NameServers: RawUtf8 = '';
  TimeoutMS: integer = DNSQUERY_TIMEOUT): RawUtf8;

/// retrieve the IPv4 address(es) of a DNS host name - using DnsQuery(drrA)
// - e.g. DnsLookups('synopse.info') currently returns ['62.210.254.173'] but
// DnsLookups('yahoo.com') returns an array of several IPv4 addresses
// - will also recognize obvious values like 'localhost' or an IPv4 address
// - default NameServers = '' will call GetDnsAddresses - but NameServers could
// be IPv4 address(es) CSV, maybe prefixed as 'tcp@1.2.3.4' to force TCP
function DnsLookups(const HostName: RawUtf8; const NameServers: RawUtf8 = '';
  TimeoutMS: integer = DNSQUERY_TIMEOUT): TRawUtf8DynArray;

/// retrieve the DNS host name of an IPv4 address - using DnsQuery(drrPTR)
// - note that the reversed host name is the one from the hosting company, and
// unlikely the usual name: e.g. DnsReverseLookup(DnsLookup('synopse.info'))
// returns the horsey '62-210-254-173.rev.poneytelecom.eu' from online.net
// - default NameServers = '' will call GetDnsAddresses - but NameServers could
// be IPv4 address(es) CSV, maybe prefixed as 'tcp@1.2.3.4' to force TCP
function DnsReverseLookup(const IP4: RawUtf8; const NameServers: RawUtf8 = '';
  TimeoutMS: integer = DNSQUERY_TIMEOUT): RawUtf8;

/// retrieve the Services of a DNS host name - using DnsQuery(drrSRV)
// - services addresses are returned with their port, e.g.
// DnsServices('_ldap._tcp.ad.mycorp.com') returns
// ['dc-one.mycorp.com:389', 'dc-two.mycorp.com:389']
// - default NameServers = '' will call GetDnsAddresses - but NameServers could
// be IPv4 address(es) CSV, maybe prefixed as 'tcp@1.2.3.4' to force TCP
function DnsServices(const HostName: RawUtf8; const NameServers: RawUtf8 = '';
  TimeoutMS: integer = DNSQUERY_TIMEOUT): TRawUtf8DynArray;

/// retrieve the LDAP Services of a DNS host name - using DnsQuery(drrSRV)
// - just a wrapper around DnsServices('_ldap._tcp.' + DomainName, NameServer)
// - e.g. DnsLdapServices('ad.mycorp.com') returns
// ['dc-one.mycorp.com:389', 'dc-two.mycorp.com:389']
// - default NameServers = '' will call GetDnsAddresses - but NameServers could
// be IPv4 address(es) CSV, maybe prefixed as 'tcp@1.2.3.4' to force TCP
function DnsLdapServices(const DomainName: RawUtf8;
  const NameServers: RawUtf8 = ''): TRawUtf8DynArray;

/// retrieve the LDAP controlers from the current system AD domain name
// - returns e.g. ['dc-one.mycorp.com:389', 'dc-two.mycorp.com:389']
// - optionally return the associated AD controler host name, e.g. 'ad.mycorp.com'
// - default NameServers = '' will call GetDnsAddresses - but NameServers could
// be IPv4 address(es) CSV, maybe prefixed as 'tcp@1.2.3.4' to force TCP
// - see also CldapMyController() from mormot.net.ldap for a safer client approach
function DnsLdapControlers(const NameServers: RawUtf8 = '';
  UsePosixEnv: boolean = false; DomainName: PRawUtf8 = nil): TRawUtf8DynArray;


implementation

{ **************** Low-Level DNS Protocol Definitions }

const
  // Flags 1
  QF_QR     = $80;
  QF_OPCODE = $78;
  QF_AA     = $04;
  QF_TC     = $02;  // Truncated
  QF_RD     = $01;

  // Flags 2
  QF_RA     = $80;
  QF_Z      = $70;
  QF_RCODE  = $0F;

  DNS_RESP_SUCCESS = $00;

  DNS_RELATIVE = $c0; // two high bits set = offset within the response message


{ TDnsHeader }

function TDnsHeader.GetAA: boolean;
begin
  result := (Flags and QF_AA) <> 0;
end;

function TDnsHeader.GetOpCode: byte;
begin
  result := (Flags and QF_OPCODE) shr 3;
end;

function TDnsHeader.GetQR: boolean;
begin
  result := (Flags and QF_QR) <> 0;
end;

function TDnsHeader.GetRA: boolean;
begin
  result := (Flags2 and QF_RA) <> 0;
end;

function TDnsHeader.GetRCode: byte;
begin
  result := (Flags2 and QF_RCODE);
end;

function TDnsHeader.GetRD: boolean;
begin
  result := (Flags and QF_RD) <> 0;
end;

function TDnsHeader.GetTC: boolean;
begin
  result := (Flags and QF_TC) <> 0;
end;

function TDnsHeader.GetZ: byte;
begin
  result := (Flags and QF_Z) shr 4;
end;

procedure TDnsHeader.SetOpCode(AValue: byte);
begin
  Flags := (Flags and not(QF_OPCODE)) or ((AValue and $f) shl 3);
end;

procedure TDnsHeader.SetQR(AValue: boolean);
begin
  Flags := Flags and not(QF_QR);
  if AValue then
    Flags := Flags or QF_QR;
end;

procedure TDnsHeader.SetRD(AValue: boolean);
begin
  Flags := Flags and not(QF_RD);
  if AValue then
    Flags := Flags or QF_RD;
end;

procedure TDnsHeader.SetZ(AValue: byte);
begin
  Flags := (Flags2 and not(QF_Z)) or ((AValue and $7) shl 4);
end;


function DnsParseString(const Answer: RawByteString; Pos: PtrInt;
  var Text: RawUtf8): PtrInt;
var
  p: PByteArray;
  nextpos, max: PtrInt;
  len: byte;
  tmp: ShortString;
begin
  result := 0; // indicates error
  nextpos := 0;
  p := pointer(Answer);
  max := length(Answer);
  tmp[0] := #0;
  repeat
    if Pos >= max then
      exit; // avoid any buffer overflow on malformated/malinuous input
    len := p[Pos];
    inc(Pos);
    if len = 0 then
      break;
    while (len and DNS_RELATIVE) = DNS_RELATIVE do
    begin
      // see https://www.rfc-editor.org/rfc/rfc1035.html#section-4.1.4
      if nextpos = 0 then
        nextpos := Pos + 1; // if compressed, return end of offset
      if Pos >= max then
        exit;
      Pos := PtrInt(len and (not DNS_RELATIVE)) shl 8 + p[Pos]; // 14-bit offset
      if Pos >= max then
        exit;
      len := p[Pos]; // 8-bit length from offset
      inc(Pos);
    end;
    if len = 0 then
      break;
    if Pos + len > max then
      exit;
    AppendShortBuffer(pointer(@p[Pos]), len, @tmp);
    AppendShortCharSafe('.', @tmp);
    inc(Pos, len);
  until false;
  if tmp[ord(tmp[0])] = '.' then
    dec(tmp[0]);
  FastSetString(Text, @tmp[1], ord(tmp[0]));
  if nextpos = 0 then
    result := Pos
  else
    result := nextpos;
end;

function DnsParseWord(p: PByteArray; var pos: PtrInt): cardinal;
begin
  result := bswap16(PWord(@p[pos])^);
  inc(pos, 2);
end;

function DnsParseCardinal(p: PByteArray; var pos: PtrInt): cardinal;
begin
  result := bswap32(PCardinal(@p[pos])^);
  inc(pos, 4);
end;

procedure DnsParseData(RR: TDnsResourceRecord;
  const Answer: RawByteString; Pos, Len: PtrInt; var Text: RawUtf8);
var
  p: PByteArray;
  s2: RawUtf8;
begin
  p := @PByteArray(Answer)[Pos];
  case RR of // see https://www.rfc-editor.org/rfc/rfc1035#section-3.3
    drrA:
      // 32-bit IPv4 binary address
      if Len = 4 then
        IP4Text(p, Text);
    drrAAAA:
      // 128-bit IPv6 binary address
      if Len = 16 then
        IP6Text(p, Text);
    drrCNAME,
    drrMB,
    drrMD,
    drrMG,
    drrTXT,
    drrNS,
    drrPTR:
      // single text Value
      DnsParseString(Answer, Pos, Text);
    drrMX:
      // Priority:W / Value
      if Len > 2 then
        DnsParseString(Answer, Pos + 2, Text);
    drrHINFO,
    drrSOA:
      // several values, first two as TEXT
      begin
        // HINFO: CPU / OS
        // SOA: MName / RName / Serial:I / Refresh:I / Retry:I / Expire:I / TTL:I
        Pos := DnsParseString(Answer, Pos, Text);
        if (Pos <> 0) and
           (DnsParseString(Answer, Pos, s2) <> 0) then
          Append(Text, ' ', s2);
      end;
    drrSRV: // see https://www.rfc-editor.org/rfc/rfc2782
      if Len > 6 then
        // Priority:W / Weight:W / Port:W / QName
        if DnsParseString(Answer, Pos + 6, Text) <> 0 then
          Append(Text, [':', bswap16(PWordArray(p)[2])]); // QName:port
  end;
end;

function DnsBuildQuestion(const QName: RawUtf8; RR: TDnsResourceRecord;
  QClass: cardinal): RawByteString;
var
  tmp: TTextWriterStackBuffer; // 8KB work buffer on stack
  w: TBufferWriter;
  h: TDnsHeader;
  n: PUtf8Char;
  one: ShortString;
begin
  w := TBufferWriter.Create(tmp{%H-});
  try
    FillCharFast(h, SizeOf(h), 0);
    repeat
      h.Xid := Random32; // truncated to 16-bit
    until h.XId <> 0;
    h.RecursionDesired := true;
    h.QuestionCount := 1 shl 8;
    w.Write(@h, SizeOf(h));
    n := pointer(QName);
    while n <> nil do
    begin
      GetNextItemShortString(n, @one, '.');
      if one[0] = #0 then
        break;
      w.Write1(ord(one[0]));
      w.Write(@one[1], ord(one[0]));
    end;
    w.Write1(0); // final #0
    w.Write2(bswap16(ord(RR)));
    w.Write2(bswap16(QClass));
    result := w.FlushTo;
  finally
    w.Free;
  end;
end;

var
  NoTcpSafe: TLightLock;
  NoTcpServers: TRawUtf8DynArray;
  NoTcpTix16: cardinal; // cache flushed after 65,536 seconds

function DnsSendQuestion(const Address, Port: RawUtf8;
  const Request: RawByteString; out Answer: RawByteString;
  out TimeElapsed: cardinal; TimeOutMS: integer): boolean;
var
  server: RawUtf8;
  tcponly: boolean;
  addr, resp: TNetAddr;
  sock: TNetSocket;
  len, notcp: PtrInt;
  start, stop: Int64;
  tix16: cardinal;
  lenw: word;
  tmp: TBuffer4K;
  hdr: PDnsHeader;
begin
  result := false;
  TimeElapsed := 0;
  QueryPerformanceMicroSeconds(start);
  // validate input parameters
  server := Address;
  tcponly := IdemPChar(pointer(server), 'TCP@');
  if tcponly then
    delete(server, 1, 4)
  else
    tcponly := DnsSendOverTcp; // global setting
  FillCharFast(addr, SizeOf(addr), 0);
  if not addr.SetFromIP4(server, {nolookup=}true) or
     (addr.SetPort(GetCardinalDef(pointer(Port), 389)) <> nrOk) then
    exit;
  if not tcponly then
  begin
    // send the DNS query over UDP
    sock := addr.NewSocket(nlUdp);
    if sock = nil then
      exit;
    try
      sock.SetReceiveTimeout(TimeOutMS);
      len := length(Request);
      if sock.SendTo(pointer(Request), len, addr) <> nrOk then
        exit;
      // get the response and ensure it is valid
      len := sock.RecvFrom(@tmp, SizeOf(tmp), resp);
    finally
      sock.Close;
    end;
    hdr := @tmp;
    if (len <= length(Request)) or
       not addr.IPEqual(resp) or
       (hdr^.Xid <> PDnsHeader(Request)^.Xid) or
       not hdr^.IsResponse or
       (hdr^.ResponseCode <> DNS_RESP_SUCCESS) or
       (hdr^.AnswerCount = 0) then
       // hdr^.NameServerCount or hdr^.AdditionalCount wouldn't be enough
      exit;
    tcponly := hdr^.Truncation;
    if not tcponly then
      FastSetRawByteString(answer, @tmp, len);
  end;
  if tcponly then
  begin
    // UDP frame was too small: try with a TCP connection
    // ensure was not marked in NoTcpServers (avoid unneeded timeout)
    tix16 := GetTickCount64 shr 16;
    NoTcpSafe.Lock;
    if NoTcpTix16 <> tix16 then
      NoTcpServers := nil; // flush after 1 minute
    NoTcpTix16 := tix16;
    notcp := FindPropName(pointer(NoTcpServers), server, length(NoTcpServers));
    NoTcpSafe.UnLock;
    if notcp >= 0 then
      exit;
    // setup the connection
    sock := addr.NewSocket(nlTcp);
    try
      if addr.SocketConnect(sock, TimeOutMS) <> nrOk then
        exit;
      sock.SetSendTimeout(TimeOutMS);
      // send the DNS query over TCP
      len := length(Request);
      if len > SizeOf(tmp) - 2 then
        exit; // paranoid
      PWordArray(@tmp)[0] := bswap16(len); // not found in RFCs, but mandatory
      MoveFast(pointer(Request)^, PWordArray(@tmp)[1], len);
      if sock.SendAll(@tmp, len + 2) <> nrOk then
        exit;
      // get the response and ensure it is valid
      lenw := 0;
      if sock.RecvAll(TimeOutMS, @lenw, 2) <> nrOk then // first 2 bytes are len
      begin
        NoTcpSafe.Lock;
        AddRawUtf8(NoTcpServers, server); // won't try again in the next minute
        NoTcpSafe.UnLock;
        exit;
      end;
      len := bswap16(lenw);
      if len <= length(Request) then
        exit;
      hdr := FastNewRawByteString(answer, len);
      if (sock.RecvAll(TimeOutMS, pointer(answer), len) <> nrOk) or
         (hdr^.Xid <> PDnsHeader(Request)^.Xid) or
         not hdr^.IsResponse or
         hdr^.Truncation or
         not hdr^.RecursionAvailable or
         (hdr^.ResponseCode <> DNS_RESP_SUCCESS) or
         (hdr^.AnswerCount = 0) then
        exit;
    finally
      sock.Close;
    end;
  end;
  // we got a valid answer
  QueryPerformanceMicroSeconds(stop);
  TimeElapsed := stop - start;
  result := true;
end;


{ **************** High-Level DNS Query }

function DnsParseRecord(const Answer: RawByteString; var Pos: PtrInt;
  var Dest: TDnsAnswer; QClass: cardinal): boolean;
var
  len: PtrInt;
  qc: cardinal;
  p: PByteArray;
begin
  result := false;
  p := pointer(Answer);
  Pos := DnsParseString(Answer, Pos, Dest.QName);
  if (Pos = 0) or
     (Pos + 10 > length(Answer)) then
    exit;
  word(Dest.QType) := DnsParseWord(p, Pos);
  qc := DnsParseWord(p, Pos);
  if (qc <> QClass) and  // https://www.rfc-editor.org/rfc/rfc6891#section-6.1.2
     (Dest.QType <> drrOPT) then // OPT stores the UDP payload size here :(
    exit;
  Dest.TTL := DnsParseCardinal(p, Pos); // RCODE and flags for drrOPT
  len := DnsParseWord(p, Pos);
  if Pos + len > length(Answer) then
    exit;
  Dest.Position := Pos;
  Dest.Len := len;
  DnsParseData(Dest.QType, Answer, Pos, len, Dest.Text);
  inc(Pos, len);
  result := true;
end;

function DnsQuery(const QName: RawUtf8; out Res: TDnsResult;
  RR: TDnsResourceRecord; const NameServers: RawUtf8;
  TimeOutMS: integer; QClass: cardinal): boolean;
var
  i, pos: PtrInt;
  servers: TRawUtf8DynArray;
  request: RawByteString;
begin
  result := false;
  if (QName = '') or
     not IsAnsiCompatible(QName) then
    exit;
  // send the DNS request to the DNS server(s)
  Finalize(Res);
  FillCharFast(Res, SizeOf(Res), 0);
  request := DnsBuildQuestion(QName, RR, QClass);
  if NameServers = '' then
    // if no NameServer is specified, will ask all OS DNS in order
    servers := GetDnsAddresses
  else
    // the DNS server IP(s) have been specified
    CsvToRawUtf8DynArray(pointer(NameServers), servers);
  for i := 0 to high(servers) do
    if DnsSendQuestion(servers[i], DnsPort,
         request, Res.RawAnswer, Res.ElapsedMicroSec, TimeOutMS) then
      break; // we got one non-void response
  if Res.RawAnswer = '' then
    exit;
  // we received a valid response from a DNS
  Res.Header := PDnsHeader(Res.RawAnswer)^;
  Res.Header.QuestionCount := bswap16(Res.Header.QuestionCount);
  Res.Header.AnswerCount := bswap16(Res.Header.AnswerCount);
  Res.Header.NameServerCount := bswap16(Res.Header.NameServerCount);
  Res.Header.AdditionalCount := bswap16(Res.Header.AdditionalCount);
  pos := length(request); // jump Header + Question = point to records
  if Res.Header.AnswerCount <> 0 then
  begin
    SetLength(Res.Answer, Res.Header.AnswerCount);
    for i := 0 to high(Res.Answer) do
      if not DnsParseRecord(Res.RawAnswer, pos, Res.Answer[i], QClass) then
        exit;
  end;
  if Res.Header.NameServerCount <> 0 then
  begin
    SetLength(Res.Authority, Res.Header.NameServerCount);
    for i := 0 to high(Res.Authority) do
      if not DnsParseRecord(Res.RawAnswer, pos, Res.Authority[i], QClass) then
        exit;
  end;
  if Res.Header.AdditionalCount <> 0 then
  begin
    SetLength(Res.Additional, Res.Header.AdditionalCount);
    for i := 0 to high(Res.Additional) do
      if not DnsParseRecord(Res.RawAnswer, pos, Res.Additional[i], QClass) then
        exit;
  end;
  result := true;
end;

function DnsLookupKnown(const HostName: RawUtf8; out Ip: RawUtf8): boolean;
begin
  result := true;
  if PropNameEquals(HostName, 'localhost') or
     (HostName = c6Localhost) then
    Ip := IP4local
  else if NetIsIP4(pointer(HostName)) then // '1.2.3.4'
    Ip := HostName
  else
    result := false; // and Ip has been set to ''
end;

function DnsLookup(const HostName, NameServers: RawUtf8; TimeoutMS: integer): RawUtf8;
var
  res: TDnsResult;
  i: PtrInt;
begin
  if not DnsLookupKnown(HostName, result) then // e.g. 'localhost' or '1.2.3.4'
    if DnsQuery(HostName, res, drrA, NameServers, TimeoutMS) then
      for i := 0 to high(res.Answer) do
        if res.Answer[i].QType = drrA then
        begin
          result := res.Answer[i].Text;
          break; // ignore CNAME but return first A record
        end;
end;

function DnsLookups(const HostName, NameServers: RawUtf8; TimeoutMS: integer): TRawUtf8DynArray;
var
  res: TDnsResult;
  known: RawUtf8;
  i: PtrInt;
begin
  result := nil;
  if DnsLookupKnown(HostName, known) then // e.g. 'localhost' or '1.2.3.4'
    AddRawUtf8(result, known)
  else if DnsQuery(HostName, res, drrA, NameServers, TimeoutMS) then
    for i := 0 to high(res.Answer) do
      if res.Answer[i].QType = drrA then
        AddRawUtf8(result, res.Answer[i].Text); // return all A records
end;

function DnsReverseLookup(const IP4, NameServers: RawUtf8; TimeoutMS: integer): RawUtf8;
var
  b: array[0..3] of byte; // to be asked in inverse byte order
  res: TDnsResult;
  i: PtrInt;
begin
  result := '';
  PCardinal(@b)^ := 0;
  if NetIsIP4(pointer(IP4), @b) and
     DnsQuery(FormatUtf8('%.%.%.%.in-addr.arpa', [b[3], b[2], b[1], b[0]]),
       res, drrPTR, NameServers, TimeoutMS) then
    for i := 0 to high(res.Answer) do
      if res.Answer[i].QType = drrPTR then
      begin
        result := res.Answer[i].Text;
        exit;
      end;
end;

function DnsServices(const HostName, NameServers: RawUtf8; TimeoutMS: integer): TRawUtf8DynArray;
var
  res: TDnsResult;
  i: PtrInt;
begin
  result := nil;
  if DnsQuery(HostName, res, drrSRV, NameServers, TimeoutMS) then
    for i := 0 to high(res.Answer) do
      if res.Answer[i].QType = drrSRV then
        AddRawUtf8(result, res.Answer[i].Text, {nodup=}true, {casesens=}false);
end;

function DnsLdapServices(const DomainName, NameServers: RawUtf8): TRawUtf8DynArray;
begin
  result := DnsServices('_ldap._tcp.' + DomainName, NameServers);
end;

function DnsLdapControlers(const NameServers: RawUtf8; UsePosixEnv: boolean;
  DomainName: PRawUtf8): TRawUtf8DynArray;
var
  ad: TRawUtf8DynArray;
  i: PtrInt;
begin
  result := nil;
  ad := GetDomainNames(UsePosixEnv);
  for i := 0 to high(ad) do
  begin
    result := DnsLdapServices(ad[i], NameServers);
    if result <> nil then
    begin
      if DomainName <> nil then
        DomainName^ := ad[i];
      exit;
    end;
  end;
end;

function _NewSocketIP4Lookup(const HostName: RawUtf8; out IP4: cardinal): boolean;
var
  ip: RawUtf8;
begin
  ip4 := 0; // clearly identify failure
  ip := DnsLookup(HostName, NewSocketIP4LookupServer);
  result := NetIsIP4(pointer(ip), @ip4);
end;


initialization
  assert(ord(drrOPT) = 41);
  assert(ord(drrHTTPS) = 65);
  assert(ord(drrSPF) = 99);
  assert(ord(drrEUI64) = 109);
  assert(ord(drrTKEY) = 249);
  assert(ord(drrAMTRELAY) = 260);
  NewSocketIP4Lookup := _NewSocketIP4Lookup;

end.

