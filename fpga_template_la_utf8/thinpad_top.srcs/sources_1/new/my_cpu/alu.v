`include "mycpu.h"

module alu(
    input  wire [`ALU_OP -1:0] alu_op,
    input  wire [31:0] alu_src1,
    input  wire [31:0] alu_src2,
    output wire [31:0] alu_result,
  
    input         clk,
    input         reset,
    output        complete
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate

wire op_mul_w  ;
wire op_mulh_w ;
wire op_mulh_wu;
wire op_div_w  ;
wire op_mod_w  ;
wire op_div_wu ;
wire op_mod_wu ;


// control code decomposition
assign op_add     = alu_op[ 0];
assign op_sub     = alu_op[ 1];
assign op_slt     = alu_op[ 2];
assign op_sltu    = alu_op[ 3];
assign op_and     = alu_op[ 4];
assign op_nor     = alu_op[ 5];
assign op_or      = alu_op[ 6];
assign op_xor     = alu_op[ 7];
assign op_sll     = alu_op[ 8];
assign op_srl     = alu_op[ 9];
assign op_sra     = alu_op[10];
assign op_lui     = alu_op[11];
assign op_mul_w   = alu_op[12];
assign op_mulh_w  = alu_op[13];
assign op_mulh_wu = alu_op[14];
assign op_div_w   = alu_op[15];
assign op_mod_w   = alu_op[16];
assign op_div_wu  = alu_op[17];
assign op_mod_wu  = alu_op[18];


wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [63:0] mul64_result;
wire [31:0] div_result;
wire [63:0] u_div64_result; 
wire [63:0] s_div64_result; 


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << ui5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

// Mul result
wire [32:0] src1;
wire [32:0] src2;
// MUL result
// assign unsigned_prod = alu_src1 * alu_src2;
// assign signed_prod   = $signed(alu_src1) * $signed(alu_src2);
// 33bits mul
assign src1 = op_mul_w || op_mulh_w ? {alu_src1[31], alu_src1} : {1'b0, alu_src1};
assign src2 = op_mul_w || op_mulh_w ? {alu_src2[31], alu_src2} : {1'b0, alu_src2};
assign mul64_result  = $signed(src1) * $signed(src2);


// DIV result
wire            complete_udiv;
wire            complete_sdiv;

divu uut_u_div (
    .clk                     (clk                  ),
    .reset                   (reset                ),
    .src1                    (alu_src1       [31:0]),
    .src2                    (alu_src2       [31:0]),
    .op_div                  (op_div_wu | op_mod_wu),
    .di_result            (u_div64_result [63:0]),
    .complete                (complete_udiv        )
);

s_div uut_s_div (
    .clk                     (clk                  ),
    .reset                   (reset                ),
    .src1                    (alu_src1       [31:0]),
    .src2                    (alu_src2       [31:0]),
    .op_div                  (op_div_w | op_mod_w  ),
    .div64_result            (s_div64_result [63:0]),
    .complete                (complete_sdiv        )
);

assign complete = op_div_w || op_mod_w ? complete_sdiv : complete_udiv;



// final result mux
assign alu_result = ({32{op_add|op_sub         }} & add_sub_result)
                  | ({32{op_slt                }} & slt_result)
                  | ({32{op_sltu               }} & sltu_result)
                  | ({32{op_and                }} & and_result)
                  | ({32{op_nor                }} & nor_result)
                  | ({32{op_or                 }} & or_result)
                  | ({32{op_xor                }} & xor_result)
                  | ({32{op_lui                }} & lui_result)
                  | ({32{op_sll                }} & sll_result)
                  | ({32{op_srl | op_sra       }} & sr_result)
                  | ({32{op_mul_w              }} & mul64_result[31:0])
                  | ({32{op_mulh_w | op_mulh_wu}} & mul64_result[63:32])
                  | ({32{op_div_w              }} & s_div64_result[63:32])
                  | ({32{op_div_wu             }} & u_div64_result[63:32])
                  | ({32{op_mod_w              }} & s_div64_result[31: 0])
                  | ({32{op_mod_wu             }} & u_div64_result[31: 0]);

endmodule