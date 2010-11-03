require "minitest/autorun"
require "zombies"
require "set"

class SpatialHash < Array
  attr_reader :width, :height, :unit
  def initialize width, height, unit
    @width, @height, @unit = width, height, unit

    cells = (height / unit) * (width / unit)

    super(cells) { Set.new }
  end

  def key x, y
    x = x.limit_to(0, width - 1)
    y = y.limit_to(0, height - 1)

    x = x.to_i / unit
    y = y.to_i / unit
    b = width  / unit
    y * b + x
  end

  def [] x, y = nil
    x, y = *x unless y
    raise ArgumentError, "need x,y or [x,y]" unless y
    at key(x, y)
  end
end

class TestZombies < MiniTest::Unit::TestCase
  attr_accessor :p

  def setup
    @p = Person.new nil, 37, 42
  end

  def test_tl
    assert_equal [32, 37], p.tl
  end

  def test_tr
    assert_equal [42, 37], p.tr
  end

  def test_bl
    assert_equal [32, 47], p.bl
  end

  def test_br
    assert_equal [42, 47], p.br
  end
end

class TestSpatialHash < MiniTest::Unit::TestCase
  attr_accessor :p, :h, :sw, :sh, :u

  def setup
    srand 0
    @p = Person.new nil, 77, 82
    @sw, @sh = Gosu.screen_width, Gosu.screen_height
    @u = 80
    @h = SpatialHash.new @sw, @sh, @u
  end

  def test_prototype
    h[p.tl] << p
    h[p.tr] << p
    h[p.bl] << p
    h[p.br] << p

    assert_equal [p], h[p.tl].to_a
    assert_equal [p], h[p.tr].to_a
    assert_equal [p], h[p.bl].to_a
    assert_equal [p], h[p.br].to_a
  end

  def test_key
    assert_equal   0, h.key(*p.tl)
    assert_equal   1, h.key(*p.tr)
    assert_equal  16, h.key(*p.bl)
    assert_equal  17, h.key(*p.br)
    assert_equal 159, h.key(1281, 801)
  end

  def test_sanity
    assert_in_delta 14.142, Gosu.distance(0, 0, 10, 10)

    srand 0

    people = (0...10_000).map { Person.new nil, rand(sw), rand(sh) }

    x = people.map { |op| [op.x, op.y] }

    assert_equal([[684, 559], [1216, 763], [1033, 723], [599, 70], [314, 705]],
                 x.first(5))

    people.each do |op|
      h[op.tl] << op
      h[op.tr] << op
      h[op.bl] << op
      h[op.br] << op
    end

    op        = h[0,0].sort_by { |oop| [oop.x, oop.y] }.first
    neighbors = h[op.tl] - [op] + h[op.tr] + h[op.bl] + h[op.br] - [op]
    visible   = neighbors.find_all { |oop| op - oop < op.sight }

    assert_equal  1, op.x
    assert_equal 23, op.y
    assert_equal 50, op.sight
    assert_equal 82, h[0,0].size
    assert_equal 81, neighbors.size
    assert_equal 38, visible.size
  end
end
