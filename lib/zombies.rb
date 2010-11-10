require 'gosu'

class Zombies < Gosu::Window
  VERSION = '1.0.0'

  if $DEBUG then
    W, H, FULL, U = 800, 600, false, 50
  else
    W, H, FULL, U = Gosu::screen_width, Gosu::screen_height, true, 80
  end

  # Tweakables:

  PEOPLE       = $DEBUG ? 100 : 200
  PRIESTS      = 5
  ZOMBIES      = 5
  BULLY_LIMIT  = 5
  PERSON_SIGHT = 50
  ZOMBIE_SIGHT = 40
  PRIEST_SIGHT = 2*U

  attr_reader :people
  attr_reader :humans
  attr_accessor :paused
  alias :paused? :paused

  def self.run n = nil
    window = Zombies.new n
    window.show
  end

  def initialize n = nil
    srand 42 if $DEBUG

    @t0 = Gosu.milliseconds
    @fps = FPSCounter.new
    @people, @humans = [], []
    @paused = false

    super W, H, FULL

    self.caption = "Zombie Epidemic Simulator"

    (n || PEOPLE).to_i.times do
      people << Person.new(self)
    end

    people[0...ZOMBIES].each do |person|
      person.infect!
    end

    people[ZOMBIES...ZOMBIES+PRIESTS].each do |person|
      person.fight!
    end

    humans.push(*people[ZOMBIES..-1])

    # randomize them so that priest/zombie battles are even
    people.replace people.sort_by { rand }
  end

  def priests myself = nil, &b
    result = people.grep Priest
    result.delete myself if myself
    result = result.find_all(&b) if b
    result
  end

  def zombies myself = nil, &b
    result = people.grep Zombie
    result.delete myself if myself
    result = result.find_all(&b) if b
    result
  end

  def calculate_fps
    return if paused?

    @fps.register_tick
    t1 = Gosu.milliseconds / 2000
    if t1 != @t0 then
      p @fps.fps
      @t0 = t1
    end
  end

  def update
    calculate_fps

    people.each do |p|
      p.update
    end unless paused?

    self.paused = true if humans.empty? or not people.any? { |p| Zombie === p }
  end

  def draw
    if $DEBUG then
      c = Gosu::Color::DK_GRAY
      (0..W).step(U) do |x|
        draw_line x, 0, c, x, H, c
      end
      (0..H).step(U) do |y|
        draw_line 0, y, c, W, y, c
      end
    end
    people.each do |person|
      person.draw
    end
  end

  def button_down id
    case id
    when Gosu::KbD, Gosu::KbH then
      $DEBUG = ! $DEBUG
    when Gosu::KbEscape, Gosu::KbX then
      close
    when Gosu::KbSpace then
      self.paused = ! self.paused
    when Gosu::MsLeft then
      if paused? then
        fake = Person.new(self, mouse_x, mouse_y)
        hits = people.find_all { |p| (fake - p).abs < fake.w }
        p hits
        p :people => hits.map { |p| people.index(p) }
        p :humans => hits.map { |p| humans.index(p) }
      end
    end
  end

  def needs_cursor?
    paused?
  end
end

class Person
  W, H, V, DA = 10, 10, 2, 30
  W2, H2, DA2 = W/2, H/2, DA/2

  W_MIN, W_MAX = W2, Zombies::W - W2 - 1
  H_MIN, H_MAX = H2, Zombies::H - H2 - 1

  attr_reader :window
  attr_accessor :x, :y, :v, :a, :neighbors, :panicked
  attr_accessor :chases
  alias :panicked? :panicked

  def initialize window, x = nil, y = nil
    @window = window
    @panicked = false
    @neighbors = []
    @chases = 0

    # for 800 I want (6 .. 794)
    # or:            (0 .. 800 - W - 2) + 5 + 1

    self.x = x || rand(window.width  - W - 2) + W2 + 1
    self.y = y || rand(window.height - H - 2) + H2 + 1

    self.v, self.a = V, rand(360)
  end

  def sight
    Zombies::PERSON_SIGHT
  end

  def da;  DA;  end
  def da2; DA2; end
  def w;   W;   end
  def w2;  W2;  end
  def h2;  H2;  end

  def move
    dx, dy = Gosu.offset_xy a, v
    self.x = (x + dx).limit_to(W_MIN, W_MAX)
    self.y = (y + dy).limit_to(H_MIN, H_MAX)
  end

  def update
    update_neighbors
    change_direction
    move
    attack
  end

  def update_neighbors
  end

  def change_direction
    if panicked? then
      panic
    else
      self.a += rand(da) - da2
      move_away_from_wall if near_edge?
    end
  end

  def attack
  end

  def hunt
    closest = neighbors.first
    self.a = Gosu::angle(x, y, closest.x, closest.y)
  end

  def move_away_from_wall
    self.a = Gosu::angle(x, y, window.width/2, window.height/2)
  end

  def panic
    self.a += rand(2*da) - da
    self.panicked -= 1
    self.calm! if self.panicked == 0
  end

  def draw
    window.draw_rect l, t, r, b, color
  end

  def draw_sight
    window.draw_circle x, y, sight, Gosu::Color::GRAY, 0
  end

  def - o
    Gosu.distance x, y, o.x, o.y
  end

  def infect!
    window.humans.delete self
    extend Zombie
  end

  def fight!
    extend Priest
  end

  def panic!
    self.panicked = 10
    self.v = V * 2
  end

  def calm!
    self.panicked = false
    self.v = V
    self.chases += 1
    self.fight! if chases > Zombies::BULLY_LIMIT
  end

  def touching? o
    self - o < W
  end

  def r; x + W2; end
  def l; x - W2; end
  def t; y - H2; end
  def b; y + H2; end

  def tl; [l, t]; end
  def tr; [r, t]; end
  def bl; [l, b]; end
  def br; [r, b]; end

  def near_edge?
    x <= W_MIN or y <= H_MIN or x >= W_MAX or y >= H_MAX
  end

  def color
    if panicked? then
      Gosu::Color::YELLOW
    else
      Gosu::Color::GRAY
    end
  end
