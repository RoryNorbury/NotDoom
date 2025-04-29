require 'gosu'
require 'matrix'

class LevelEditor < Gosu::Window
    def initialize
        super(640, 640, false)
        self.caption = "Level Editor"  
    end
    def update
        # Update logic goes here
    end
    def draw
        # Draw the window background
        draw_rect(0, 0, width, height, Gosu::Color::WHITE)
        
        # Draw a red rectangle in the center of the window
        draw_rect(width / 4, height / 4, width / 2, height / 2, Gosu::Color::RED)
    end
end

class Level
    attr_accessor :walls
    def initialize()
        @walls = Array.new()
    end
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
            vector = Vector[line.split(',').map(&:to_f)]
            @walls.push(vector)
        end
        file.close()
    end
end

def main()
    filename = "level.txt"
    level = Level.new()
    level.load_from_file(filename)
    level.walls.each do |wall|
        puts(wall)
    end
    window = LevelEditor.new()
    window.show()  
end

main()