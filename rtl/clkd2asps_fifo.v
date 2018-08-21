////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016, University of British Columbia (UBC)  All rights reserved. //
//                                                                                //
// Redistribution  and  use  in  source   and  binary  forms,   with  or  without //
// modification,  are permitted  provided that  the following conditions are met: //
//   * Redistributions   of  source   code  must  retain   the   above  copyright //
//     notice,  this   list   of   conditions   and   the  following  disclaimer. //
//   * Redistributions  in  binary  form  must  reproduce  the  above   copyright //
//     notice, this  list  of  conditions  and the  following  disclaimer in  the //
//     documentation and/or  other  materials  provided  with  the  distribution. //
//   * Neither the name of the University of British Columbia (UBC) nor the names //
//     of   its   contributors  may  be  used  to  endorse  or   promote products //
//     derived from  this  software without  specific  prior  written permission. //
//                                                                                //
// THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" //
// AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE //
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE //
// DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE //
// FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL //
// DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR //
// SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER //
// CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, //
// OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE //
// OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//              clkd2asps_fifo.v: clkd -> asp* fifo top-level module              //
//   Author: Ameer M.S. Abdelhadi (ameer.abdelhadi@gmail.com; ameer@ece.ubc.ca)   //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
// >---------------------------------.  .-------------------------------.         //
// reset                             |  |put_token                      |         //
// >------------------------------.  |  |  .--------------------------. |         //
// clk_put         ____           |  |  |  |get_token                 | |         //
// >--------------|    \  en_put  |  |  |  |                          | |         //
// req_put        | AND )------.  |  |  |  |  .-----------------------|-|-------< //
//        .-------|____/       |  |  |  |  |  |                       | | req_get //
//        |                   _V__V__V__V__V__V_                      | |         //
//        |       .=========>| |  |  | STAGE  | |>===========.        | |         //
//        |       ||         | |  |  |   n-1  | |dataout_tmp||        | |         //
//        |       ||  .-----<|_|__|__|________|_|>-----.    ||        | |         //
//        |       ||  |write_  |  |  |  V  V  |   ack_ |    ::        | |         //
//        |       ||  |enable  |  |  |  |  |  |   get_ |    ::        | |         //
//        |       ::  |        :  :  :  :  :  :   tmp  :    ||        | |         //
//        |       ::  |        :  :  :  :  :  :        :    ||        | |         //
//        |       ||  |        |  |  |  |  |  |        |    ||        | |         //
//        |       ||  |       _V__V__V__|__|__V_       |    ||        | |         //
//        |       |+==|=====>| |  |  |        | |>=====|==. ||        | |         //
//        |       ||  |      | |  |  |STAGE 1 | |      | || ||        | |         //
//        |       ||  | .---<|_|__|__|________|_|>---. | || ||        | |         //
//        |       ||  | |      |  |  |  V  V  |      | | || ||        | |         //
//        |       ||  | |      |  |  |  |  |  |      | | || ||        | |         //
//        |       ||  | |      |  |  |  |  |  |      | | || || ____   | |         //
//        |       ||  | |      |  |  |  |  |  |      | | || '==\   \  | |         //
//        |       ||  | |     _V__V__V__V__V__V_     | | '======)OR )=|=|=======> //
// >======|========+==|=|===>|                  |>===|=|=======/___/  | | dataout //
// datain |   ____    | |    |        STAGE 0   |    | |       ____   | |         // 
//        |  /    /---' | .-<|__________________|>-. | '-------\   \  | |         //
// <------+-( OR (------' |             V  V       | '----------)OR )-|-|-------> //
// spaceav   \____\-------'             |  |       '-----------/___/  | | ack_get // 
//                                      |  '--------------------------' |         //
//                                      '-------------------------------'         //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

