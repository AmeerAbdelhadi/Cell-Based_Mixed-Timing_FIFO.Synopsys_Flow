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
//              asps2asps_fifo.v: asp* -> asp* fifo top-level module              //
//   Author: Ameer M.S. Abdelhadi (ameer.abdelhadi@gmail.com; ameer@ece.ubc.ca)   //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//                               .--------------------------------------.         //
//                               |get_token                             |         //
// >--------------------------.  |  .---------------------------------. |         //
// reset                      |  |  |put_token                        | |         //
// >-----------------------.  |  |  |  .------------------------------|-|-------< //
// req_put                 |  |  |  |  |                              | | req_get //
// >====================.  |  |  |  |  |  .================.          | |         //
// datain              ||  |  |  |  |  |  ||  dataout_tmp ||          | |         //
//                    _\/__V__V__V__V__V__/\_             ||          | |         //
//                   | ||  |  | STAGE  |     |            ||          | |         //
//           .------<| ||  |  |   n-1  |     |            ||          | |         //
//           |  ack_ |_||__|__|________|_____|>----.      ||          | |         //
//           |  put_   ||  |  |  V  V  |   ack_    |      ||          | |         //
//           |  tmp    ||  |  |  |  |  |   get_    |      ||          | |         //
//           |         ::  :  :  :  :  :   tmp     :      ::          | |         //
//           |         ::  :  :  :  :  :           :      ::          | |         //
//           |         ||  |  |  |  |  |  .============.  ||          | |         //
//           |         ||  |  |  |  |  |  ||       |  ||  ||          | |         //
//           |        _\/__V__V__|__|__V__/\_      |  ||  ||          | |         //
//           |       | ||  |  |        |     |     |  ||  ||          | |         //
//           | .----<| ||  |  |STAGE 1 |     |     |  ||  ||          | |         //
//           | |ack_ |_||__|__|________|_____|>--. |  ||  ||   ____   | |         //
//           | |put_   ||  |  |  V  V  |         | |  ||  '===\    \  | |         //
//           | |tmp    ||  |  |  |  |  |         | |  '========) OR )=|=|=======> //
//           | |       ||  |  |  |  |  |  .======|=|==========/____/  | | dataout //
//      ____ | |       ||  |  |  |  |  |  ||     | |                  | |         //
//     /   /-' |      _\/__V__V__V__V__V__/\_    | |           ____   | |         //
// <--(OR (----'     |                       |   | '----------\    \  | |         //
// ack \___\--------<|         STAGE 0       |   '-------------) OR )-|-|-------> //
// _put         ack_ |_______________________|>---------------/____/  | | ack_get //
//              put_             V  V                                 | |         //
//              tmp              |  |                                 | |         //
//                               |  '---------------------------------' |         //
//                               '--------------------------------------'         //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

// include configuration file; generated by scr/do; defines DATAWD and STAGES
`include "config.h"

module asps2asps_fifo
  #( parameter               DATAWD = `DATAWD,  // data bus width
     parameter               STAGES = `STAGES)  // number of fifo stages
   ( input                   reset           ,  // global reset
     input                   req_put         ,  // asp* sender  : request put
     output                  ack_put         ,  // asp* sender  : acknowledge put
     input [DATAWD-1:0]      datain          ,  // asp* sender  : data in
     input                   req_get         ,  // asp* receiver: request get
     output                  ack_get         ,  // asp* receiver: acknowledge get
     output reg [DATAWD-1:0] dataout         ); // asp* receiver: data out

  // local registers and wires
  wire [STAGES-1:0] ack_put_tmp             ;
  wire [STAGES-1:0] ack_get_tmp             ;
  wire [DATAWD-1:0] dataout_tmp [STAGES-1:0];
  wire [STAGES  :0] put_token_in_tmp        ;
  wire [STAGES  :0] get_token_in_tmp        ;
  integer           j                       ;
  
  // loopback tokens
  assign put_token_in_tmp[0]  = put_token_in_tmp[STAGES];
  assign get_token_in_tmp[0]  = get_token_in_tmp[STAGES];
  
  // create FIFO stages
  genvar i;
  generate for (i=0; i < STAGES; i=i+1)
    begin : stage_gen
      asps2asps_stage  #( .DATAW         (DATAWD               ),  // param : data bus width
                          .STAGE         (i                    ))  // param : stage index
      asps2asps_stage_i ( .reset         (reset                ),  // input : global reset
                          .datain        (datain               ),  // input : asp* sender  : data in 
                          .req_put       (req_put              ),  // input : asp* sender  : request put
                          .ack_put       (ack_put_tmp[i]       ),  // output: asp* sender  : acknowledge put
                          .put_token_in  (put_token_in_tmp[i]  ),  // input : fifo ring    : put token in
                          .put_token_out (put_token_in_tmp[i+1]),  // output: fifo ring    : put token out
                          .get_token_in  (get_token_in_tmp[i]  ),  // input : fifo ring    : get token in
                          .get_token_out (get_token_in_tmp[i+1]),  // output: fifo ring    : get token out
                          .dataout       (dataout_tmp[i]       ),  // output: asp* receiver: dataout
                          .ack_get       (ack_get_tmp[i]       ),  // output: asp* receiver: acknowledge get
                          .req_get       (req_get              )); // input : asp* receiver: request get
    end // block: stage_gen
  endgenerate

  // create top-level signals
  assign ack_put = |ack_put_tmp;
  assign ack_get = |ack_get_tmp;
 
  // or together the dataout busses..
  always @* begin
    dataout = {DATAWD{1'b0}};
    for (j=0; j< STAGES; j=j+1)
      dataout = dataout | dataout_tmp[j];
  end

endmodule // asps2asps_fifo

