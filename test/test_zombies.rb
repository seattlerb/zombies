require "minitest/autorun"
require "minitest/benchmark" if ENV['BENCH']
require "zombies"

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
  attr_accessor :person, :h, :sw, :sh, :u

  def setup
    srand 0
    @sw, @sh, @u = 800, 600, 50
    @person = Person.new nil, @u-2, @u-2

    @h = SpatialHash.new @sw, @sh, @u
  end

  def test_prototype
    h[person.tl] << person
    h[person.tr] << person
    h[person.bl] << person
    h[person.br] << person

    assert_equal [person], h[person.tl].to_a
    assert_equal [person], h[person.tr].to_a
    assert_equal [person], h[person.bl].to_a
    assert_equal [person], h[person.br].to_a
  end

  def test_key
    assert_equal [43, 43], person.tl
    assert_equal [53, 43], person.tr
    assert_equal [43, 53], person.bl
    assert_equal [53, 53], person.br

    assert_equal   0, h.key(*person.tl)
    assert_equal   1, h.key(*person.tr)
    assert_equal  16, h.key(*person.bl)
    assert_equal  17, h.key(*person.br)
    assert_equal 191, h.key(801, 601)
  end

  def test_sanity
    srand 0

    @sw, @sh, @u = 40, 30, 10
    @h = SpatialHash.new @sw, @sh, @u

    people = (0...100).map { Person.new nil, rand(sw), rand(sh) }

    x = people.map { |op| [op.x, op.y] }

    assert_equal([[0, 3], [3, 7], [19, 21], [36, 23], [24, 24]],
                 x.first(5))

    people.each do |op|
      h[op.tl] << op
      h[op.tr] << op
      h[op.bl] << op
      h[op.br] << op
    end

    zero = [0, 0]
    op        = h[zero].sort_by { |oop| [oop.x, oop.y] }.first
    neighbors = h[op.tl] - [op] + h[op.tr] + h[op.bl] + h[op.br] - [op]
    visible   = neighbors.find_all { |oop| op - oop < op.sight }

    assert_equal  0, op.x
    assert_equal 3, op.y
    assert_equal 50, op.sight
    assert_equal 27, h[zero].size # TODO: check this, seems high.
    assert_equal 26, neighbors.size
    assert_equal 26, visible.size

    new = people.map { |op|
      neighbors = h[op.tl] - [op] + h[op.tr] + h[op.bl] + h[op.br] - [op]
      visible   = neighbors.find_all { |oop| op - oop < op.sight }
      touching  = visible.find_all { |oop| op.touching? oop }
      touching.size
    }

    old = people.map { |op|
      visible  = people.find_all { |oop| op - oop < op.sight } - [op]
      touching = visible.find_all { |oop| op.touching? oop }
      touching.size
    }

    assert_equal old, new
  end

  attr_accessor :people

  def self.bench_range
    bench_linear 100, 1000, 100
  end

  def setup_bench n
    @people = (0...n).map { Person.new nil, rand(sw), rand(sh) }
  end

  def bench_collision_detection_old
    a, b, rr = assert_performance_power 0.95 do |n|
      setup_bench n

      people.each do |op|
        visible  = people.find_all { |oop| op - oop < op.sight } - [op]
        touching = visible.find_all { |oop| op.touching? oop }
      end
    end

    assert_in_epsilon 1.6e-6, a, 0.2
    assert_in_epsilon 2.1,    b, 0.2
  end

  def bench_spatial_hash_new
    assert_performance_power 0.95 do |n|
      setup_bench n

      people.each do |op|
        h[op.tl] << op
        h[op.tr] << op
        h[op.bl] << op
        h[op.br] << op
      end

      people.each do |op|
        neighbors = h[op.tl] - [op] + h[op.tr] + h[op.bl] + h[op.br] - [op]
        visible   = neighbors.find_all { |oop| op - oop < op.sight }
        touching  = visible.find_all { |oop| op.touching? oop }
      end
    end

    assert_in_epsilon 4.6e-6, a, 0.2
    assert_in_epsilon 1.7,    b, 0.2
  end
end
