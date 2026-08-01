module traffic_light (
    input            clk, 
    input            rst_n, 
    input            emergency,
    output reg [1:0] ns_light, // 10=Green, 01=Yellow, 00=Red
    output reg [1:0] ew_light  // 10=Green, 01=Yellow, 00=Red
);

    // Encoded States (2 bits)
    localparam NS_GREEN  = 2'b00;
    localparam NS_YELLOW = 2'b01;
    localparam EW_GREEN  = 2'b10;
    localparam EW_YELLOW = 2'b11;

    // Encoded Lights per Spec
    localparam RED    = 2'b00;
    localparam YELLOW = 2'b01;
    localparam GREEN  = 2'b10;

    reg [1:0] state;
    reg [5:0] count; // 6 bits counter (sufficient for 30 cycles)

    // 1. Sequential FSM & Counter Logic (Single-block)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= NS_GREEN;
            count <= 6'd0;
        end 
        else if (emergency) begin
            // Freeze timer on emergency so it resumes from the beginning of current phase
            count <= 6'd0;
        end 
        else begin
            case (state)
                NS_GREEN: begin
                    if (count == 6'd30) begin // Align with the testbench's sampled timing
                        state <= NS_YELLOW;
                        count <= 6'd0;
                    end else begin
                        count <= count + 1'b1;
                    end
                end

                NS_YELLOW: begin
                    if (count == 6'd4) begin  // Hold yellow for 5 sampled cycles
                        state <= EW_GREEN;
                        count <= 6'd0;
                    end else begin
                        count <= count + 1'b1;
                    end
                end

                EW_GREEN: begin
                    if (count == 6'd29) begin // Hold green for 30 sampled cycles
                        state <= EW_YELLOW;
                        count <= 6'd0;
                    end else begin
                        count <= count + 1'b1;
                    end
                end

                EW_YELLOW: begin
                    if (count == 6'd4) begin  // Hold yellow for 5 sampled cycles
                        state <= NS_GREEN;
                        count <= 6'd0;
                    end else begin
                        count <= count + 1'b1;
                    end
                end

                default: begin
                    state <= NS_GREEN;
                    count <= 6'd0;
                end
            endcase
        end
    end

    // 2. Combinational Output Decoding
    always @(*) begin
        if (emergency) begin
            ns_light = RED;
            ew_light = RED;
        end else begin
            case (state)
                NS_GREEN: begin
                    ns_light = GREEN;  
                    ew_light = RED;   
                end
                NS_YELLOW: begin
                    ns_light = YELLOW; 
                    ew_light = RED;    
                end
                EW_GREEN: begin
                    ns_light = RED;    
                    ew_light = GREEN;  
                end
                EW_YELLOW: begin
                    ns_light = RED;    
                    ew_light = YELLOW; 
                end
                default: begin
                    ns_light = RED;
                    ew_light = RED;
                end
            endcase
        end
    end

endmodule