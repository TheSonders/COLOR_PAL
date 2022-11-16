`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
/*
MIT License

Copyright (c) 2022 Antonio Sánchez (@TheSonders)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
//////////////////////////////////////////////////////////////////////////////////
// ESTE WRAPPER ESTÁ AÚN EN PRUEBAS 
// Y SE PUEDE DAÑAR TU MONITOR, ¡¡¡ÚSALO BAJO TU RESPONSABILIDAD!!!
// THIS WRAPPER IS STILL IN TESTING
// AND YOUR MONITOR MAY BE DAMAGED, USE IT AT YOUR OWN RISK!!!
//////////////////////////////////////////////////////////////////////////////////
//References:
//https://www.youtube.com/watch?v=-JXuwwXQh8c
//https://bitluni.net/esp32-color-pal
//http://martin.hinner.info/vga/pal.html
//http://blog.retroleum.co.uk/electronics-articles/pal-tv-timing-and-voltages/
//https://www.csse.canterbury.ac.nz/greg.ewing/c64_pal_decoder/PAL/PAL-Video-Encoding.html
//////////////////////////////////////////////////////////////////////////////////
//512 Colors Composite PAL modulator
//Requires an RGB input and HSync and VSync
//Input clock frequency between 35.465 and 36.000MHz
//Outputs a 7bits modulated output. 
//You can use a resistor DAC to get about 1V peak to peak
//////////////////////////////////////////////////////////////////////////////////
module Composite_PAL512( 
    input CLK36M,			// Input frequency 36MHz (carrier 4.43361875MHz)
	 input[2:0] RED, 		// 
	 input[2:0] GREEN, 	// 
	 input[2:0] BLUE, 	// 
    input HSYNC,			// HSync input (negative polarity)
    input VSYNC,			// VSync input (negative polarity)    
    output reg [6:0] COMP_VIDEO // 7 bits modulated output
    );

	 
	 `define	FallHSync	(prev_HSYNC && ~HSYNC)
//Line width 64us
//Hsync polarity negative
//Vysnc polarity negative
// SYNC   + BACKPORCH +  VIDEO  + FRONTPORCH =  TOTAL
// 4.7us  +  5.8us    +   52us  +   1.5us 	=   64us	 //Microseconds
// 169.2p +  208.8p   +  1872p  +    54p	   = 2304p   //Clock pulses
//  169p		 209p			 1872p		 54p		= 2304p   //Rounded pulses counter
//BACKPORCH = 33+80+96

//HORIZONTAL TIMING
localparam HFrontPulses=53;
localparam HSyncPulses=HFrontPulses+167;
localparam HPrevBurstPulses=HSyncPulses+26;
localparam HBurstPulses=HPrevBurstPulses+96;
localparam HBackPulses=HBurstPulses+84;
localparam TotalHPulses=HBackPulses;

//SYNC VOLTAGE LEVELS
localparam SyncLevel=0;
localparam BlankLevel='d28;

reg[6:0] ColorBurst;

always @(*)begin
	if (prev_VSYNC==0)begin
		if (HSYNC==0)COMP_VIDEO<=SyncLevel;
		else COMP_VIDEO<=BlankLevel;
	end
	else begin
		COMP_VIDEO<=
		(HCountEnable==0)?ColorEncoding:
		(HCounter<HFrontPulses)?BlankLevel:
		(HCounter<HSyncPulses)?SyncLevel:
		(HCounter<HPrevBurstPulses)?BlankLevel:
		(HCounter<HBurstPulses)?ColorBurst:BlankLevel;
	end

	case (BurstDivider) 
		4:ColorBurst<='d28;
		5:ColorBurst<='d39;
		6:ColorBurst<='d43;
		7:ColorBurst<='d39;
		0:ColorBurst<='d28;
		1:ColorBurst<='d17;
		2:ColorBurst<='d13;
		3:ColorBurst<='d17;
	endcase
end

reg HCountEnable=0;
reg [$clog2(TotalHPulses)-1:0]HCounter=0;
reg [2:0]BurstDivider=0;
reg prev_HSYNC=0;
reg prev_VSYNC=0;
reg [2:0]REDc=0;
reg [2:0]GREENc=0;
reg [2:0]BLUEc=0;

//HORIZONTAL TIMING
always @(posedge CLK36M)begin
	prev_HSYNC<=HSYNC;
	prev_VSYNC<=VSYNC;
	REDc<=RED;
	GREENc<=GREEN;
	BLUEc<=BLUE;
	BurstDivider<=BurstDivider+1;
	if (`FallHSync)begin
		HCounter<=0;
		HCountEnable<=1;
	end
	else begin
		if (HCountEnable)begin
			if (HCounter<TotalHPulses-1)begin
				HCounter<=HCounter+1;
			end
			else begin
				HCountEnable<=0;
			end
		end
	end
end
	 
reg [6:0]ColorEnc=0;
wire [6:0]ColorEncoding = ColorEnc+BlankLevel;
reg signed[6:0]Y=0;
reg signed[6:0]U=0;
reg signed[6:0]V=0;
reg signed[6:0]normU=0;
reg signed[6:0]normV=0;


always @(posedge CLK36M)begin

	//Delay 1 YUV MATRIX
	Y<=(REDc*3)+(GREENc*6)+BLUE;
	U<=((BLUEc*10)-((REDc*3)+(GREENc*6)+BLUE));
	V<=((REDc*10)-((REDc*3)+(GREENc*6)+BLUE));
	
	//Delay 2 UV CORRECTION
	normU<=((U/2));
	normV<=((V*7)/8);
		
	//Delay 3 QAM ENCODER
	case (BurstDivider)
		0:	ColorEnc<=Y+normV;
		1:	ColorEnc<=Y+(normV/2)+(normV/4)+(normU/2)+(normU/4);
		2:	ColorEnc<=Y+normU;
		3:	ColorEnc<=Y-(normV/2)-(normV/4)+(normU/2)+(normU/4);
		4:	ColorEnc<=Y-normV;
		5:	ColorEnc<=Y-(normV/2)-(normV/4)-(normU/2)-(normU/4);
		6:	ColorEnc<=Y-normU;
		7:	ColorEnc<=Y+(normV/2)+(normV/4)-(normU/2)-(normU/4);
	endcase
end
endmodule
