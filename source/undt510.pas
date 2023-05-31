{ +--------------------------------------------------------------------------+ }
{ | GetDT510 v0.1 * Reader for DATCON DT510 power meter                      | }
{ | Copyright (C) 2023 Pozsar Zsolt <pozsarzs@gmail.com>                     | }
{ | undt510.pas                                                              | }
{ | convert raw data to real values                                          | }
{ +--------------------------------------------------------------------------+ }

{
  This program is Public Domain, you can redistribute it and/or modify
  it under the terms of the Creative Common Zero Universal version 1.0.
}

unit undt510;
interface

function pqs(l: longint): real;
Function urms(l: longint): real;
function irms(l: longint): real;
function pf(i: integer): real;

implementation

{ P/Q/S: active/reactive/apparant power }
function pqs(l: longint): real;
begin
  { 32767 = 3000 W }
  pqs := (l * 3000) / 32767;
end;

{ Urms: effective voltage }
function urms(l: longint): real;
begin
  { 32767=367.7 V }
  urms := (l * 367.7) / 32767;
end;

{ Irms: effective current }
function irms(l: longint): real;
begin
  { 32767=8.16 A }
  irms := (l * 8.16) / 32767;
end;

{ cosFi: power factor (32767=1.0000) }
function pf(i: integer): real;
begin
  pf := i / 32767;
end;

end.
