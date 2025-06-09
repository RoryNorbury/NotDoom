# extend gosu functions structure chart
# 2 records
# 1 enumeration

require 'gosu'
require "matrix"

PI = Math::PI
RESOLUTION = [640, 640]
CAMERA_PAN_SPEED = PI/2 / 60
PLAYER_MOVEMENT_SPEED = 2.0
ENEMY_MOVEMENT_SPEED = 2.0
MAX_RENDER_DISTANCE = 1024.0
MIN_RENDER_DISTANCE = 0.0001
PLAYER_HITBOX_SIZE = 1.1

# Combat constants
GUN_SCALE = 3
GUN_COOLDOWN = (0.2 * 60).to_i()
GUN_ANIMATION_TIME = (0.1 * 60).to_i()
MAX_GUN_RANGE = 100
ENEMY_REACH = 1
DAMAGE_COOLDOWN = 0.5 * 60

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
    attr_accessor :position, :velocity, :view_angle, :height_vector, :health
    def initialize()
        @position = Vector.zero(3)
        @velocity = Vector.zero(3)
        @view_angle = 0
        @height_vector = Vector[0, 1, 0]
        @health = 3
    end
end

class Enemy
    attr_accessor :position, :texture, :dimensions, :dead, :transparency
    def initialize(position)
        @position = position
        @dimensions = [1.0, 1.5]
        # used for death animation
        @dead = false
        @transparency = 0
    end
end

Clock_array_length = 5
module Clock_index
    Load_file = 0
    User_click = 1
    User_keyboard = 2
    Gun_cooldown = 3
    Damage_cooldown = 4
end

class Intersect_data
    attr_accessor :p1, :p2, :m, :c, :minX, :maxX, :minY, :maxY
    def initialize(p1, p2)
        @p1 = p1
        @p2 = p2
        @minX = [p1[0], p2[0]].min
        @maxX = [p1[0], p2[0]].max
        @minY = [p1[1], p2[1]].min
        @maxY = [p1[1], p2[1]].max
        # Note: if line is vertical, c represents constant x value
        if (p1[0] == p2[0])
            @m = nil
            @c = p1[0]
        else
            @m = (p1[1] - p2[1]) / (p1[0] - p2[0])
            @c = p1[1] - @m * p1[0]
        end
    end
    def intersects?(other)
        # line is vertical
        if @m == nil
            if other.m == nil
                return(@c == other.c)
            else
                # intersect point
                ix, iy = @c, other.m * @c + other.c
                return ((iy >= @minY) && (iy <= @maxY) && (ix >= other.minX) && (ix <= other.maxX) && (iy >= other.minY) && (iy <= other.maxY))
            end
        # other line is vertical
        elsif other.m == nil
            # intersect point
            ix, iy = other.c, @m * other.c + @c
            return ((iy >= other.minY) && (iy <= other.maxY) && (ix >= @minX) && (ix <= @maxX) && (iy >= @minY) && (iy <= @maxY))
        # lines are the same
        elsif (@m == other.m)
            if (@c == other.c)
                return ((@minX <= other.maxX) && (@maxX >= other.minX) && (@minY <= other.maxY) && (@maxY >= other.minY))
            else
                return false
            end
        # if lines are actually normal
        else
            # intersect point
            ix = (other.c - @c) / (@m - other.m)
            iy = @m*ix + @c
            return ((ix >= @minX) && (ix <= @maxX) && (iy >= @minY) && (iy <= @maxY) && (ix >= other.minX) && (ix <= other.maxX) && (iy >= other.minY) && (iy <= other.maxY))
        end
    end
    # get intersect point of two segments (nil if no intersect)
    def intersect_point(other)
        # line is vertical
        if @m == nil
            if other.m == nil
                return nil
            else
                # intersect point
                ix, iy = @c, other.m * @c + other.c
                if ((iy >= @minY) && (iy <= @maxY) && (ix >= other.minX) && (ix <= other.maxX) && (iy >= other.minY) && (iy <= other.maxY))
                    return Vector[ix, iy]
                end
            end
        # other line is vertical
        elsif other.m == nil
            # intersect point
            ix, iy = other.c, @m * other.c + @c
            if ((iy >= other.minY) && (iy <= other.maxY) && (ix >= @minX) && (ix <= @maxX) && (iy >= @minY) && (iy <= @maxY))
                return Vector[ix, iy]
            end
        # lines are the same
        elsif (@m == other.m)
            return nil
        # if lines are actually normal
        else
            # intersect point
            ix = (other.c - @c) / (@m - other.m)
            iy = @m*ix + @c
            if ((ix >= @minX) && (ix <= @maxX) && (iy >= @minY) && (iy <= @maxY) && (ix >= other.minX) && (ix <= other.maxX) && (iy >= other.minY) && (iy <= other.maxY))
                return Vector[ix, iy]
            end
        end
        return nil
    end
