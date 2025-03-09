
`timescale 1ns/1ps

module i2c_pwm_tb;
    reg clk;
    reg rst;
    reg scl;
    wire sda;
    wire pwm_out;
    
    reg sda_drive;
    reg sda_in;
    assign sda = sda_drive ? sda_in : 1'bz;
    
    // Instantiate the I2C-based PWM module
    i2c_pwm uut (
        .clk(clk),
        .rst(rst),
        .SCL(scl),
        .SDA(sda),
        .pwm_out(pwm_out)
    );
    
    // Clock generation
    always #5 clk = ~clk; // 100MHz clock
    
    // Task to simulate an I2C write transaction
    task i2c_write;
        input [7:0] addr;
        input [7:0] data;
        integer i;
        begin
            // START condition
            sda_drive = 1; sda_in = 0;
            #100 scl = 0;
            
            // Send device address (write mode)
            for (i = 7; i >= 0; i = i - 1) begin
                sda_in = (8'hAA >> i) & 1;
                #50 scl = 1; #50 scl = 0;
            end
            
            // ACK
            #50 sda_drive = 0; #50 scl = 1; #50 scl = 0;
            
            // Send register index
            sda_drive = 1;
            for (i = 7; i >= 0; i = i - 1) begin
                sda_in = (addr >> i) & 1;
                #50 scl = 1; #50 scl = 0;
            end
            
            // ACK
            #50 sda_drive = 0; #50 scl = 1; #50 scl = 0;
            
            // Send data
            sda_drive = 1;
            for (i = 7; i >= 0; i = i - 1) begin
                sda_in = (data >> i) & 1;
                #50 scl = 1; #50 scl = 0;
            end
            
            // ACK
            #50 sda_drive = 0; #50 scl = 1; #50 scl = 0;
            
            // STOP condition
            #50 sda_drive = 1; sda_in = 1;
        end
    endtask
    
    // Test sequence
    initial begin
        clk = 0; rst = 1; scl = 1; sda_drive = 1; sda_in = 1;
        #100 rst = 0; #100 rst = 1;
        
        // Send 50% duty cycle (0x80)
        #200 i2c_write(8'h00, 8'h80);
        
        // Wait and observe PWM output
        #500000;
        
        $stop;
    end
endmodule
