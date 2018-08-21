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
//  asps2asps_full_empty_ctrl.v: asp* -> asp* stage full/empty controller module  //
//   Author: Ameer M.S. Abdelhadi (ameer.abdelhadi@gmail.com; ameer@ece.ubc.ca)   //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
// reset >----+-------------.                                                     //
//            |         ____|_____                                                //
//            |        |   RST   |                                                //
// read  >----|--------|CLK  __  |                                                //
//            |        |    ^   Q|----.  read_r                                   //
//            |   .----|D __|    |    |                                           //
//            |   |    |_________|    |                                           //
//            |   |                   |                                           //
//            |   '--------o<|--------+                                           //
//            |                       |  ____       .----|>o----> empty           //
//            '-------------.         '-\\    \     |                             //
//                      ____|_____       ))XOR )----+                             //
//                     |   RST   |    .-//____/     |                             //
// write >-------------|CLK  __  |    |             '------------> full           //
//                     |    ^   Q|----+                                           //
//                .----|D __|    |    |                                           //
//                |    |_________|    |                                           //
//                |                   |                                           //
//                '--------o<|--------'  write_r                                  //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

module asps2asps_full_empty_ctrl
  ( input  reset,  // global reset
    input  write,  // record write
    output empty,  // fifo is empty
    input  read ,  // record read
    output full ); // fifo is full

  // local wires/regs
  reg read_r ;
  reg write_r;
  
  // read flop
  always@(posedge read or posedge reset)
    if (reset) read_r <= 1'b0   ;
    else       read_r <= ~read_r;
  
  // write flop
  always@(posedge write or posedge reset)
    if (reset) write_r <= 1'b0    ;
    else       write_r <= ~write_r;

  // assign outputs
  assign empty = ~(read_r ^ write_r);
  assign full  =  (read_r ^ write_r);
   
endmodule // asps2asps_full_empty_ctrl