// include configuration file; generated by scr/do; defines DATAWD, STAGES &  SYNCDP
`include "config.h"

module clkd2asps_fifo
  #( parameter               DATAWD = `DATAWD,  // data bus width
     parameter               STAGES = `STAGES,  // number of fifo stages
     parameter               SYNCDP = `SYNCDP,  // brute-force synchronizer depth
     parameter               PIPESA = `PIPESA)  // pipeline spaceav (FIFO not full ) signale
   ( input                   reset           ,  // global reset 
     input                   clk_put         ,  // clocked sender: clock for sender domain
     input                   req_put         ,  // clocked sender: request put
     output                  spaceav         ,  // clocked sender: space available indicator
     input  [DATAWD-1:0]     datain          ,  // clocked sender: data in
     input                   req_get         ,  // asp* recevier : request get
     output                  ack_get         ,  // asp* recevier : acknowledge get
     output reg [DATAWD-1:0] dataout         ); // asp* recevier : data out

  // local registers and wires
  wire              en_put                  ;
  wire [STAGES-1:0] write_enable            ;
  wire [DATAWD-1:0] dataout_tmp [STAGES-1:0];
  wire [STAGES-1:0] ack_get_tmp             ;
  wire [STAGES  :0] put_token_in_tmp        ;
  wire [STAGES  :0] get_token_in_tmp        ;
  integer           j                       ;

  // create 'spaceav' signal
  generate
    if (PIPESA) begin : PIPELINEDSPACEAV
      vacancy    #(.STAGES  (STAGES      ))  // number of FIFO stages
      spaceav_vac (.rst     (reset       ),  // global reset 
                   .clk     (clk_put     ),  // clock for sender domain
                   .req     (req_put     ),  // request put
                   .vac_stgs(write_enable),  // stages vacancy (write enable)
                   .vac_fifo(spaceav     )); // fifo vacancy (space available)
    end
    else begin : NOTPIPELINEDSPACEAV
      assign spaceav = |write_enable; 
    end
  endgenerate

  // create internal 'en_put' signal
  assign en_put = spaceav && req_put;

  // loopback tokens
  assign put_token_in_tmp[0] = put_token_in_tmp[STAGES];
  assign get_token_in_tmp[0] = get_token_in_tmp[STAGES];
  
  // create FIFO stages
  genvar i;
  generate for (i=0; i<STAGES; i=i+1)
    begin : stage_gen
      clkd2asps_stage   #( .DATAW         (DATAWD               ),  // param : data bus width
                           .STAGE         (i                    ),  // param : stage index
                           .SYNCD         (SYNCDP               ))  // param: brute-force synchronizer depth
      clkd2asps_stage_i  ( .reset         (reset                ),  // global reset
                           .clk_put       (clk_put              ),  // input : clocked sender: clock for sender domain
                           .en_put        (en_put               ),  // input : clocked sender: enable put
                           .write_enable  (write_enable[i]      ),  // output: clocked sender: writing enable
                           .datain        (datain               ),  // input : clocked sender: data in
                           .put_token_in  (put_token_in_tmp[i]  ),  // input : fifo ring     : put token in
                           .put_token_out (put_token_in_tmp[i+1]),  // output: fifo ring     : put token out
                           .get_token_in  (get_token_in_tmp[i]  ),  // input : fifo ring     : get token in
                           .get_token_out (get_token_in_tmp[i+1]),  // output: fifo ring     : get token out
                           .req_get       (req_get              ),  // input : asp* receiver : request get
                           .ack_get       (ack_get_tmp[i]       ),  // output: asp* receiver : acknowledge get
                           .dataout       (dataout_tmp[i]       )); // output: asp* receiver : data out
    end // block: stage_gen
  endgenerate

  // create top-level signals
  assign ack_get = |ack_get_tmp;

  // or together the dataout busses..
  always @* begin
      dataout = {DATAWD{1'b0}};
      for (j=0; j<STAGES; j=j+1)
        dataout = dataout | dataout_tmp[j];
  end

endmodule // clkd2asps_fifo

