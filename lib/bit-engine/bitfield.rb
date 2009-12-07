class BitField
  attr_reader :size, :field
  include Enumerable
  
  ELEMENT_WIDTH = 8 
  ALL_SET_VALUE = 2**8-1
  
  def initialize(size, field = nil)
    @size = size
    @field = field || Array.new(((size - 1) / ELEMENT_WIDTH) + 1, 0)
  end

  def self.create_with_data(data)
    size  = data.length * ELEMENT_WIDTH
    new(size, data)
  end

  class SizeMismatchError < StandardError; end;

  # intersection
  def &(b)
    raise SizeMismatchError if b.size != @size

    intersection = BitField.new(@size)
    
    b.field.each_with_index do |b_element, idx|
      intersection.field[idx] = b_element.to_i & @field[idx].to_i
    end

    intersection
  end

  def inverse
    inverse = BitField.new(@size)
    
    @field.each_with_index do |element, idx|
      inverse.field[idx] = element ^ ALL_SET_VALUE
    end

    inverse
  end
  
  # Set a bit (1/0)
  def []=(position, value)
    if value == 1
      @field[position / ELEMENT_WIDTH] |= 1 << (position % ELEMENT_WIDTH)
    elsif (@field[position / ELEMENT_WIDTH]) & (1 << (position % ELEMENT_WIDTH)) != 0
      @field[position / ELEMENT_WIDTH] ^= 1 << (position % ELEMENT_WIDTH)
    end
  end
  
  # Read a bit (1/0)
  def [](position)
    @field[position / ELEMENT_WIDTH] & 1 << (position % ELEMENT_WIDTH) > 0 ? 1 : 0
  end
  
  # Iterate over each bit
  def each(&block)
    @size.times { |position| yield self[position] }
  end

  def to_packed_s
    field.pack('C*')
  end

  # Returns the field as a string like "0101010100111100," etc.
  def to_s
    inject("") { |a, b| a + b.to_s }
  end
  
  # Clears the bitfield. More efficient than using Bitfield#each
  def clear
    @field.each_index { |i| @field[i] = 0 }
  end
  
  # Returns the total number of bits that are set
  # (The technique used here is about 6 times faster than using each or inject direct on the bitfield)
  def total_set
    @field.inject(0) { |a, byte| a += byte & 1 and byte >>= 1 until byte == 0; a }
  end
end
