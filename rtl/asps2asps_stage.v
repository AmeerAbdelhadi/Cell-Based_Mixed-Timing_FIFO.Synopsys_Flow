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
//                asps2asps_stage.v: asp* -> asp* fifo stage module               //
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
//                 | clock | empty  | full_ |  full  | clock |                    //
// req_put ------->| less_ |<-------| empty |------->| less_ |<---------- req_get //
//                 | put   | write  | _ctrl |  read  | get   |                    //
// ack_put <-------|       |----+-->|       |<-------|       |----------> ack_get //
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

module asps2asps_stage
  #( parameter          DATAW = 32   ,  // data bus width
     parameter          STAGE = 0    )  // stage index
   ( input              reset        ,  // global reset 
     input              req_put      ,  // asp* sender  : request put
     output             ack_put      ,  // asp* sender  : acknowkedge put
     input  [DATAW-1:0] datain       ,  // asp* sender  : data in 
     input              put_token_in ,  // fifo ring    : put token in
     output             put_token_out,  // fifo ring    : put token out
     input              get_token_in ,  // fifo ring    : get token in
     output             get_token_out,  // fifo ring    : get token out
     input              req_get      ,  // asp* receiver: request get
     output             ack_get      ,  // asp* receiver: acknowkedge get
     output [DATAW-1:0] dataout      ); // asp* receiver: data out

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
                .empty         (empty        )); // input : current stage is empty

  // asps_get.v: asp* get interface and token propagation module
  asps_get   #( .STAGE         (STAGE        ))  // param : stage index
  asps_get_i  ( .reset         (reset        ),  // input : global reset
                .req_get       (req_get      ),  // input : request get
                .ack_get       (ack_get      ),  // output: acknowledge get
                .get_token_in  (get_token_in ),  // input : get token ring in
                .get_token_out (get_token_out),  // output: get token ring ou
                .read          (read         ),  // output: read indicator to current stage
                .full          (full         )); // input : current stage is full

  // asps2asps_full_empty_ctrl.v: asp* -> asp* stage full/empty controller module
  asps2asps_full_empty_ctrl
  asps2asps_full_empty_ctrl_i ( .reset (reset),  // input : global reset
                                .write (write),  // input : record write
                                .empty (empty),  // output: fifo is empty
                                .read  (read ),  // input : record read
                                .full  (full )); // output: fifo is full

  // latch data
  always@(write or datain)
    if (write)
      dataout_tmp <= datain;

  // gate invalid data for OR-tree
  assign dataout = dataout_tmp & {DATAW{get_token_in}};

endmodule // asps2asps_stage