end

class MyGame < Gosu::Window
    attr_reader :player, :walls
    def initialize
        
        super(*RESOLUTION)
        self.caption = "Not Doom"

        @player = Player.new()

        # random number generator
        @rng = Random.new()

        # font used for drawing text
        @screen_font = Gosu::Font.new(24, {:name => "Aptos"})

        # sprites
        # Baron of hell sprite from Doom 95. Credit: id Software, sourced from https://www.spriters-resource.com/fullview/187360/
        @enemy_sprite = Gosu::Image.new("sources/baron_of_hell.png")
        # Pistol sprite from Doom 95. Credit: id Software, sourced from https://www.spriters-resource.com/fullview/4111/
        @gun_sprite = Gosu::Image.new("sources/gun.png")
        @gun_firing_sprite = Gosu::Image.new("sources/gun_firing.png")
        # Health indication sprites
        @full_heart_sprite = Gosu::Image.new("sources/full_heart.png")
        @empty_heart_sprite = Gosu::Image.new("sources/empty_heart.png")
        
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
        @sky_colour = Gosu::Color.new(255, 50, 20, 0)
        @wall_colour_a = Gosu::Color.new(255, 100, 100, 100)
        @wall_colour_b = Gosu::Color.new(255, 40, 40, 40)

        # list of enemies
        @enemy_count = 8
        @enemies = []

        # list of vertex quads for walls, in anticlockwise order
        @level_filename = "level.txt"
        @walls = load_walls(@level_filename)

        # array for storing cycle count
        @clock_array = Array.new(Clock_array_length, 0)
        @clock_array[Clock_index::Gun_cooldown] = GUN_COOLDOWN
    end
    
    def update_clock_array()
        @clock_array.length.times do |i|
            @clock_array[i] += 1  
        end  
    end

    # happens before update
    # happens on key press but not key hold
    def button_down(id)
        case id
        # reset position
        when Gosu::KB_R
            @player.position = Vector.zero(3)
        # close
        when Gosu::KB_ESCAPE
            close()
        # fire gun
        when Gosu::KB_SPACE
            if @clock_array[Clock_index::Gun_cooldown] > GUN_COOLDOWN
                fire_gun()
                @clock_array[Clock_index::Gun_cooldown] = 0
            end
        end
    end

    # overriden Gosu::Window function
    # frame-by-frame logic goes here
    def update
        # set horizontal velocity to 0
        @player.velocity[0] = 0
        @player.velocity[2] = 0

        # handle clock array
        update_clock_array()
        if (@clock_array[Clock_index::Load_file] > 15)
            @walls = load_walls(@level_filename)
            @clock_array[Clock_index::Load_file] = 0
        end

        # keyboard input handling
        movement_speed_multiplier = 1
        if Gosu.button_down?(Gosu::KB_LEFT_SHIFT)
            movement_speed_multiplier = 3 * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_LEFT)
            @player.view_angle += CAMERA_PAN_SPEED
        end
        if Gosu.button_down?(Gosu::KB_RIGHT)
            @player.view_angle -= CAMERA_PAN_SPEED
        end
        if Gosu.button_down?(Gosu::KB_W)
            @player.velocity += @view_vector * PLAYER_MOVEMENT_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_S)
            @player.velocity -= @view_vector * PLAYER_MOVEMENT_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_A)
            @player.velocity -= @right_vector * PLAYER_MOVEMENT_SPEED * movement_speed_multiplier
        end
        if Gosu.button_down?(Gosu::KB_D)
            @player.velocity += @right_vector * PLAYER_MOVEMENT_SPEED * movement_speed_multiplier
        end
        # useful for t-bagging
        if Gosu.button_down?(Gosu::KB_LEFT_CONTROL)
            @player.height_vector[1] = 0.5
        else
            @player.height_vector[1] = 1
        end

        # collision checks 
        update_player_position()

        # enemy logic
        do_enemy_logic()
    end
    
    def fire_gun()
        # intersect_data for bullet
        bullet_data = Intersect_data.new(to_2d_vector(@player.position), to_2d_vector(@player.position + @view_vector * MAX_GUN_RANGE))
        # find distance to wall hit by shot
        closest = MAX_GUN_RANGE.to_f()
        @intersect_data.each do |data|
            intersect_point = bullet_data.intersect_point(data)
            if (intersect_point != nil)
                distance = (intersect_point - to_2d_vector(@player.position)).magnitude()
                if (distance < closest)
                    closest = distance
                end
            end
        end
        printf("Closest wall: %.3f\n", closest)
        # determine which enemy was hit by shot, if any
        i = 0
        hit_enemy = nil
        @enemies.each do |enemy|
            if !enemy.dead
                data = Intersect_data.new(to_2d_vector(enemy.position - @right_vector * enemy.dimensions[0] / 2), to_2d_vector(enemy.position + @right_vector * enemy.dimensions[0] / 2))
                intersect_point = bullet_data.intersect_point(data)
                if (intersect_point != nil)
                    distance = (intersect_point - to_2d_vector(@player.position)).magnitude()
                    if (distance < closest)
                        hit_enemy = i
                        closest = distance
                        printf("Enemy distance: %.3f\n", closest)
                    end
                end
            end
            i += 1
        end
        # flag hit enemy as dead
        if (hit_enemy != nil)
            printf("Hit enemy %i\n", hit_enemy)
            @enemies[hit_enemy].dead = true
        end
    end

    def do_enemy_logic
        # spawn new enemy if needed
        while (@enemies.length < @enemy_count)
            position = Vector[@rng.rand(20.0) - 10.0, 0, @rng.rand(20.0) - 10.0]
            @enemies.push(Enemy.new(position))
        end

        i = 0
        kill_list = []
        @enemies.each do |enemy|
            # if alive and can see player
            if (!enemy.dead && (can_see_player(enemy)))
                # move towards the player if they are out of reach
                if ((@player.position - enemy.position).magnitude > ENEMY_REACH)
                    printf("Enemy %i moving\n", i)
                    enemy.position += (@player.position - enemy.position).normalize() * ENEMY_MOVEMENT_SPEED * DT
                # attack the player if they are in range
                else
                    if (@clock_array[Clock_index::Damage_cooldown] > DAMAGE_COOLDOWN)
                        @player.health -= 1
                        @clock_array[Clock_index::Damage_cooldown] = 0
                    end
                end
            end

            # if dead, increase transparency
            if enemy.dead
                enemy.transparency += 0.05
                if enemy.transparency >= 1
                    kill_list.push(i)
                end
            end
            i += 1
        end
        kill_list.each do |i|
            @enemies.delete_at(i)
        end
    end

    def can_see_player(enemy)
        # enemy and player intersect data
        intersect_data = Intersect_data.new(to_2d_vector(@player.position), to_2d_vector(enemy.position))
        visible = true
        @intersect_data.each do |data|
            if (intersect_data.intersects?(data))
                visible = false
                break
            end
        end
        return visible
    end

    # moves player with velocity
    def update_player_position()
        # Physics:
        new_position = @player.position + @player.velocity * DT
        @player.velocity += @GRAVITY * DT

        # make sure player is above the floor
        if (new_position[1] < @FLOOR_HEIGHT)
            @player.velocity[1] = 0
            new_position[1] = @FLOOR_HEIGHT
        end

        # check collision with walls

        # use AABBs for broad phase
        # and line-line intersect test for narrow phase
        # player intersect data
        px, pz = new_position[0], new_position[2]
        player_data = [
            Intersect_data.new(Vector[px - PLAYER_HITBOX_SIZE/2, pz - PLAYER_HITBOX_SIZE/2], Vector[px + PLAYER_HITBOX_SIZE/2, pz - PLAYER_HITBOX_SIZE/2]),
            Intersect_data.new(Vector[px + PLAYER_HITBOX_SIZE/2, pz - PLAYER_HITBOX_SIZE/2], Vector[px + PLAYER_HITBOX_SIZE/2, pz + PLAYER_HITBOX_SIZE/2]),
            Intersect_data.new(Vector[px + PLAYER_HITBOX_SIZE/2, pz + PLAYER_HITBOX_SIZE/2], Vector[px - PLAYER_HITBOX_SIZE/2, pz + PLAYER_HITBOX_SIZE/2]),
            Intersect_data.new(Vector[px - PLAYER_HITBOX_SIZE/2, pz + PLAYER_HITBOX_SIZE/2], Vector[px + PLAYER_HITBOX_SIZE/2, pz - PLAYER_HITBOX_SIZE/2])
        ]
        
        # narrow phase
        collision = false
        @intersect_data.each do |data|
            if collision
                break
            end
            player_data.each do |pdata|
                if collision
                    break
                end
                if (pdata.intersects?(data))
                    collision = true
                end
            end
        end
        # if colliding with wall, set x and z back to previous values
        if collision
            new_position = Vector[@player.position[0], new_position[1], player.position[2]]
        end
        @player.position = new_position
    end

    # overriden Gosu::Window function
    # drawing calls go here
    def draw
        recalculate_render_variables()
        draw_walls(@walls)
        draw_enemies(@enemies)
        draw_background()
        draw_hud()
    end

    def draw_hud()
        draw_text()
        draw_gun()
        draw_hearts()
        if (@clock_array[Clock_index::Damage_cooldown] < DAMAGE_COOLDOWN)
            draw_bloody_screen()
        end
    end
    # draw info onto screen
    def draw_text()
        @screen_font.draw_text("FPS: " + Gosu.fps().to_s(), 5, 45, 1)
    end

    def draw_gun()
        if (@clock_array[Clock_index::Gun_cooldown] < GUN_ANIMATION_TIME)
            sprite = @gun_firing_sprite
        else
            sprite = @gun_sprite
        end
        x = (RESOLUTION[0] - sprite.width * GUN_SCALE) / 2
        y = RESOLUTION[1] - sprite.height * GUN_SCALE
        sprite.draw(x, y, 1, GUN_SCALE, GUN_SCALE)
    end

    def draw_hearts()
        i = 0
        padding = @full_heart_sprite.width * 0.1
        while i < 3
            if @player.health > i
                @full_heart_sprite.draw(padding + i * (@full_heart_sprite.width + padding), padding, 1)
            else
                @empty_heart_sprite.draw(padding + i * (@full_heart_sprite.width + padding), padding, 1)
            end
            i += 1
        end
    end

    def draw_bloody_screen
        colour = Gosu::Color.new((1 - (@clock_array[Clock_index::Damage_cooldown] / DAMAGE_COOLDOWN)) * 255, 200, 0, 0)
        Gosu::draw_rect(0, 0, *RESOLUTION, colour, 1)
    end

    # draw enemies to screen
    def draw_enemies(enemies)
        enemies.each do |enemy|
            # calculate vertices (only need two)
            v1 = enemy.position - @right_vector * enemy.dimensions[0] / 2
            v2 = enemy.position + @right_vector * enemy.dimensions[0] / 2
            v2[1] = enemy.dimensions[1]

            # screen coordinates
            s1 = get_screen_coordinates(v1)
            s2 = get_screen_coordinates(v2)
            if (s1 != nil && s2 != nil)
                colour = Gosu::Color.new((1-enemy.transparency)*255, 255, 255, 255)
                z = (s1[2])
                z = 1-z
                s1 *= RESOLUTION[0]
                s2 *= RESOLUTION[0]
                @enemy_sprite.draw_as_quad(
                    s2[0], s2[1], colour,
                    s1[0], s2[1], colour,
                    s1[0], s1[1], colour,
                    s2[0], s1[1], colour,
                    z)
            end
        end
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
                z += screen_coordinates[i][2]
                screen_coordinates[i] *= RESOLUTION[0] # TODO: allow non-square screen - use aspect ratio
            end
            if (!nil_coordinate)
                z /= 4.0
                z = 1-z
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
    
    # draw the floor and sky (drawn last, behind everything)
    # probably doesn't deserve its own function
    def draw_background()
        # floor will always cover bottom half of screen
        Gosu.draw_rect(0, RESOLUTION[1]/2.0, RESOLUTION[0], RESOLUTION[1]/2.0, @floor_colour, -256.0)
        #sky covers the other half
        Gosu.draw_rect(0, 0, RESOLUTION[0], RESOLUTION[1]/2.0, @sky_colour, -256.0)
    end


    # Drawing functions ---------------------------------------------------------------------------
    
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

        # transform into screen coordinates (z becomes depth)
        a = Vector[intersect_point[0], -intersect_point[1], z] # y axis flipped
        screen_coordinates = a + Vector[0.5, 0.5, 0.0]
        # if z < 0 r z > 1 coordinate is outside viewing frustrum
        return screen_coordinates
    end

    def recalculate_render_variables
        @rotation_matrix = get_rotation_matrix(@player.view_angle)
        @reverse_rotation_matrix = get_rotation_matrix(-@player.view_angle)
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
        # UPDATE: Somewhat fixed this by partitioning walls into smaler sections

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

    # create data used for intersection tests
    # makes intersect tests cheaper
    def generate_intersect_data(walls)
        intersect_data = []
        walls.each do |wall|
            p1 = to_2d_vector(wall[0])
            p2 = to_2d_vector(wall[2])
            intersect_data.push(Intersect_data.new(p1, p2))
        end
        return intersect_data
    end


    # Data loading functions ----------------------------------------------------------------------

    # load walls from file
    def load_walls(filename)
        walls = []
        file = File.open(filename, "r")
        while !file.eof? do
            # load two vectors from the file and store them as a wall
            v1 = load_vector(file)
            v2 = load_vector(file)
            walls.push(corners_to_vertices(v1, v2))
        end
        file.close()
        # create intersect data from unsplit walls
        @intersect_data = generate_intersect_data(walls)
        # split walls for better rendering
        walls = split_walls(walls)
        return walls
    end

    # splits a wall segment into many smaller segments
    def split_walls(walls)
        output = Array.new()
        walls.each do |wall|
            w1, w2 = wall[0], wall[2] # opposite corners of wall
            length = Math.sqrt((w1[0] - w2[0])**2 + (w1[2] - w2[2])**2)
            segment_count = length.ceil
            # z and x change per segment
            dx = (w2[0] - w1[0]) / segment_count
            dz = (w2[2] - w1[2]) / segment_count
            p1 = Vector[w1[0], w2[1], w1[2]]
            for i in 1..segment_count
                p0 = Vector[p1[0], w1[1], p1[2]]
                p1 = Vector[p1[0] + dx, w2[1], p1[2] + dz]
                output.push(corners_to_vertices(p0, p1))
            end
        end
        return output
    end

    # loads a vector in from a txt file
    def load_vector(file_object)
        # vectors are stored as 'x,z,y'
        vector = Vector.elements(file_object.readline().split(',').map(&:to_f))
        # swap y and z coordinates
        vector[1], vector[2] = vector[2], -vector[1]
        return vector
    end

    # convert two points to an array of four vectors that correspond to the corners of a wall
    def corners_to_vertices(v1, v2)
        # create other two vertices from first two
        v3 = Vector[v2[0], v1[1], v2[2]]
        v4 = Vector[v1[0], v2[1], v1[2]]
        return [v1, v3, v2, v4]
    end

    # get x and z components of 3d vector, useful for simple intersection tests
    def to_2d_vector(vector)
        return Vector[vector[0], vector[2]]
    end
end

def main()
    MyGame.new.show()
end

if __FILE__ == $0
    main()
end