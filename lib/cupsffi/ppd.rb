# The MIT License
#
# Copyright (c) 2011 Nathan Ehresman
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

class CupsPPD
  def initialize(printer_name)
    @file = CupsFFI::cupsGetPPD(printer_name)
    raise "No PPD found for #{printer_name}" if @file.nil?

    @pointer = CupsFFI::ppdOpenFile(@file)
    raise "Unable to open PPD #{file}" if @pointer.null?

    @ppd_file_s = CupsFFI::PPDFileS.new(@pointer)
  end

  def close
    CupsFFI::ppdClose(@pointer)
    File.unlink(@file)
  end

  def options
    options = []
    option_pointer = CupsFFI::ppdFirstOption(@pointer)
    while !option_pointer.null?
      option = CupsFFI::PPDOptionS.new(option_pointer)
      choices = []
      option[:num_choices].times do |i|
        choice = CupsFFI::PPDChoiceS.new(option[:choices] + (CupsFFI::PPDChoiceS.size * i))
        choices.push({
          :text => String.new(choice[:text]),
          :choice => String.new(choice[:choice])
        })
      end
      options.push({
        :keyword => String.new(option[:keyword]),
        :default_choice => String.new(option[:defchoice]),
        :text => String.new(option[:text]),
        :ui => String.new(option[:ui].to_s),
        :section => String.new(option[:section].to_s),
        :order => option[:order],
        :choices => choices
      })

      option_pointer = CupsFFI::ppdNextOption(@pointer)
    end
    options
  end
  
  def attributes
    attributes = []
    attr_ptr = @ppd_file_s[:attrs].read_pointer
    if !attr_ptr.null?
      @ppd_file_s[:attrs].get_array_of_pointer(0, @ppd_file_s[:num_attrs]).each do |attr_ptr|
        attribute = CupsFFI::PPDAttrS.new(attr_ptr)
        attributes.push({
          :name => String.new(attribute[:name]),
          :spec => String.new(attribute[:spec]),
          :text => String.new(attribute[:text]),
          :value => String.new(attribute[:value]),
        })
      end
    end
    attributes
  end
  
  def attribute(name, spec=nil)
    attributes = []
    attribute_pointer = CupsFFI::ppdFindAttr(@pointer, name, spec)
    while !attribute_pointer.null?
      attribute = CupsFFI::PPDAttrS.new(attribute_pointer)
      attributes.push({
        :name => String.new(attribute[:name]),
        :spec => String.new(attribute[:spec]),
        :text => String.new(attribute[:text]),
        :value => String.new(attribute[:value]),
      })
  
      attribute_pointer = CupsFFI::ppdFindNextAttr(@pointer, name, spec)
    end
    attributes
  end
  
  def page_size(name=nil)
    size_ptr = CupsFFI::ppdPageSize(@pointer, name)
    size = CupsFFI::PPDSizeS.new(size_ptr)
    if size.null?
      nil
    else
      {
        :marked => (size[:marked] != 0),
        :name => String.new(size[:name]),
        :width => size[:width],
        :length => size[:length],
        :margin => {
          :left => size[:left],
          :bottom => size[:bottom],
          :right => size[:right],
          :top => size[:top]
        }
      }
    end
  end
  
end
