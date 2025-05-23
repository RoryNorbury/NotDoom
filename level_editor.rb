require 'gosu'
require 'matrix'

RESOLUTION = [360, 360]
ORIGIN = Vector.elements(RESOLUTION.map{|a|a/2.0})

module Clock_index
    Global = 0 # cycles since program start
    Click = 1 # cycles since last click interaction
    Key = 2 # cycles since last key interaction  
    File = 3 # cycles since last file read/write
end

class LevelEditor < Gosu::Window
    def initialize
        super(*RESOLUTION, false)
        self.caption = "Level Editor"
        @filename = "level.txt"
        @backup_filename = "level.backup.txt"
        @level = Level.new()
        @level.load_from_file(@filename)
        @level.save_to_file(@backup_filename)
        @default_wall_height = 4.0 # meters
        
        @scale = 40 # pixels to a meter
        @gridsize = @scale / 2.0

        # colours
        @background_colour = Gosu::Color::BLACK
        @grid_colour = Gosu::Color.argb(255, 32, 32, 32)
        @line_colour = Gosu::Color.argb(255, 192, 192, 192)
        @player_colour = Gosu::Color.argb(255, 0, 192, 0)
        
        # interaction state
        @is_drawing_line = false
        @last_click_coordinate = nil

        # clock array for tracking
        @clock_array = Array.new(4, 0)
    end
    def update
        # update clock array
        @clock_array.length.times do |i|
            @clock_array[i] += 1
        end
        # input handling
        if Gosu.button_down?(Gosu::KB_ESCAPE)
            close()
        end
        if Gosu.button_down?(Gosu::MS_LEFT)
            # only do stuff if it has been a while since the last click event
            if (@clock_array[Clock_index::Click] > 15)
                closest_gridpoint = get_closest_gridpoint(Vector[mouse_x, mouse_y])
                if @is_drawing_line
                    current_position = closest_gridpoint
                    # if both wall endpoints are different, add wall to wall array
                    if (current_position != @last_click_coordinate)
                        @level.walls.push(
                            Vector[
                            Vector[*((@last_click_coordinate - ORIGIN) / @scale), 0.0],
                            Vector[*((current_position - ORIGIN) / @scale), @default_wall_height]
                            ])
                        @last_click_coordinate = current_position
                        @is_drawing_line = false
                    end
                else
                    @last_click_coordinate = closest_gridpoint
                    @is_drawing_line = true
                end
                # reset clock index
                @clock_array[Clock_index::Click] = 0
            end
        end
        if Gosu.button_down?(Gosu::MS_RIGHT)
            if @is_drawing_line
                @is_drawing_line = false
            else
                # delete wall if it exists
                closest_gridpoint = get_closest_gridpoint(Vector[mouse_x, mouse_y])
                @level.delete_wall(Vector[*((closest_gridpoint - ORIGIN) / @scale)])
            end
        end
        if Gosu.button_down?(Gosu::KB_DOWN)
            if @clock_array[Clock_index::Key] > 5
                @scale *= 2.0/3.0 # pixels to a meter
                @gridsize = @scale / 2.0
                @clock_array[Clock_index::Key] = 0
                printf("Scale: %f\n", @scale)
                printf("Grid size: %f\n\n", @gridsize)
            end
        end
        if Gosu.button_down?(Gosu::KB_UP)
            if @clock_array[Clock_index::Key] > 5
                @scale *= 1.5 # pixels to a meter
                @gridsize = @scale / 2.0
                @clock_array[Clock_index::Key] = 0
                printf("Scale: %f\n", @scale)
                printf("Grid size: %f\n\n", @gridsize)
            end
        end
        
        # save walls to file
        if @clock_array[Clock_index::File] > 60
            @level.save_to_file(@filename)
            @clock_array[Clock_index::File] = 0                      
        end
    end
    def draw
        # draw black background
        draw_rect(0, 0, *RESOLUTION, Gosu::Color::BLACK)
        # draw grid
        x_grid_count = (RESOLUTION[0] / @gridsize).ceil()
        y_grid_count = (RESOLUTION[1] / @gridsize).ceil()
        # vertical lines
        x = ORIGIN[0] - @gridsize * (x_grid_count / 2)
        while x < RESOLUTION[0]
            draw_line(x, 0, @grid_colour, x, RESOLUTION[1], @grid_colour)
            x += @gridsize
        end
        # horizontal lines
        y = ORIGIN[1] - @gridsize * (y_grid_count / 2)
        while y < RESOLUTION[1]
            draw_line(0, y, @grid_colour, RESOLUTION[0], y, @grid_colour)
            y += @gridsize
        end
        draw_walls()
        # draw current line
        if @is_drawing_line
            draw_line(*@last_click_coordinate, @line_colour, mouse_x, mouse_y, @line_colour)  
        end
        # draw player position
        draw_triangle(*(ORIGIN + Vector[-@gridsize / 2, @gridsize / 2]), @player_colour, *(ORIGIN + Vector[0, -@gridsize / 2]), @player_colour, *(ORIGIN + Vector[@gridsize / 2, @gridsize / 2]), @player_colour)
    end
    def draw_walls()
        i = 0
        while i < @level.walls.length
            wall1 = (@level.walls[i][0].dup() * @scale) + Vector[*ORIGIN, 0.0]
            wall2 = (@level.walls[i][1].dup() * @scale) + Vector[*ORIGIN, 0.0]
            draw_line(wall1[0], wall1[1], @line_colour, wall2[0], wall2[1], @line_colour)
            i += 1
        end
    end
    def get_closest_gridpoint(vector)
        # round the vector to the nearest grid point
        x = @gridsize * ((vector[0] - ORIGIN[0]) / @gridsize.to_f()).round() + ORIGIN[0]
        y = @gridsize * ((vector[1] - ORIGIN[1]) / @gridsize.to_f()).round() + ORIGIN[1]
        return Vector[x, y]
    end
end

class Level
    attr_accessor :walls
    def initialize()
        @walls = Array.new()
    end
    # TODO: store walls as four 3d vectors instead of two
    def save_to_file(filename)
        file = File.open(filename, "w")
        @walls.each do |wall|
            file.puts(wall[0].to_a.join(','))
            file.puts(wall[1].to_a.join(','))
        end
        file.close()
    end
    def load_from_file(filename)
        file = File.open(filename, "r")
        while !file.eof? do
            # load two vectors from the file and store them as a wall
            wall = Vector[load_vector(file), load_vector(file)]
            @walls.push(wall)
        end
        file.close()
    end
    # loads a vector in from a txt file
    def load_vector(file_object)
        vector = Vector.elements(file_object.readline().split(',').map(&:to_f))
        return vector
    end
    # delete any wall with the same vector
    def delete_wall(vector)
        i = 0
        while i < @walls.length
            # delete wall if it matches the x and y values of either vector in wall
            err = 0.001 # allowed error margin
            if ((abs_diff(@walls[i][0][0], vector[0]) < err and abs_diff(@walls[i][0][1], vector[1]) < err) or (abs_diff(@walls[i][1][0], vector[0]) < err and abs_diff(@walls[i][1][1], vector[1]) < err))
                @walls.delete_at(i)
            end
            i += 1
        end
    end
end

def print_quad_array(quads)
    quads.each do |quad|
        puts quad
        puts "\n"  
    end  
end

def abs_diff(a, b)
    return (a-b).abs
end

def main()
    window = LevelEditor.new()
    window.show()
end

main()