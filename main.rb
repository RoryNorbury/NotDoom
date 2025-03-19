require 'gosu'
require "matrix"

PI = Math::PI

class Plane
    attr_accessor :normal, :point
    def initialize(normal, point)
        @normal = normal
        @point = point
    end
end

class Player
    def initialize()
        @position = Vector.zero(3)
        @view_angle = 0
    end
    attr_accessor :position
    attr_accessor :view_angle
end

class MyGame < Gosu::Window
    attr_reader :player, :walls
    def initialize
        super(640, 360)
        self.caption = "Not Doom"

        @player = Player.new()

        # variables for screen coordinate calculation
        @initial_view_vector = Vector[0.0, 0.0, 1.0]
        @screen_edges = [Vector[-0.5, 0.5, 1], Vector[0.5, -0.5, 1]]
        # should be recalculated every frame
        recalculate_render_variables()

        # list of vertex pairs for walls
        @walls = [[Vector[1.0, 1.0, 1.0], Vector[2.0, 1.0, 1.0]]]
    end

    # overriden Gosu::Window function
    # frame-by-frame logic goes here
    def update
        player.position -= Vector[0, 0, 0.2] / 60.0
    end
  
    # overriden Gosu::Window function
    # drawing calls go here
    def draw
        recalculate_render_variables()
        draw_walls(@walls)
    end

    # draw walls to screen
    def draw_walls(wall_vertices)
        wall_vertices.each do |wall|
            Gosu.draw_triangle(20, 20, Gosu::Color::RED, 100, 200, Gosu::Color::GREEN, 200, 100, Gosu::Color::BLUE)
        end                
    end
    
    # determine the screen coordinates that a point translates to
    def get_screen_coordinates(point)
        point -= player.position

        intersect_point = get_intersect_point(point, @screen_plane)
        if intersect_point == nil
            return nil
        end

        # rotate intersect point back into screen space
        intersect_point = @reverse_rotation_matrix * intersect_point




        point += player.position
    end

    def recalculate_render_variables
        @rotation_matrix = get_rotation_matrix(player.view_angle)
        @reverse_rotation_matrix = get_rotation_matrix(-player.view_angle)
        @view_vector = @rotation_matrix * @initial_view_vector
        @screen_plane = Plane.new(@view_vector, @view_vector)
    end

    def get_rotation_matrix(theta)
        c = Math.cos(theta)
        s = Math.sin(theta)
        rotation_matrix = Matrix[ [c, 0, s], [0, 1, 0], [-s, 0, c] ]
        return rotation_matrix
    end

    # get intersect point of a line from the origin to a point and a plane
    def get_intersect_point(point, plane)
        gradient = point.normalize()
        # source: https://en.wikipedia.org/wiki/Line–plane_intersection#Algebraic_form
        # assuming l0 is the origin ([0, 0, 0])

        # if p0 * l <= 0 point is behind player
        if plane.point.dot(gradient) <= 0
            return nil
        end
        p0_dot_n = plane.point.dot(plane.normal)
        l_dot_n = gradient.dot(plane.normal)
        if l_dot_n == 0
            return nil
        end
        # shouldn't ever happen; means screen and view ray are parallel
        if p_dot_n == 0
            raise "screen and view ray are parallel"
        end
        d = p_dot_n / l_dot_n  
        return d
    end


end

def main()
    MyGame.new.show()
end

if __FILE__ == $0
    main()
end