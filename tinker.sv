module instruction_decoder(
    input [31:0] instruction,
    output [4:0] opcode,
    output [4:0] rd,
    output [4:0] rs,
    output [4:0] rt,
    output [11:0] L,
    output reg use_alu,
    output reg use_fpu,
    output reg is_literal,
    output reg br_abs,
    output reg br_rel_reg,
    output reg br_rel_lit,
    output reg br_nz,
    output reg br_gt,
    output reg call_inst,
    output reg return_inst,
    output reg [4:0] alu_op,
    output reg [4:0] fpu_op,
    output reg reg_write
);

localparam [4:0] OP_AND      = 5'h00;
localparam [4:0] OP_OR       = 5'h01;
localparam [4:0] OP_XOR      = 5'h02;
localparam [4:0] OP_NOT      = 5'h03;
localparam [4:0] OP_SHR      = 5'h04;
localparam [4:0] OP_SHRI     = 5'h05;
localparam [4:0] OP_SHL      = 5'h06;
localparam [4:0] OP_SHLI     = 5'h07;
localparam [4:0] OP_BR_ABS   = 5'h08;
localparam [4:0] OP_BR_RREG  = 5'h09;
localparam [4:0] OP_BR_RLIT  = 5'h0A;
localparam [4:0] OP_BR_NZ    = 5'h0B;
localparam [4:0] OP_CALL     = 5'h0C;
localparam [4:0] OP_RET      = 5'h0D;
localparam [4:0] OP_BR_GT    = 5'h0E;
localparam [4:0] OP_HALT     = 5'h0F;
localparam [4:0] OP_LOAD     = 5'h10;
localparam [4:0] OP_MOV_RR   = 5'h11;
localparam [4:0] OP_MOVI     = 5'h12;
localparam [4:0] OP_STORE    = 5'h13;
localparam [4:0] OP_ADDF     = 5'h14;
localparam [4:0] OP_SUBF     = 5'h15;
localparam [4:0] OP_MULF     = 5'h16;
localparam [4:0] OP_DIVF     = 5'h17;
localparam [4:0] OP_ADD      = 5'h18;
localparam [4:0] OP_ADDI     = 5'h19;
localparam [4:0] OP_SUB      = 5'h1A;
localparam [4:0] OP_SUBI     = 5'h1B;
localparam [4:0] OP_MUL      = 5'h1C;
localparam [4:0] OP_DIV      = 5'h1D;

assign opcode = instruction[31:27];
assign rd = instruction[26:22];
assign rs = instruction[21:17];
assign rt = instruction[16:12];
assign L = instruction[11:0];

always @(*) begin
    use_alu = 1'b0;
    use_fpu = 1'b0;
    is_literal = 1'b0;
    br_abs = 1'b0;
    br_rel_reg = 1'b0;
    br_rel_lit = 1'b0;
    br_nz = 1'b0;
    br_gt = 1'b0;
    call_inst = 1'b0;
    return_inst = 1'b0;
    alu_op = opcode;
    fpu_op = opcode;
    reg_write = 1'b0;

    case (opcode)
        OP_AND, OP_OR, OP_XOR, OP_NOT, OP_SHR, OP_SHRI, OP_SHL, OP_SHLI,
        OP_MOV_RR, OP_MOVI, OP_ADD, OP_ADDI, OP_SUB, OP_SUBI, OP_MUL, OP_DIV: begin
            use_alu = 1'b1;
            reg_write = 1'b1;
            if ((opcode == OP_MOVI) || (opcode == OP_ADDI) || (opcode == OP_SUBI) ||
                (opcode == OP_SHRI) || (opcode == OP_SHLI))
                is_literal = 1'b1;
        end
        OP_ADDF, OP_SUBF, OP_MULF, OP_DIVF: begin
            use_fpu = 1'b1;
            reg_write = 1'b1;
        end
        OP_BR_ABS: begin
            br_abs = 1'b1;
        end
        OP_BR_RREG: begin
            br_rel_reg = 1'b1;
        end
        OP_BR_RLIT: begin
            br_rel_lit = 1'b1;
            is_literal = 1'b1;
        end
        OP_BR_NZ: begin
            br_nz = 1'b1;
        end
        OP_BR_GT: begin
            br_gt = 1'b1;
        end
        OP_CALL: begin
            call_inst = 1'b1;
        end
        OP_RET: begin
            return_inst = 1'b1;
        end
        OP_LOAD: begin
            reg_write = 1'b1;
        end
        default: begin
        end
    endcase
end

endmodule

module register_file(
    input clk,
    input reset,
    input [4:0] rd,
    input [4:0] rs,
    input [4:0] rt,
    input [63:0] write_data,
    input reg_write,
    output [63:0] rd_data,
    output [63:0] rs_data,
    output [63:0] rt_data,
    output [63:0] r31_data
);

localparam [63:0] MEM_SIZE = 64'd524288;

reg [63:0] registers [0:31];
integer i;

assign rd_data = registers[rd];
assign rs_data = registers[rs];
assign rt_data = registers[rt];
assign r31_data = registers[31];

always @(posedge clk or posedge reset) begin
    if (reset) begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] <= 64'd0;
        registers[31] <= MEM_SIZE;
    end
    else if (reg_write) begin
        registers[rd] <= write_data;
    end
end

endmodule

module alu(
    input [4:0] alu_op,
    input [63:0] a,
    input [63:0] b,
    output reg [63:0] result
);

localparam [4:0] OP_AND    = 5'h00;
localparam [4:0] OP_OR     = 5'h01;
localparam [4:0] OP_XOR    = 5'h02;
localparam [4:0] OP_NOT    = 5'h03;
localparam [4:0] OP_SHR    = 5'h04;
localparam [4:0] OP_SHRI   = 5'h05;
localparam [4:0] OP_SHL    = 5'h06;
localparam [4:0] OP_SHLI   = 5'h07;
localparam [4:0] OP_MOV_RR = 5'h11;
localparam [4:0] OP_MOVI   = 5'h12;
localparam [4:0] OP_ADD    = 5'h18;
localparam [4:0] OP_ADDI   = 5'h19;
localparam [4:0] OP_SUB    = 5'h1A;
localparam [4:0] OP_SUBI   = 5'h1B;
localparam [4:0] OP_MUL    = 5'h1C;
localparam [4:0] OP_DIV    = 5'h1D;

