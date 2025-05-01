require 'gosu'
require 'matrix'

SCALE = 200 # pixels to a meter
GRIDSIZE = SCALE / 2
RESOLUTION = [1280, 720]
ORIGIN = Vector.elements(RESOLUTION.map{|a|a/2.0})

class LevelEditor < Gosu::Window
    def initialize
        super(*RESOLUTION, false)
        self.caption = "Level Editor"
        @level = Level.new()
        @level.load_from_file("level.txt")
        @last_click_coordinate = nil

        # colours
        @background_colour = Gosu::Color::BLACK
        @grid_colour = Gosu::Color.argb(255, 32, 32, 32)
        @line_colour = Gosu::Color.argb(255, 192, 192, 192)
        @player_colour = Gosu::Color.argb(255, 0, 192, 0)
    end
    def update
        if Gosu.button_down?(Gosu::KB_ESCAPE)
            close()
        end
        if Gosu.button_down?(Gosu::MS_LEFT)
            # 
            @last_click_coordinate = [GRIDSIZE * ((mouse_x - ORIGIN[0]) / GRIDSIZE.to_f()).round() + ORIGIN[0], GRIDSIZE * ((mouse_y - ORIGIN[1]) / GRIDSIZE.to_f()).round() + ORIGIN[1]]
        end
    end
    def draw
        # draw black background
        draw_rect(0, 0, *RESOLUTION, Gosu::Color::BLACK)
        # draw grid
        x_grid_count = RESOLUTION[0] / GRIDSIZE
        y_grid_count = RESOLUTION[1] / GRIDSIZE
        # vertical lines
        x = ORIGIN[0] - GRIDSIZE * (x_grid_count / 2)
        while x < RESOLUTION[0]
            draw_line(x, 0, @grid_colour, x, RESOLUTION[1], @grid_colour)
            x += GRIDSIZE
        end
        # horizontal lines
        y = ORIGIN[1] - GRIDSIZE * (y_grid_count / 2)
        while y < RESOLUTION[1]
            draw_line(0, y, @grid_colour, RESOLUTION[0], y, @grid_colour)
            y += GRIDSIZE
        end
        draw_walls()
        # draw current line
        if @last_click_coordinate != nil
            draw_line(*@last_click_coordinate, @line_colour, mouse_x, mouse_y, @line_colour)  
        end
        # draw player position
        draw_triangle(*(ORIGIN + Vector[-GRIDSIZE / 2, GRIDSIZE / 2]), @player_colour, *(ORIGIN + Vector[0, -GRIDSIZE / 2]), @player_colour, *(ORIGIN + Vector[GRIDSIZE / 2, GRIDSIZE / 2]), @player_colour)

    end
    def draw_walls()
        i = 0
        while i < @level.walls.length
            wall1 = (@level.walls[i].dup() * SCALE) + Vector[*ORIGIN, 0.0]
            wall2 = (@level.walls[i+1].dup() * SCALE) + Vector[*ORIGIN, 0.0]
            draw_line(wall1[0], wall1[1], @line_colour, wall2[0], wall2[1], @line_colour)
            i += 2
        end
    end
end

class Level
    attr_accessor :walls
    def initialize()
        @walls = Array.new()
    end
    # TODO: store walls as four 3d vectors instead of two
    def save_to_file(filename)
        file = File.open(filename, "a")
        @walls.each do |wall|
            file.puts(wall.to_a.join(','))
        end
        file.close()
    end
    def load_from_file(filename)
        file = File.open(filename, "r")
        file.each_line do |line|
            vector = Vector.elements(line.split(',').map(&:to_f))
            @walls.push(vector)
        end
        file.close()
    end
    # returns an array of vertex quads usable for rendering
    def to_quad_array()
        quads = Array.new()
        i = 0
        while i < @walls.length/2.0
            quads.push(Array.new())
            # fuck pass by reference
            quads[i].push(@walls[2 * i].dup())
            quads[i].push(@walls[2 * i + 1].dup())
            quads[i].push(@walls[2 * i + 1].dup())
            quads[i].push(@walls[2 * i].dup())
            quads[i][1][2] = quads[i][0][2]
            quads[i][3][2] = quads[i][2][2]
            i += 1
        end
        return quads
    end
end

def print_quad_array(quads)
    quads.each do |quad|
        puts quad
        puts "\n"  
    end  
end

def main()
    filename = "level.txt"
    level = Level.new()
    level.load_from_file(filename)
    print_quad_array(level.to_quad_array())
    window = LevelEditor.new()
    window.show()  
end

main()