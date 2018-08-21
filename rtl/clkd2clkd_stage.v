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
//                clkd2clkd_stage.v: clkd -> clkd fifo stage module               //
//   Author: Ameer M.S. Abdelhadi (ameer.abdelhadi@gmail.com; ameer@ece.ubc.ca)   //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//         full_      put_                              get_      empty_          //
//         prv_n    token_in                          token_in    prv_n           //
//           |         |                                 |          |             //
//           |         |                                 |          |             //
//           |      ___V___          _______          ___V___       |             //
//           |     |       |        |       |        |   |   |      |             //
//           '---->|       |        |       |        |   |   |<-----'             //
//                 |       |        |       |        |   |   |                    //
//                 |       |        |       |        |   |   |                    //
// reset   ------->|-------|------->|-------|------->|   '-. |                    //
//                 |       |        |       |        |     | |                    //
//                 |       |        |       |        |     | |                    //
// clk_put ---- +->|-------|------->|       |<-------|-----|-|<---------- clk_get //
//              |  |       |        |       |        |     | |                    //
//              |  |       | full_n | clkd_ |empty_n |     | |                    //
// full_n <--+--|--|-------|<-------| full_ |------->|-----|-|------+---> empty_n //
//           |  |  |       |        |       |        |     | |      |             //
//           |  |  | clkd  | write  | empty |  read  | clkd| |      |             //
// req_put --|--|->| _put  |--+---->| _ctrl |<-------| _get| |<-----|---- req_get //
//           |  |  |_______|  |     |_______|        |_____|_|      |             //
//           |  |      |      |  __     ___________      | |        |             //
//           |  |      |      '-|  \   |      LATCH|     | | ___    |             //
//           |  |      |        |AND)--|CLK        |     | '-\  \   |     __      //
//           |  '------|-------O|__/   |           |     |    )OR)--|--|=|  \     //
//           |         |               |    ___    |     +---/__/   |    |AND)==> //
// datain >==|=========|===============|D _|   |_ Q|=====|==========|====|__/data //
//           |         |               |___________|     |          |        out  //
//           |         |                   dataout_tmp   |          |             //
//           V         V                                 V          V             //
//         full_      put_                              get_      empty_          //
//         nxt_n    token_out                         token_out   nxt_n           //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

module clkd2clkd_stage
  #(  parameter DATAW = 32            ,  // data bus width
      parameter STAGE = 0             ,  // stage index
      parameter SYNCD = 3             )  // brute-force synchronizer depth
   (  input              reset        ,  // global reset
      input              clk_put      ,  // clocked sender  : clock for sender domain
      input              req_put      ,  // clocked sender  : put request
      output             full_n       ,  // clocked sender  : writing enable
      input  [DATAW-1:0] datain       ,  // clocked sender  : data in
      input              put_token_in ,  // fifo ring       : put token in
      output             put_token_out,  // fifo ring       : put token out
      input              get_token_in ,  // fifo ring       : get token in
      output             get_token_out,  // fifo ring       : get token out
      input              full_prv_n   ,
      output             full_nxt_n   ,
      input              empty_prv_n  ,
      output             empty_nxt_n  ,
      input              clk_get      ,  // clocked receiver: clock for receiver domain
      input              req_get      ,  // clocked receiver: get request
      output             empty_n      ,  // clocked receiver: enable reading
      output [DATAW-1:0] dataout      ); // clocked receiver: data out

  // local registers and wires
  reg    [DATAW-1:0] dataout_tmp;
  wire               write      ;
  wire               read       ;
  
  // clkd_put.v: clocked put interface and token propagation module
  clkd_token    #( .STAGE    (STAGE        ))  // param : stage index 
  clkd_token_put ( .rst      (reset        ),  // input : global reset
                   .clk      (clk_put      ),  // input : clock for sender domain
                   .req      (req_put      ),  // input : put request
                   .token_in (put_token_in ),  // input : put token ring in
                   .token_out(put_token_out),  // output: put token ring out
                   .update   (write        ),  // output: write indicator to current stage
                   .vac_n    (full_n       ),  // input : current  stage is full
                   .vac_prv_n(full_prv_n   )); // input : previous stage is full
                 
  // clkd_get.v: clocked interface and get token propagation module
  clkd_token    #( .STAGE    (STAGE        ))  // param : stage index 
  clkd_token_get ( .rst      (reset        ),  // input : global reset
                   .clk      (clk_get      ),  // input : clock for receiver domain
                   .req      (req_get      ),  // input : get request
                   .token_in (get_token_in ),  // input : get token ring in
                   .token_out(get_token_out),  // output: get token ring out
                   .update   (read         ),  // output: read indicator to current stage
                   .vac_n    (empty_n      ),  // input : current  stage is empty
                   .vac_prv_n(empty_prv_n  )); // input : previous stage is empty

  // clkd2clkd_full_empty_ctrl.v: clkd -> clkd stage full/empty controller module
  clkd2clkd_full_empty_ctrl   #( .SYNCD  (SYNCD  ))  // param : brute-force synchronizer depth
  clkd2clkd_full_empty_ctrl_i  ( .reset  (reset  ),  // input : global reset
                                 .clk_get(clk_get),  // input : clock for receiver domain
                                 .clk_put(clk_put),  // input : clock for sender domain
                                 .write  (write  ),  // input : record write
                                 .empty_n(empty_n),  // output: fifo is empty
                                 .read   (read   ),  // input : record read
                                 .full_n (full_n )); // output: fifo is full

  // latch data
//always@(clk_put or datain)
//    if (!clk_put)
//      if (write)
//        dataout_tmp <= datain;


  always@(clk_put or write or datain)
      if (!clk_put && write)
          dataout_tmp <= datain;

// always@(posedge clk_put)
//  if (write) dataout_tmp <= datain;;

  assign full_nxt_n  = full_n ;
  assign empty_nxt_n = empty_n;

  // gate invalid data for OR-tree
  assign dataout = dataout_tmp & {DATAW{(get_token_in||get_token_out)}};

endmodule // clkd2clkd_stage


  
  
  
