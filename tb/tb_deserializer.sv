`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: X-MEN
// Engineer: Marcos Luz
// 
// Create Date: 08/10/2026 05:20:42 PM
// Design Name: 
// Module Name: tb_deserializer
// Project Name: SPI_AES_Accelerator
// Target Devices:  
// Tool Versions: Vivado 2025.1
// Description: 
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File created
// Revision 1.00 - Add basic validation for the generalized deserializer
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_deserializer;
  localparam INPUT_WIDTH  = 8;
  localparam NUM_ELEMENTS = 16;
  localparam OUTPUT_WIDTH = INPUT_WIDTH * NUM_ELEMENTS;

  logic clk = 0;
  logic rst = 1;
  logic en = 0;
  
  wire s_tready;
  logic s_tvalid = 0;
  logic [INPUT_WIDTH-1:0] s_tdata = 0;
  logic s_tlast = 0;
  
  logic m_tready = 0;
  wire m_tvalid;
  wire [OUTPUT_WIDTH-1:0] m_tdata;
  wire m_tlast;
  
  always begin
    #5 clk = ~clk;
  end

  deserializer #(
    .INPUT_WIDTH(INPUT_WIDTH),
    .NUM_ELEMENTS(NUM_ELEMENTS)
  ) deserializer_dut (.*);

  // Envia um byte para o DUT durante a borda de descida
  task automatic send_byte(input logic [7:0] data, input logic last = 0);
    @(negedge clk);
    s_tvalid = 1;
    s_tdata  = data;
    s_tlast  = last;
    
    do @(posedge clk); while (!s_tready);
    @(negedge clk);
    s_tvalid = 0;
    s_tlast  = 0;
  endtask

  // Verifica se a palavra gerada na saída é igual a palavra esperada 
  // e se saída é limpa depois do handshake
  task automatic check_word(input logic [OUTPUT_WIDTH-1:0] expected, input logic expected_last);
    repeat(3) begin
      @(negedge clk);
      if (m_tvalid !== 1'b1 || m_tdata !== expected || m_tlast !== expected_last || s_tready !== 1'b0)
        $fatal(1, "FAIL: Saída Inválida: valid=%b data=%h last=%b; expected=%h/%b",
               m_tvalid, m_tdata, m_tlast, expected, expected_last);
    end

    m_tready = 1;
    @(posedge clk);
    @(negedge clk);

    if (m_tvalid !== 1'b0 || m_tlast !== 1'b0 || m_tdata !== '0)
      $fatal(1, "FAIL: A Saída não foi limpa após handshake com o consumidor");
    m_tready = 0;
  endtask

  initial begin
    $dumpfile("tb_deserializer.vcd");
    $dumpvars(0, tb_deserializer);

    repeat(3) begin
      @(negedge clk);
    end
    
    if (m_tvalid !== 1'b0 || m_tdata !== '0 || m_tlast !== 1'b0)
      $fatal(1, "FAIL: Reset falhou");
    rst = 0;

    // TESTE 1: Envio de bytes enquanto o módulo está desabilitado.
    s_tvalid = 1;
    s_tdata  = 8'hFF;

    repeat(3) begin
      @(negedge clk);
      if (s_tready !== 1'b0 || m_tvalid !== 1'b0)
        $fatal(1, "FAIL: Saída aceita enquanto o módulo estava desabilitado");
    end

    s_tvalid = 0;
    en = 1;

    // TESTE 2: Envio de uma palavra válida
    for (int i = 0; i < NUM_ELEMENTS; i++) begin
      send_byte(i, i == NUM_ELEMENTS-1);
      if (i < NUM_ELEMENTS-1 && m_tvalid !== 1'b0)
        $fatal(1, "FAIL: A saída foi habilitada antes de todos os bytes serem recebidos");
    end
    
    check_word(128'h000102030405060708090A0B0C0D0E0F, 1'b1);

    // TESTE 3: Envio de uma palavra sem indicar o fim da transmissão.
    for (int i = 0; i < NUM_ELEMENTS; i++) begin
      repeat(2) begin 
        @(negedge clk);
      end
      send_byte(8'hA0 + i, 1'b0);
    end

    check_word(128'hA0A1A2A3A4A5A6A7A8A9AAABACADAEAF, 1'b0);

    // TESTE 4: Desabilita o módulo depois de alguns bytes transmitidos
    // e depois envia uma palavra com o módulo novamente habilitado
    send_byte(8'hDE);
    send_byte(8'hAD);
    @(negedge clk) en = 0;

    repeat(2) begin
      @(negedge clk); 
    end

    if (s_tready !== 1'b0 || m_tvalid !== 1'b0) begin
      $fatal(1, "FAIL: A desabilitação do módulo não descartou os bytes recebidos");
    end 
    
    en = 1;
    for (int i = 0; i < NUM_ELEMENTS; i++) begin
      send_byte(8'h10 + i, i == NUM_ELEMENTS-1);
    end
    
    check_word(128'h101112131415161718191A1B1C1D1E1F, 1'b1);

    $display("PASS: Todos os testes passaram");
    $finish;
  end

  // Interrompe a simulação depois de 10us para evitar execução desnecessária
  initial begin
    #10000 $fatal(1, "FAIL: Testbench timeout");
  end
endmodule