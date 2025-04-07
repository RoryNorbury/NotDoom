require 'gosu'
require "matrix"

PI = Math::PI
RESOLUTION = [640, 640]
CAMERA_PAN_SPEED = PI/4 / 60
PLAYER_MOVEMENT_SPEED = 1.0 / 60
MAX_RENDER_DISTANCE = 128
MIN_RENDER_DISTANCE = 1

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
    attr_accessor :position, :view_angle
end

class MyGame < Gosu::Window
    attr_reader :player, :walls
    def initialize
        
        super(*RESOLUTION)
        self.caption = "Not Doom"

        @player = Player.new()
        @player.position -= Vector[0, 0, 1]
        
        # variables for screen coordinate calculation
        @initial_view_vector = Vector[0.0, 0.0, 1.0]
        @screen_edges = [Vector[-0.5, 0.5, 1], Vector[0.5, -0.5, 1]]

        # variable initialisation because screw interpreters
        @rotation_matrix = Matrix
        @reverse_rotation_matrix = Matrix
        @view_vector = Vector
        @right_vector = Vector
        @up_vector = Vector[0, 1, 0]
        @screen_plane = Plane

        # should be recalculated every frame
        recalculate_render_variables()

        # list of vertex pairs for walls
        @walls = [
            [Vector[1.0, 1.0, 2.0], Vector[2.0, 1.0, 2.0], Vector[2.0, 0.0, 2.0], Vector[1.0, 0.0, 2.0]],
            [Vector[0.0, 1.0, 2.0], Vector[1.0, 1.0, 2.0], Vector[1.0, 0.0, 2.0], Vector[0.0, 0.0, 2.0]],
            [Vector[0.5, 1.0, 1.5], Vector[1.5, 1.0, 2.0], Vector[1.5, 0.0, 2.0], Vector[0.5, 0.0, 1.5]],
            [Vector[0.5, 1.0, 2.0], Vector[1.5, 1.0, 2.5], Vector[1.5, 0.0, 2.5], Vector[0.5, 0.0, 2.0]]
        ]
    end
    
    # overriden Gosu::Window function
    # frame-by-frame logic goes here
    def update
        # keyboard input handling
        if Gosu.button_down?(Gosu::KB_LEFT)
            player.view_angle += CAMERA_PAN_SPEED
        end
        if Gosu.button_down?(Gosu::KB_RIGHT)
            player.view_angle -= CAMERA_PAN_SPEED
        end
        if Gosu.button_down?(Gosu::KB_W)
            player.position += @view_vector * PLAYER_MOVEMENT_SPEED
        end
        if Gosu.button_down?(Gosu::KB_S)
            player.position -= @view_vector * PLAYER_MOVEMENT_SPEED
        end
        if Gosu.button_down?(Gosu::KB_A)
            player.position -= @right_vector * PLAYER_MOVEMENT_SPEED
        end
        if Gosu.button_down?(Gosu::KB_D)
            player.position += @right_vector * PLAYER_MOVEMENT_SPEED
        end
        if Gosu.button_down?(Gosu::KB_SPACE)
            player.position += @up_vector * PLAYER_MOVEMENT_SPEED
        end
        if Gosu.button_down?(Gosu::KB_LEFT_CONTROL)
            player.position -= @up_vector * PLAYER_MOVEMENT_SPEED
        end
        if Gosu.button_down?(Gosu::KB_ESCAPE)
            close()
        end
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
            screen_coordinates = Array.new(4, Vector.zero(2))
            # if the point maps to a position on the screen
            z = 0
            for i in 0..3
                screen_coordinates[i] = get_screen_coordinates(wall[i])
                if screen_coordinates[i] == nil
                    return
                end
                screen_coordinates[i] *= RESOLUTION[0] # TODO: allow non-square screen - use aspect ratio
                z += screen_coordinates[i][2]
            end
            z /= 4.0
            z = 1-z
            # puts("Screen coordinates: " + screen_coordinates.to_s())
            Gosu.draw_quad(
                screen_coordinates[0][0], screen_coordinates[0][1], Gosu::Color::BLUE,
                screen_coordinates[1][0], screen_coordinates[1][1], Gosu::Color::BLUE,
                screen_coordinates[2][0], screen_coordinates[2][1], Gosu::Color::BLUE,
                screen_coordinates[3][0], screen_coordinates[3][1], Gosu::Color::BLUE,
                z
                )
        end
    end
    
    # determine the screen coordinates that a point translates to
    def get_screen_coordinates(point)
        # puts("Point: " + point.to_s())
        point -= player.position

        intersect_point = get_intersect_point(point, @screen_plane)
        if intersect_point == nil
            return nil
        end

        # calculate distance to camera
        distance = point.magnitude()
        # map between 0 and 1
        z = (distance - MIN_RENDER_DISTANCE) / (MAX_RENDER_DISTANCE - MIN_RENDER_DISTANCE)

        # rotate intersect point back into screen space
        intersect_point = (intersect_point.to_matrix().transpose() * @reverse_rotation_matrix ).row_vectors()[0]
        # puts("Intersect point: " + intersect_point.to_s())

        # transform into screen coordinates (becomes depth)
        a = Vector[intersect_point[0], -intersect_point[1], z] # y axis flipped
        screen_coordinates = a + Vector[0.5, 0.5, 0.0]
        # puts("Screen coordinates: " + screen_coordinates.to_s())
        # if z < 0 r z > 1 coordinate is outside viewing frustrum
        return screen_coordinates
    end

    def recalculate_render_variables
        @rotation_matrix = get_rotation_matrix(player.view_angle)
        @reverse_rotation_matrix = get_rotation_matrix(-player.view_angle)
        # this is actually fucked please please please use C or python next time
        @view_vector = (@initial_view_vector.to_matrix().transpose() * @rotation_matrix).row_vectors()[0]
        @right_vector = @view_vector.cross(Vector[0, -1, 0]) # left handed i think
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
        # shouldn't ever happen; means screen and view ray are parallel
        if l_dot_n == 0
            raise "screen and view ray are parallel"
        end
        d = p0_dot_n / l_dot_n  
        return d * gradient
    end


end

def main()
    MyGame.new.show()
end

if __FILE__ == $0
    main()
end