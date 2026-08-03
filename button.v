`timescale 1ns / 1ps

module debouncer #(parameter CLK_FREQ_KHZ = 100) (
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,
    output reg  btn_out,
    output reg  btn_pressed,
    output reg  btn_released
);

    // Tính toán số chu kỳ khử nhiễu (5 ms)
    localparam DEBOUNCE_CYCLES = CLK_FREQ_KHZ * 5;
    localparam COUNTER_WIDTH   = $clog2(DEBOUNCE_CYCLES);
    reg [COUNTER_WIDTH-1:0] count;

    always @(posedge clk) begin
        if (!rst_n) begin
            btn_out      <= 1'b0;
            btn_pressed  <= 1'b0;
            btn_released <= 1'b0;
            count        <= {COUNTER_WIDTH{1'b0}};
        end
        else begin
            btn_pressed  <= 1'b0;
            btn_released <= 1'b0;
            if (btn_in != btn_out) begin
                if (count == DEBOUNCE_CYCLES - 2) begin
                    btn_out <= btn_in;
                    count   <= {COUNTER_WIDTH{1'b0}};

                    // Phát xung 1 chu kỳ
                    if (btn_in && !btn_out) begin
                        btn_pressed <= 1'b1;
                    end
                    if (!btn_in && btn_out) begin
                        btn_released <= 1'b1;
                    end
                end 
                else begin
                    count <= count + 1'b1;
                end
            end 
            else begin
                count <= {COUNTER_WIDTH{1'b0}};
            end
        end
    end

endmodule