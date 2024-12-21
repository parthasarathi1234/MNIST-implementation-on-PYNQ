`timescale 1ns / 1ps

`include "../rtl/include.v"

`define MaxTestSamples 100

module top_sim();
    
    reg reset;
    reg clock;
    reg [`dataWidth-1:0] in;
    reg in_valid;
    reg [`dataWidth-1:0] in_mem [784:0];
    reg [8*24-1:0] fileNameStr;  // Single register for file name
    reg s_axi_awvalid;
    reg [31:0] s_axi_awaddr;
    wire s_axi_awready;
    reg [31:0] s_axi_wdata;
    reg s_axi_wvalid;
    wire s_axi_wready;
    wire s_axi_bvalid;
    reg s_axi_bready;
    wire intr;
    reg [31:0] axiRdData;
    reg [31:0] s_axi_araddr;
    wire [31:0] s_axi_rdata;
    reg s_axi_arvalid;
    wire s_axi_arready;
    wire s_axi_rvalid;
    reg s_axi_rready;
    reg [`dataWidth-1:0] expected;

    wire [31:0] numNeurons[31:1];
    wire [31:0] numWeights[31:1];
    
    assign numNeurons[1] = 30;
    assign numNeurons[2] = 30;
    assign numNeurons[3] = 10;
    assign numNeurons[4] = 10;
    
    assign numWeights[1] = 784;
    assign numWeights[2] = 30;
    assign numWeights[3] = 30;
    assign numWeights[4] = 10;
    
    integer right = 0;
    integer wrong = 0;
    
    zyNet dut(
        .s_axi_aclk(clock),
        .s_axi_aresetn(reset),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(0),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(4'hF),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(0),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .axis_in_data(in),
        .axis_in_data_valid(in_valid),
        .axis_in_data_ready(),
        .intr(intr)
    );
    
    initial
    begin
        clock = 1'b0;
        s_axi_awvalid = 1'b0;
        s_axi_bready = 1'b0;
        s_axi_wvalid = 1'b0;
        s_axi_arvalid = 1'b0;
    end
        
    always
        #5 clock = ~clock;
    
    function [7:0] to_ascii;
        input integer a;
        begin
            to_ascii = a + 48;
        end
    endfunction
    
    always @(posedge clock)
    begin
        s_axi_bready <= s_axi_bvalid;
        s_axi_rready <= s_axi_rvalid;
    end
    
    task writeAxi(input [31:0] address, input [31:0] data);
    begin
        @(posedge clock);
        s_axi_awvalid <= 1'b1;
        s_axi_awaddr <= address;
        s_axi_wdata <= data;
        s_axi_wvalid <= 1'b1;
        wait(s_axi_wready);
        @(posedge clock);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid <= 1'b0;
        @(posedge clock);
    end
    endtask
    
    task readAxi(input [31:0] address);
    begin
        @(posedge clock);
        s_axi_arvalid <= 1'b1;
        s_axi_araddr <= address;
        wait(s_axi_arready);
        @(posedge clock);
        s_axi_arvalid <= 1'b0;
        wait(s_axi_rvalid);
        @(posedge clock);
        axiRdData <= s_axi_rdata;
        @(posedge clock);
    end
    endtask

    // Task to print the filename
    task printFileName;
        integer idx;
        begin
            $display("Reading file: %s", fileNameStr);
        end
    endtask
    
    task configWeights();
    integer i, j, k, t;
    integer neuronNo_int;
    reg [`dataWidth:0] config_mem [783:0];
    begin
        @(posedge clock);
        for (k = 1; k <= `numLayers; k = k + 1) begin
            writeAxi(12, k); // Write layer number
            for (j = 0; j < numNeurons[k]; j = j + 1) begin
                neuronNo_int = j;
                
                // Clear the fileNameStr
                fileNameStr = {8*24{1'b0}};
                
                // Build the filename
                fileNameStr[8*1-1 -: 8] = "f";
                fileNameStr[8*2-1 -: 8] = "i";
                fileNameStr[8*3-1 -: 8] = "m";
                fileNameStr[8*4-1 -: 8] = ".";
                fileNameStr[8*5-1 -: 8] = (j > 9) ? to_ascii(j/10) : "0";
                fileNameStr[8*6-1 -: 8] = to_ascii(j % 10);
                fileNameStr[8*7-1 -: 8] = "_";
                fileNameStr[8*8-1 -: 8] = to_ascii(k);
                fileNameStr[8*9-1 -: 8] = "_";
                fileNameStr[8*10-1 -: 8] = "w";

                // Print the filename before reading
                printFileName();

                // Now read the file
                $readmemb(fileNameStr, config_mem);
                writeAxi(16, j); // Write neuron number
                for (t = 0; t < numWeights[k]; t = t + 1) begin
                    writeAxi(0, {15'd0, config_mem[t]});
                end 
            end
        end
    end
    endtask
    
    task configBias();
    integer i, j, k;
    integer neuronNo_int;
    reg [31:0] bias[0:0];
    begin
        @(posedge clock);
        for (k = 1; k <= `numLayers; k = k + 1) begin
            writeAxi(12, k); // Write layer number
            for (j = 0; j < numNeurons[k]; j = j + 1) begin
                neuronNo_int = j;
                
                // Clear the fileNameStr
                fileNameStr = {8*24{1'b0}};
                
                // Build the filename
                fileNameStr[8*1-1 -: 8] = "f";
                fileNameStr[8*2-1 -: 8] = "i";
                fileNameStr[8*3-1 -: 8] = "m";
                fileNameStr[8*4-1 -: 8] = ".";
                fileNameStr[8*5-1 -: 8] = (j > 9) ? to_ascii(j/10) : "0";
                fileNameStr[8*6-1 -: 8] = to_ascii(j % 10);
                fileNameStr[8*7-1 -: 8] = "_";
                fileNameStr[8*8-1 -: 8] = to_ascii(k);
                fileNameStr[8*9-1 -: 8] = "_";
                fileNameStr[8*10-1 -: 8] = "b";

                // Print the filename before reading
                printFileName();

                $readmemb(fileNameStr, bias);
                writeAxi(16, j); // Write neuron number
                writeAxi(4, {15'd0, bias[0]});
            end
        end
    end
    endtask
    
task sendData();
    integer t;
    begin
        // Clear the fileNameStr
        fileNameStr = {8*24{1'b0}};
        
        // Build the filename as "test_data_XXXX.txt" with a four-digit count
        fileNameStr[8*24-1 -: 8] = "t";
        fileNameStr[8*23-1 -: 8] = "e";
        fileNameStr[8*22-1 -: 8] = "s";
        fileNameStr[8*21-1 -: 8] = "t";
        fileNameStr[8*20-1 -: 8] = "_";
        fileNameStr[8*19-1 -: 8] = "d";
        fileNameStr[8*18-1 -: 8] = "a";
        fileNameStr[8*17-1 -: 8] = "t";
        fileNameStr[8*16-1 -: 8] = "a";
        fileNameStr[8*15-1 -: 8] = "_";
        
        // Convert testDataCount to a four-digit format
        fileNameStr[8*14-1 -: 8] = to_ascii((testDataCount / 1000) % 10);
        fileNameStr[8*13-1 -: 8] = to_ascii((testDataCount / 100) % 10);
        fileNameStr[8*12-1 -: 8] = to_ascii((testDataCount / 10) % 10);
        fileNameStr[8*11-1 -: 8] = to_ascii(testDataCount % 10);
        
        fileNameStr[8*10-1 -: 8] = ".";
        fileNameStr[8*9-1 -: 8] = "t";
        fileNameStr[8*8-1 -: 8] = "x";
        fileNameStr[8*7-1 -: 8] = "t";

        // Print the filename before reading
        printFileName();
        
        // Read data from the generated filename
        $readmemb(fileNameStr, in_mem);
        @(posedge clock);
        
        // Send data in sequence
        for (t = 0; t < 784; t = t + 1) begin
            @(posedge clock);
            in <= in_mem[t];
            in_valid <= 1;
        end 
        @(posedge clock);
        in_valid <= 0;
        expected = in_mem[t];
    end
endtask

   
    integer i, j, layerNo = 1, k;
    integer start;
    integer testDataCount;
    integer testDataCount_int;
    initial begin
        reset = 0;
        in_valid = 0;
        #100;
        reset = 1;
        #100
        writeAxi(28, 0); // clear soft reset
        start = $time;
        `ifndef pretrained
            configWeights();
            configBias();
        `endif
        $display("Configuration completed",,,,,"ns");
        start = $time;
        for (testDataCount = 0; testDataCount < `MaxTestSamples; testDataCount = testDataCount + 1) begin
            testDataCount_int = testDataCount;
            sendData();
            @(posedge intr);
            readAxi(8);
            if (axiRdData == expected)
                right = right + 1;
            $display("%0d. Accuracy: %f, Detected number: %0x, Expected: %x", testDataCount + 1, right * 100.0 / (testDataCount + 1), axiRdData, expected);
        end
        $display("Accuracy: %f", right * 100.0 / testDataCount);
        $stop;
    end

endmodule

