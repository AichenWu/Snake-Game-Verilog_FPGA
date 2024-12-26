module Snake_2(
    output reg [0:7] LedR, LedG, LedB,
    output reg [2:0] comm,
    output reg enable,
    output reg [7:0] point,
    input SYS_CLK, RST, PAUSE, UP, DOWN, LEFT, RIGHT
);

    reg [1:0] state; // 01 is gaming, 10 is end

    reg game_clk;
    reg led_clk;    

    reg [7:0] map [7:0]; // LED map 8x8, map[x][~y]

    reg [2:0] X, Y; // snake head position
    reg [2:0] body_mem_x[63:0]; // positions of X *64
    reg [2:0] body_mem_y[63:0]; // positions of Y *64
    reg [5:0] length; // include head

    reg [2:0] item_x, item_y;

    reg pass;
    reg [7:0] pass_pic [7:0];

    reg [6:0] i;
    reg [5:0] j;

    reg [24:0] led_counter;
    reg [24:0] move_counter;
    reg [1:0] move_dir;

    integer led_count_to = 50000; // LED clock 1kHz display
    integer count_to = 4500000; // game clock 0.5Hz

    // 這裡設置結束後顯示的圖案（例如一個 "GAME OVER" 字樣）
    reg [7:0] game_over_pattern [7:0];
    initial begin
        // 初始化顯示
        LedR = 8'b11111111;
        LedG = 8'b11111111;
        LedB = 8'b11111111;
        enable = 1'b1;
        comm = 3'b000;

        pass = 1'b0;

        pass_pic[3'b000] = 8'b00000000;
        pass_pic[3'b001] = 8'b11110110;
        pass_pic[3'b010] = 8'b11110110;
        pass_pic[3'b011] = 8'b11110110;
        pass_pic[3'b100] = 8'b11110110;
        pass_pic[3'b101] = 8'b11110110;
        pass_pic[3'b110] = 8'b11110110;
        pass_pic[3'b111] = 8'b11110000;

        // 初始化遊戲
        map[3'b010][~3'b010] = 1'b1; // head
        map[3'b001][~3'b010] = 1'b1; // body
        map[3'b000][~3'b010] = 1'b1; // body

        item_x = 3'b110;
        item_y = 3'b110;

        point = 8'b00000000;

        X = 3'b010;
        Y = 3'b010;
        // head
        body_mem_x[0] = 3'b010;
        body_mem_y[0] = 3'b010;
        // body1
        body_mem_x[1] = 3'b010;
        body_mem_y[1] = 3'b001;        
        // body2
        body_mem_x[2] = 3'b010;
        body_mem_y[2] = 3'b000;        
        length = 3;
        state = 2'b01;
        move_dir = 2'b00; // when game start, snake direction

        // 初始化 GAME OVER 圖案 (自訂圖案)
        game_over_pattern[0] = 8'b00000000; // 顯示的圖案示例
        game_over_pattern[1] = 8'b00010000;
        game_over_pattern[2] = 8'b00100110;
        game_over_pattern[3] = 8'b01000000;
        game_over_pattern[4] = 8'b01000000;
        game_over_pattern[5] = 8'b00100110;
        game_over_pattern[6] = 8'b00010000;
        game_over_pattern[7] = 8'b00000000;
    end

    ////// system clock to game clock and LED clock
    always @(posedge SYS_CLK) begin
        if (PAUSE == 1'b1) ; // Do nothing to counter if paused
        else if (move_counter < count_to) begin
            move_counter <= move_counter + 1;
        end else begin
            game_clk <= ~game_clk;
            move_counter <= 25'b0;
        end
        
        // LED clock
        if (led_counter < led_count_to)
            led_counter <= led_counter + 1;
        else begin
            led_counter <= 25'b0;
            led_clk <= ~led_clk;
        end
    end    

    ///// 8x8 LED display
    ///// change comm(s0s1s2)
    always @(posedge led_clk) begin
        if (comm == 3'b111) comm <= 3'b000;
        else comm <= comm + 1'b1;
    end    

    ///// print map info to LED
    always @(comm) begin
        if (state == 2'b10) begin
            // Game over, 顯示自訂的圖案
            LedG = ~game_over_pattern[comm]; // 顯示 game_over 圖案
            LedB = 8'b11111111; // 藍燈熄滅
            LedR = 8'b11111111; // 紅燈熄滅
        end else if (point > 8'b00001000) begin // Change color when score > 4
            LedG = ~map[comm];
            LedB = 8'b11111111;
        end else begin
            LedB = ~map[comm];
            LedG = 8'b11111111;
        end

        if (state != 2'b10 && comm == item_x) // 遊戲結束時不顯示紅點
            LedR[item_y] = 1'b0;
        else
            LedR = 8'b11111111;
    end    

    //// update move direction    
    always @(UP or DOWN or LEFT or RIGHT) begin // Directions can't all use "posedge"
        if (UP == 1'b1 && DOWN != 1'b1 && LEFT != 1'b1 && RIGHT != 1'b1 && move_dir != 2'b01)
            move_dir = 2'b00;  
        else if (DOWN == 1'b1 && UP != 1'b1 && LEFT != 1'b1 && RIGHT != 1'b1 && move_dir != 2'b00)
            move_dir = 2'b01; 
        else if (LEFT == 1'b1 && UP != 1'b1 && DOWN != 1'b1 && RIGHT != 1'b1 && move_dir != 2'b11)
            move_dir = 2'b10; 
        else if (RIGHT == 1'b1 && UP != 1'b1 && DOWN != 1'b1 && LEFT != 1'b1 && move_dir != 2'b10)
            move_dir = 2'b11; 
    end  

    //// game clock game body
    always @(posedge game_clk) begin
        if (move_dir == 2'b00) Y <= Y + 1;
        else if (move_dir == 2'b01) Y <= Y - 1;
        else if (move_dir == 2'b10) X <= X - 1;
        else if (move_dir == 2'b11) X <= X + 1;

        // update map
        map[X][~Y] <= 1'b1;

        // 當得分達到 8 分時結束遊戲
        if (point == 8'b00001000) begin
            state = 2'b10; // 改為結束遊戲狀態
        end

        // get item
        if (X == item_x && Y == item_y) begin
            if (point > 8'b11111110)
                state = 2'b10; // 遊戲結束
            point = point * 2 + 1'b1;

            // change item position
            if (move_dir == 2'b00 || move_dir == 2'b01) begin    
                item_x = X + 3'b011 + game_clk * 2;
                item_y = Y - 3'b011 + game_clk;
            end else begin
                item_x = X - 3'b011 - game_clk;
                item_y = Y + 3'b011 - game_clk * 2;
            end
        end

        map[body_mem_x[length-1]][~body_mem_y[length-1]] = 1'b0;

        for (i = 1; i < length; i = i + 1) begin
            body_mem_x[length-i] <= body_mem_x[length-i-1];
            body_mem_y[length-i] <= body_mem_y[length-i-1];
        end
        body_mem_x[0] = X;
        body_mem_y[0] = Y;
    end
endmodule
