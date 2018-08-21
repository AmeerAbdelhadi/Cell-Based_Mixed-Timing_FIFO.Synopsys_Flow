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
//  clkd2clkd_full_empty_ctrl.v: clkd -> clkd stage full/empty controller module  //
//   Author: Ameer M.S. Abdelhadi (ameer.abdelhadi@gmail.com; ameer@ece.ubc.ca)   //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////
//                                                                                 //
// clk_  .---------------------.                                                   //
// get   |              _____  |   _____    _____        _____                     //
// >-----|-+--------.  |     | |  |     |  |     |      |     |                    //
// reset | |        '->|CL+  | '->|CLK--|->|CLK--|-...->|CLK  |                    //
// >---+-|-|--------.  |     |    |     |  |     |      |     |                    //
// read| | |     __ '->|RST--|--->|RST--|->|RST--|-...->|RST  | read_              //
// >---|-|-|---\\ X\   |     |    |     |  |     |      |     | r_sync  ___        //
//     | | |    ))OR)->|D   Q|-+->|D   Q|->|D   Q|-...->|D   Q|--------\\XN\full_n //
//     | | | .-//__/   |   _ | |  |   _ |  |   _ |      |   _ |         ))OR)O---> //
//     | | | |         | _/  | |  | _/  |  | _/  |      | _/  |      .-//__/       //
//     | | | |         |_____| |  |_____|  |_____|      |_____|      |             //
//     | | | |                 |                                     |             //
//     | | | |                 |read_r                               |             //
//     | | | '-----------------+-----------------------------------. |             //
//     | | |                                                       | |             //
//     | | '-------------------.                                   | |             //
// clk_| |              _____  |   _____    _____        _____     | |             //
// >---|-+----------.  |     | |  |     |  |     |      |     |    | |             //
// put |            '->|CLK  | '->|CLK--|->|CLK--|-...->|CLK  |    | |             //
//     '------------.  |     |    |     |  |     |      |     |    | |  ___        //
// write         __ '->|RST--|--->|RST--|->|RST--|-...->|RST  |    '-|-\\X \empty_n//
// >-----------\\ X\   |     |    |     |  |     |      |     |write |  ))OR)----> //
//              ))OR)->|D   Q|-+->|D   Q|->|D   Q|-...->|D   Q|------|-//__/       //
//           .-//__/   |   _ | |  |   _ |  |   _ |      |   _ |r_sync|             //
//           |         | _/  | |  | _/  |  | _/  |      | _/  |      |             //
//           |         |_____| |  |_____|  |_____|      |_____|      |             //
//           |                 |                                     |             //
//           |                 |write_r                              |             //
//           '-----------------+-------------------------------------'             //
//                                                                                 //
/////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////
//                                                                                 //
// >-------------------+------------+------------.            .------------------< //
// clk_put             |            |            |            |            clk_get //
//                   __V__        __V__        __V__        __V__                  //
//                  | CLK |      | CLK |      | CLK |      | CLK |                 //
//      read_r_sync |     |      |     |      |     |      |     |    ___          //
//         ___      |     |      |     |      |     |      |     |   /X //-------< //
// full_n /XN//---->|Q   D|<-...-|Q   D|<-----|Q   D|<--+--|Q   D|<-(OR((     read //
// <----O(OR((      |   _ |      |   _ |      |   _ |   |  |   _ |   \__\\-.       //
//        \__\\--.  | _/  |      | _/  |      | _/  |   |  | _/  |         |       //
//               |  |_RST_|      |_RST_|      |_RST_|   |  |_RST_|         |       //
//               |     |            |            |      |     |            |       //
//               |     |            |            |      '-----|-----+------'       //
// rst           |     |            |            |            |     |              //
// >-------------|-----+------------+------------+------------+     |              // 
//               |     |            |            |            |     |              //
//        .------+-----|-----.      |            |            |     |              //
//        |          __|__   |    __|__        __|__        __|__   |              //
//        |         | RST |  |   | RST |      | RST |      | RST |  |  ___         //
//        |   __    |     |  |   |     |      |     |      |     |  '-\\X \empty_n //
//        '-\\ X\   |     |  |   |     |      |     |      |     |     ))OR)-----> //
// write     ))OR)->|D   Q|--+-->|D   Q|----->|D   Q|-...->|D   Q|----//__/        //
// >--------//__/   |   _ |      |   _ |      |   _ |      |   _ |write_r_sync     //
//                  | _/  |      | _/  |      | _/  |      | _/  |                 //
//                  |_CLK_|      |_CLK_|      |_CLK_|      |_CLK_|                 //
//                     A          A              A            A                    //
// clk_put             |          |              |            |            clk_put //
// >-------------------'          '--------------+------------+------------------< //
//                                                                                 //
/////////////////////////////////////////////////////////////////////////////////////


module clkd2clkd_full_empty_ctrl
  #( parameter SYNCD = 3 )  // brute-force synchronizer depth
   ( input     reset     ,  // global reset
     input     clk_get   ,  // clock for receiver domain
     input     clk_put   ,  // clock for sender domain
     input     write     ,  // record write
     output    empty_n   ,  // fifo is empty (inverted)
     input     read      ,  // record read
     output    full_n    ); // fifo is full (inverted)

  // local wires/regs
  reg             read_r      ;
  reg             write_r     ;
  reg [SYNCD-1:0] write_r_sync;
  reg [SYNCD-1:0] read_r_sync ;
  
  // read flop
  always@(posedge clk_get or posedge reset)
    if (reset) read_r <= 1'b0                   ;
    else       read_r <= read ? ~read_r : read_r;
  
  // write flop
  always@(posedge clk_put or posedge reset)
    if (reset) write_r <= 1'b0                      ;
    else       write_r <= write ? ~write_r : write_r;

  // synchronize write flops into read clock domain
  always@(posedge clk_get or posedge reset)
    if (reset) write_r_sync <= {SYNCD{1'b0}                    };
    else       write_r_sync <= {write_r_sync[SYNCD-2:0],write_r};

  // synchronize read flops into write clock domain
  always@(posedge clk_put or posedge reset)
    if (reset) read_r_sync <= {SYNCD{1'b0}                  };
    else       read_r_sync <= {read_r_sync[SYNCD-2:0],read_r};  
  
  // assign outputs
  assign empty_n =  (read_r               ^ write_r_sync[SYNCD-1]);
  assign full_n  = !(read_r_sync[SYNCD-1] ^ write_r              );
   
endmodule // clkd2clkd_full_empty_ctrl