always @(*) begin
    case (alu_op)
        OP_AND:    result = a & b;
        OP_OR:     result = a | b;
        OP_XOR:    result = a ^ b;
        OP_NOT:    result = ~a;
        OP_SHR,
        OP_SHRI:   result = a >> b[5:0];
        OP_SHL,
        OP_SHLI:   result = a << b[5:0];
        OP_MOV_RR: result = a;
        OP_MOVI:   result = {a[63:12], b[11:0]};
        OP_ADD,
        OP_ADDI:   result = a + b;
        OP_SUB,
        OP_SUBI:   result = a - b;
        OP_MUL:    result = a * b;
        OP_DIV:    result = (b == 64'd0) ? 64'd0 : (a / b);
        default:   result = 64'd0;
    endcase
end

endmodule

module fpu(
    input [63:0] a,
    input [63:0] b,
    input [4:0] fpu_op,
    output reg [63:0] result
);

localparam [4:0] OP_ADDF = 5'h14;
localparam [4:0] OP_SUBF = 5'h15;
localparam [4:0] OP_MULF = 5'h16;
localparam [4:0] OP_DIVF = 5'h17;

real ra;
real rb;
real rr;

always @(*) begin
    ra = $bitstoreal(a);
    rb = $bitstoreal(b);
    rr = 0.0;

    case (fpu_op)
        OP_ADDF: rr = ra + rb;
        OP_SUBF: rr = ra - rb;
        OP_MULF: rr = ra * rb;
        OP_DIVF: begin
            if (rb == 0.0)
                rr = 0.0;
            else
                rr = ra / rb;
        end
        default: rr = 0.0;
    endcase

    result = $realtobits(rr);
end

endmodule

module memory(
    input clk,
    input reset,
    input [63:0] pc,
    output [31:0] instruction,
    input [63:0] data_addr,
    input [63:0] write_data,
    input mem_write,
    output [63:0] data_read
);

localparam MEM_SIZE = 524288;

reg [7:0] bytes [0:MEM_SIZE-1];
integer i;

assign instruction = ((pc + 64'd3) < MEM_SIZE) ?
    {bytes[pc + 64'd3], bytes[pc + 64'd2], bytes[pc + 64'd1], bytes[pc]} :
    32'd0;

assign data_read = ((data_addr + 64'd7) < MEM_SIZE) ?
    {bytes[data_addr + 64'd7], bytes[data_addr + 64'd6], bytes[data_addr + 64'd5], bytes[data_addr + 64'd4],
     bytes[data_addr + 64'd3], bytes[data_addr + 64'd2], bytes[data_addr + 64'd1], bytes[data_addr]} :
    64'd0;

task write_word;
    input [63:0] addr;
    input [31:0] value;
    begin
        if ((addr + 64'd3) < MEM_SIZE) begin
            bytes[addr] = value[7:0];
            bytes[addr + 64'd1] = value[15:8];
            bytes[addr + 64'd2] = value[23:16];
            bytes[addr + 64'd3] = value[31:24];
        end
    end
endtask

task write_doubleword;
    input [63:0] addr;
    input [63:0] value;
    begin
        if ((addr + 64'd7) < MEM_SIZE) begin
            bytes[addr] = value[7:0];
            bytes[addr + 64'd1] = value[15:8];
            bytes[addr + 64'd2] = value[23:16];
            bytes[addr + 64'd3] = value[31:24];
            bytes[addr + 64'd4] = value[39:32];
            bytes[addr + 64'd5] = value[47:40];
            bytes[addr + 64'd6] = value[55:48];
            bytes[addr + 64'd7] = value[63:56];
        end
    end
endtask

initial begin
    for (i = 0; i < MEM_SIZE; i = i + 1)
        bytes[i] = 8'd0;
end

always @(posedge clk) begin
    if (!reset && mem_write && ((data_addr + 64'd7) < MEM_SIZE)) begin
        bytes[data_addr] <= write_data[7:0];
        bytes[data_addr + 64'd1] <= write_data[15:8];
        bytes[data_addr + 64'd2] <= write_data[23:16];
        bytes[data_addr + 64'd3] <= write_data[31:24];
        bytes[data_addr + 64'd4] <= write_data[39:32];
        bytes[data_addr + 64'd5] <= write_data[47:40];
        bytes[data_addr + 64'd6] <= write_data[55:48];
        bytes[data_addr + 64'd7] <= write_data[63:56];
    end
end

endmodule

module tinker_core(
    input clk,
    input reset,
    output reg hlt
);

localparam ROB_SIZE    = 16;
localparam INT_RS_SIZE = 8;
localparam FP_RS_SIZE  = 8;
localparam LSQ_SIZE    = 8;
localparam FQ_SIZE     = 4;
localparam [63:0] MEM_SIZE = 64'd524288;
localparam PHYS_SIZE   = 64;
localparam ARCH_REGS   = 32;
localparam BTB_SIZE    = 8;

localparam [4:0] OP_AND      = 5'h00;
localparam [4:0] OP_OR       = 5'h01;
localparam [4:0] OP_XOR      = 5'h02;
localparam [4:0] OP_NOT      = 5'h03;
localparam [4:0] OP_SHR      = 5'h04;
localparam [4:0] OP_SHRI     = 5'h05;
localparam [4:0] OP_SHL      = 5'h06;
localparam [4:0] OP_SHLI     = 5'h07;
localparam [4:0] OP_BR_ABS   = 5'h08;
localparam [4:0] OP_BR_RREG  = 5'h09;
localparam [4:0] OP_BR_RLIT  = 5'h0A;
localparam [4:0] OP_BR_NZ    = 5'h0B;
localparam [4:0] OP_CALL     = 5'h0C;
localparam [4:0] OP_RET      = 5'h0D;
localparam [4:0] OP_BR_GT    = 5'h0E;
localparam [4:0] OP_HALT     = 5'h0F;
localparam [4:0] OP_LOAD     = 5'h10;
localparam [4:0] OP_MOV_RR   = 5'h11;
localparam [4:0] OP_MOVI     = 5'h12;
localparam [4:0] OP_STORE    = 5'h13;
localparam [4:0] OP_ADDF     = 5'h14;
localparam [4:0] OP_SUBF     = 5'h15;
localparam [4:0] OP_MULF     = 5'h16;
localparam [4:0] OP_DIVF     = 5'h17;
localparam [4:0] OP_ADD      = 5'h18;
localparam [4:0] OP_ADDI     = 5'h19;
localparam [4:0] OP_SUB      = 5'h1A;
localparam [4:0] OP_SUBI     = 5'h1B;
localparam [4:0] OP_MUL      = 5'h1C;
localparam [4:0] OP_DIV      = 5'h1D;

function [63:0] zext12;
    input [11:0] imm;
    begin
        zext12 = {52'b0, imm};
    end
endfunction

function [63:0] sext12;
    input [11:0] imm;
    begin
        sext12 = {{52{imm[11]}}, imm};
    end
endfunction

function [3:0] rob_inc;
    input [3:0] idx;
    begin
        if (idx == ROB_SIZE-1)
            rob_inc = 4'd0;
        else
            rob_inc = idx + 4'd1;
    end
endfunction

function [2:0] btb_index;
    input [63:0] pc_val;
    begin
        btb_index = pc_val[4:2];
    end
endfunction

function is_ctrl_opcode;
    input [4:0] opcode;
    begin
        case (opcode)
            OP_BR_ABS, OP_BR_RREG, OP_BR_RLIT, OP_BR_NZ, OP_CALL, OP_RET, OP_BR_GT: is_ctrl_opcode = 1'b1;
            default: is_ctrl_opcode = 1'b0;
        endcase
    end
endfunction

function is_load_like;
    input [4:0] opcode;
    begin
        case (opcode)
            OP_LOAD, OP_RET: is_load_like = 1'b1;
            default: is_load_like = 1'b0;
        endcase
    end
endfunction

function is_store_like;
    input [4:0] opcode;
    begin
        case (opcode)
            OP_STORE, OP_CALL: is_store_like = 1'b1;
            default: is_store_like = 1'b0;
        endcase
    end
endfunction

function is_cond_branch;
    input [4:0] opcode;
    begin
        case (opcode)
            OP_BR_NZ, OP_BR_GT: is_cond_branch = 1'b1;
            default: is_cond_branch = 1'b0;
        endcase
    end
endfunction

function int_entry_ready;
    input [4:0] opcode;
    input s1_ready;
    input s2_ready;
    input s3_ready;
    begin
        case (opcode)
            OP_BR_ABS, OP_BR_RREG, OP_CALL: int_entry_ready = s3_ready;
            OP_BR_RLIT: int_entry_ready = 1'b1;
            OP_BR_NZ: int_entry_ready = s1_ready && s3_ready;
            OP_BR_GT: int_entry_ready = s1_ready && s2_ready && s3_ready;
            OP_NOT, OP_MOV_RR: int_entry_ready = s1_ready;
            default: int_entry_ready = s1_ready && s2_ready;
        endcase
    end
endfunction

// current state
reg [63:0] fetch_pc;
reg [63:0] n_fetch_pc;

reg fq_valid [0:FQ_SIZE-1];
reg n_fq_valid [0:FQ_SIZE-1];
reg [31:0] fq_inst [0:FQ_SIZE-1];
reg [31:0] n_fq_inst [0:FQ_SIZE-1];
reg [63:0] fq_pc [0:FQ_SIZE-1];
reg [63:0] n_fq_pc [0:FQ_SIZE-1];
reg fq_pred_taken [0:FQ_SIZE-1];
reg n_fq_pred_taken [0:FQ_SIZE-1];
reg [63:0] fq_pred_target [0:FQ_SIZE-1];
reg [63:0] n_fq_pred_target [0:FQ_SIZE-1];

reg btb_valid [0:BTB_SIZE-1];
reg n_btb_valid [0:BTB_SIZE-1];
reg [63:0] btb_tag [0:BTB_SIZE-1];
reg [63:0] n_btb_tag [0:BTB_SIZE-1];
reg [63:0] btb_target [0:BTB_SIZE-1];
reg [63:0] n_btb_target [0:BTB_SIZE-1];
reg [1:0] bht [0:BTB_SIZE-1];
reg [1:0] n_bht [0:BTB_SIZE-1];

reg [5:0] rat [0:ARCH_REGS-1];
reg [5:0] n_rat [0:ARCH_REGS-1];

reg [63:0] prf_value [0:PHYS_SIZE-1];
reg [63:0] n_prf_value [0:PHYS_SIZE-1];
reg prf_ready [0:PHYS_SIZE-1];
reg n_prf_ready [0:PHYS_SIZE-1];
reg phys_free [0:PHYS_SIZE-1];
reg n_phys_free [0:PHYS_SIZE-1];

reg rob_valid [0:ROB_SIZE-1];
reg n_rob_valid [0:ROB_SIZE-1];
reg rob_done [0:ROB_SIZE-1];
reg n_rob_done [0:ROB_SIZE-1];
reg rob_halt [0:ROB_SIZE-1];
reg n_rob_halt [0:ROB_SIZE-1];
reg rob_has_dest [0:ROB_SIZE-1];
reg n_rob_has_dest [0:ROB_SIZE-1];
reg rob_has_lsq [0:ROB_SIZE-1];
reg n_rob_has_lsq [0:ROB_SIZE-1];
reg [4:0] rob_opcode [0:ROB_SIZE-1];
reg [4:0] n_rob_opcode [0:ROB_SIZE-1];
reg [4:0] rob_arch_dst [0:ROB_SIZE-1];
reg [4:0] n_rob_arch_dst [0:ROB_SIZE-1];
reg [5:0] rob_new_phys [0:ROB_SIZE-1];
reg [5:0] n_rob_new_phys [0:ROB_SIZE-1];
reg [5:0] rob_old_phys [0:ROB_SIZE-1];
reg [5:0] n_rob_old_phys [0:ROB_SIZE-1];
reg [3:0] rob_lsq_idx [0:ROB_SIZE-1];
reg [3:0] n_rob_lsq_idx [0:ROB_SIZE-1];
reg [63:0] rob_pc [0:ROB_SIZE-1];
reg [63:0] n_rob_pc [0:ROB_SIZE-1];
reg rob_pred_taken [0:ROB_SIZE-1];
reg n_rob_pred_taken [0:ROB_SIZE-1];
reg [63:0] rob_pred_target [0:ROB_SIZE-1];
reg [63:0] n_rob_pred_target [0:ROB_SIZE-1];
reg rob_branch_taken [0:ROB_SIZE-1];
reg n_rob_branch_taken [0:ROB_SIZE-1];
reg [63:0] rob_branch_target [0:ROB_SIZE-1];
reg [63:0] n_rob_branch_target [0:ROB_SIZE-1];
reg [5:0] rob_chk_rat [0:ROB_SIZE-1][0:ARCH_REGS-1];
reg [5:0] n_rob_chk_rat [0:ROB_SIZE-1][0:ARCH_REGS-1];
reg [3:0] rob_head;
reg [3:0] n_rob_head;
reg [3:0] rob_tail;
reg [3:0] n_rob_tail;
reg [4:0] rob_count;
reg [4:0] n_rob_count;

reg int_rs_valid [0:INT_RS_SIZE-1];
reg n_int_rs_valid [0:INT_RS_SIZE-1];
reg [4:0] int_rs_opcode [0:INT_RS_SIZE-1];
reg [4:0] n_int_rs_opcode [0:INT_RS_SIZE-1];
reg [4:0] int_rs_alu_op [0:INT_RS_SIZE-1];
reg [4:0] n_int_rs_alu_op [0:INT_RS_SIZE-1];
reg [11:0] int_rs_imm [0:INT_RS_SIZE-1];
reg [11:0] n_int_rs_imm [0:INT_RS_SIZE-1];
reg [63:0] int_rs_pc [0:INT_RS_SIZE-1];
reg [63:0] n_int_rs_pc [0:INT_RS_SIZE-1];
reg [3:0] int_rs_rob_idx [0:INT_RS_SIZE-1];
reg [3:0] n_int_rs_rob_idx [0:INT_RS_SIZE-1];
reg int_rs_has_dest [0:INT_RS_SIZE-1];
reg n_int_rs_has_dest [0:INT_RS_SIZE-1];
reg [5:0] int_rs_dest_phys [0:INT_RS_SIZE-1];
reg [5:0] n_int_rs_dest_phys [0:INT_RS_SIZE-1];
reg int_rs_s1_ready [0:INT_RS_SIZE-1];
reg n_int_rs_s1_ready [0:INT_RS_SIZE-1];
reg [63:0] int_rs_s1_value [0:INT_RS_SIZE-1];
reg [63:0] n_int_rs_s1_value [0:INT_RS_SIZE-1];
reg [5:0] int_rs_s1_tag [0:INT_RS_SIZE-1];
reg [5:0] n_int_rs_s1_tag [0:INT_RS_SIZE-1];
reg int_rs_s2_ready [0:INT_RS_SIZE-1];
reg n_int_rs_s2_ready [0:INT_RS_SIZE-1];
reg [63:0] int_rs_s2_value [0:INT_RS_SIZE-1];
reg [63:0] n_int_rs_s2_value [0:INT_RS_SIZE-1];
reg [5:0] int_rs_s2_tag [0:INT_RS_SIZE-1];
reg [5:0] n_int_rs_s2_tag [0:INT_RS_SIZE-1];
reg int_rs_s3_ready [0:INT_RS_SIZE-1];
reg n_int_rs_s3_ready [0:INT_RS_SIZE-1];
reg [63:0] int_rs_s3_value [0:INT_RS_SIZE-1];
reg [63:0] n_int_rs_s3_value [0:INT_RS_SIZE-1];
reg [5:0] int_rs_s3_tag [0:INT_RS_SIZE-1];
reg [5:0] n_int_rs_s3_tag [0:INT_RS_SIZE-1];

reg fp_rs_valid [0:FP_RS_SIZE-1];
reg n_fp_rs_valid [0:FP_RS_SIZE-1];
reg [4:0] fp_rs_opcode [0:FP_RS_SIZE-1];
reg [4:0] n_fp_rs_opcode [0:FP_RS_SIZE-1];
reg [4:0] fp_rs_fpu_op [0:FP_RS_SIZE-1];
reg [4:0] n_fp_rs_fpu_op [0:FP_RS_SIZE-1];
reg [3:0] fp_rs_rob_idx [0:FP_RS_SIZE-1];
reg [3:0] n_fp_rs_rob_idx [0:FP_RS_SIZE-1];
reg fp_rs_has_dest [0:FP_RS_SIZE-1];
reg n_fp_rs_has_dest [0:FP_RS_SIZE-1];
reg [5:0] fp_rs_dest_phys [0:FP_RS_SIZE-1];
reg [5:0] n_fp_rs_dest_phys [0:FP_RS_SIZE-1];
reg fp_rs_s1_ready [0:FP_RS_SIZE-1];
reg n_fp_rs_s1_ready [0:FP_RS_SIZE-1];
reg [63:0] fp_rs_s1_value [0:FP_RS_SIZE-1];
reg [63:0] n_fp_rs_s1_value [0:FP_RS_SIZE-1];
reg [5:0] fp_rs_s1_tag [0:FP_RS_SIZE-1];
reg [5:0] n_fp_rs_s1_tag [0:FP_RS_SIZE-1];
reg fp_rs_s2_ready [0:FP_RS_SIZE-1];
reg n_fp_rs_s2_ready [0:FP_RS_SIZE-1];
reg [63:0] fp_rs_s2_value [0:FP_RS_SIZE-1];
reg [63:0] n_fp_rs_s2_value [0:FP_RS_SIZE-1];
reg [5:0] fp_rs_s2_tag [0:FP_RS_SIZE-1];
reg [5:0] n_fp_rs_s2_tag [0:FP_RS_SIZE-1];

reg lsq_valid [0:LSQ_SIZE-1];
reg n_lsq_valid [0:LSQ_SIZE-1];
reg lsq_done [0:LSQ_SIZE-1];
reg n_lsq_done [0:LSQ_SIZE-1];
reg [4:0] lsq_opcode [0:LSQ_SIZE-1];
reg [4:0] n_lsq_opcode [0:LSQ_SIZE-1];
reg [3:0] lsq_rob_idx [0:LSQ_SIZE-1];
reg [3:0] n_lsq_rob_idx [0:LSQ_SIZE-1];
reg lsq_has_dest [0:LSQ_SIZE-1];
reg n_lsq_has_dest [0:LSQ_SIZE-1];
reg [5:0] lsq_dest_phys [0:LSQ_SIZE-1];
reg [5:0] n_lsq_dest_phys [0:LSQ_SIZE-1];
reg [11:0] lsq_imm [0:LSQ_SIZE-1];
reg [11:0] n_lsq_imm [0:LSQ_SIZE-1];
reg lsq_base_ready [0:LSQ_SIZE-1];
reg n_lsq_base_ready [0:LSQ_SIZE-1];
reg [63:0] lsq_base_value [0:LSQ_SIZE-1];
reg [63:0] n_lsq_base_value [0:LSQ_SIZE-1];
reg [5:0] lsq_base_tag [0:LSQ_SIZE-1];
reg [5:0] n_lsq_base_tag [0:LSQ_SIZE-1];
reg lsq_data_ready [0:LSQ_SIZE-1];
reg n_lsq_data_ready [0:LSQ_SIZE-1];
reg [63:0] lsq_data_value [0:LSQ_SIZE-1];
reg [63:0] n_lsq_data_value [0:LSQ_SIZE-1];
reg [5:0] lsq_data_tag [0:LSQ_SIZE-1];
reg [5:0] n_lsq_data_tag [0:LSQ_SIZE-1];
reg lsq_addr_ready [0:LSQ_SIZE-1];
reg n_lsq_addr_ready [0:LSQ_SIZE-1];
reg [63:0] lsq_addr [0:LSQ_SIZE-1];
reg [63:0] n_lsq_addr [0:LSQ_SIZE-1];

reg alu0_valid, n_alu0_valid;
reg [4:0] alu0_opcode, n_alu0_opcode;
reg [4:0] alu0_alu_op, n_alu0_alu_op;
reg [11:0] alu0_imm, n_alu0_imm;
reg [63:0] alu0_pc, n_alu0_pc;
reg [3:0] alu0_rob_idx, n_alu0_rob_idx;
reg alu0_has_dest, n_alu0_has_dest;
reg [5:0] alu0_dest_phys, n_alu0_dest_phys;
reg [63:0] alu0_s1, n_alu0_s1;
reg [63:0] alu0_s2, n_alu0_s2;
reg [63:0] alu0_s3, n_alu0_s3;

reg alu1_valid, n_alu1_valid;
reg [4:0] alu1_opcode, n_alu1_opcode;
reg [4:0] alu1_alu_op, n_alu1_alu_op;
reg [11:0] alu1_imm, n_alu1_imm;
reg [63:0] alu1_pc, n_alu1_pc;
reg [3:0] alu1_rob_idx, n_alu1_rob_idx;
reg alu1_has_dest, n_alu1_has_dest;
reg [5:0] alu1_dest_phys, n_alu1_dest_phys;
reg [63:0] alu1_s1, n_alu1_s1;
reg [63:0] alu1_s2, n_alu1_s2;
reg [63:0] alu1_s3, n_alu1_s3;

reg fpu0_valid, n_fpu0_valid;
reg [4:0] fpu0_opcode, n_fpu0_opcode;
reg [4:0] fpu0_fpu_op, n_fpu0_fpu_op;
reg [3:0] fpu0_rob_idx, n_fpu0_rob_idx;
reg fpu0_has_dest, n_fpu0_has_dest;
reg [5:0] fpu0_dest_phys, n_fpu0_dest_phys;
reg [63:0] fpu0_s1, n_fpu0_s1;
reg [63:0] fpu0_s2, n_fpu0_s2;

reg fpu1_valid, n_fpu1_valid;
reg [4:0] fpu1_opcode, n_fpu1_opcode;
reg [4:0] fpu1_fpu_op, n_fpu1_fpu_op;
reg [3:0] fpu1_rob_idx, n_fpu1_rob_idx;
reg fpu1_has_dest, n_fpu1_has_dest;
reg [5:0] fpu1_dest_phys, n_fpu1_dest_phys;
reg [63:0] fpu1_s1, n_fpu1_s1;
reg [63:0] fpu1_s2, n_fpu1_s2;

reg ld_valid, n_ld_valid;
reg [4:0] ld_opcode, n_ld_opcode;
reg [3:0] ld_rob_idx, n_ld_rob_idx;
reg ld_has_dest, n_ld_has_dest;
reg [5:0] ld_dest_phys, n_ld_dest_phys;
reg [3:0] ld_lsq_idx, n_ld_lsq_idx;
reg [63:0] ld_value, n_ld_value;

reg n_hlt;

// temp / helper regs
reg keep_rob [0:ROB_SIZE-1];
reg used_phys [0:PHYS_SIZE-1];
reg cdb_valid [0:4];
reg [5:0] cdb_tag [0:4];
reg [63:0] cdb_value [0:4];
reg [3:0] cdb_rob [0:4];
reg brcand_valid [0:2];
reg [3:0] brcand_rob [0:2];
reg [4:0] brcand_opcode [0:2];
reg brcand_taken [0:2];
reg [63:0] brcand_target [0:2];
reg [63:0] brcand_pc [0:2];

integer i;
integer j;
integer k;
integer t;

// memory and architectural register file sideband control
reg [63:0] mem_data_addr;
reg [63:0] mem_write_data;
reg mem_write_en;
reg [4:0] arf_commit_rd;
reg [63:0] arf_commit_data;
reg arf_commit_write;

// decode wires for the next two instructions to dispatch
wire [4:0] d0_opcode, d0_rd, d0_rs, d0_rt;
wire [11:0] d0_L;
wire d0_use_alu, d0_use_fpu, d0_is_literal, d0_br_abs, d0_br_rel_reg, d0_br_rel_lit, d0_br_nz, d0_br_gt, d0_call_inst, d0_return_inst, d0_reg_write;
wire [4:0] d0_alu_op, d0_fpu_op;
wire [4:0] d1_opcode, d1_rd, d1_rs, d1_rt;
wire [11:0] d1_L;
wire d1_use_alu, d1_use_fpu, d1_is_literal, d1_br_abs, d1_br_rel_reg, d1_br_rel_lit, d1_br_nz, d1_br_gt, d1_call_inst, d1_return_inst, d1_reg_write;
wire [4:0] d1_alu_op, d1_fpu_op;

wire [31:0] memory_instruction;
wire [63:0] memory_data_read;
wire [63:0] unused_rd_data;
wire [63:0] unused_rs_data;
wire [63:0] unused_rt_data;
wire [63:0] unused_r31_data;

wire [63:0] alu0_result_wire;
wire [63:0] alu1_result_wire;
wire [63:0] fpu0_result_wire;
wire [63:0] fpu1_result_wire;

instruction_decoder dec0(
    .instruction(fq_inst[0]),
    .opcode(d0_opcode),
    .rd(d0_rd),
    .rs(d0_rs),
    .rt(d0_rt),
    .L(d0_L),
    .use_alu(d0_use_alu),
    .use_fpu(d0_use_fpu),
    .is_literal(d0_is_literal),
    .br_abs(d0_br_abs),
    .br_rel_reg(d0_br_rel_reg),
    .br_rel_lit(d0_br_rel_lit),
    .br_nz(d0_br_nz),
    .br_gt(d0_br_gt),
    .call_inst(d0_call_inst),
    .return_inst(d0_return_inst),
    .alu_op(d0_alu_op),
    .fpu_op(d0_fpu_op),
    .reg_write(d0_reg_write)
);

instruction_decoder dec1(
    .instruction(fq_inst[1]),
    .opcode(d1_opcode),
    .rd(d1_rd),
    .rs(d1_rs),
    .rt(d1_rt),
    .L(d1_L),
    .use_alu(d1_use_alu),
    .use_fpu(d1_use_fpu),
    .is_literal(d1_is_literal),
    .br_abs(d1_br_abs),
    .br_rel_reg(d1_br_rel_reg),
    .br_rel_lit(d1_br_rel_lit),
    .br_nz(d1_br_nz),
    .br_gt(d1_br_gt),
    .call_inst(d1_call_inst),
    .return_inst(d1_return_inst),
    .alu_op(d1_alu_op),
    .fpu_op(d1_fpu_op),
    .reg_write(d1_reg_write)
);

register_file reg_file(
    .clk(clk),
    .reset(reset),
    .rd(arf_commit_rd),
    .rs(5'd0),
    .rt(5'd0),
    .write_data(arf_commit_data),
    .reg_write(arf_commit_write),
    .rd_data(unused_rd_data),
    .rs_data(unused_rs_data),
    .rt_data(unused_rt_data),
    .r31_data(unused_r31_data)
);

alu alu0(
    .alu_op(alu0_alu_op),
    .a(alu0_s1),
    .b(alu0_s2),
    .result(alu0_result_wire)
);

alu alu1(
    .alu_op(alu1_alu_op),
    .a(alu1_s1),
    .b(alu1_s2),
    .result(alu1_result_wire)
);

fpu fpu(
    .a(fpu0_s1),
    .b(fpu0_s2),
    .fpu_op(fpu0_fpu_op),
    .result(fpu0_result_wire)
);

fpu fpu1(
    .a(fpu1_s1),
    .b(fpu1_s2),
    .fpu_op(fpu1_fpu_op),
    .result(fpu1_result_wire)
);

memory memory(
    .clk(clk),
    .reset(reset),
    .pc(fetch_pc),
    .instruction(memory_instruction),
    .data_addr(mem_data_addr),
    .write_data(mem_write_data),
    .mem_write(mem_write_en),
    .data_read(memory_data_read)
);


reg mispredict_valid;
reg [3:0] mispredict_rob;
reg [63:0] mispredict_target;

reg int_issue0_valid;
reg [2:0] int_issue0_idx;
reg int_issue1_valid;
reg [2:0] int_issue1_idx;

reg fp_issue0_valid;
reg [2:0] fp_issue0_idx;
reg fp_issue1_valid;
reg [2:0] fp_issue1_idx;

reg ld_issue_valid;
reg [3:0] ld_issue_lsq;
reg ld_issue_forward;
reg [63:0] ld_issue_value;
reg ld_issue_uses_mem;

reg [4:0] fetch0_opcode;
reg [11:0] fetch0_L;
reg fetch0_pred_taken;
reg [63:0] fetch0_pred_target;
reg [4:0] fetch1_opcode;
reg [11:0] fetch1_L;
reg fetch1_pred_taken;
reg [63:0] fetch1_pred_target;

// main next-state / control logic
always @(*) begin
    // defaults
    n_hlt = hlt;
    n_fetch_pc = fetch_pc;

    arf_commit_rd = 5'd0;
    arf_commit_data = 64'd0;
    arf_commit_write = 1'b0;

    mem_data_addr = fetch_pc + 64'd4;
    mem_write_data = 64'd0;
    mem_write_en = 1'b0;

    // copy arrays/scalars forward
    n_rob_head = rob_head;
    n_rob_tail = rob_tail;
    n_rob_count = rob_count;

    n_alu0_valid = alu0_valid;
    n_alu0_opcode = alu0_opcode;
    n_alu0_alu_op = alu0_alu_op;
    n_alu0_imm = alu0_imm;
    n_alu0_pc = alu0_pc;
    n_alu0_rob_idx = alu0_rob_idx;
    n_alu0_has_dest = alu0_has_dest;
    n_alu0_dest_phys = alu0_dest_phys;
    n_alu0_s1 = alu0_s1;
    n_alu0_s2 = alu0_s2;
    n_alu0_s3 = alu0_s3;

    n_alu1_valid = alu1_valid;
    n_alu1_opcode = alu1_opcode;
    n_alu1_alu_op = alu1_alu_op;
    n_alu1_imm = alu1_imm;
    n_alu1_pc = alu1_pc;
    n_alu1_rob_idx = alu1_rob_idx;
    n_alu1_has_dest = alu1_has_dest;
    n_alu1_dest_phys = alu1_dest_phys;
    n_alu1_s1 = alu1_s1;
    n_alu1_s2 = alu1_s2;
    n_alu1_s3 = alu1_s3;

    n_fpu0_valid = fpu0_valid;
    n_fpu0_opcode = fpu0_opcode;
    n_fpu0_fpu_op = fpu0_fpu_op;
    n_fpu0_rob_idx = fpu0_rob_idx;
    n_fpu0_has_dest = fpu0_has_dest;
    n_fpu0_dest_phys = fpu0_dest_phys;
    n_fpu0_s1 = fpu0_s1;
    n_fpu0_s2 = fpu0_s2;

    n_fpu1_valid = fpu1_valid;
    n_fpu1_opcode = fpu1_opcode;
    n_fpu1_fpu_op = fpu1_fpu_op;
    n_fpu1_rob_idx = fpu1_rob_idx;
    n_fpu1_has_dest = fpu1_has_dest;
    n_fpu1_dest_phys = fpu1_dest_phys;
    n_fpu1_s1 = fpu1_s1;
    n_fpu1_s2 = fpu1_s2;

    n_ld_valid = ld_valid;
    n_ld_opcode = ld_opcode;
    n_ld_rob_idx = ld_rob_idx;
    n_ld_has_dest = ld_has_dest;
    n_ld_dest_phys = ld_dest_phys;
    n_ld_lsq_idx = ld_lsq_idx;
    n_ld_value = ld_value;

    for (i = 0; i < FQ_SIZE; i = i + 1) begin
        n_fq_valid[i] = fq_valid[i];
        n_fq_inst[i] = fq_inst[i];
        n_fq_pc[i] = fq_pc[i];
        n_fq_pred_taken[i] = fq_pred_taken[i];
        n_fq_pred_target[i] = fq_pred_target[i];
    end

    for (i = 0; i < BTB_SIZE; i = i + 1) begin
        n_btb_valid[i] = btb_valid[i];
        n_btb_tag[i] = btb_tag[i];
        n_btb_target[i] = btb_target[i];
        n_bht[i] = bht[i];
    end

    for (i = 0; i < ARCH_REGS; i = i + 1) begin
        n_rat[i] = rat[i];
    end

    for (i = 0; i < PHYS_SIZE; i = i + 1) begin
        n_prf_value[i] = prf_value[i];
        n_prf_ready[i] = prf_ready[i];
        n_phys_free[i] = phys_free[i];
        used_phys[i] = 1'b0;
    end

    // Keep identity-mapped architectural registers coherent with the
    // architectural register file state the testbench initializes.
    for (i = 0; i < ARCH_REGS; i = i + 1) begin
        if (n_rat[i] == i[5:0]) begin
            n_prf_value[i] = reg_file.registers[i];
            n_prf_ready[i] = 1'b1;
            n_phys_free[i] = 1'b0;
        end
    end

    for (i = 0; i < ROB_SIZE; i = i + 1) begin
        n_rob_valid[i] = rob_valid[i];
        n_rob_done[i] = rob_done[i];
        n_rob_halt[i] = rob_halt[i];
        n_rob_has_dest[i] = rob_has_dest[i];
        n_rob_has_lsq[i] = rob_has_lsq[i];
        n_rob_opcode[i] = rob_opcode[i];
        n_rob_arch_dst[i] = rob_arch_dst[i];
        n_rob_new_phys[i] = rob_new_phys[i];
        n_rob_old_phys[i] = rob_old_phys[i];
        n_rob_lsq_idx[i] = rob_lsq_idx[i];
        n_rob_pc[i] = rob_pc[i];
        n_rob_pred_taken[i] = rob_pred_taken[i];
        n_rob_pred_target[i] = rob_pred_target[i];
        n_rob_branch_taken[i] = rob_branch_taken[i];
        n_rob_branch_target[i] = rob_branch_target[i];
        keep_rob[i] = 1'b0;
        for (j = 0; j < ARCH_REGS; j = j + 1) begin
            n_rob_chk_rat[i][j] = rob_chk_rat[i][j];
        end
    end

    for (i = 0; i < INT_RS_SIZE; i = i + 1) begin
        n_int_rs_valid[i] = int_rs_valid[i];
        n_int_rs_opcode[i] = int_rs_opcode[i];
        n_int_rs_alu_op[i] = int_rs_alu_op[i];
        n_int_rs_imm[i] = int_rs_imm[i];
        n_int_rs_pc[i] = int_rs_pc[i];
        n_int_rs_rob_idx[i] = int_rs_rob_idx[i];
        n_int_rs_has_dest[i] = int_rs_has_dest[i];
        n_int_rs_dest_phys[i] = int_rs_dest_phys[i];
        n_int_rs_s1_ready[i] = int_rs_s1_ready[i];
        n_int_rs_s1_value[i] = int_rs_s1_value[i];
        n_int_rs_s1_tag[i] = int_rs_s1_tag[i];
        n_int_rs_s2_ready[i] = int_rs_s2_ready[i];
        n_int_rs_s2_value[i] = int_rs_s2_value[i];
        n_int_rs_s2_tag[i] = int_rs_s2_tag[i];
        n_int_rs_s3_ready[i] = int_rs_s3_ready[i];
        n_int_rs_s3_value[i] = int_rs_s3_value[i];
        n_int_rs_s3_tag[i] = int_rs_s3_tag[i];
    end

    for (i = 0; i < FP_RS_SIZE; i = i + 1) begin
        n_fp_rs_valid[i] = fp_rs_valid[i];
        n_fp_rs_opcode[i] = fp_rs_opcode[i];
        n_fp_rs_fpu_op[i] = fp_rs_fpu_op[i];
        n_fp_rs_rob_idx[i] = fp_rs_rob_idx[i];
        n_fp_rs_has_dest[i] = fp_rs_has_dest[i];
        n_fp_rs_dest_phys[i] = fp_rs_dest_phys[i];
        n_fp_rs_s1_ready[i] = fp_rs_s1_ready[i];
        n_fp_rs_s1_value[i] = fp_rs_s1_value[i];
        n_fp_rs_s1_tag[i] = fp_rs_s1_tag[i];
        n_fp_rs_s2_ready[i] = fp_rs_s2_ready[i];
        n_fp_rs_s2_value[i] = fp_rs_s2_value[i];
        n_fp_rs_s2_tag[i] = fp_rs_s2_tag[i];
    end

    for (i = 0; i < LSQ_SIZE; i = i + 1) begin
        n_lsq_valid[i] = lsq_valid[i];
        n_lsq_done[i] = lsq_done[i];
        n_lsq_opcode[i] = lsq_opcode[i];
        n_lsq_rob_idx[i] = lsq_rob_idx[i];
        n_lsq_has_dest[i] = lsq_has_dest[i];
        n_lsq_dest_phys[i] = lsq_dest_phys[i];
        n_lsq_imm[i] = lsq_imm[i];
        n_lsq_base_ready[i] = lsq_base_ready[i];
        n_lsq_base_value[i] = lsq_base_value[i];
        n_lsq_base_tag[i] = lsq_base_tag[i];
        n_lsq_data_ready[i] = lsq_data_ready[i];
        n_lsq_data_value[i] = lsq_data_value[i];
        n_lsq_data_tag[i] = lsq_data_tag[i];
        n_lsq_addr_ready[i] = lsq_addr_ready[i];
        n_lsq_addr[i] = lsq_addr[i];
    end

    for (i = 0; i < 5; i = i + 1) begin
        cdb_valid[i] = 1'b0;
        cdb_tag[i] = 6'd0;
        cdb_value[i] = 64'd0;
        cdb_rob[i] = 4'd0;
    end

    for (i = 0; i < 3; i = i + 1) begin
        brcand_valid[i] = 1'b0;
        brcand_rob[i] = 4'd0;
        brcand_opcode[i] = 5'd0;
        brcand_taken[i] = 1'b0;
        brcand_target[i] = 64'd0;
        brcand_pc[i] = 64'd0;
    end

    if (!hlt) begin
        // ------------------------------------------------------------
        // 1) in-order commit (single-width to keep the architectural RF simple)
        // ------------------------------------------------------------
        if ((rob_count != 0) && rob_valid[rob_head]) begin
            if (rob_halt[rob_head] && rob_done[rob_head]) begin
                n_hlt = 1'b1;
                n_rob_valid[rob_head] = 1'b0;
                n_rob_done[rob_head] = 1'b0;
                n_rob_halt[rob_head] = 1'b0;
                n_rob_has_dest[rob_head] = 1'b0;
                n_rob_has_lsq[rob_head] = 1'b0;
                n_rob_head = rob_inc(rob_head);
                n_rob_count = rob_count - 5'd1;
            end
            else if ((rob_opcode[rob_head] == OP_STORE) && rob_has_lsq[rob_head] && lsq_valid[rob_lsq_idx[rob_head]] && lsq_addr_ready[rob_lsq_idx[rob_head]] && lsq_data_ready[rob_lsq_idx[rob_head]]) begin
                mem_write_en = 1'b1;
                mem_data_addr = lsq_addr[rob_lsq_idx[rob_head]];
                mem_write_data = lsq_data_value[rob_lsq_idx[rob_head]];
                n_lsq_valid[rob_lsq_idx[rob_head]] = 1'b0;
                n_rob_valid[rob_head] = 1'b0;
                n_rob_done[rob_head] = 1'b0;
                n_rob_has_lsq[rob_head] = 1'b0;
                n_rob_head = rob_inc(rob_head);
                n_rob_count = rob_count - 5'd1;
            end
            else if ((rob_opcode[rob_head] == OP_CALL) && rob_done[rob_head] && rob_has_lsq[rob_head] && lsq_valid[rob_lsq_idx[rob_head]] && lsq_addr_ready[rob_lsq_idx[rob_head]] && lsq_data_ready[rob_lsq_idx[rob_head]]) begin
                mem_write_en = 1'b1;
                mem_data_addr = lsq_addr[rob_lsq_idx[rob_head]];
                mem_write_data = lsq_data_value[rob_lsq_idx[rob_head]];
                n_lsq_valid[rob_lsq_idx[rob_head]] = 1'b0;
                n_rob_valid[rob_head] = 1'b0;
                n_rob_done[rob_head] = 1'b0;
                n_rob_has_lsq[rob_head] = 1'b0;
                n_rob_head = rob_inc(rob_head);
                n_rob_count = rob_count - 5'd1;
            end
            else if (rob_done[rob_head]) begin
                if (rob_has_dest[rob_head]) begin
                    arf_commit_write = 1'b1;
                    arf_commit_rd = rob_arch_dst[rob_head];
                    arf_commit_data = prf_value[rob_new_phys[rob_head]];
                    n_phys_free[rob_old_phys[rob_head]] = 1'b1;
                end
                if (rob_has_lsq[rob_head]) begin
                    n_lsq_valid[rob_lsq_idx[rob_head]] = 1'b0;
                end
                n_rob_valid[rob_head] = 1'b0;
                n_rob_done[rob_head] = 1'b0;
                n_rob_halt[rob_head] = 1'b0;
                n_rob_has_dest[rob_head] = 1'b0;
                n_rob_has_lsq[rob_head] = 1'b0;
                n_rob_head = rob_inc(rob_head);
                n_rob_count = rob_count - 5'd1;
            end
        end

        // ------------------------------------------------------------
        // 2) collect execution completions into CDB / branch result slots
        // ------------------------------------------------------------
        if (alu0_valid) begin
            if (is_ctrl_opcode(alu0_opcode)) begin
                brcand_valid[0] = 1'b1;
                brcand_rob[0] = alu0_rob_idx;
                brcand_opcode[0] = alu0_opcode;
                brcand_pc[0] = alu0_pc;
                case (alu0_opcode)
                    OP_BR_ABS, OP_CALL: begin
                        brcand_taken[0] = 1'b1;
                        brcand_target[0] = alu0_s3;
                    end
                    OP_BR_RREG: begin
                        brcand_taken[0] = 1'b1;
                        brcand_target[0] = alu0_pc + alu0_s3;
                    end
                    OP_BR_RLIT: begin
                        brcand_taken[0] = 1'b1;
                        brcand_target[0] = alu0_pc + sext12(alu0_imm);
                    end
                    OP_BR_NZ: begin
                        brcand_taken[0] = (alu0_s1 != 64'd0);
                        if (alu0_s1 != 64'd0)
                            brcand_target[0] = alu0_s3;
                        else
                            brcand_target[0] = alu0_pc + 64'd4;
                    end
                    OP_BR_GT: begin
                        brcand_taken[0] = ($signed(alu0_s1) > $signed(alu0_s2));
                        if ($signed(alu0_s1) > $signed(alu0_s2))
                            brcand_target[0] = alu0_s3;
                        else
                            brcand_target[0] = alu0_pc + 64'd4;
                    end
                    default: begin
                        brcand_taken[0] = 1'b0;
                        brcand_target[0] = alu0_pc + 64'd4;
                    end
                endcase
            end
            else if (alu0_has_dest) begin
                cdb_valid[0] = 1'b1;
                cdb_tag[0] = alu0_dest_phys;
                cdb_value[0] = alu0_result_wire;
                cdb_rob[0] = alu0_rob_idx;
            end
            n_alu0_valid = 1'b0;
        end

        if (alu1_valid) begin
            if (is_ctrl_opcode(alu1_opcode)) begin
                brcand_valid[1] = 1'b1;
                brcand_rob[1] = alu1_rob_idx;
                brcand_opcode[1] = alu1_opcode;
                brcand_pc[1] = alu1_pc;
                case (alu1_opcode)
                    OP_BR_ABS, OP_CALL: begin
                        brcand_taken[1] = 1'b1;
                        brcand_target[1] = alu1_s3;
                    end
                    OP_BR_RREG: begin
                        brcand_taken[1] = 1'b1;
                        brcand_target[1] = alu1_pc + alu1_s3;
                    end
                    OP_BR_RLIT: begin
                        brcand_taken[1] = 1'b1;
                        brcand_target[1] = alu1_pc + sext12(alu1_imm);
                    end
                    OP_BR_NZ: begin
                        brcand_taken[1] = (alu1_s1 != 64'd0);
                        if (alu1_s1 != 64'd0)
                            brcand_target[1] = alu1_s3;
                        else
                            brcand_target[1] = alu1_pc + 64'd4;
                    end
                    OP_BR_GT: begin
                        brcand_taken[1] = ($signed(alu1_s1) > $signed(alu1_s2));
                        if ($signed(alu1_s1) > $signed(alu1_s2))
                            brcand_target[1] = alu1_s3;
                        else
                            brcand_target[1] = alu1_pc + 64'd4;
                    end
                    default: begin
                        brcand_taken[1] = 1'b0;
                        brcand_target[1] = alu1_pc + 64'd4;
                    end
                endcase
            end
            else if (alu1_has_dest) begin
                cdb_valid[1] = 1'b1;
                cdb_tag[1] = alu1_dest_phys;
                cdb_value[1] = alu1_result_wire;
                cdb_rob[1] = alu1_rob_idx;
            end
            n_alu1_valid = 1'b0;
        end

        if (fpu0_valid) begin
            if (fpu0_has_dest) begin
                cdb_valid[2] = 1'b1;
                cdb_tag[2] = fpu0_dest_phys;
                cdb_value[2] = fpu0_result_wire;
                cdb_rob[2] = fpu0_rob_idx;
            end
            n_fpu0_valid = 1'b0;
        end

        if (fpu1_valid) begin
            if (fpu1_has_dest) begin
                cdb_valid[3] = 1'b1;
                cdb_tag[3] = fpu1_dest_phys;
                cdb_value[3] = fpu1_result_wire;
                cdb_rob[3] = fpu1_rob_idx;
            end
            n_fpu1_valid = 1'b0;
        end

        if (ld_valid) begin
            if (ld_opcode == OP_RET) begin
                brcand_valid[2] = 1'b1;
                brcand_rob[2] = ld_rob_idx;
                brcand_opcode[2] = ld_opcode;
                brcand_taken[2] = 1'b1;
                brcand_target[2] = ld_value;
                brcand_pc[2] = rob_pc[ld_rob_idx];
                n_lsq_done[ld_lsq_idx] = 1'b1;
            end
            else if (ld_has_dest) begin
                cdb_valid[4] = 1'b1;
                cdb_tag[4] = ld_dest_phys;
                cdb_value[4] = ld_value;
                cdb_rob[4] = ld_rob_idx;
                n_lsq_done[ld_lsq_idx] = 1'b1;
            end
            n_ld_valid = 1'b0;
        end

        // write CDB results into PRF / ROB and wake up queues
        for (i = 0; i < 5; i = i + 1) begin
            if (cdb_valid[i]) begin
                n_prf_value[cdb_tag[i]] = cdb_value[i];
                n_prf_ready[cdb_tag[i]] = 1'b1;
                n_rob_done[cdb_rob[i]] = 1'b1;
            end
        end

        for (i = 0; i < INT_RS_SIZE; i = i + 1) begin
            if (n_int_rs_valid[i]) begin
                for (j = 0; j < 5; j = j + 1) begin
                    if (cdb_valid[j] && !n_int_rs_s1_ready[i] && (n_int_rs_s1_tag[i] == cdb_tag[j])) begin
                        n_int_rs_s1_ready[i] = 1'b1;
                        n_int_rs_s1_value[i] = cdb_value[j];
                    end
                    if (cdb_valid[j] && !n_int_rs_s2_ready[i] && (n_int_rs_s2_tag[i] == cdb_tag[j])) begin
                        n_int_rs_s2_ready[i] = 1'b1;
                        n_int_rs_s2_value[i] = cdb_value[j];
                    end
                    if (cdb_valid[j] && !n_int_rs_s3_ready[i] && (n_int_rs_s3_tag[i] == cdb_tag[j])) begin
                        n_int_rs_s3_ready[i] = 1'b1;
                        n_int_rs_s3_value[i] = cdb_value[j];
                    end
                end
            end
        end

        for (i = 0; i < FP_RS_SIZE; i = i + 1) begin
            if (n_fp_rs_valid[i]) begin
                for (j = 0; j < 5; j = j + 1) begin
                    if (cdb_valid[j] && !n_fp_rs_s1_ready[i] && (n_fp_rs_s1_tag[i] == cdb_tag[j])) begin
                        n_fp_rs_s1_ready[i] = 1'b1;
                        n_fp_rs_s1_value[i] = cdb_value[j];
                    end
                    if (cdb_valid[j] && !n_fp_rs_s2_ready[i] && (n_fp_rs_s2_tag[i] == cdb_tag[j])) begin
                        n_fp_rs_s2_ready[i] = 1'b1;
                        n_fp_rs_s2_value[i] = cdb_value[j];
                    end
                end
            end
        end

        for (i = 0; i < LSQ_SIZE; i = i + 1) begin
            if (n_lsq_valid[i]) begin
                for (j = 0; j < 5; j = j + 1) begin
                    if (cdb_valid[j] && !n_lsq_base_ready[i] && (n_lsq_base_tag[i] == cdb_tag[j])) begin
                        n_lsq_base_ready[i] = 1'b1;
                        n_lsq_base_value[i] = cdb_value[j];
                    end
                    if (cdb_valid[j] && !n_lsq_data_ready[i] && (n_lsq_data_tag[i] == cdb_tag[j])) begin
                        n_lsq_data_ready[i] = 1'b1;
                        n_lsq_data_value[i] = cdb_value[j];
                    end
                end
            end
        end

        // LSQ address generation after wakeup
        for (i = 0; i < LSQ_SIZE; i = i + 1) begin
            if (n_lsq_valid[i] && !n_lsq_addr_ready[i] && n_lsq_base_ready[i]) begin
                n_lsq_addr_ready[i] = 1'b1;
                if ((n_lsq_opcode[i] == OP_CALL) || (n_lsq_opcode[i] == OP_RET))
                    n_lsq_addr[i] = n_lsq_base_value[i] - 64'd8;
                else
                    n_lsq_addr[i] = n_lsq_base_value[i] + zext12(n_lsq_imm[i]);
            end
        end

        // branch predictor update + actual branch state capture
        mispredict_valid = 1'b0;
        mispredict_rob = 4'd0;
        mispredict_target = 64'd0;

        for (i = 0; i < 3; i = i + 1) begin
            if (brcand_valid[i]) begin
                n_rob_done[brcand_rob[i]] = 1'b1;
                n_rob_branch_taken[brcand_rob[i]] = brcand_taken[i];
                n_rob_branch_target[brcand_rob[i]] = brcand_target[i];
                n_btb_valid[btb_index(brcand_pc[i])] = 1'b1;
                n_btb_tag[btb_index(brcand_pc[i])] = brcand_pc[i];
                n_btb_target[btb_index(brcand_pc[i])] = brcand_target[i];
                if (is_cond_branch(brcand_opcode[i])) begin
                    if (brcand_taken[i]) begin
                        if (n_bht[btb_index(brcand_pc[i])] != 2'b11)
                            n_bht[btb_index(brcand_pc[i])] = n_bht[btb_index(brcand_pc[i])] + 2'b01;
                    end
                    else begin
                        if (n_bht[btb_index(brcand_pc[i])] != 2'b00)
                            n_bht[btb_index(brcand_pc[i])] = n_bht[btb_index(brcand_pc[i])] - 2'b01;
                    end
                end
                else begin
                    n_bht[btb_index(brcand_pc[i])] = 2'b11;
                end
            end
        end

        // choose the oldest mispredicted control instruction that completed this cycle
        k = n_rob_head;
        for (t = 0; t < ROB_SIZE; t = t + 1) begin
            if (n_rob_valid[k]) begin
                for (i = 0; i < 3; i = i + 1) begin
                    if (!mispredict_valid && brcand_valid[i] && (brcand_rob[i] == k)) begin
                        if ((n_rob_pred_taken[k] != brcand_taken[i]) ||
                            (n_rob_pred_taken[k] && brcand_taken[i] && (n_rob_pred_target[k] != brcand_target[i]))) begin
                            mispredict_valid = 1'b1;
                            mispredict_rob = k;
                            if (brcand_taken[i])
                                mispredict_target = brcand_target[i];
                            else
                                mispredict_target = brcand_pc[i] + 64'd4;
                        end
                    end
                end
            end
            k = rob_inc(k[3:0]);
        end

        if (mispredict_valid) begin
            k = n_rob_head;
            j = 0;
            for (t = 0; t < ROB_SIZE; t = t + 1) begin
                if (n_rob_valid[k] && (j == 0)) begin
                    keep_rob[k] = 1'b1;
                end
                if (k == mispredict_rob)
                    j = 1;
                k = rob_inc(k[3:0]);
            end

            for (i = 0; i < ARCH_REGS; i = i + 1) begin
                n_rat[i] = n_rob_chk_rat[mispredict_rob][i];
            end

            j = 0;
            for (i = 0; i < ROB_SIZE; i = i + 1) begin
                if (n_rob_valid[i] && !keep_rob[i]) begin
                    n_rob_valid[i] = 1'b0;
                    n_rob_done[i] = 1'b0;
                    n_rob_halt[i] = 1'b0;
                    n_rob_has_dest[i] = 1'b0;
                    n_rob_has_lsq[i] = 1'b0;
                end
                if (n_rob_valid[i] && keep_rob[i])
                    j = j + 1;
            end
            n_rob_tail = rob_inc(mispredict_rob);
            n_rob_count = j[4:0];

            for (i = 0; i < INT_RS_SIZE; i = i + 1) begin
                if (n_int_rs_valid[i] && !keep_rob[n_int_rs_rob_idx[i]])
                    n_int_rs_valid[i] = 1'b0;
            end
            for (i = 0; i < FP_RS_SIZE; i = i + 1) begin
                if (n_fp_rs_valid[i] && !keep_rob[n_fp_rs_rob_idx[i]])
                    n_fp_rs_valid[i] = 1'b0;
            end
            for (i = 0; i < LSQ_SIZE; i = i + 1) begin
                if (n_lsq_valid[i] && !keep_rob[n_lsq_rob_idx[i]]) begin
                    n_lsq_valid[i] = 1'b0;
                    n_lsq_done[i] = 1'b0;
                end
            end

            if (n_alu0_valid && !keep_rob[n_alu0_rob_idx])
                n_alu0_valid = 1'b0;
            if (n_alu1_valid && !keep_rob[n_alu1_rob_idx])
                n_alu1_valid = 1'b0;
            if (n_fpu0_valid && !keep_rob[n_fpu0_rob_idx])
                n_fpu0_valid = 1'b0;
            if (n_fpu1_valid && !keep_rob[n_fpu1_rob_idx])
                n_fpu1_valid = 1'b0;
            if (n_ld_valid && !keep_rob[n_ld_rob_idx])
                n_ld_valid = 1'b0;

            for (i = 0; i < FQ_SIZE; i = i + 1) begin
                n_fq_valid[i] = 1'b0;
                n_fq_inst[i] = 32'd0;
                n_fq_pc[i] = 64'd0;
                n_fq_pred_taken[i] = 1'b0;
                n_fq_pred_target[i] = 64'd0;
            end

            for (i = 0; i < PHYS_SIZE; i = i + 1) begin
                used_phys[i] = 1'b0;
            end
            for (i = 0; i < ARCH_REGS; i = i + 1) begin
                used_phys[n_rat[i]] = 1'b1;
            end
            for (i = 0; i < ROB_SIZE; i = i + 1) begin
                if (n_rob_valid[i] && keep_rob[i] && n_rob_has_dest[i])
                    used_phys[n_rob_old_phys[i]] = 1'b1;
            end
            for (i = 0; i < PHYS_SIZE; i = i + 1) begin
                n_phys_free[i] = !used_phys[i];
            end

            n_fetch_pc = mispredict_target;
        end
        else if (!n_hlt) begin : sched_block
            reg slot_found;
            reg blocked;
            reg stop_scan;
            reg [3:0] scan_rob;
            reg [3:0] alloc_rob;
            reg [3:0] alloc_lsq;
            reg [5:0] alloc_phys;
            reg [5:0] old_phys;
            reg [2:0] alloc_int_rs;
            reg [2:0] alloc_fp_rs;
            reg [2:0] free_slot_count;
            reg [2:0] disp_count;
            reg [63:0] imm_val;
            reg slot0_valid_local;
            reg slot1_valid_local;
            reg slot0_is_load;
            reg slot0_is_store;
            reg slot0_is_halt;
            reg slot0_is_nop;
            reg slot0_needs_int_rs;
            reg slot0_needs_fp_rs;
            reg slot0_needs_lsq;
            reg slot0_has_dest;
            reg slot0_can_dispatch;
            reg slot1_is_load;
            reg slot1_is_store;
            reg slot1_is_halt;
            reg slot1_is_nop;
            reg slot1_needs_int_rs;
            reg slot1_needs_fp_rs;
            reg slot1_needs_lsq;
            reg slot1_has_dest;
            reg slot1_can_dispatch;

            // ------------------------------------------------------------
            // 3) issue ready integer / FP ops into the free execution slots
            // ------------------------------------------------------------
            int_issue0_valid = 1'b0;
            int_issue0_idx = 3'd0;
            int_issue1_valid = 1'b0;
            int_issue1_idx = 3'd0;
            for (i = 0; i < INT_RS_SIZE; i = i + 1) begin
                if (n_int_rs_valid[i] && int_entry_ready(n_int_rs_opcode[i], n_int_rs_s1_ready[i], n_int_rs_s2_ready[i], n_int_rs_s3_ready[i])) begin
                    if (!int_issue0_valid) begin
                        int_issue0_valid = 1'b1;
                        int_issue0_idx = i[2:0];
                    end
                    else if (!int_issue1_valid) begin
                        int_issue1_valid = 1'b1;
                        int_issue1_idx = i[2:0];
                    end
                end
            end

            slot_found = !n_alu0_valid;
            blocked = !n_alu1_valid;
            if (slot_found && int_issue0_valid) begin
                n_alu0_valid = 1'b1;
                n_alu0_opcode = n_int_rs_opcode[int_issue0_idx];
                n_alu0_alu_op = n_int_rs_alu_op[int_issue0_idx];
                n_alu0_imm = n_int_rs_imm[int_issue0_idx];
                n_alu0_pc = n_int_rs_pc[int_issue0_idx];
                n_alu0_rob_idx = n_int_rs_rob_idx[int_issue0_idx];
                n_alu0_has_dest = n_int_rs_has_dest[int_issue0_idx];
                n_alu0_dest_phys = n_int_rs_dest_phys[int_issue0_idx];
                n_alu0_s1 = n_int_rs_s1_value[int_issue0_idx];
                n_alu0_s2 = n_int_rs_s2_value[int_issue0_idx];
                n_alu0_s3 = n_int_rs_s3_value[int_issue0_idx];
                n_int_rs_valid[int_issue0_idx] = 1'b0;
            end
            if (blocked) begin
                if (slot_found && int_issue1_valid) begin
                    n_alu1_valid = 1'b1;
                    n_alu1_opcode = n_int_rs_opcode[int_issue1_idx];
                    n_alu1_alu_op = n_int_rs_alu_op[int_issue1_idx];
                    n_alu1_imm = n_int_rs_imm[int_issue1_idx];
                    n_alu1_pc = n_int_rs_pc[int_issue1_idx];
                    n_alu1_rob_idx = n_int_rs_rob_idx[int_issue1_idx];
                    n_alu1_has_dest = n_int_rs_has_dest[int_issue1_idx];
                    n_alu1_dest_phys = n_int_rs_dest_phys[int_issue1_idx];
                    n_alu1_s1 = n_int_rs_s1_value[int_issue1_idx];
                    n_alu1_s2 = n_int_rs_s2_value[int_issue1_idx];
                    n_alu1_s3 = n_int_rs_s3_value[int_issue1_idx];
                    n_int_rs_valid[int_issue1_idx] = 1'b0;
                end
                else if (!slot_found && int_issue0_valid) begin
                    n_alu1_valid = 1'b1;
                    n_alu1_opcode = n_int_rs_opcode[int_issue0_idx];
                    n_alu1_alu_op = n_int_rs_alu_op[int_issue0_idx];
                    n_alu1_imm = n_int_rs_imm[int_issue0_idx];
                    n_alu1_pc = n_int_rs_pc[int_issue0_idx];
                    n_alu1_rob_idx = n_int_rs_rob_idx[int_issue0_idx];
                    n_alu1_has_dest = n_int_rs_has_dest[int_issue0_idx];
                    n_alu1_dest_phys = n_int_rs_dest_phys[int_issue0_idx];
                    n_alu1_s1 = n_int_rs_s1_value[int_issue0_idx];
                    n_alu1_s2 = n_int_rs_s2_value[int_issue0_idx];
                    n_alu1_s3 = n_int_rs_s3_value[int_issue0_idx];
                    n_int_rs_valid[int_issue0_idx] = 1'b0;
                end
            end

            fp_issue0_valid = 1'b0;
            fp_issue0_idx = 3'd0;
            fp_issue1_valid = 1'b0;
            fp_issue1_idx = 3'd0;
            for (i = 0; i < FP_RS_SIZE; i = i + 1) begin
                if (n_fp_rs_valid[i] && n_fp_rs_s1_ready[i] && n_fp_rs_s2_ready[i]) begin
                    if (!fp_issue0_valid) begin
                        fp_issue0_valid = 1'b1;
                        fp_issue0_idx = i[2:0];
                    end
                    else if (!fp_issue1_valid) begin
                        fp_issue1_valid = 1'b1;
                        fp_issue1_idx = i[2:0];
                    end
                end
            end

            slot_found = !n_fpu0_valid;
            blocked = !n_fpu1_valid;
            if (slot_found && fp_issue0_valid) begin
                n_fpu0_valid = 1'b1;
                n_fpu0_opcode = n_fp_rs_opcode[fp_issue0_idx];
                n_fpu0_fpu_op = n_fp_rs_fpu_op[fp_issue0_idx];
                n_fpu0_rob_idx = n_fp_rs_rob_idx[fp_issue0_idx];
                n_fpu0_has_dest = n_fp_rs_has_dest[fp_issue0_idx];
                n_fpu0_dest_phys = n_fp_rs_dest_phys[fp_issue0_idx];
                n_fpu0_s1 = n_fp_rs_s1_value[fp_issue0_idx];
                n_fpu0_s2 = n_fp_rs_s2_value[fp_issue0_idx];
                n_fp_rs_valid[fp_issue0_idx] = 1'b0;
            end
            if (blocked) begin
                if (slot_found && fp_issue1_valid) begin
                    n_fpu1_valid = 1'b1;
                    n_fpu1_opcode = n_fp_rs_opcode[fp_issue1_idx];
                    n_fpu1_fpu_op = n_fp_rs_fpu_op[fp_issue1_idx];
                    n_fpu1_rob_idx = n_fp_rs_rob_idx[fp_issue1_idx];
                    n_fpu1_has_dest = n_fp_rs_has_dest[fp_issue1_idx];
                    n_fpu1_dest_phys = n_fp_rs_dest_phys[fp_issue1_idx];
                    n_fpu1_s1 = n_fp_rs_s1_value[fp_issue1_idx];
                    n_fpu1_s2 = n_fp_rs_s2_value[fp_issue1_idx];
                    n_fp_rs_valid[fp_issue1_idx] = 1'b0;
                end
                else if (!slot_found && fp_issue0_valid) begin
                    n_fpu1_valid = 1'b1;
                    n_fpu1_opcode = n_fp_rs_opcode[fp_issue0_idx];
                    n_fpu1_fpu_op = n_fp_rs_fpu_op[fp_issue0_idx];
                    n_fpu1_rob_idx = n_fp_rs_rob_idx[fp_issue0_idx];
                    n_fpu1_has_dest = n_fp_rs_has_dest[fp_issue0_idx];
                    n_fpu1_dest_phys = n_fp_rs_dest_phys[fp_issue0_idx];
                    n_fpu1_s1 = n_fp_rs_s1_value[fp_issue0_idx];
                    n_fpu1_s2 = n_fp_rs_s2_value[fp_issue0_idx];
                    n_fp_rs_valid[fp_issue0_idx] = 1'b0;
                end
            end

            // ------------------------------------------------------------
            // 4) one load/return can execute per cycle; stores wait for commit
            // ------------------------------------------------------------
            ld_issue_valid = 1'b0;
            ld_issue_lsq = 4'd0;
            ld_issue_forward = 1'b0;
            ld_issue_value = 64'd0;
            ld_issue_uses_mem = 1'b0;
            if (!n_ld_valid) begin
                scan_rob = n_rob_head;
                for (t = 0; t < ROB_SIZE; t = t + 1) begin
                    if (!ld_issue_valid && n_rob_valid[scan_rob] && n_rob_has_lsq[scan_rob]) begin
                        if (n_lsq_valid[n_rob_lsq_idx[scan_rob]] && !n_lsq_done[n_rob_lsq_idx[scan_rob]] && (n_lsq_opcode[n_rob_lsq_idx[scan_rob]] == OP_LOAD || n_lsq_opcode[n_rob_lsq_idx[scan_rob]] == OP_RET) && n_lsq_addr_ready[n_rob_lsq_idx[scan_rob]]) begin
                            blocked = 1'b0;
                            stop_scan = 1'b0;
                            ld_issue_forward = 1'b0;
                            ld_issue_value = 64'd0;
                            k = n_rob_head;
                            for (j = 0; j < ROB_SIZE; j = j + 1) begin
                                if (!stop_scan && (k == scan_rob))
                                    stop_scan = 1'b1;
                                if (!stop_scan && n_rob_valid[k] && n_rob_has_lsq[k]) begin
                                    if (n_lsq_valid[n_rob_lsq_idx[k]] && (n_lsq_opcode[n_rob_lsq_idx[k]] == OP_STORE || n_lsq_opcode[n_rob_lsq_idx[k]] == OP_CALL)) begin
                                        if (!n_lsq_addr_ready[n_rob_lsq_idx[k]])
                                            blocked = 1'b1;
                                        else if (n_lsq_addr[n_rob_lsq_idx[k]] == n_lsq_addr[n_rob_lsq_idx[scan_rob]]) begin
                                            if (!n_lsq_data_ready[n_rob_lsq_idx[k]])
                                                blocked = 1'b1;
                                            else begin
                                                ld_issue_forward = 1'b1;
                                                ld_issue_value = n_lsq_data_value[n_rob_lsq_idx[k]];
                                            end
                                        end
                                    end
                                end
                                k = rob_inc(k[3:0]);
                            end
                            if (!blocked) begin
                                ld_issue_valid = 1'b1;
                                ld_issue_lsq = n_rob_lsq_idx[scan_rob];
                                ld_issue_uses_mem = !ld_issue_forward;
                            end
                        end
                    end
                    scan_rob = rob_inc(scan_rob[3:0]);
                end
            end

            if (ld_issue_valid) begin
                if (ld_issue_forward || !mem_write_en) begin
                    if (!ld_issue_forward) begin
                        mem_data_addr = n_lsq_addr[ld_issue_lsq];
                        ld_issue_value = memory_data_read;
                    end
                    n_ld_valid = 1'b1;
                    n_ld_opcode = n_lsq_opcode[ld_issue_lsq];
                    n_ld_rob_idx = n_lsq_rob_idx[ld_issue_lsq];
                    n_ld_has_dest = n_lsq_has_dest[ld_issue_lsq];
                    n_ld_dest_phys = n_lsq_dest_phys[ld_issue_lsq];
                    n_ld_lsq_idx = ld_issue_lsq;
                    n_ld_value = ld_issue_value;
                end
            end

            // ------------------------------------------------------------
            // 5) dispatch / rename up to two instructions from the fetch queue
            // ------------------------------------------------------------
            disp_count = 3'd0;

            slot0_valid_local = n_fq_valid[0];
            slot0_is_load = (d0_opcode == OP_LOAD);
            slot0_is_store = (d0_opcode == OP_STORE);
            slot0_is_halt = (d0_opcode == OP_HALT) && (d0_L == 12'h000);
            slot0_is_nop = !(d0_use_alu || d0_use_fpu || d0_br_abs || d0_br_rel_reg || d0_br_rel_lit || d0_br_nz || d0_br_gt || d0_call_inst || d0_return_inst || slot0_is_load || slot0_is_store || slot0_is_halt);
            slot0_needs_int_rs = d0_use_alu || d0_br_abs || d0_br_rel_reg || d0_br_rel_lit || d0_br_nz || d0_br_gt || d0_call_inst;
            slot0_needs_fp_rs = d0_use_fpu;
            slot0_needs_lsq = slot0_is_load || slot0_is_store || d0_call_inst || d0_return_inst;
            slot0_has_dest = d0_reg_write;
            slot0_can_dispatch = 1'b0;

            alloc_phys = 6'd0;
            alloc_int_rs = 3'd0;
            alloc_fp_rs = 3'd0;
            alloc_lsq = 4'd0;
            if (slot0_valid_local && (n_rob_count < ROB_SIZE)) begin
                slot0_can_dispatch = 1'b1;
                if (slot0_has_dest) begin
                    slot_found = 1'b0;
                    for (i = 0; i < PHYS_SIZE; i = i + 1) begin
                        if (!slot_found && n_phys_free[i]) begin
                            alloc_phys = i[5:0];
                            slot_found = 1'b1;
                        end
                    end
                    if (!slot_found)
                        slot0_can_dispatch = 1'b0;
                end
                if (slot0_needs_int_rs) begin
                    slot_found = 1'b0;
                    for (i = 0; i < INT_RS_SIZE; i = i + 1) begin
                        if (!slot_found && !n_int_rs_valid[i]) begin
                            alloc_int_rs = i[2:0];
                            slot_found = 1'b1;
                        end
                    end
                    if (!slot_found)
                        slot0_can_dispatch = 1'b0;
                end
                if (slot0_needs_fp_rs) begin
                    slot_found = 1'b0;
                    for (i = 0; i < FP_RS_SIZE; i = i + 1) begin
                        if (!slot_found && !n_fp_rs_valid[i]) begin
                            alloc_fp_rs = i[2:0];
                            slot_found = 1'b1;
                        end
                    end
                    if (!slot_found)
                        slot0_can_dispatch = 1'b0;
                end
                if (slot0_needs_lsq) begin
                    slot_found = 1'b0;
                    for (i = 0; i < LSQ_SIZE; i = i + 1) begin
                        if (!slot_found && !n_lsq_valid[i]) begin
                            alloc_lsq = i[3:0];
                            slot_found = 1'b1;
                        end
                    end
                    if (!slot_found)
                        slot0_can_dispatch = 1'b0;
                end
            end

            if (slot0_can_dispatch) begin
                alloc_rob = n_rob_tail;
                old_phys = 6'd0;
                if (slot0_has_dest)
                    old_phys = n_rat[d0_rd];

                n_rob_valid[alloc_rob] = 1'b1;
                if (slot0_is_store || slot0_is_nop || slot0_is_halt)
                    n_rob_done[alloc_rob] = 1'b1;
                else
                    n_rob_done[alloc_rob] = 1'b0;
                n_rob_halt[alloc_rob] = slot0_is_halt;
                n_rob_has_dest[alloc_rob] = slot0_has_dest;
                n_rob_has_lsq[alloc_rob] = slot0_needs_lsq;
                n_rob_opcode[alloc_rob] = d0_opcode;
                n_rob_arch_dst[alloc_rob] = d0_rd;
                n_rob_new_phys[alloc_rob] = alloc_phys;
                n_rob_old_phys[alloc_rob] = old_phys;
                n_rob_lsq_idx[alloc_rob] = alloc_lsq;
                n_rob_pc[alloc_rob] = n_fq_pc[0];
                n_rob_pred_taken[alloc_rob] = n_fq_pred_taken[0];
                n_rob_pred_target[alloc_rob] = n_fq_pred_target[0];
                n_rob_branch_taken[alloc_rob] = 1'b0;
                n_rob_branch_target[alloc_rob] = 64'd0;
                if (is_ctrl_opcode(d0_opcode)) begin
                    for (i = 0; i < ARCH_REGS; i = i + 1) begin
                        n_rob_chk_rat[alloc_rob][i] = n_rat[i];
                    end
                end

                if (slot0_needs_int_rs) begin
                    n_int_rs_valid[alloc_int_rs] = 1'b1;
                    n_int_rs_opcode[alloc_int_rs] = d0_opcode;
                    n_int_rs_alu_op[alloc_int_rs] = d0_alu_op;
                    n_int_rs_imm[alloc_int_rs] = d0_L;
                    n_int_rs_pc[alloc_int_rs] = n_fq_pc[0];
                    n_int_rs_rob_idx[alloc_int_rs] = alloc_rob;
                    n_int_rs_has_dest[alloc_int_rs] = d0_use_alu && slot0_has_dest;
                    n_int_rs_dest_phys[alloc_int_rs] = alloc_phys;
                    n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                    n_int_rs_s1_value[alloc_int_rs] = 64'd0;
                    n_int_rs_s1_tag[alloc_int_rs] = 6'd0;
                    n_int_rs_s2_ready[alloc_int_rs] = 1'b1;
                    n_int_rs_s2_value[alloc_int_rs] = 64'd0;
                    n_int_rs_s2_tag[alloc_int_rs] = 6'd0;
                    n_int_rs_s3_ready[alloc_int_rs] = 1'b1;
                    n_int_rs_s3_value[alloc_int_rs] = 64'd0;
                    n_int_rs_s3_tag[alloc_int_rs] = 6'd0;
                    case (d0_opcode)
                        OP_NOT, OP_MOV_RR: begin
                            if (n_prf_ready[n_rat[d0_rs]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d0_rs]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d0_rs];
                            end
                        end
                        OP_SHRI, OP_SHLI, OP_MOVI, OP_ADDI, OP_SUBI: begin
                            if (n_prf_ready[n_rat[d0_rd]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d0_rd]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d0_rd];
                            end
                            n_int_rs_s2_ready[alloc_int_rs] = 1'b1;
                            n_int_rs_s2_value[alloc_int_rs] = zext12(d0_L);
                        end
                        OP_BR_ABS, OP_BR_RREG, OP_CALL: begin
                            if (n_prf_ready[n_rat[d0_rd]]) begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s3_value[alloc_int_rs] = n_prf_value[n_rat[d0_rd]];
                            end
                            else begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s3_tag[alloc_int_rs] = n_rat[d0_rd];
                            end
                        end
                        OP_BR_RLIT: begin
                        end
                        OP_BR_NZ: begin
                            if (n_prf_ready[n_rat[d0_rs]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d0_rs]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d0_rs];
                            end
                            if (n_prf_ready[n_rat[d0_rd]]) begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s3_value[alloc_int_rs] = n_prf_value[n_rat[d0_rd]];
                            end
                            else begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s3_tag[alloc_int_rs] = n_rat[d0_rd];
                            end
                        end
                        OP_BR_GT: begin
                            if (n_prf_ready[n_rat[d0_rs]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d0_rs]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d0_rs];
                            end
                            if (n_prf_ready[n_rat[d0_rt]]) begin
                                n_int_rs_s2_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s2_value[alloc_int_rs] = n_prf_value[n_rat[d0_rt]];
                            end
                            else begin
                                n_int_rs_s2_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s2_tag[alloc_int_rs] = n_rat[d0_rt];
                            end
                            if (n_prf_ready[n_rat[d0_rd]]) begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s3_value[alloc_int_rs] = n_prf_value[n_rat[d0_rd]];
                            end
                            else begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s3_tag[alloc_int_rs] = n_rat[d0_rd];
                            end
                        end
                        default: begin
                            if (n_prf_ready[n_rat[d0_rs]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d0_rs]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d0_rs];
                            end
                            if (n_prf_ready[n_rat[d0_rt]]) begin
                                n_int_rs_s2_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s2_value[alloc_int_rs] = n_prf_value[n_rat[d0_rt]];
                            end
                            else begin
                                n_int_rs_s2_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s2_tag[alloc_int_rs] = n_rat[d0_rt];
                            end
                        end
                    endcase
                end

                if (slot0_needs_fp_rs) begin
                    n_fp_rs_valid[alloc_fp_rs] = 1'b1;
                    n_fp_rs_opcode[alloc_fp_rs] = d0_opcode;
                    n_fp_rs_fpu_op[alloc_fp_rs] = d0_fpu_op;
                    n_fp_rs_rob_idx[alloc_fp_rs] = alloc_rob;
                    n_fp_rs_has_dest[alloc_fp_rs] = slot0_has_dest;
                    n_fp_rs_dest_phys[alloc_fp_rs] = alloc_phys;
                    if (n_prf_ready[n_rat[d0_rs]]) begin
                        n_fp_rs_s1_ready[alloc_fp_rs] = 1'b1;
                        n_fp_rs_s1_value[alloc_fp_rs] = n_prf_value[n_rat[d0_rs]];
                        n_fp_rs_s1_tag[alloc_fp_rs] = 6'd0;
                    end
                    else begin
                        n_fp_rs_s1_ready[alloc_fp_rs] = 1'b0;
                        n_fp_rs_s1_value[alloc_fp_rs] = 64'd0;
                        n_fp_rs_s1_tag[alloc_fp_rs] = n_rat[d0_rs];
                    end
                    if (n_prf_ready[n_rat[d0_rt]]) begin
                        n_fp_rs_s2_ready[alloc_fp_rs] = 1'b1;
                        n_fp_rs_s2_value[alloc_fp_rs] = n_prf_value[n_rat[d0_rt]];
                        n_fp_rs_s2_tag[alloc_fp_rs] = 6'd0;
                    end
                    else begin
                        n_fp_rs_s2_ready[alloc_fp_rs] = 1'b0;
                        n_fp_rs_s2_value[alloc_fp_rs] = 64'd0;
                        n_fp_rs_s2_tag[alloc_fp_rs] = n_rat[d0_rt];
                    end
                end

                if (slot0_needs_lsq) begin
                    n_lsq_valid[alloc_lsq] = 1'b1;
                    n_lsq_done[alloc_lsq] = 1'b0;
                    n_lsq_opcode[alloc_lsq] = d0_opcode;
                    n_lsq_rob_idx[alloc_lsq] = alloc_rob;
                    n_lsq_has_dest[alloc_lsq] = slot0_is_load;
                    n_lsq_dest_phys[alloc_lsq] = alloc_phys;
                    n_lsq_imm[alloc_lsq] = d0_L;
                    n_lsq_base_ready[alloc_lsq] = 1'b1;
                    n_lsq_base_value[alloc_lsq] = 64'd0;
                    n_lsq_base_tag[alloc_lsq] = 6'd0;
                    n_lsq_data_ready[alloc_lsq] = 1'b1;
                    n_lsq_data_value[alloc_lsq] = 64'd0;
                    n_lsq_data_tag[alloc_lsq] = 6'd0;
                    n_lsq_addr_ready[alloc_lsq] = 1'b0;
                    n_lsq_addr[alloc_lsq] = 64'd0;
                    if (d0_opcode == OP_LOAD) begin
                        if (n_prf_ready[n_rat[d0_rs]]) begin
                            n_lsq_base_ready[alloc_lsq] = 1'b1;
                            n_lsq_base_value[alloc_lsq] = n_prf_value[n_rat[d0_rs]];
                            n_lsq_addr_ready[alloc_lsq] = 1'b1;
                            n_lsq_addr[alloc_lsq] = n_prf_value[n_rat[d0_rs]] + zext12(d0_L);
                        end
                        else begin
                            n_lsq_base_ready[alloc_lsq] = 1'b0;
                            n_lsq_base_tag[alloc_lsq] = n_rat[d0_rs];
                        end
                    end
                    else if (d0_opcode == OP_STORE) begin
                        if (n_prf_ready[n_rat[d0_rd]]) begin
                            n_lsq_base_ready[alloc_lsq] = 1'b1;
                            n_lsq_base_value[alloc_lsq] = n_prf_value[n_rat[d0_rd]];
                            n_lsq_addr_ready[alloc_lsq] = 1'b1;
                            n_lsq_addr[alloc_lsq] = n_prf_value[n_rat[d0_rd]] + zext12(d0_L);
                        end
                        else begin
                            n_lsq_base_ready[alloc_lsq] = 1'b0;
                            n_lsq_base_tag[alloc_lsq] = n_rat[d0_rd];
                        end
                        if (n_prf_ready[n_rat[d0_rs]]) begin
                            n_lsq_data_ready[alloc_lsq] = 1'b1;
                            n_lsq_data_value[alloc_lsq] = n_prf_value[n_rat[d0_rs]];
                        end
                        else begin
                            n_lsq_data_ready[alloc_lsq] = 1'b0;
                            n_lsq_data_tag[alloc_lsq] = n_rat[d0_rs];
                        end
                    end
                    else if (d0_opcode == OP_CALL) begin
                        if (n_prf_ready[n_rat[5'd31]]) begin
                            n_lsq_base_ready[alloc_lsq] = 1'b1;
                            n_lsq_base_value[alloc_lsq] = n_prf_value[n_rat[5'd31]];
                            n_lsq_addr_ready[alloc_lsq] = 1'b1;
                            n_lsq_addr[alloc_lsq] = n_prf_value[n_rat[5'd31]] - 64'd8;
                        end
                        else begin
                            n_lsq_base_ready[alloc_lsq] = 1'b0;
                            n_lsq_base_tag[alloc_lsq] = n_rat[5'd31];
                        end
                        n_lsq_data_ready[alloc_lsq] = 1'b1;
                        n_lsq_data_value[alloc_lsq] = n_fq_pc[0] + 64'd4;
                    end
                    else if (d0_opcode == OP_RET) begin
                        n_lsq_has_dest[alloc_lsq] = 1'b0;
                        n_lsq_dest_phys[alloc_lsq] = 6'd0;
                        if (n_prf_ready[n_rat[5'd31]]) begin
                            n_lsq_base_ready[alloc_lsq] = 1'b1;
                            n_lsq_base_value[alloc_lsq] = n_prf_value[n_rat[5'd31]];
                            n_lsq_addr_ready[alloc_lsq] = 1'b1;
                            n_lsq_addr[alloc_lsq] = n_prf_value[n_rat[5'd31]] - 64'd8;
                        end
                        else begin
                            n_lsq_base_ready[alloc_lsq] = 1'b0;
                            n_lsq_base_tag[alloc_lsq] = n_rat[5'd31];
                        end
                    end
                end

                if (slot0_has_dest) begin
                    n_phys_free[alloc_phys] = 1'b0;
                    n_prf_ready[alloc_phys] = 1'b0;
                    n_prf_value[alloc_phys] = 64'd0;
                    n_rat[d0_rd] = alloc_phys;
                end

                n_rob_tail = rob_inc(n_rob_tail);
                n_rob_count = n_rob_count + 5'd1;
                disp_count = 3'd1;
            end

            slot1_valid_local = (slot0_can_dispatch && n_fq_valid[1]);
            slot1_is_load = (d1_opcode == OP_LOAD);
            slot1_is_store = (d1_opcode == OP_STORE);
            slot1_is_halt = (d1_opcode == OP_HALT) && (d1_L == 12'h000);
            slot1_is_nop = !(d1_use_alu || d1_use_fpu || d1_br_abs || d1_br_rel_reg || d1_br_rel_lit || d1_br_nz || d1_br_gt || d1_call_inst || d1_return_inst || slot1_is_load || slot1_is_store || slot1_is_halt);
            slot1_needs_int_rs = d1_use_alu || d1_br_abs || d1_br_rel_reg || d1_br_rel_lit || d1_br_nz || d1_br_gt || d1_call_inst;
            slot1_needs_fp_rs = d1_use_fpu;
            slot1_needs_lsq = slot1_is_load || slot1_is_store || d1_call_inst || d1_return_inst;
            slot1_has_dest = d1_reg_write;
            slot1_can_dispatch = 1'b0;

            alloc_phys = 6'd0;
            alloc_int_rs = 3'd0;
            alloc_fp_rs = 3'd0;
            alloc_lsq = 4'd0;
            if (slot1_valid_local && (n_rob_count < ROB_SIZE)) begin
                slot1_can_dispatch = 1'b1;
                if (slot1_has_dest) begin
                    slot_found = 1'b0;
                    for (i = 0; i < PHYS_SIZE; i = i + 1) begin
                        if (!slot_found && n_phys_free[i]) begin
                            alloc_phys = i[5:0];
                            slot_found = 1'b1;
                        end
                    end
                    if (!slot_found)
                        slot1_can_dispatch = 1'b0;
                end
                if (slot1_needs_int_rs) begin
                    slot_found = 1'b0;
                    for (i = 0; i < INT_RS_SIZE; i = i + 1) begin
                        if (!slot_found && !n_int_rs_valid[i]) begin
                            alloc_int_rs = i[2:0];
                            slot_found = 1'b1;
                        end
                    end
                    if (!slot_found)
                        slot1_can_dispatch = 1'b0;
                end
                if (slot1_needs_fp_rs) begin
                    slot_found = 1'b0;
                    for (i = 0; i < FP_RS_SIZE; i = i + 1) begin
                        if (!slot_found && !n_fp_rs_valid[i]) begin
                            alloc_fp_rs = i[2:0];
                            slot_found = 1'b1;
                        end
                    end
                    if (!slot_found)
                        slot1_can_dispatch = 1'b0;
                end
                if (slot1_needs_lsq) begin
                    slot_found = 1'b0;
                    for (i = 0; i < LSQ_SIZE; i = i + 1) begin
                        if (!slot_found && !n_lsq_valid[i]) begin
                            alloc_lsq = i[3:0];
                            slot_found = 1'b1;
                        end
                    end
                    if (!slot_found)
                        slot1_can_dispatch = 1'b0;
                end
            end

            if (slot1_can_dispatch) begin
                alloc_rob = n_rob_tail;
                old_phys = 6'd0;
                if (slot1_has_dest)
                    old_phys = n_rat[d1_rd];

                n_rob_valid[alloc_rob] = 1'b1;
                if (slot1_is_store || slot1_is_nop || slot1_is_halt)
                    n_rob_done[alloc_rob] = 1'b1;
                else
                    n_rob_done[alloc_rob] = 1'b0;
                n_rob_halt[alloc_rob] = slot1_is_halt;
                n_rob_has_dest[alloc_rob] = slot1_has_dest;
                n_rob_has_lsq[alloc_rob] = slot1_needs_lsq;
                n_rob_opcode[alloc_rob] = d1_opcode;
                n_rob_arch_dst[alloc_rob] = d1_rd;
                n_rob_new_phys[alloc_rob] = alloc_phys;
                n_rob_old_phys[alloc_rob] = old_phys;
                n_rob_lsq_idx[alloc_rob] = alloc_lsq;
                n_rob_pc[alloc_rob] = n_fq_pc[1];
                n_rob_pred_taken[alloc_rob] = n_fq_pred_taken[1];
                n_rob_pred_target[alloc_rob] = n_fq_pred_target[1];
                n_rob_branch_taken[alloc_rob] = 1'b0;
                n_rob_branch_target[alloc_rob] = 64'd0;
                if (is_ctrl_opcode(d1_opcode)) begin
                    for (i = 0; i < ARCH_REGS; i = i + 1) begin
                        n_rob_chk_rat[alloc_rob][i] = n_rat[i];
                    end
                end

                if (slot1_needs_int_rs) begin
                    n_int_rs_valid[alloc_int_rs] = 1'b1;
                    n_int_rs_opcode[alloc_int_rs] = d1_opcode;
                    n_int_rs_alu_op[alloc_int_rs] = d1_alu_op;
                    n_int_rs_imm[alloc_int_rs] = d1_L;
                    n_int_rs_pc[alloc_int_rs] = n_fq_pc[1];
                    n_int_rs_rob_idx[alloc_int_rs] = alloc_rob;
                    n_int_rs_has_dest[alloc_int_rs] = d1_use_alu && slot1_has_dest;
                    n_int_rs_dest_phys[alloc_int_rs] = alloc_phys;
                    n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                    n_int_rs_s1_value[alloc_int_rs] = 64'd0;
                    n_int_rs_s1_tag[alloc_int_rs] = 6'd0;
                    n_int_rs_s2_ready[alloc_int_rs] = 1'b1;
                    n_int_rs_s2_value[alloc_int_rs] = 64'd0;
                    n_int_rs_s2_tag[alloc_int_rs] = 6'd0;
                    n_int_rs_s3_ready[alloc_int_rs] = 1'b1;
                    n_int_rs_s3_value[alloc_int_rs] = 64'd0;
                    n_int_rs_s3_tag[alloc_int_rs] = 6'd0;
                    case (d1_opcode)
                        OP_NOT, OP_MOV_RR: begin
                            if (n_prf_ready[n_rat[d1_rs]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d1_rs]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d1_rs];
                            end
                        end
                        OP_SHRI, OP_SHLI, OP_MOVI, OP_ADDI, OP_SUBI: begin
                            if (n_prf_ready[n_rat[d1_rd]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d1_rd]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d1_rd];
                            end
                            n_int_rs_s2_ready[alloc_int_rs] = 1'b1;
                            n_int_rs_s2_value[alloc_int_rs] = zext12(d1_L);
                        end
                        OP_BR_ABS, OP_BR_RREG, OP_CALL: begin
                            if (n_prf_ready[n_rat[d1_rd]]) begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s3_value[alloc_int_rs] = n_prf_value[n_rat[d1_rd]];
                            end
                            else begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s3_tag[alloc_int_rs] = n_rat[d1_rd];
                            end
                        end
                        OP_BR_RLIT: begin
                        end
                        OP_BR_NZ: begin
                            if (n_prf_ready[n_rat[d1_rs]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d1_rs]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d1_rs];
                            end
                            if (n_prf_ready[n_rat[d1_rd]]) begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s3_value[alloc_int_rs] = n_prf_value[n_rat[d1_rd]];
                            end
                            else begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s3_tag[alloc_int_rs] = n_rat[d1_rd];
                            end
                        end
                        OP_BR_GT: begin
                            if (n_prf_ready[n_rat[d1_rs]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d1_rs]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d1_rs];
                            end
                            if (n_prf_ready[n_rat[d1_rt]]) begin
                                n_int_rs_s2_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s2_value[alloc_int_rs] = n_prf_value[n_rat[d1_rt]];
                            end
                            else begin
                                n_int_rs_s2_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s2_tag[alloc_int_rs] = n_rat[d1_rt];
                            end
                            if (n_prf_ready[n_rat[d1_rd]]) begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s3_value[alloc_int_rs] = n_prf_value[n_rat[d1_rd]];
                            end
                            else begin
                                n_int_rs_s3_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s3_tag[alloc_int_rs] = n_rat[d1_rd];
                            end
                        end
                        default: begin
                            if (n_prf_ready[n_rat[d1_rs]]) begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s1_value[alloc_int_rs] = n_prf_value[n_rat[d1_rs]];
                            end
                            else begin
                                n_int_rs_s1_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s1_tag[alloc_int_rs] = n_rat[d1_rs];
                            end
                            if (n_prf_ready[n_rat[d1_rt]]) begin
                                n_int_rs_s2_ready[alloc_int_rs] = 1'b1;
                                n_int_rs_s2_value[alloc_int_rs] = n_prf_value[n_rat[d1_rt]];
                            end
                            else begin
                                n_int_rs_s2_ready[alloc_int_rs] = 1'b0;
                                n_int_rs_s2_tag[alloc_int_rs] = n_rat[d1_rt];
                            end
                        end
                    endcase
                end

                if (slot1_needs_fp_rs) begin
                    n_fp_rs_valid[alloc_fp_rs] = 1'b1;
                    n_fp_rs_opcode[alloc_fp_rs] = d1_opcode;
                    n_fp_rs_fpu_op[alloc_fp_rs] = d1_fpu_op;
                    n_fp_rs_rob_idx[alloc_fp_rs] = alloc_rob;
                    n_fp_rs_has_dest[alloc_fp_rs] = slot1_has_dest;
                    n_fp_rs_dest_phys[alloc_fp_rs] = alloc_phys;
                    if (n_prf_ready[n_rat[d1_rs]]) begin
                        n_fp_rs_s1_ready[alloc_fp_rs] = 1'b1;
                        n_fp_rs_s1_value[alloc_fp_rs] = n_prf_value[n_rat[d1_rs]];
                        n_fp_rs_s1_tag[alloc_fp_rs] = 6'd0;
                    end
                    else begin
                        n_fp_rs_s1_ready[alloc_fp_rs] = 1'b0;
                        n_fp_rs_s1_value[alloc_fp_rs] = 64'd0;
                        n_fp_rs_s1_tag[alloc_fp_rs] = n_rat[d1_rs];
                    end
                    if (n_prf_ready[n_rat[d1_rt]]) begin
                        n_fp_rs_s2_ready[alloc_fp_rs] = 1'b1;
                        n_fp_rs_s2_value[alloc_fp_rs] = n_prf_value[n_rat[d1_rt]];
                        n_fp_rs_s2_tag[alloc_fp_rs] = 6'd0;
                    end
                    else begin
                        n_fp_rs_s2_ready[alloc_fp_rs] = 1'b0;
                        n_fp_rs_s2_value[alloc_fp_rs] = 64'd0;
                        n_fp_rs_s2_tag[alloc_fp_rs] = n_rat[d1_rt];
                    end
                end

                if (slot1_needs_lsq) begin
                    n_lsq_valid[alloc_lsq] = 1'b1;
                    n_lsq_done[alloc_lsq] = 1'b0;
                    n_lsq_opcode[alloc_lsq] = d1_opcode;
                    n_lsq_rob_idx[alloc_lsq] = alloc_rob;
                    n_lsq_has_dest[alloc_lsq] = slot1_is_load;
                    n_lsq_dest_phys[alloc_lsq] = alloc_phys;
                    n_lsq_imm[alloc_lsq] = d1_L;
                    n_lsq_base_ready[alloc_lsq] = 1'b1;
                    n_lsq_base_value[alloc_lsq] = 64'd0;
                    n_lsq_base_tag[alloc_lsq] = 6'd0;
                    n_lsq_data_ready[alloc_lsq] = 1'b1;
                    n_lsq_data_value[alloc_lsq] = 64'd0;
                    n_lsq_data_tag[alloc_lsq] = 6'd0;
                    n_lsq_addr_ready[alloc_lsq] = 1'b0;
                    n_lsq_addr[alloc_lsq] = 64'd0;
                    if (d1_opcode == OP_LOAD) begin
                        if (n_prf_ready[n_rat[d1_rs]]) begin
                            n_lsq_base_ready[alloc_lsq] = 1'b1;
                            n_lsq_base_value[alloc_lsq] = n_prf_value[n_rat[d1_rs]];
                            n_lsq_addr_ready[alloc_lsq] = 1'b1;
                            n_lsq_addr[alloc_lsq] = n_prf_value[n_rat[d1_rs]] + zext12(d1_L);
                        end
                        else begin
                            n_lsq_base_ready[alloc_lsq] = 1'b0;
                            n_lsq_base_tag[alloc_lsq] = n_rat[d1_rs];
                        end
                    end
                    else if (d1_opcode == OP_STORE) begin
                        if (n_prf_ready[n_rat[d1_rd]]) begin
                            n_lsq_base_ready[alloc_lsq] = 1'b1;
                            n_lsq_base_value[alloc_lsq] = n_prf_value[n_rat[d1_rd]];
                            n_lsq_addr_ready[alloc_lsq] = 1'b1;
                            n_lsq_addr[alloc_lsq] = n_prf_value[n_rat[d1_rd]] + zext12(d1_L);
                        end
                        else begin
                            n_lsq_base_ready[alloc_lsq] = 1'b0;
                            n_lsq_base_tag[alloc_lsq] = n_rat[d1_rd];
                        end
                        if (n_prf_ready[n_rat[d1_rs]]) begin
                            n_lsq_data_ready[alloc_lsq] = 1'b1;
                            n_lsq_data_value[alloc_lsq] = n_prf_value[n_rat[d1_rs]];
                        end
                        else begin
                            n_lsq_data_ready[alloc_lsq] = 1'b0;
                            n_lsq_data_tag[alloc_lsq] = n_rat[d1_rs];
                        end
                    end
                    else if (d1_opcode == OP_CALL) begin
                        if (n_prf_ready[n_rat[5'd31]]) begin
                            n_lsq_base_ready[alloc_lsq] = 1'b1;
                            n_lsq_base_value[alloc_lsq] = n_prf_value[n_rat[5'd31]];
                            n_lsq_addr_ready[alloc_lsq] = 1'b1;
                            n_lsq_addr[alloc_lsq] = n_prf_value[n_rat[5'd31]] - 64'd8;
                        end
                        else begin
                            n_lsq_base_ready[alloc_lsq] = 1'b0;
                            n_lsq_base_tag[alloc_lsq] = n_rat[5'd31];
                        end
                        n_lsq_data_ready[alloc_lsq] = 1'b1;
                        n_lsq_data_value[alloc_lsq] = n_fq_pc[1] + 64'd4;
                    end
                    else if (d1_opcode == OP_RET) begin
                        n_lsq_has_dest[alloc_lsq] = 1'b0;
                        n_lsq_dest_phys[alloc_lsq] = 6'd0;
                        if (n_prf_ready[n_rat[5'd31]]) begin
                            n_lsq_base_ready[alloc_lsq] = 1'b1;
                            n_lsq_base_value[alloc_lsq] = n_prf_value[n_rat[5'd31]];
                            n_lsq_addr_ready[alloc_lsq] = 1'b1;
                            n_lsq_addr[alloc_lsq] = n_prf_value[n_rat[5'd31]] - 64'd8;
                        end
                        else begin
                            n_lsq_base_ready[alloc_lsq] = 1'b0;
                            n_lsq_base_tag[alloc_lsq] = n_rat[5'd31];
                        end
                    end
                end

                if (slot1_has_dest) begin
                    n_phys_free[alloc_phys] = 1'b0;
                    n_prf_ready[alloc_phys] = 1'b0;
                    n_prf_value[alloc_phys] = 64'd0;
                    n_rat[d1_rd] = alloc_phys;
                end

                n_rob_tail = rob_inc(n_rob_tail);
                n_rob_count = n_rob_count + 5'd1;
                disp_count = 3'd2;
            end

            // compact the fetch queue after dispatch
            if (disp_count != 0) begin
                for (i = 0; i < FQ_SIZE; i = i + 1) begin
                    if ((i + disp_count) < FQ_SIZE) begin
                        n_fq_valid[i] = n_fq_valid[i + disp_count];
                        n_fq_inst[i] = n_fq_inst[i + disp_count];
                        n_fq_pc[i] = n_fq_pc[i + disp_count];
                        n_fq_pred_taken[i] = n_fq_pred_taken[i + disp_count];
                        n_fq_pred_target[i] = n_fq_pred_target[i + disp_count];
                    end
                    else begin
                        n_fq_valid[i] = 1'b0;
                        n_fq_inst[i] = 32'd0;
                        n_fq_pc[i] = 64'd0;
                        n_fq_pred_taken[i] = 1'b0;
                        n_fq_pred_target[i] = 64'd0;
                    end
                end
            end

            // ------------------------------------------------------------
            // 6) front-end fill: fetch 1 or 2 instructions when queue space exists
            // ------------------------------------------------------------
            free_slot_count = 3'd0;
            for (i = 0; i < FQ_SIZE; i = i + 1) begin
                if (!n_fq_valid[i])
                    free_slot_count = free_slot_count + 3'd1;
            end

            if (free_slot_count != 0) begin
                fetch0_opcode = memory_instruction[31:27];
                fetch0_L = memory_instruction[11:0];
                fetch0_pred_taken = 1'b0;
                fetch0_pred_target = fetch_pc + 64'd4;
                case (fetch0_opcode)
                    OP_BR_RLIT: begin
                        fetch0_pred_taken = 1'b1;
                        fetch0_pred_target = fetch_pc + sext12(fetch0_L);
                    end
                    OP_BR_ABS, OP_BR_RREG, OP_CALL, OP_RET: begin
                        if (btb_valid[btb_index(fetch_pc)] && (btb_tag[btb_index(fetch_pc)] == fetch_pc)) begin
                            fetch0_pred_taken = 1'b1;
                            fetch0_pred_target = btb_target[btb_index(fetch_pc)];
                        end
                    end
                    OP_BR_NZ, OP_BR_GT: begin
                        if (btb_valid[btb_index(fetch_pc)] && (btb_tag[btb_index(fetch_pc)] == fetch_pc) && bht[btb_index(fetch_pc)][1]) begin
                            fetch0_pred_taken = 1'b1;
                            fetch0_pred_target = btb_target[btb_index(fetch_pc)];
                        end
                    end
                    default: begin
                    end
                endcase

                slot_found = 1'b0;
                for (i = 0; i < FQ_SIZE; i = i + 1) begin
                    if (!slot_found && !n_fq_valid[i]) begin
                        n_fq_valid[i] = 1'b1;
                        n_fq_inst[i] = memory_instruction;
                        n_fq_pc[i] = fetch_pc;
                        n_fq_pred_taken[i] = fetch0_pred_taken;
                        n_fq_pred_target[i] = fetch0_pred_target;
                        slot_found = 1'b1;
                    end
                end

                if (fetch0_pred_taken)
                    n_fetch_pc = fetch0_pred_target;
                else
                    n_fetch_pc = fetch_pc + 64'd4;

                if (!fetch0_pred_taken && (free_slot_count > 1) && !mem_write_en && !(ld_issue_valid && !ld_issue_forward)) begin
                    fetch1_opcode = memory_data_read[31:27];
                    fetch1_L = memory_data_read[11:0];
                    fetch1_pred_taken = 1'b0;
                    fetch1_pred_target = fetch_pc + 64'd8;
                    case (fetch1_opcode)
                        OP_BR_RLIT: begin
                            fetch1_pred_taken = 1'b1;
                            fetch1_pred_target = (fetch_pc + 64'd4) + sext12(fetch1_L);
                        end
                        OP_BR_ABS, OP_BR_RREG, OP_CALL, OP_RET: begin
                            if (btb_valid[btb_index(fetch_pc + 64'd4)] && (btb_tag[btb_index(fetch_pc + 64'd4)] == (fetch_pc + 64'd4))) begin
                                fetch1_pred_taken = 1'b1;
                                fetch1_pred_target = btb_target[btb_index(fetch_pc + 64'd4)];
                            end
                        end
                        OP_BR_NZ, OP_BR_GT: begin
                            if (btb_valid[btb_index(fetch_pc + 64'd4)] && (btb_tag[btb_index(fetch_pc + 64'd4)] == (fetch_pc + 64'd4)) && bht[btb_index(fetch_pc + 64'd4)][1]) begin
                                fetch1_pred_taken = 1'b1;
                                fetch1_pred_target = btb_target[btb_index(fetch_pc + 64'd4)];
                            end
                        end
                        default: begin
                        end
                    endcase
                    slot_found = 1'b0;
                    for (i = 0; i < FQ_SIZE; i = i + 1) begin
                        if (!slot_found && !n_fq_valid[i]) begin
                            n_fq_valid[i] = 1'b1;
                            n_fq_inst[i] = memory_data_read[31:0];
                            n_fq_pc[i] = fetch_pc + 64'd4;
                            n_fq_pred_taken[i] = fetch1_pred_taken;
                            n_fq_pred_target[i] = fetch1_pred_target;
                            slot_found = 1'b1;
                        end
                    end
                    if (fetch1_pred_taken)
                        n_fetch_pc = fetch1_pred_target;
                    else
                        n_fetch_pc = fetch_pc + 64'd8;
                end
            end
        end
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        hlt <= 1'b0;
        fetch_pc <= 64'h2000;
        rob_head <= 4'd0;
        rob_tail <= 4'd0;
        rob_count <= 5'd0;

        alu0_valid <= 1'b0;
        alu0_opcode <= 5'd0;
        alu0_alu_op <= 5'd0;
        alu0_imm <= 12'd0;
        alu0_pc <= 64'd0;
        alu0_rob_idx <= 4'd0;
        alu0_has_dest <= 1'b0;
        alu0_dest_phys <= 6'd0;
        alu0_s1 <= 64'd0;
        alu0_s2 <= 64'd0;
        alu0_s3 <= 64'd0;

        alu1_valid <= 1'b0;
        alu1_opcode <= 5'd0;
        alu1_alu_op <= 5'd0;
        alu1_imm <= 12'd0;
        alu1_pc <= 64'd0;
        alu1_rob_idx <= 4'd0;
        alu1_has_dest <= 1'b0;
        alu1_dest_phys <= 6'd0;
        alu1_s1 <= 64'd0;
        alu1_s2 <= 64'd0;
        alu1_s3 <= 64'd0;

        fpu0_valid <= 1'b0;
        fpu0_opcode <= 5'd0;
        fpu0_fpu_op <= 5'd0;
        fpu0_rob_idx <= 4'd0;
        fpu0_has_dest <= 1'b0;
        fpu0_dest_phys <= 6'd0;
        fpu0_s1 <= 64'd0;
        fpu0_s2 <= 64'd0;

        fpu1_valid <= 1'b0;
        fpu1_opcode <= 5'd0;
        fpu1_fpu_op <= 5'd0;
        fpu1_rob_idx <= 4'd0;
        fpu1_has_dest <= 1'b0;
        fpu1_dest_phys <= 6'd0;
        fpu1_s1 <= 64'd0;
        fpu1_s2 <= 64'd0;

        ld_valid <= 1'b0;
        ld_opcode <= 5'd0;
        ld_rob_idx <= 4'd0;
        ld_has_dest <= 1'b0;
        ld_dest_phys <= 6'd0;
        ld_lsq_idx <= 4'd0;
        ld_value <= 64'd0;

        for (i = 0; i < FQ_SIZE; i = i + 1) begin
            fq_valid[i] <= 1'b0;
            fq_inst[i] <= 32'd0;
            fq_pc[i] <= 64'd0;
            fq_pred_taken[i] <= 1'b0;
            fq_pred_target[i] <= 64'd0;
        end

        for (i = 0; i < BTB_SIZE; i = i + 1) begin
            btb_valid[i] <= 1'b0;
            btb_tag[i] <= 64'd0;
            btb_target[i] <= 64'd0;
            bht[i] <= 2'b01;
        end

        for (i = 0; i < ARCH_REGS; i = i + 1) begin
            rat[i] <= i[5:0];
        end

        for (i = 0; i < PHYS_SIZE; i = i + 1) begin
            prf_value[i] <= 64'd0;
            if (i < ARCH_REGS)
                prf_ready[i] <= 1'b1;
            else
                prf_ready[i] <= 1'b0;
            if (i < ARCH_REGS)
                phys_free[i] <= 1'b0;
            else
                phys_free[i] <= 1'b1;
        end
        prf_value[31] <= MEM_SIZE;

        for (i = 0; i < ROB_SIZE; i = i + 1) begin
            rob_valid[i] <= 1'b0;
            rob_done[i] <= 1'b0;
            rob_halt[i] <= 1'b0;
            rob_has_dest[i] <= 1'b0;
            rob_has_lsq[i] <= 1'b0;
            rob_opcode[i] <= 5'd0;
            rob_arch_dst[i] <= 5'd0;
            rob_new_phys[i] <= 6'd0;
            rob_old_phys[i] <= 6'd0;
            rob_lsq_idx[i] <= 4'd0;
            rob_pc[i] <= 64'd0;
            rob_pred_taken[i] <= 1'b0;
            rob_pred_target[i] <= 64'd0;
            rob_branch_taken[i] <= 1'b0;
            rob_branch_target[i] <= 64'd0;
            for (j = 0; j < ARCH_REGS; j = j + 1) begin
                rob_chk_rat[i][j] <= 6'd0;
            end
        end

        for (i = 0; i < INT_RS_SIZE; i = i + 1) begin
            int_rs_valid[i] <= 1'b0;
            int_rs_opcode[i] <= 5'd0;
            int_rs_alu_op[i] <= 5'd0;
            int_rs_imm[i] <= 12'd0;
            int_rs_pc[i] <= 64'd0;
            int_rs_rob_idx[i] <= 4'd0;
            int_rs_has_dest[i] <= 1'b0;
            int_rs_dest_phys[i] <= 6'd0;
            int_rs_s1_ready[i] <= 1'b0;
            int_rs_s1_value[i] <= 64'd0;
            int_rs_s1_tag[i] <= 6'd0;
            int_rs_s2_ready[i] <= 1'b0;
            int_rs_s2_value[i] <= 64'd0;
            int_rs_s2_tag[i] <= 6'd0;
            int_rs_s3_ready[i] <= 1'b0;
            int_rs_s3_value[i] <= 64'd0;
            int_rs_s3_tag[i] <= 6'd0;
        end

        for (i = 0; i < FP_RS_SIZE; i = i + 1) begin
            fp_rs_valid[i] <= 1'b0;
            fp_rs_opcode[i] <= 5'd0;
            fp_rs_fpu_op[i] <= 5'd0;
            fp_rs_rob_idx[i] <= 4'd0;
            fp_rs_has_dest[i] <= 1'b0;
            fp_rs_dest_phys[i] <= 6'd0;
            fp_rs_s1_ready[i] <= 1'b0;
            fp_rs_s1_value[i] <= 64'd0;
            fp_rs_s1_tag[i] <= 6'd0;
            fp_rs_s2_ready[i] <= 1'b0;
            fp_rs_s2_value[i] <= 64'd0;
            fp_rs_s2_tag[i] <= 6'd0;
        end

        for (i = 0; i < LSQ_SIZE; i = i + 1) begin
            lsq_valid[i] <= 1'b0;
            lsq_done[i] <= 1'b0;
            lsq_opcode[i] <= 5'd0;
            lsq_rob_idx[i] <= 4'd0;
            lsq_has_dest[i] <= 1'b0;
            lsq_dest_phys[i] <= 6'd0;
            lsq_imm[i] <= 12'd0;
            lsq_base_ready[i] <= 1'b0;
            lsq_base_value[i] <= 64'd0;
            lsq_base_tag[i] <= 6'd0;
            lsq_data_ready[i] <= 1'b0;
            lsq_data_value[i] <= 64'd0;
            lsq_data_tag[i] <= 6'd0;
            lsq_addr_ready[i] <= 1'b0;
            lsq_addr[i] <= 64'd0;
        end
    end
    else if (!hlt) begin
        hlt <= n_hlt;
        fetch_pc <= n_fetch_pc;
        rob_head <= n_rob_head;
        rob_tail <= n_rob_tail;
        rob_count <= n_rob_count;

        alu0_valid <= n_alu0_valid;
        alu0_opcode <= n_alu0_opcode;
        alu0_alu_op <= n_alu0_alu_op;
        alu0_imm <= n_alu0_imm;
        alu0_pc <= n_alu0_pc;
        alu0_rob_idx <= n_alu0_rob_idx;
        alu0_has_dest <= n_alu0_has_dest;
        alu0_dest_phys <= n_alu0_dest_phys;
        alu0_s1 <= n_alu0_s1;
        alu0_s2 <= n_alu0_s2;
        alu0_s3 <= n_alu0_s3;

        alu1_valid <= n_alu1_valid;
        alu1_opcode <= n_alu1_opcode;
        alu1_alu_op <= n_alu1_alu_op;
        alu1_imm <= n_alu1_imm;
        alu1_pc <= n_alu1_pc;
        alu1_rob_idx <= n_alu1_rob_idx;
        alu1_has_dest <= n_alu1_has_dest;
        alu1_dest_phys <= n_alu1_dest_phys;
        alu1_s1 <= n_alu1_s1;
        alu1_s2 <= n_alu1_s2;
        alu1_s3 <= n_alu1_s3;

        fpu0_valid <= n_fpu0_valid;
        fpu0_opcode <= n_fpu0_opcode;
        fpu0_fpu_op <= n_fpu0_fpu_op;
        fpu0_rob_idx <= n_fpu0_rob_idx;
        fpu0_has_dest <= n_fpu0_has_dest;
        fpu0_dest_phys <= n_fpu0_dest_phys;
        fpu0_s1 <= n_fpu0_s1;
        fpu0_s2 <= n_fpu0_s2;

        fpu1_valid <= n_fpu1_valid;
        fpu1_opcode <= n_fpu1_opcode;
        fpu1_fpu_op <= n_fpu1_fpu_op;
        fpu1_rob_idx <= n_fpu1_rob_idx;
        fpu1_has_dest <= n_fpu1_has_dest;
        fpu1_dest_phys <= n_fpu1_dest_phys;
        fpu1_s1 <= n_fpu1_s1;
        fpu1_s2 <= n_fpu1_s2;

        ld_valid <= n_ld_valid;
        ld_opcode <= n_ld_opcode;
        ld_rob_idx <= n_ld_rob_idx;
        ld_has_dest <= n_ld_has_dest;
        ld_dest_phys <= n_ld_dest_phys;
        ld_lsq_idx <= n_ld_lsq_idx;
        ld_value <= n_ld_value;

        for (i = 0; i < FQ_SIZE; i = i + 1) begin
            fq_valid[i] <= n_fq_valid[i];
            fq_inst[i] <= n_fq_inst[i];
            fq_pc[i] <= n_fq_pc[i];
            fq_pred_taken[i] <= n_fq_pred_taken[i];
            fq_pred_target[i] <= n_fq_pred_target[i];
        end

        for (i = 0; i < BTB_SIZE; i = i + 1) begin
            btb_valid[i] <= n_btb_valid[i];
            btb_tag[i] <= n_btb_tag[i];
            btb_target[i] <= n_btb_target[i];
            bht[i] <= n_bht[i];
        end

        for (i = 0; i < ARCH_REGS; i = i + 1) begin
            rat[i] <= n_rat[i];
        end

        for (i = 0; i < PHYS_SIZE; i = i + 1) begin
            prf_value[i] <= n_prf_value[i];
            prf_ready[i] <= n_prf_ready[i];
            phys_free[i] <= n_phys_free[i];
        end

        for (i = 0; i < ROB_SIZE; i = i + 1) begin
            rob_valid[i] <= n_rob_valid[i];
            rob_done[i] <= n_rob_done[i];
            rob_halt[i] <= n_rob_halt[i];
            rob_has_dest[i] <= n_rob_has_dest[i];
            rob_has_lsq[i] <= n_rob_has_lsq[i];
            rob_opcode[i] <= n_rob_opcode[i];
            rob_arch_dst[i] <= n_rob_arch_dst[i];
            rob_new_phys[i] <= n_rob_new_phys[i];
            rob_old_phys[i] <= n_rob_old_phys[i];
            rob_lsq_idx[i] <= n_rob_lsq_idx[i];
            rob_pc[i] <= n_rob_pc[i];
            rob_pred_taken[i] <= n_rob_pred_taken[i];
            rob_pred_target[i] <= n_rob_pred_target[i];
            rob_branch_taken[i] <= n_rob_branch_taken[i];
            rob_branch_target[i] <= n_rob_branch_target[i];
            for (j = 0; j < ARCH_REGS; j = j + 1) begin
                rob_chk_rat[i][j] <= n_rob_chk_rat[i][j];
            end
        end

        for (i = 0; i < INT_RS_SIZE; i = i + 1) begin
            int_rs_valid[i] <= n_int_rs_valid[i];
            int_rs_opcode[i] <= n_int_rs_opcode[i];
            int_rs_alu_op[i] <= n_int_rs_alu_op[i];
            int_rs_imm[i] <= n_int_rs_imm[i];
            int_rs_pc[i] <= n_int_rs_pc[i];
            int_rs_rob_idx[i] <= n_int_rs_rob_idx[i];
            int_rs_has_dest[i] <= n_int_rs_has_dest[i];
            int_rs_dest_phys[i] <= n_int_rs_dest_phys[i];
            int_rs_s1_ready[i] <= n_int_rs_s1_ready[i];
            int_rs_s1_value[i] <= n_int_rs_s1_value[i];
            int_rs_s1_tag[i] <= n_int_rs_s1_tag[i];
            int_rs_s2_ready[i] <= n_int_rs_s2_ready[i];
            int_rs_s2_value[i] <= n_int_rs_s2_value[i];
            int_rs_s2_tag[i] <= n_int_rs_s2_tag[i];
            int_rs_s3_ready[i] <= n_int_rs_s3_ready[i];
            int_rs_s3_value[i] <= n_int_rs_s3_value[i];
            int_rs_s3_tag[i] <= n_int_rs_s3_tag[i];
        end

        for (i = 0; i < FP_RS_SIZE; i = i + 1) begin
            fp_rs_valid[i] <= n_fp_rs_valid[i];
            fp_rs_opcode[i] <= n_fp_rs_opcode[i];
            fp_rs_fpu_op[i] <= n_fp_rs_fpu_op[i];
            fp_rs_rob_idx[i] <= n_fp_rs_rob_idx[i];
            fp_rs_has_dest[i] <= n_fp_rs_has_dest[i];
            fp_rs_dest_phys[i] <= n_fp_rs_dest_phys[i];
            fp_rs_s1_ready[i] <= n_fp_rs_s1_ready[i];
            fp_rs_s1_value[i] <= n_fp_rs_s1_value[i];
            fp_rs_s1_tag[i] <= n_fp_rs_s1_tag[i];
            fp_rs_s2_ready[i] <= n_fp_rs_s2_ready[i];
            fp_rs_s2_value[i] <= n_fp_rs_s2_value[i];
            fp_rs_s2_tag[i] <= n_fp_rs_s2_tag[i];
        end

        for (i = 0; i < LSQ_SIZE; i = i + 1) begin
            lsq_valid[i] <= n_lsq_valid[i];
            lsq_done[i] <= n_lsq_done[i];
            lsq_opcode[i] <= n_lsq_opcode[i];
            lsq_rob_idx[i] <= n_lsq_rob_idx[i];
            lsq_has_dest[i] <= n_lsq_has_dest[i];
            lsq_dest_phys[i] <= n_lsq_dest_phys[i];
            lsq_imm[i] <= n_lsq_imm[i];
            lsq_base_ready[i] <= n_lsq_base_ready[i];
            lsq_base_value[i] <= n_lsq_base_value[i];
            lsq_base_tag[i] <= n_lsq_base_tag[i];
            lsq_data_ready[i] <= n_lsq_data_ready[i];
            lsq_data_value[i] <= n_lsq_data_value[i];
            lsq_data_tag[i] <= n_lsq_data_tag[i];
            lsq_addr_ready[i] <= n_lsq_addr_ready[i];
            lsq_addr[i] <= n_lsq_addr[i];
        end
    end
end

endmodule