end

module Zombie
  def draw
    super
    draw_sight if $DEBUG
  end

  def panic!
    # no brains... no panic
  end

  def color
    if neighbors.empty?
      Gosu::Color::DARK_GREEN
    else
      Gosu::Color::PURPLE
    end
  end

  def update_neighbors
    visible = window.humans.find_all { |op| self - op < op.sight }
    visible.each { |op| op.panic! } # FIX: this should be pull, not push

    self.neighbors.replace visible.find_all { |op|
      self - op < self.sight # think "smell"
    }.sort_by { |op| self - op }
  end

  def change_direction
    if neighbors.empty? then
      self.a += rand(da) - da2
    else
      hunt
    end
  end

  def attack
    neighbors.each do |op|
      break unless touching? op
      op.infect!
    end
  end

  def sight # more like smell
    Zombies::ZOMBIE_SIGHT
  end

  def v
    super / 2
  end

  def inspect
    super.gsub(/Person/, 'Zombie')
  end
end

module Priest
  def draw
    super
    draw_sight if $DEBUG
  end

  def color
    if neighbors.empty?
      Gosu::Color::WHITE
    else
      Gosu::Color::RED
    end
  end

  def sight
    Zombies::PRIEST_SIGHT
  end

  def v
    super * 1.25
  end

  def panic!
    # um... no
  end

  def infect!
    @hp ||= 50
    @hp -= 1
    super if @hp == 0
  end

  def update_neighbors
    self.neighbors.replace window.zombies { |op| self - op < self.sight }.
      sort_by { |op| self - op }
  end

  def change_direction
    if neighbors.empty? then
      self.a =
        if near_edge? then
          move_away_from_wall
        elsif op = window.priests(self) { |op| self - op < self.sight }.first
          Gosu::angle(op.x, op.y, x, y)
        else
          self.a + rand(da) - da2
        end
    else
      hunt
    end
  end

  def attack
    neighbors.each do |op|
      break unless touching? op
      window.people.delete op
    end
  end

  def inspect
    super.gsub(/Person/, 'Priest')
  end
end

class Numeric
  def limit_to min, max
    self < min ? min : self > max ? max : self
  end
end

module Gosu
  Color::PURPLE     = Gosu::Color.new 0xFF7A00BE
  Color::DARK_GREEN = Gosu::Color.new 0xff006600
  Color::DK_GRAY    = Gosu::Color.new 0xff333333

  def self.offset_xy a, r
    return Gosu::offset_x(a, r), Gosu::offset_y(a, r)
  end

  class Window
    def draw_rect x1, y1, x2, y2, c
      draw_quad(x1, y1, c,
                x2, y1, c,
                x1, y2, c,
                x2, y2, c)
    end

    require 'inline'
    inline :C do |b|
      b.add_compile_flags "-x c++"
      b.add_compile_flags "-Igosu-0.7.25"
      b.add_compile_flags "-I/usr/local/Cellar/boost/1.44.0/include"
      b.include '"Gosu/Gosu.hpp"'

      b.c <<-EOC
        void draw_circle(double x, double y, double r, VALUE c, int z) {
          Gosu::AlphaMode mode = Gosu::amDefault;
          Gosu::Window * w;
          Gosu::Color * xc;
          double dx, dy, xx = 0, yy = -r, da = 290 / r + 4.5;

          Data_Get_Struct(self, Gosu::Window, w);
          Data_Get_Struct(   c, Gosu::Color, xc);

          for (double a = da, max = 360.0 + da; a <= max; a += da) {
            dx = Gosu::offsetX(a, r);
            dy = Gosu::offsetY(a, r);
            w->graphics().drawLine(x+xx, y+yy, *xc, x+dx, y+dy, *xc, z, mode);
            xx = dx;
            yy = dy;
          }
        }
      EOC
    end
  end
end

class FPSCounter
  attr_reader :fps

  def initialize
    @current_second = Gosu::milliseconds / 1000
    @accum_fps = 0
    @fps = 0
  end

  def register_tick
    @accum_fps += 1
    current_second = Gosu::milliseconds / 1000
    if current_second != @current_second
      @current_second = current_second
      @fps = @accum_fps
      @accum_fps = 0
    end
  end
end
