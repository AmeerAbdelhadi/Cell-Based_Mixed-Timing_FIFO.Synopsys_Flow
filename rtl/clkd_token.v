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
//         clkd_put.v: clocked put interface and token propagation module         //
//   Author: Ameer M.S. Abdelhadi (ameer.abdelhadi@gmail.com; ameer@ece.ubc.ca)   //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

//                                       token_in
//                                           V
//                                           |
//                                     ______|______
// rst >------------------------------|RST/  D      | STAGE=0 ? SET : RST
//                                    |SET    ___   |
// clk >-----------------.            |      ^      |
//                       '------------|CLK   |      |
// req >-----------+-------.  ____    |      |      |
//                 |  _____ \|    \   |   ___|      |
// vac_n >------+--|--\    \ | AND )--|EN           |
//              |  |   ) OR )|____/   |______Q______|
// vac_prv_n >--|--|--/____/                 |     ____
//              |  |                         +----|    \
//              |  '-------------------------|----| AND )----> update
//              '----------------------------|----|____/
//                                           |
//                                           V
//                                      token_out
//

module clkd_token
  #( parameter  STAGE = 0    )  // stage index
   ( input      rst        ,  // global reset
     input      clk      ,  // clock for sender/receiver domain
     input      req      ,  // request (put/get)
     input      token_in ,  // token ring in  (put/get)
     output     token_out,  // token ring out (put/get)
     output     update        ,  // update current stage (write/read)
     input      vac_n         , // vacancy (inverted) (full/empty)
     input      vac_prv_n     ); // previous stage vacancy (inverted) (full/empty)

  wire move_token;

  assign move_token = req && (vac_n || vac_prv_n);

  // flop to hold token state       
//  always@(posedge clk or posedge rst)
//    if (rst)
//      if (STAGE == 0) token_out <= 1'b1;
//      else            token_out <= 1'b0;
//    else if (en_put)
//      token_out <= token_in;

  dff      #( .W(1                                    ),
              .S(STAGE==0                             ))
  token_dff ( .c(clk                              ),
              .r(rst                                ),
              .d(move_token ? token_in : token_out),
              .q(token_out                        ));

  // assign outputs
  assign update        = token_out && req && vac_n;

endmodule // clkd_put

