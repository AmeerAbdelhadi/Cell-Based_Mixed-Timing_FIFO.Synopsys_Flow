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
//                asps2clkd_stage.v: asp* -> clkd fifo stage module               //
//   Author: Ameer M.S. Abdelhadi (ameer.abdelhadi@gmail.com; ameer@ece.ubc.ca)   //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//               put_token_out                     get_token_out                  //
//                     ^                                 ^                        //
//                     |                                 |                        //
//                  ___|___          _______          ___|___                     //
//                 |       |        |       |        |       |                    //
// reset   ------->|-------|------->|-------|------->|       |                    //
//                 |       |        |       |        |       |                    //
// req_put ------->|       |        | asps2 |<-------|-------|<---------- clk_get //
//                 |       | empty  | clkd_ |  empty |       |                    //
// ack_put <-------|       |<-------| full_ |------->|       |<----------- en_get //
//                 | asps  | write  | empty |  read  | clkd  |                    //
//                 | _put  |----+-->| _ctrl |<-------| _get  |------> read_enable // 
//                 |_______|    |   |_______|        |_______|                    //
//                     ^        |                        ^                        //
//                     |        |                        |                        //
//                     |        '------------.           |                        //
//                     |                     |           |                        //
//                     |                _____|_____      |      ____              //
//                     |               |     G     |     +--|==|    \             //
//                     |               |    ___    | tmp |     | AND )==> dataout //
// datain >============|===============|D _|   |_ Q|=====|=====|____/             //
//                     |               |   LATCH   |     |                        //
//                     |               |___________|     |                        //
//                     |                                 |                        //
//                     |                                 |                        //
//                put_token_in                      get_token_in                  //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

module asps2clkd_stage
  #( parameter          DATAW = 32   ,  // data bus width
     parameter          STAGE = 0    ,  // stage index 
     parameter          SYNCD = 3    )  // brute-force synchronizer depth
   ( input              reset        ,  // global reset
     input  [DATAW-1:0] datain       ,  // asp* sender     : data in
     input              req_put      ,  // asp* sender     : request put
     output             ack_put      ,  // asp* sender     : acknowledge
     input              put_token_in ,  // fifo ring       : put token in
     output             put_token_out,  // fifo ring       : put token out
     input              get_token_in ,  // fifo ring       : get token in
     output             get_token_out,  // fifo ring       : get token out
     input              clk_get      ,  // clocked receiver: clock for receiver domain
     input              en_get       ,  // clocked receiver: enable get
     output             read_enable  ,  // clocked receiver: enable reading
     output [DATAW-1:0] dataout      ); // clocked receiver: data out

  // local registers and wires
  reg    [DATAW-1:0] dataout_tmp;
  wire               write      ;
  wire               read       ;
  wire               empty      ;
  wire               full       ;
  
  // asps_put.v: asp* put interface and token propagation module
  asps_put   #( .STAGE         (STAGE        ))  // param : stage index 
  asps_put_i  ( .reset         (reset        ),  // input : global reset
                .req_put       (req_put      ),  // input : request put
                .ack_put       (ack_put      ),  // output: acknowledge put
                .put_token_in  (put_token_in ),  // input : put token ring in
                .put_token_out (put_token_out),  // output: put token ring out
                .write         (write        ),  // output: write indicator to current stage
                .empty         (!full        )); // input : current stage is empty

  // clkd_get.v: clocked interface and get token propagation module
  clkd_get   #( .STAGE         (STAGE        ))  // param : stage index 
  clkd_get_i  ( .reset         (reset        ),  // input : global reset
                .clk_get       (clk_get      ),  // input : clock for receiver domain
                .en_get        (en_get       ),  // input : enable get
                .read_enable   (read_enable  ),  // output: enable reading
                .get_token_in  (get_token_in ),  // input : get token ring in
                .get_token_out (get_token_out),  // output: get token ring out
                .read          (read         ),  // output: read indicator to current stage
                .empty         (empty        )); // input : current stage is ful

  // asps2clkd_full_empty_ctrl.v: asp* -> clkd stage full/empty controller module
  asps2clkd_full_empty_ctrl   #( .SYNCD   (SYNCD  ))  // param : brute-force synchronizer depth
  asps2clkd_full_empty_ctrl_i  ( .reset   (reset  ),  // input : global reset
                                 .clk_get (clk_get),  // input : clock for receiver domain
                                 .write   (write  ),  // input : record write
                                 .empty   (empty  ),  // output: fifo is empty
                                 .read    (read   ),  // input : record read
                                 .full    (full   )); // output: fifo is full

  // latch data
  always@(write or datain)
    if (write)
      dataout_tmp <= datain;

  // gate invalid data for OR-tree
  assign dataout = dataout_tmp & {DATAW{get_token_in}};

endmodule // asps2clkd_stage

