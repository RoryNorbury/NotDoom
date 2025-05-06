require 'gosu'
require "matrix"

PI = Math::PI
RESOLUTION = [640, 640]
CAMERA_PAN_SPEED = PI/4 / 60
PLAYER_MOVEMENT_SPEED = 2.0 / 60
MAX_RENDER_DISTANCE = 1024.0
MIN_RENDER_DISTANCE = 0.0001

FPS = 60.0
DT = 1.0 / FPS

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
        @velocity = Vector.zero(3)
        @view_angle = 0
        @height_vector = Vector[0, 1, 0]
    end
    attr_accessor :position, :velocity, :view_angle, :height_vector
end

Clock_array_length = 1
module Clock_index
    LoadFile = 0  
end

class MyGame < Gosu::Window
    attr_reader :player, :walls
    def initialize
        
        super(*RESOLUTION)
        self.caption = "Not Doom"

        @player = Player.new()
        @player.position -= Vector[0, 0, 1] # should delete
        
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

        # World Settings---------------------------------------------------------------------------

        @GRAVITY = Vector[0, -4, 0]
        @FLOOR_HEIGHT = 0

        @floor_colour = Gosu::Color.new(255, 60, 60, 60)
        @wall_colour_a = Gosu::Color.new(255, 0, 0, 160)
        @wall_colour_b = Gosu::Color.new(255, 0, 0, 80)

        # list of vertex quads for walls, in anticlockwise order
        @level_filename = "level.txt"
        @walls = load_walls(@level_filename)

        # array for storing cycle count
        @clock_array = Array.new(Clock_array_length, 0)
    end
    
    def update_clock_array()
        @clock_array.length.times do |i|
            @clock_array[i] += 1  
        end  
    end
    # overriden Gosu::Window function
    # frame-by-frame logic goes here
    def update
        update_clock_array()
        if (@clock_array[Clock_index::LoadFile] > 15)
            @walls = load_walls(@level_filename)
            @clock_array[Clock_index::LoadFile] = 0
        end
        # keyboard input handling
        movement_speed_multiplier = 1
        if Gosu.button_down?(Gosu::KB_LEFT_SHIFT)
            movement_speed_multiplier = 3 * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_LEFT)
            @player.view_angle += CAMERA_PAN_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_RIGHT)
            @player.view_angle -= CAMERA_PAN_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_W)
            @player.position += @view_vector * PLAYER_MOVEMENT_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_S)
            @player.position -= @view_vector * PLAYER_MOVEMENT_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_A)
            @player.position -= @right_vector * PLAYER_MOVEMENT_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_D)
            @player.position += @right_vector * PLAYER_MOVEMENT_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_SPACE) # jump
            if (@player.position[1] == @FLOOR_HEIGHT)
                @player.velocity += Vector[0, 1.8, 0]
            end
        end
        if Gosu.button_down?(Gosu::KB_LEFT_CONTROL)
            @player.height_vector[1] = 0.5
        else
            @player.height_vector[1] = 1
        end
        if Gosu.button_down?(Gosu::KB_ESCAPE)
            close()
        end
        # Physics:
        @player.position += @player.velocity * DT
        @player.velocity += @GRAVITY * DT
        if (@player.position[1] < @FLOOR_HEIGHT)
            @player.velocity = Vector.zero(3)
            @player.position[1] = @FLOOR_HEIGHT
        end
        # printf("Position: %.2f, %.2f, %.2f\n", *@player.position)
        # printf("Velocity: %.2f, %.2f, %.2f\n", *@player.velocity)

    end
  
    # overriden Gosu::Window function
    # drawing calls go here
    def draw
        recalculate_render_variables()
        draw_walls(@walls)
        draw_floor()
    end

    # draw walls to screen
    def draw_walls(wall_vertices)
        wall_vertices.each do |wall|
            screen_coordinates = Array.new(4, Vector.zero(2))
            z = 0
            nil_coordinate = false
            for i in 0..3
                screen_coordinates[i] = get_screen_coordinates(wall[i])
                if screen_coordinates[i] == nil
                    nil_coordinate = true
                    break
                end
                screen_coordinates[i] *= RESOLUTION[0] # TODO: allow non-square screen - use aspect ratio
                z += screen_coordinates[i][2]
            end
            if (!nil_coordinate)
                z /= 4.0
                z = 1-z
                # puts("Screen coordinates: " + screen_coordinates.to_s())
                # TODO: store wall colour either as global value or per vertex
                Gosu.draw_quad(
                    screen_coordinates[0][0], screen_coordinates[0][1], @wall_colour_b,
                    screen_coordinates[1][0], screen_coordinates[1][1], @wall_colour_b,
                    screen_coordinates[2][0], screen_coordinates[2][1], @wall_colour_a,
                    screen_coordinates[3][0], screen_coordinates[3][1], @wall_colour_a,
                    z
                    )
            end
        end
    end
    
    # draw the floor (drawn last, behind everything)
    # probably doesn't deserve its own function
    def draw_floor()
        # floor will always cover bottom half of screen
        Gosu.draw_rect(0, RESOLUTION[1]/2.0, RESOLUTION[0], RESOLUTION[1], @floor_colour, -256.0)
    end

    # determine the screen coordinates that a point translates to
    def get_screen_coordinates(point)
        # puts("Point: " + point.to_s())
        # move point into player space
        point -= (@player.position + @player.height_vector)

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

        # transform into screen coordinates (z becomes depth)
        a = Vector[intersect_point[0], -intersect_point[1], z] # y axis flipped
        screen_coordinates = a + Vector[0.5, 0.5, 0.0]
        # puts("Screen coordinates: " + screen_coordinates.to_s())
        # if z < 0 r z > 1 coordinate is outside viewing frustrum
        return screen_coordinates
    end

    def recalculate_render_variables
        @rotation_matrix = get_rotation_matrix(@player.view_angle)
        @reverse_rotation_matrix = get_rotation_matrix(-@player.view_angle)
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

        # WARNING: Currently entire face will not be rendered if any point is behind view plane

        # if p0 * l <= 0 point is behind player
        if plane.point.dot(gradient) <= 0 # possibly test is point is in reverse viewing frustrum instread? (compare to dot of screen edge)
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
    def load_walls(filename)
        walls = []
        file = File.open(filename, "r")
        while !file.eof? do
            # load two vectors from the file and store them as a wall
            v1 = load_vector(file)
            v3 = load_vector(file)
            # create other two vertices from first two
            v2 = Vector[v3[0], v1[1], v3[2]]
            v4 = Vector[v1[0], v3[1], v1[2]]
            walls.push([v1, v2, v3, v4])
        end
        file.close()
        return walls
    end
    # loads a vector in from a txt file
    def load_vector(file_object)
        # vectors are stored as 'x,z,y'
        vector = Vector.elements(file_object.readline().split(',').map(&:to_f))
        # swap y and z coordinates
        vector[1], vector[2] = vector[2], -vector[1]
        return vector
    end
end

def main()
    MyGame.new.show()
end

if __FILE__ == $0
    main()
end