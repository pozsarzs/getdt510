{ +--------------------------------------------------------------------------+ }
{ | GetDT510 v0.1 * Reader for DATCON DT510 power meter                      | }
{ | Copyright (C) 2023 Pozsar Zsolt <pozsarzs@gmail.com>                     | }
{ | getdt510.pas                                                             | }
{ | main program                                                             | }
{ +--------------------------------------------------------------------------+ }

{
  This program is Public Domain, you can redistribute it and/or modify
  it under the terms of the Creative Common Zero Universal version 1.0.
}

program getdt510;
uses
  crt, undt510, unmodbus, unserial;
const
  { number of the serial port}
  COM1    = $00;
  COM2    = $01;
  COM3    = $02;
  COM4    = $03;
  { speed of the serial port }
  S1200   = 96;
  S2400   = 48;
  S4800   = 24;
  S9600   = 12;
  S14400  =  8;
  S19200  =  6;
  S28800  =  4;
  S38400  =  3;
  S57600  =  2;
  S115200 =  1;
  { parity check type of the serial port }
  PNONE   = $00;
  PEVEN   = $18;
  PODD    = $08;
  { stop bit(s) of the serial port}
  S1      = $00;
  S2      = $04;
  { data bits of the serial port}
  D5      = $00;
  D6      = $01;
  D7      = $02;
  D8      = $03;
var
  w: word;

begin
  writeln('Get measured data from old DATCON DT510 power meter device:');
  writeln('- RS-232:   COM1, 9600 bps, 7E1');
  writeln('- ModBUS:   SlaveID: 1, Holding registers: 100-105');
  { get data from device }
  openserialport(PEVEN or D7 or S1, COM1, S9600);
  readmodbusholdreg(1,40101,6);
  closeserialport;
  { write received data }
  writeln('- raw values:');
  for w:=40101 to 40106 do
    writeln('  Register #',w,': ',holdreg[w]);
  writeln('- real values:');
  writeln('  P:     ',pqs(holdreg[40101]):0:2,' W');
  writeln('  Q:     ',pqs(holdreg[40102]):0:2,' VAr');
  writeln('  S:     ',pqs(holdreg[40103]):0:2,' VA');
  writeln('  Urms:  ',urms(holdreg[40104]):0:2,' V');
  writeln('  Irms:  ',irms(holdreg[40105]):0:2,' A');
  writeln('  cosFi: ',pf(holdreg[40106]):0:2);
end.
