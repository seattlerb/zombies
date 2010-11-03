require 'gosu'

class Zombies < Gosu::Window
  VERSION = '1.0.0'

  if $DEBUG then
    W, H, FULL = 800, 600, false
  else
    W, H, FULL = Gosu::screen_width, Gosu::screen_height, true
  end

  PEOPLE  = 300
  PRIESTS =  10
  ZOMBIES =   5

  PERSON_SIGHT = 50
  ZOMBIE_SIGHT = 25
  PRIEST_SIGHT = 100

  attr_reader :people
  attr_reader :humans
  attr_accessor :paused
  alias :paused? :paused

  def self.run
    window = Zombies.new
    window.show
  end

  def initialize
    @t0 = Gosu.milliseconds
    @fps = FPSCounter.new
    @people, @humans = [], []
    @paused = false

    super W, H, FULL

    self.caption = "Zombie Epidemic Simulator"

    PEOPLE.times do
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

  def draw_rect x1, y1, x2, y2, c
    draw_quad(x1, y1, c,
              x2, y1, c,
              x1, y2, c,
              x2, y2, c)
  end

  def draw_circle x, y, r, c
    xx, yy = Gosu.offset_xy 0, r

    (0..360).step(20) do |a|
      next if a == 0
      dx, dy = Gosu.offset_xy a, r
      draw_line x+xx, y+yy, c, x+dx, y+dy, c
      xx, yy = dx, dy
    end
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

  attr_reader :window
  attr_accessor :x, :y, :v, :a, :neighbors, :panicked
  alias :panicked? :panicked

  def initialize window, x = nil, y = nil
    @window = window
    @panicked = false
    @neighbors = []

    self.x = x || rand(window.width)
    self.y = y || rand(window.height)

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
    self.x = (x + dx).limit_to(0, window.width  - w2)
    self.y = (y + dy).limit_to(0, window.height - h2)
  end

  def update
    if panicked? then
      panic
    else
      self.a += rand(da) - da2
      self.a = Gosu::angle(x, y, window.width/2, window.height/2) if near_edge?
    end

    move
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
    window.draw_circle x, y, sight, Gosu::Color::GRAY
  end

  def - o
    Gosu.distance(x, y, o.x, o.y)
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
  end

  def touching? o
    self - o < W
  end

  def r; x + W2; end
  def l; x - W2; end
  def t; y - H2; end
  def b; y + H2; end

  def near_edge?
    ( l < w2 or
      t < h2 or
      r > window.width - w2 or
      b > window.height - h2 )
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
      not Zombie === op and self - op < self.sight # think "smell"
    }.sort_by { |op| self - op }
  end

  def update
    update_neighbors

    if neighbors.empty? then
      self.a += rand(da) - da2
    else
      neighbors.each do |op|
        break unless touching? op
        op.infect!
      end

      closest = neighbors.first
      self.a = Gosu::angle(x, y, closest.x, closest.y)
    end

    move
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
    self.neighbors.replace window.people.find_all { |op|
      Zombie === op and self - op < self.sight
    }.sort_by { |op| self - op }
  end

  def update
    update_neighbors

    if neighbors.empty? then
      self.a += rand(da) - da2
      self.a = Gosu::angle(x, y, window.width/2, window.height/2) if near_edge?
    else
      closest = neighbors.first
      self.a = Gosu::angle(x, y, closest.x, closest.y)
    end

    neighbors.each do |op|
      break unless touching? op
      window.people.delete op
    end

    move
  end

  def inspect
    super.gsub(/Person/, 'Priest')
  end
end

class Numeric
  def limit_to min, max
    [min, [self, max].min].max
  end
end

module Gosu
  Color::PURPLE     = Gosu::Color.new 0xFF7A00BE
  Color::DARK_GREEN = Gosu::Color.new 0xff006600

  def self.offset_xy a, r
    return Gosu::offset_x(a, r), Gosu::offset_y(a, r)
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
