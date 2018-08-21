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
//              asps2clkd_fifo.v: asp* -> clkd fifo top-level module              //
//   Author: Ameer M.S. Abdelhadi (ameer.abdelhadi@gmail.com; ameer@ece.ubc.ca)   //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//                               .--------------------------------------.         //
//                               |get_token                             |         //
//                               |  .---------------------------------. |         //
//                               |  |put_token                        | |         //
//                               |  |  .------------------------------|-|-------< //
// >--------------------------.  |  |  |                       ___    | | clk_get //
// reset                      |  |  |  |              en_get  /   |---|-|-------< //
// >-----------------------.  |  |  |  |  .------------------( AND|   | | req_get //
// req_put                 |  |  |  |  |  |                   \___|-. | |         //
// >====================.  |  |  |  |  |  |  .=============.        | | |         //
// datain              ||  |  |  |  |  |  |  ||dataout_tmp||        | | |         //
//                    _\/__V__V__V__V__V__V__/\_          ||        | | |         //
//                   | ||  |  | STAGE  |  |     |         ||        | | |         //
//           .------<| ||  |  |   n-1  |  |     |         ||        | | |         //
//           |  ack_ |_||__|__|________|__|_____|>---.    ||        | | |         //
//           |  put_   ||  |  |  V  V  |  |    read_ |    ||        | | |         //
//           |  tmp    ||  |  |  |  |  |  |    enable|    ||        | | |         //
//           |         ::  :  :  :  :  :  :          :    ::        | | |         //
//           |         ::  :  :  :  :  :  :          :    ::        | | |         //
//           |         ||  |  |  |  |  |  |  .==========. ||        | | |         //
//           |         ||  |  |  |  |  |  |  ||      | || ||        | | |         //
//           |        _\/__V__V__|__|__V__V__/\_     | || ||        | | |         //
//           |       | ||  |  |        |  |     |    | || ||        | | |         //
//           | .----<| ||  |  |STAGE 1 |  |     |    | || ||        | | |         //
//           | |ack_ |_||__|__|________|__|_____|>-. | || ||  ___   | | |         //
//           | |put_   ||  |  |  V  V  |  |        | | || '==\   \  | | |         //
//           | |tmp    ||  |  |  |  |  |  |        | | '======)OR )=|=|=|=======> //
//           | |       ||  |  |  |  |  |  |  .=====|=|=======/___/  | | | dataout //
//      ___  | |       ||  |  |  |  |  |  |  ||    | |              | | |         //
//     /   /-' |      _\/__V__V__V__V__V__V__/\_   | |        ___   | | |         //
// <--( OR(----'     |                          |  | '-------\   \  | | |         //
// ack \___\--------<|         STAGE 0          |  '----------)OR )-+-|-|-------> //
// _put         ack_ |__________________________|>-----------/___/    | |   datav //
//              put_             V  V                                 | |         //
//              tmp              |  |                                 | |         //
//                               |  '---------------------------------' |         //
//                               '--------------------------------------'         //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

// include configuration file; generated by scr/do; defines DATAWD, STAGES &  SYNCDP
`include "config.h"

module asps2clkd_fifo
  #( parameter           DATAWD = `DATAWD,  // data bus width
     parameter           STAGES = `STAGES,  // number of fifo stages
     parameter           SYNCDP = `SYNCDP,  // brute-force synchronizer depth
     parameter           PIPEDV = `PIPEDV)  // pipeline datav (FIFO not empty) signal
   ( input               reset           ,  // global reset 
     input [DATAWD-1:0]  datain          ,  // asp* sender     : data in
     input               req_put         ,  // asp* sender     : request put
     output              ack_put         ,  // asp* sender     : acknowledge put
     input               clk_get         ,  // clocked receiver: clock for receiver domain
     input               req_get         ,  // clocked receiver: request get
     output              datav           ,  // clocked receiver: data valid indicator
     output [DATAWD-1:0] dataout         ); // clocked receiver: data out

  // local registers and wires
  reg  [DATAWD-1:0] dataout_o               ;
  reg               req_get_r               ;
  wire              en_get                  ;
  wire [STAGES-1:0] read_enable             ;
  wire [DATAWD-1:0] dataout_tmp [STAGES-1:0];
  wire [STAGES  :0] put_token_in_tmp        ;
  wire [STAGES  :0] get_token_in_tmp        ;
  wire [STAGES-1:0] ack_put_tmp             ;
  integer           j                       ;

  // loopback tokens
  assign put_token_in_tmp[0]  = put_token_in_tmp[STAGES];
  assign get_token_in_tmp[0]  = get_token_in_tmp[STAGES];
  
  // create FIFO stages
  genvar i;
  generate for (i=0; i < STAGES; i=i+1)
    begin : stage_gen
      asps2clkd_stage   #( .DATAW         (DATAWD               ),  // param : data bus width
                           .STAGE         (i                    ),  // param : stage index
                           .SYNCD         (SYNCDP               ))  // param: brute-force synchronizer depth
      asps2clkd_stage_i  ( .reset         (reset                ),  // global reset
                           .datain        (datain               ),  // input : asp* sender     : data in
                           .req_put       (req_put              ),  // input : asp* sender     : request put
                           .ack_put       (ack_put_tmp[i]       ),  // output: asp* sender     : acknowledge put
                           .put_token_in  (put_token_in_tmp[i]  ),  // input : fifo ring       : put token in
                           .put_token_out (put_token_in_tmp[i+1]),  // output: fifo ring       : put token out
                           .get_token_in  (get_token_in_tmp[i]  ),  // input : fifo ring       : get token in
                           .get_token_out (get_token_in_tmp[i+1]),  // output: fifo ring       : get token out
                           .clk_get       (clk_get              ),  // input : clocked receiver: clock for receiver domain
                           .en_get        (en_get               ),  // input : clocked receiver: enable get
                           .read_enable   (read_enable[i]       ),  // output: clocked receiver: enable reading
                           .dataout       (dataout_tmp[i])      );  // output: clocked receiver: data out
    end // block: stage_gen
  endgenerate
  
  // create top-level signals
  assign ack_put = |ack_put_tmp;
 
  // or together the dataout busses..
  always @* begin
    dataout_o = {DATAWD{1'b0}};
    for (j=0; j< STAGES; j=j+1)
      dataout_o = dataout_o | dataout_tmp[j];
  end
    
  // assign outputs
  assign dataout = dataout_o;
  
  // create 'datav' signal
  generate
    if (PIPEDV) begin : PIPELINEDDATAV
      vacancy  #(.STAGES  (STAGES     ))  // number of FIFO stages
      datav_vac (.rst     (reset      ),  // global reset 
                 .clk     (clk_get    ),  // clock for receiver domain
                 .req     (req_get    ),  // request get
                 .vac_stgs(read_enable),  // stages vacancy (read enable)
                 .vac_fifo(datav      )); // fifo vacancy (data valis)
    end
    else begin : NOTPIPELINEDDATAV
      assign datav = |read_enable; 
    end
  endgenerate

  // create internal signals
  assign en_get     =  datav & req_get;
  
endmodule // asps2clkd_fifo

