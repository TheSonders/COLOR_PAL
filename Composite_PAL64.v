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
//64 Colour Composite PAL modulator
//Requires an RGB input and HSync and VSync
//Input clock frequency between 35.465 and 36.000MHz
//Outputs a 7bits modulated output. 
//You can use a resistor DAC to get about 1V peak to peak
//////////////////////////////////////////////////////////////////////////////////
module Composite_PAL64(  
    input CLK36M,			// Input frequency 36MHz (carrier 4.43361875MHz)
    input[5:0] VIDEO, 	// RGB(2:2:2) input
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
//  167p		 206p			 1872p		 53p		= 2304p   //Rounded pulses counter
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
		3:ColorBurst<='d28;
		4:ColorBurst<='d39;
		5:ColorBurst<='d43;
		6:ColorBurst<='d39;
		7:ColorBurst<='d28;
		0:ColorBurst<='d17;
		1:ColorBurst<='d13;
		2:ColorBurst<='d17;
	endcase
end

reg HCountEnable=0;
reg [$clog2(TotalHPulses)-1:0]HCounter=0;
reg [2:0]BurstDivider=0;
reg prev_HSYNC=0;
reg prev_VSYNC=0;
reg[5:0] VIDEOc=0;

//HORIZONTAL TIMING
always @(posedge CLK36M)begin
	BurstDivider<=BurstDivider+1;
	prev_HSYNC<=HSYNC;
	prev_VSYNC<=VSYNC;
	VIDEOc<=VIDEO;
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

//COLOR VOLTAGE LEVELS
reg [55:0] Color=0;
reg [6:0] ColorEncoding;

always @(*)begin
	case (BurstDivider)
		0:ColorEncoding<=Color[55:49];
		1:ColorEncoding<=Color[48:42];
		2:ColorEncoding<=Color[41:35];
		3:ColorEncoding<=Color[34:28];
		4:ColorEncoding<=Color[27:21];
		5:ColorEncoding<=Color[20:14];
		6:ColorEncoding<=Color[13: 7];
		7:ColorEncoding<=Color[ 6: 0];
	endcase
	
	case (VIDEOc)
 0:Color<=56'h3870E1C3870E1C;
 1:Color<=56'h38914A74264A15;
 2:Color<=56'h38B1B334C5870F;
 3:Color<=56'h3AD61BF564C70E;
 4:Color<=56'h3A711AD6CDD8A6;
 5:Color<=56'h3C9183976D149F;
 6:Color<=56'h3CB5EC580C5099;
 7:Color<=56'h3CD65518AB8C93;
 8:Color<=56'h3E7153FA14E330;
 9:Color<=56'h3E95BCBAD41F2A;
10:Color<=56'h40B6257B735B23;
11:Color<=56'h40DA8E3C12971D;
12:Color<=56'h42758D1D7BEDBA;
13:Color<=56'h4295F5DE1B29B4;
14:Color<=56'h42BA5E9EBA65AE;
15:Color<=56'h44DACF5F59A1A7;
16:Color<=56'h62ACF96286D330;
17:Color<=56'h64CD6223260F29;
18:Color<=56'h64F1D2D3C54BA3;
19:Color<=56'h65123B9464879C;
20:Color<=56'h66AD3285CD9DBA;
21:Color<=56'h68D1A3468D1A34;
22:Color<=56'h68F20BF72C562D;
23:Color<=56'h691274B7CB9227;
24:Color<=56'h6AAD6BA934A844;
25:Color<=56'h6AD1DC59D3E4BE;
26:Color<=56'h6CF2451A7320B7;
27:Color<=56'h6D16ADDB125CB1;
28:Color<=56'h6EB1ACBC7BB2CE;
29:Color<=56'h6ED2157D1AEF48;
30:Color<=56'h6EF67E3DDA2B42;
31:Color<=56'h7116E6FE79673B;
32:Color<=56'h8EE91901C698C4;
33:Color<=56'h910981C225D4BD;
34:Color<=56'h912DEA82E510B7;
35:Color<=56'h914E5343844D31;
36:Color<=56'h92E95224EDA34E;
37:Color<=56'h930DBAE58CDF48;
38:Color<=56'h952E23A62C1B41;
39:Color<=56'h95529456CB57BB;
40:Color<=56'h96ED8B48346DD8;
41:Color<=56'h970DF408D3A9D2;
42:Color<=56'h993264C993264C;
43:Color<=56'h9952CD7A326245;
44:Color<=56'h9AEDC46B9B7863;
45:Color<=56'h9B0E2D2C3AB45C;
46:Color<=56'h9B329DDCD9F0D6;
47:Color<=56'h9D53069D792CCF;
48:Color<=56'hBB2530E1C65E58;
49:Color<=56'hBD45A161C59A51;
50:Color<=56'hBD6A0A21E4D64B;
51:Color<=56'hBD8A72E2841245;
52:Color<=56'hBF2571C3ED68E2;
53:Color<=56'hBF49DA848CA4DC;
54:Color<=56'hC16A43452BE0D5;
55:Color<=56'hC18EAC05EB1CCF;
56:Color<=56'hC329AAE754736C;
57:Color<=56'hC34A13A7F3AF66;
58:Color<=56'hC36E7C6892EB60;
59:Color<=56'hC58EE529322759;
60:Color<=56'hC529E40A9B3DF7;
61:Color<=56'hC74E4CCB3A79F0;
62:Color<=56'hC76EB58BD9B5EA;
63:Color<=56'hC993264C993264;
	endcase
end
endmodule