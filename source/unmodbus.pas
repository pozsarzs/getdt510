{ +--------------------------------------------------------------------------+ }
{ | GetDT510 v0.1 * Reader for DATCON DT510 power meter                      | }
{ | Copyright (C) 2023 Pozsar Zsolt <pozsarzs@gmail.com>                     | }
{ | unmodbus.pas                                                             | }
{ | ModBUS handler                                                           | }
{ +--------------------------------------------------------------------------+ }

{
  This program is Public Domain, you can redistribute it and/or modify
  it under the terms of the Creative Common Zero Universal version 1.0.
}

unit unmodbus;
interface
uses
  crt, unserial;
var
  holdreg: array[40001..49999] of integer;

function readmodbusholdreg(a: byte; r, rs: word): boolean;

implementation

{ convert a byte/word number to 2/4 digit hex number as string }
function hex1(n: byte; w: word): string;
var
  b:         byte;
  remainder: word;
  res:       string;
begin
  res := '';
  for b := 1 to n do
  begin
    remainder := w mod 16;
    w := w div 16;
    if remainder <= 9 then
      res := chr (remainder + 48) + res
    else
      res := chr (remainder + 87) + res;
  end;
  hex1 := res;
end;

{ convert a string of ASCII coded hexa bytes to string of hexa bytes }
function hex2(s: string): string;
var
  b:       byte;
  c, d, e: integer;
  res:     string;
begin
  b := 1;
  res := '';
  repeat
    val('$' + s[b] + s[b + 1], d, e);
    res := res + char(d);
    b:=b + 2;
  until b >= length(s);
  hex2 := res;
end;

{ create Longitudinal Redundancy Check (LRC) value }
function lrc(s: string): word;
var
   b:   byte;
   res: word;
begin
  s := hex2(s);
  res := 0;
  for b := 1 to length(s) do
    res := res + ord(s[b]) and $FF;
  res := (((res xor $FF)+1) and $FF);
  lrc := res;
end;

{ clear array }
function clearholdreg(r, rs: word): boolean;
var
  i: integer;
begin
  clearholdreg := true;
  if (r >= 40001) and (r <= 49999)
  then
    for i := r to r + rs do
      holdreg[i] := 0
  else
    clearholdreg := false;
end;

{ read holding register(s) and store in array }
function readmodbusholdreg(a: byte; r, rs: word): boolean;
var
  b:      byte;
  buffer: string;
  c:      char;
  e:      integer;
begin
  if clearholdreg(r, rs) then
  begin
    { create ASCII telegram }
    buffer := hex1(2, a) + hex1(2, 3) + hex1(4, r - 40001) + hex1(4, rs);
    buffer := ':' + buffer + hex1(2, lrc(buffer));
    writeln('- request:  ' + buffer);
    buffer := buffer + char($0d) + char($0a);
    { send request }
    putstring(buffer);
    { receive answer }
    buffer := getstring;
    { parse received ASCII telegram and store in array }
    for b := 0 to rs - 1 do
      val('$' + buffer[8 + 4 * b] + buffer[9 + 4 * b]+ buffer[10 + 4 * b] + buffer[11 + 4 * b], holdreg[r + b], e);
    delete(buffer, length(buffer)-1,2);
    writeln('- response: ' + buffer);
  end;
end;

end.
