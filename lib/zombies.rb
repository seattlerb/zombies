require 'gosu'

class Zombies
  VERSION = '1.0.0'

  def self.run
    window = GameWindow.new
    window.show
  end
end

class GameWindow < Gosu::Window
  W, H, FULL = Gosu::screen_width, Gosu::screen_height, true
  # W, H, FULL = 800, 600, false
  PEOPLE = 100
  SIGHT = 50
  SMELL = 25

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

    people.last.infect!

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

      if p.infected? then
        visible = humans.find_all { |op| p - op < SIGHT }
        visible.each { |op| op.panic! }
        p.neighbors = visible.find_all { |op| p - op < SMELL }.
          sort_by { |op| p - op }
      end
    end unless paused?

    self.paused = true if humans.empty?
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

class Numeric
  def limit_to min, max
    [min, [self, max].min].max
  end
end

class Person
  W, H, V, DA = 10, 10, 2, 30
  W2, H2, DA2 = W/2, H/2, DA/2

  attr_accessor :x, :y, :v, :a, :neighbors
  attr_reader :window
  attr_accessor :infected, :panicked
  alias :infected? :infected
  alias :panicked? :panicked

  def initialize window
    @window = window
    @infected = @panicked = false
    @neighbors = []

    self.x = rand window.width
    self.y = rand window.height

    self.v, self.a = V, rand(360)
  end

  def move
    if infected? then
      if neighbors.empty? then
        self.a += rand(DA) - DA2
      else
        neighbors.each do |op|
          op.infect! if touching? op
        end

        closest = neighbors.first
        self.a = Gosu::angle(x, y, closest.x, closest.y)
      end
    elsif panicked? then
      self.a += rand(2*DA) - DA
      self.panicked -= 1
      self.calm! if panicked == 0
    else
      self.a += rand(DA) - DA2
      self.a = Gosu::angle(x, y, window.width/2, window.height/2) if near_edge?
    end

    dx, dy = Gosu::offset_x(a, v), Gosu::offset_y(a, v)
    self.x = (x + dx).limit_to(0, window.width  - W2)
    self.y = (y + dy).limit_to(0, window.height - H2)
  end

  def draw
    window.rect l, t, r, b, color
  end

  def - o
    Gosu.distance(x, y, o.x, o.y)
  end

  def infect!
    self.infected = true
    self.v = V / 2
    window.humans.delete self
  end

  def panic!
    return if infected?
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
    ( l < W2 or
      t < H2 or
      r > window.width - W2 or
      b > window.height - H2 )
  end

  def color
    if infected? then
      Gosu::Color::RED
    elsif panicked? then
      Gosu::Color::YELLOW
    else
      Gosu::Color::WHITE
    end
  end
end
