require 'gosu'

Gosu::Color::PURPLE = Gosu::Color.new 0xFF7A00BE

class Zombies
  VERSION = '1.0.0'

  def self.run
    window = GameWindow.new
    window.show
  end
end

class GameWindow < Gosu::Window
  if true then
    W, H, FULL = Gosu::screen_width, Gosu::screen_height, true
  else
    W, H, FULL = 800, 600, false
  end

  PEOPLE   = 300
  WARRIORS = 5
  ZOMBIES  = 2

  attr_reader :people
  attr_reader :humans
  attr_accessor :paused
  alias :paused? :paused

  def initialize
    @people, @humans = [], []
    @paused = false

    super W, H, FULL

    self.caption = "Zombie Epidemic Simulator"

    PEOPLE.times do
      people << Person.new(self)
    end

    ZOMBIES.times do
      people[rand people.size].infect!
    end

    WARRIORS.times do
      people[rand people.size].extend Warrior
    end

    humans.push(*people[0..-2])
  end

  def rect x1, y1, x2, y2, c
    draw_quad(x1, y1, c,
              x2, y1, c,
              x1, y2, c,
              x2, y2, c)
  end

  def update
    people.each do |p|
      p.move
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
    when Gosu::KbEscape then
      close
    when Gosu::KbSpace then
      self.paused = ! self.paused
    end
  end

  def needs_redraw?
    not paused?
  end
end

class Person
  W, H, V, DA = 10, 10, 2, 30
  W2, H2, DA2 = W/2, H/2, DA/2

  attr_reader :window
  attr_accessor :x, :y, :v, :a, :neighbors, :panicked
  alias :panicked? :panicked

  def initialize window
    @window = window
    @panicked = false
    @neighbors = []

    self.x = rand window.width
    self.y = rand window.height

    self.v, self.a = V, rand(360)
  end

  def sight
    50
  end

  def da;  DA; end
  def da2; DA2; end
  def w2;  W2; end
  def h2;  H2; end

  def _move
    dx, dy = Gosu::offset_x(a, v), Gosu::offset_y(a, v)
    self.x = (x + dx).limit_to(0, window.width  - w2)
    self.y = (y + dy).limit_to(0, window.height - h2)
  end

  def move
    if panicked? then
      panic
    else
      self.a += rand(da) - da2
      self.a = Gosu::angle(x, y, window.width/2, window.height/2) if near_edge?
    end

    _move
  end

  def panic
    self.a += rand(2*da) - da
    self.panicked -= 1
    self.calm! if self.panicked == 0
  end

  def draw
    window.rect l, t, r, b, color

    # c = Gosu::Color::BLUE
    # dx, dy = Gosu.offset_x(a, w2), Gosu.offset_y(a, h2)
    # window.draw_line x, y, c, x+dx, y+dy, c
  end

  def - o
    Gosu.distance(x, y, o.x, o.y)
  end

  def infect!
    window.humans.delete self
    extend Zombie
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
  def panic!
    # no brains... no panic
  end

  def color
    if neighbors.empty?
      Gosu::Color::RED
    else
      Gosu::Color::PURPLE
    end
  end

  def move
    visible = window.humans.find_all { |op| self - op < op.sight }
    visible.each { |op| op.panic! } # FIX: this should be pull, not push

    self.neighbors.replace visible.find_all { |op|
      not Zombie === op and self - op < self.sight # think "smell"
    }.sort_by { |op| self - op }

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

    _move
  end

  def sight # more like smell
    super / 2
  end

  def v
    super / 2
  end
end

module Warrior
  def color
    Gosu::Color::WHITE
  end

  def sight
    100
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

  def move
    self.neighbors.replace window.people.find_all { |op|
      Zombie === op and self - op < self.sight
    }.sort_by { |op| self - op }

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

    _move
  end
end

class Numeric
  def limit_to min, max
    [min, [self, max].min].max
  end
end
