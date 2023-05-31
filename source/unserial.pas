{ +--------------------------------------------------------------------------+ }
{ | GetDT510 v0.1 * Reader for DATCON DT510 power meter                      | }
{ | Copyright (C) 2023 Pozsar Zsolt <pozsarzs@gmail.com>                     | }
{ | unserial.pas                                                             | }
{ | RS-232 handler                                                           | }
{ +--------------------------------------------------------------------------+ }

{
  This program is Public Domain, you can redistribute it and/or modify
  it under the terms of the Creative Common Zero Universal version 1.0.
}

{$G+}
unit unserial;
interface
uses
  crt, dos;
const
  { offset of the UART registers }
  THR = $00;                                    { Transmit Holding Register }
  RBR = $00;                                      { Receive Buffer Register }
  DLL = $00;                                       { Divisor Latch Low byte }
  DLH = $01;                                      { Divisor Latch High byte }
  IER = $01;                                    { Interrupt Enable Register }
  IIR = $02;                            { Interrupt Identification Register }
  LCR = $03;                                        { Line Control Register }
  MCR = $04;                                       { Modem Control Register }
  LSR = $05;                                         { Line Status Register }
  MSR = $06;                                        { Modem Status Register }
  SCR = $07;                                             { Scratch Register }

  Address : array[0..3] of word=($03f8,$02f8,$02e8,$03e8);
  Intr    : array[0..3] of byte=(4,3,4,3);

  { Bit masquerading table}
  Bits : array[0..7] of byte=($01,$02,$04,$08,$10,$20,$40,$80);

  RecvBuffLong = 8192;
  RecvBuffMask = RecvBuffLong-1;

var
  Base:     word;
  IRQn:     byte;
  RBS,RBE:  word;
  RDS:      boolean;
  RecvBuff: array[0..RecvBuffLong-1] of byte;
  OldVect:  procedure;

procedure OpenSerialPort(Defaults: byte; COM: word; Speed: word);
procedure CloseSerialPort;
procedure PutString(const s:string);
function GetString: string;

implementation

procedure ReceiveIRQ; assembler;
asm
  push  DS                                         { store register in stack }
  pusha

  mov   dx,Seg @DATA
  mov   DS,dx                                       { set DS to data segment }

  mov   dx,Base                                    { load base address to DX }
  in    al,dx                                            { read RBR register }
  lea   bx,RecvBuff                               { set BX to receive buffer }
  add   bx,RBS                        { set position to the next empty place }
  mov   [bx],al                                  { store character in buffer }
  inc   RBS                                        { increment write pointer }
  and   RBS,RecvBuffMask                          { masquerade write pointer }

  mov   al,$20                                   { end of interrupt for 8259 }
  out   $20,al

  popa                                           { read registers from stack }
  pop   DS
  iret                                               { return from interrupt }
end;

function  GetChar: char; assembler;
asm
  mov   RDS,0                                                    { clear RDS }
  mov   ax,RBS
  cmp   ax,RBE                                      { RBS and RBE are equal? }
  jz    @exit                          { exit if equal, end of the receiving }
  lea   bx,RecvBuff                              { set BX to receivce buffer }
  add   bx,RBE                         { set position to the next read place }
  mov   al,[bx]                                           { read a character }
  inc   RBE                                         { increment read pointer }
  and   RBE,RecvBuffMask                           { masquerade read pointer }
  inc   RDS                                                        { set RDS }
@exit:
end;

procedure PutChar(c: char); assembler;
asm
  mov   dx,Base                                    { load base address to DX }
  add   dx,LSR                       { read Az LSR regisztert fogjuk olvasni }
@wait:
  in    al,dx                                                     { read LSR }
  and   al,00100000b                           { previous character is sent? }
  jz    @wait                                               { wait if is not }
  sub   dx,LSR
  mov   al,c
  out   dx,al                                           { write THR register }
end;

procedure EnableIRQline(Line: byte);
begin
  port[$21] := port[$21] and not Bits[Line];
end;

procedure DisableIRQline(Line:byte);
begin
  port[$21] := port[$21] or Bits[Line];
end;

procedure SetIRQ;
begin
  SetIntVec(IRQn + 8, @ReceiveIRQ);            { set interrupt vector to own }
  EnableIRQline(IRQn);                                   { enable interrupts }
end;

procedure ResetIRQ;
begin
  DisableIRQline(IRQn);                                 { disable interrupts }
  SetIntVec(IRQn + 8, @OldVect);      { restore interrupt vector to original }
end;

procedure SetSpeed(Speed: word); assembler;
asm
   mov   dx,Base
   add   dx,LCR
   in    al,dx
   or    al,10000000b                                              { DLA = 1 }
   out   dx,al
   mov   bl,al
   sub   dx,LCR
   mov   ax,Speed
   out   dx,ax                                   { set DLL and DLH registers }
   add   dx,LCR
   mov   al,bl
   and   al,01111111b                                              { DLA = 0 }
   out   dx,al
end;

procedure InitSerialPort(Defaults: byte); assembler;
asm
   mov   dx,Base
   in    al,dx
   mov   al,Defaults
   and   al,01111111b
   add   dx,LCR
   out   dx,al
   inc   dx                                                            { MCR }
   in    al,dx
   and   al,$01
   or    al,$0a
   out   dx,al                                                    { Set  MCR }
   mov   dx,Base
   in    al,dx                                                    { Read RBR }
   add   dx,MSR
   in    al,dx                                                    { Read MSR }
   dec   dx
   in    al,dx                                                    { Read LSR }
   sub   dx,3
   in    al,dx                                                    { Read IIR }
end;

{ open serial port }
procedure OpenSerialPort(Defaults: byte; COM: word; Speed: word);
begin
  Base := Address[COM];
  IRQn := Intr[COM];
  GetIntVec(IRQn + 8, @OldVect);           { store original interrupt vector }
  asm
    cli                                                 { disable interrupts }
  end;
  InitSerialPort(Defaults);              { set parameters of the serial port }
  SetSpeed(Speed);
  port[Base + IER] := 1;                        { enable receiving interrupt }
  SetIRQ;                                             { set interrupt vector }
  asm
    sti                                                  { enable interrupts }
  end;
end;

{ put string to serial line}
procedure PutString(const s: string);
var
   i: integer;
begin
  for i := 1 to length(s) do
    PutChar(s[i]);
end;

{ get string from serial line}
function GetString: string;
var
  c:  char;
  res: string;
begin
  res := '';
  delay(500);
  repeat
    c := GetChar;
    if RDS then
      res := res + c;
  until RBS = RBE;
  GetString := res;
end;

{ close serial port }
procedure CloseSerialPort;
begin
  port[Base + IER] := 0;                 { disable all interrupt of the UART }
  ResetIRQ;                              { restore original interrupt vector }
end;

end.
