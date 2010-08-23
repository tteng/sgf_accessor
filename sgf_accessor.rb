require 'fileutils'

class SgfAccessor

  #SGF文件格式:
  #PNG数据|PNG签名|宽(short)|高(short)|注册点X(short)|注册点Y(short)|图片帧数(short)|每帧[X,Y,W,H](short)x帧数|脚本长度(short)|脚本|所有数据长度(自SGF文件宽至脚本结束之间数据长度(字节))|SGF签名

  SIGNATURE_LENGTH = 9 #SGF签名字节

  SCRIPT_BYTES_COUNT = 4 #所有数据字节数

  WIDTH_BYTES_COUNT = 2  #图片宽度字节数

  HEIGHT_BYTES_COUNT = 2 #图片高度字节数

  REG_POINT_BYTES_COUNT_X = 2 #注册点X坐标字节数

  REG_POINT_BYTES_COUNT_Y = 2 #注册点Y坐标字节数

  FRAMES_BYTES_COUNT = 2 #动画帧字节数

  SCRIPTS_BYTES_COUNT = 2 #播放脚本字节数

  SIGNATURE = "SGF-asset" 

  ATTRS = [:data_length, :width, :height, :reg_axis_x, :reg_axis_y, :frames_count, :frames_data, :scripts_count, :scripts]

  ATTRS.each do |attr|
    attr_accessor attr
  end 

  attr_accessor :file_size

  def initialize path
    @path = path
    @file = File.new(@path)
    raise 'Unauthorized File!' unless sgf_authorized?
    @file_size = @file.size
    ATTRS.each do |attr|
      instance_variable_set "@#{attr}", method("get_#{attr}").call
    end  
  end

  def scripts= script=''
    @scripts = script
    @scripts_count = script.size
  end

  def write_back!
    width_and_height = [@width,height].pack 'n2'
    register_points = [@reg_axis_x, @reg_axis_y].pack 'n2'
    scripts_count = [@scripts_count].pack 'n' 
    data = width_and_height + register_points + @frames_data + scripts_count + @scripts
    data_size = [data.size].pack 'N'
    begin
      FileUtils.cp(@path, bakpath)    
      tail_of_png = @file_size - @data_length - SIGNATURE_LENGTH - SCRIPT_BYTES_COUNT
      File.open(bakpath, 'a+') do |file|
        file.flock File::LOCK_EX
        file.truncate(tail_of_png)
        file.seek(width_displacement, IO::SEEK_END)
        file.write(data+data_size+signature)
        file.flush
      end
      FileUtils.mv(bakpath,@path)
      true
    rescue
      FileUtils.rm_rf bakpath  
      false
    end
  end

  def sgf_authorized? 
    signature == SIGNATURE 
  end

  def reg_axis_x= (some_value=0)
    @reg_axis_x = some_value
  end

  def reg_axis_y= (some_value=0)
    @reg_axis_y = some_value
  end

  def width= w
    @width = w
  end

  def height= h
    @height = h
  end

  private

  def get_data_length
    @file.seek(-(SIGNATURE_LENGTH + SCRIPT_BYTES_COUNT), IO::SEEK_END)
    @file.read(SCRIPT_BYTES_COUNT).unpack('N').shift
  end

  def get_width
    @file.seek(width_displacement, IO::SEEK_END)
    @file.read(WIDTH_BYTES_COUNT).unpack('n').shift
  end

  def get_height
    @file.seek(height_displacement, IO::SEEK_END)
    @file.read(HEIGHT_BYTES_COUNT).unpack('n').shift
  end

  def get_reg_axis_x	
    @file.seek(reg_axis_x_displacement,IO::SEEK_END)
    @file.read(REG_POINT_BYTES_COUNT_X).unpack('n').shift
  end

  def get_reg_axis_y
    @file.seek(reg_axis_y_displacement, IO::SEEK_END)
    @file.read(REG_POINT_BYTES_COUNT_Y).unpack('n').shift
  end

  def get_frames_count
    @file.seek(frame_bytes_displacement,IO::SEEK_END)
    @file.read(FRAMES_BYTES_COUNT).unpack('n').shift
  end

  def get_scripts_count
    @file.seek(scripts_count_displacement,IO::SEEK_END)
    @file.read(SCRIPTS_BYTES_COUNT).unpack('n').shift
  end

  def get_scripts
    @file.seek(scripts_displacement,IO::SEEK_END) 
    @file.read @scripts_count 
  end

  def get_frames_data
    @file.seek(frame_bytes_displacement,IO::SEEK_END)
    @file.read(FRAMES_BYTES_COUNT + @frames_count * (REG_POINT_BYTES_COUNT_X + REG_POINT_BYTES_COUNT_Y +   WIDTH_BYTES_COUNT  + HEIGHT_BYTES_COUNT))
  end

  def signature  
    @file.seek(-SIGNATURE.length,IO::SEEK_END)
    s = @file.read SIGNATURE_LENGTH
  end

  def register_point_data
    [@reg_axis_x, @reg_axis_y].pack('n2')
  end

  #读取数据的位移

  def width_displacement
    -(SIGNATURE_LENGTH + SCRIPT_BYTES_COUNT + data_length)
  end
  
  def height_displacement
    width_displacement +  WIDTH_BYTES_COUNT
  end

  def reg_axis_x_displacement
    height_displacement + HEIGHT_BYTES_COUNT
  end

  def reg_axis_y_displacement
    reg_axis_x_displacement + REG_POINT_BYTES_COUNT_X
  end

  def frame_bytes_displacement
    reg_axis_y_displacement + REG_POINT_BYTES_COUNT_Y
  end

  def frames_displacement
    frame_bytes_displacement + frames_count * (REG_POINT_BYTES_COUNT_X + REG_POINT_BYTES_COUNT_Y +   WIDTH_BYTES_COUNT  + HEIGHT_BYTES_COUNT)
  end

  def scripts_count_displacement
    frames_displacement + FRAMES_BYTES_COUNT
  end

  def scripts_displacement
    scripts_count_displacement + SCRIPTS_BYTES_COUNT
  end

  def bakpath
    @path + ".bak"
  end

end
