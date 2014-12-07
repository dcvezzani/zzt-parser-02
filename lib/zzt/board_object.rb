module Zzt
  class BoardObject < Common
    attr_accessor :objects_by_code, :x, :y

    COLOR_TABLE = {
      black:             {code: "00", colour: "Black"}, 
      dark_blue:         {code: "01", colour: "Dark blue"}, 
      dark_green:        {code: "02", colour: "Dark green"}, 
      dark_cyan:         {code: "03", colour: "Dark cyan"}, 
      dark_red:          {code: "04", colour: "Dark red"}, 
      dark_purple:       {code: "05", colour: "Dark purple"}, 
      dark_yellow_brown: {code: "06", colour: "Dark yellow (brown)"}, 
      light_grey:        {code: "07", colour: "Light grey"}, 
      dark_grey:         {code: "08", colour: "Dark grey"}, 
      light_blue:        {code: "09", colour: "Light blue"}, 
      light_green:       {code: "0A", colour: "Light green"}, 
      light_cyan:        {code: "0B", colour: "Light cyan"}, 
      light_red:         {code: "0C", colour: "Light red"}, 
      light_purple:      {code: "0D", colour: "Light purple"}, 
      light_yellow:      {code: "0E", colour: "Light yellow"}, 
      white:             {code: "0F", colour: "White"}
    }
    
    CODE_TABLE = {
      empty_space:                    {code: "00",     char: "00",                     desc: "Empty Space"},
      special_edge_board:             {code: "01",     char: "00",                     desc: "Special: acts like edge of board"},
      ammo:                           {code: "05",     char: "84",                     desc: "Ammo"},
      torch:                          {code: "06",     char: "9D",                     desc: "Torch"},
      gem:                            {code: "07",     char: "04",                     desc: "Gem"},
      key:                            {code: "08",     char: "0C",                     desc: "Key"},
      door:                           {code: "09",     char: "0A",                     desc: "Door"},
      water:                          {code: "13",     char: "B0",                     desc: "Water"},
      forest:                         {code: "14",     char: "B0",                     desc: "Forest"},
      solid:                          {code: "15",     char: "DB",                     desc: "Solid"},
      normal:                         {code: "16",     char: "D2",                     desc: "Normal"},
      breakable:                      {code: "17",     char: "B1",                     desc: "Breakable"},
      boulder:                        {code: "18",     char: "FF",                     desc: "Boulder"},
      slider_north_south:             {code: "19",     char: "12",                     desc: "Slider: North-South"},
      slider_east_west:               {code: "1A",     char: "1D",                     desc: "Slider: East-West"},
      fake:                           {code: "1B",     char: "B2",                     desc: "Fake"},
      invisible_wall:                 {code: "1C",     char: "(invisible)",            desc: "Invisible wall"},
      blink_wall:                     {code: "1D",     char: "(varies)",               desc: "Blink Wall"},
      line:                           {code: "1F",     char: "(varies)",               desc: "Line"},
      bomb:                           {code: "0D",     char: "0B",                     desc: "Bomb"},
      energizer:                      {code: "0E",     char: "7F",                     desc: "Energizer"},
      clockwise_conveyer:             {code: "10",     char: "(spins)",                desc: "Clockwise conveyer"},
      counterclockwise_conveyor:      {code: "11",     char: "(spins)",                desc: "Counterclockwise conveyor"},
      ricochet:                       {code: "20",     char: "2A",                     desc: "Ricochet"},

      player:                         {code: "04",     char: "02",                     desc: "Player",                    class_name: "Zzt::Player"},
      scroll:                         {code: "0A",     char: "E8",                     desc: "Scroll",                    class_name: "Zzt::Scroll"},
      passage:                        {code: "0B",     char: "F0",                     desc: "Passage",                   class_name: "Zzt::Passage"},
      duplicator:                     {code: "0C",     char: "(growing O)",            desc: "Duplicator",                class_name: "Zzt::Duplicator"},
      star:                           {code: "0F",     char: "(spins)",                desc: "Star",                      class_name: "Zzt::Star"},
      bullet:                         {code: "12",     char: "F8",                     desc: "Bullet",                    class_name: "Zzt::Bullet"},
      transporter:                    {code: "1E",     char: "(varies)",               desc: "Transporter",               class_name: "Zzt::Transporter"},
      horizontal_blink_wall_ray:      {code: "21",     char: "CD",                     desc: "Horizontal blink wall ray", class_name: "Zzt::HorizontalBlinkingWall"},
      bear:                           {code: "22",     char: "99",                     desc: "Bear",                      class_name: "Zzt::Bear"},
      ruffian:                        {code: "23",     char: "05",                     desc: "Ruffian",                   class_name: "Zzt::Ruffian"},
      object:                         {code: "24",     char: "(varies)",               desc: "Object",                    class_name: "Zzt::Object"},
      slime:                          {code: "25",     char: "2A",                     desc: "Slime",                     class_name: "Zzt::Slime"},
      shark:                          {code: "26",     char: "5E",                     desc: "Shark",                     class_name: "Zzt::Shark"},
      spinning_gun:                   {code: "27",     char: "(spins)",                desc: "Spinning gun",              class_name: "Zzt::SpinningGun"},
      pusher:                         {code: "28",     char: "(varies)",               desc: "Pusher",                    class_name: "Zzt::Pusher"},
      lion:                           {code: "29",     char: "EA",                     desc: "Lion",                      class_name: "Zzt::Lion"},
      tiger:                          {code: "2A",     char: "E3",                     desc: "Tiger",                     class_name: "Zzt::Tiger"},
      vertical_blink_wall_ray:        {code: "2B",     char: "BA",                     desc: "Vertical blink wall ray",   class_name: "Zzt::VerticalBlinkingWall"},
      centipede_head:                 {code: "2C",     char: "E9",                     desc: "Centipede head",            class_name: "Zzt::CentipedeHead"},
      centipede_segment:              {code: "2D",     char: "4F",                     desc: "Centipede segment",         class_name: "Zzt::CentipedeSegment"},

      blue_text:                      {code: "2F",     char: "(set in colour byte)",   desc: "Blue text"},
      green_text:                     {code: "30",     char: "(set in colour byte)",   desc: "Green text"},
      cyan_text:                      {code: "31",     char: "(set in colour byte)",   desc: "Cyan text"},
      red_text:                       {code: "32",     char: "(set in colour byte)",   desc: "Red text"},
      purple_text:                    {code: "33",     char: "(set in colour byte)",   desc: "Purple text"},
      yellow_text:                    {code: "34",     char: "(set in colour byte)",   desc: "Yellow text"},
      white_text:                     {code: "35",     char: "(set in colour byte)",   desc: "White text"},
      white_blinking_text:            {code: "36",     char: "(set in colour byte)",   desc: "White blinking text"},
      blue_blinking_text:             {code: "37",     char: "(set in colour byte)",   desc: "Blue blinking text"},
      green_blinking_text:            {code: "38",     char: "(set in colour byte)",   desc: "Green blinking text"},
      cyan_blinking_text:             {code: "39",     char: "(set in colour byte)",   desc: "Cyan blinking text"},
      red_blinking_text:              {code: "3A",     char: "(set in colour byte)",   desc: "Red blinking text"},
      purple_blinking_text:           {code: "3B",     char: "(set in colour byte)",   desc: "Purple blinking text"},
      yellow_blinking_text:           {code: "3C",     char: "(set in colour byte)",   desc: "Yellow blinking text"},
      grey_blinking_text:             {code: "3D",     char: "(set in colour byte)",   desc: "Grey blinking text"}
    } 

    CODE_TABLE_BY_CODE = {}
    CODE_TABLE.each do |k, v|
      CODE_TABLE_BY_CODE[v[:code]] = v.merge({name: k})
    end

    CODE_TABLE_BY_CODE_FOR_CONFIGURABLE_OBJECTS = {}
    CODE_TABLE_BY_CODE.each do |k, v|
      CODE_TABLE_BY_CODE_FOR_CONFIGURABLE_OBJECTS[k] = v if v.keys.include?(:class_name)
    end

    INFO = {
      x: {start: "00", size: 1, type: :integer}, 
      y: {start: "01", size: 1, type: :integer}, 
      x_step: {start: "02", size: 2, type: :integer}, 
      y_step: {start: "04", size: 2, type: :integer}, 
      cycle: {start: "06", size: 2, type: :integer}, 
      p1: {start: "08", size: 1, type: :integer}, 
      p2: {start: "09", size: 1, type: :integer}, 
      p3: {start: "0A", size: 1, type: :integer}, 
      p4: {start: "0B", size: 4, type: :integer}, 
      ut: {start: "0F", size: 1, type: :integer}, 
      uc: {start: "10", size: 1, type: :integer}, 
      pointer: {start: "11", size: 4, type: :integer}, 
      cur_ins: {start: "15", size: 2, type: :integer}, 
      data_length: {start: "17", size: 2, type: :integer, default: 0, priority: 100}, 
      padding: {start: "19", size: 8, type: :raw}, 
      data: {start: "21", size: :data_length, type: :string}, 
      excludes: {properties: []}
    }

    def initialize()
      super(INFO)
    end

    def size
      super(INFO)
    end
    
    def parse(str)
      super(INFO, str)
    end

    def to_s
      super(self.instance_variables.select{|v| ![:@padding].include?(v) })
    end
  end

  class Player < BoardObject
    ATTRS = [:x, :y, :cycle]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Scroll < BoardObject
    ATTRS = [:x, :y, :cycle, :cur_ins, :data_length, :data]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Passageway < BoardObject
    ATTRS = [:x, :y, {destination: :p3}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Duplicator < BoardObject
    ATTRS = [:x, :y, {copy_src_x: :x_step}, {copy_src_y: :y_step}, {rate: :p2}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Bear < BoardObject
    ATTRS = [:x, :y, :cycle, {sensitivity: :p1}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Ruffian < BoardObject
    ATTRS = [:x, :y, :cycle, {intelligence: :p1}, {rest_time: :p1}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Object < BoardObject
    ATTRS = [:x, :y, :cycle, {ascii_char: :p1}, :p2, :cur_ins, :data_length, :data]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Slime < BoardObject
    ATTRS = [:x, :y, :cycle, {speed: :p2}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Shark < BoardObject
    ATTRS = [:x, :y, :cycle, {intelligence: :p1}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class SpinningGun < BoardObject
    ATTRS = [:x, :y, :cycle, {intelligence: :p1}, {firing_rate_mode: :p2}] # speed / firing_rate: 128 == stars
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Pusher < BoardObject
    ATTRS = [:x, :y, :x_step, :y_step, :cycle]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Lion < BoardObject
    ATTRS = [:x, :y, :cycle, {intelligence: :p1}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Tiger < BoardObject
    ATTRS = [:x, :y, :cycle, {intelligence: :p1}, {firing_rate_mode: :p2}] # speed / firing_rate: 128 == stars
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class CentipedeHead < BoardObject
    ATTRS = [:x, :y, :cycle, {intelligence: :p1}, {deviance: :p2}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class CentipedeSegment < BoardObject
    ATTRS = [:x, :y, :cycle]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class BlinkingWall < BoardObject
    # n: (0,-1), s: (0,1), w: (-1,0), e: (1,0)
    ATTRS = [:x, :y, {x_direction: :x_step}, {y_direction: :y_step}, :cycle, {start_time: :p1}, {firing_period: :p2}]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class HorizontalBlinkingWall < BlinkingWall
  end

  class VerticalBlinkingWall < BlinkingWall
  end

  # class HorizontalBlinkingWall < BlinkingWall
  #   # n: (0,-1), s: (0,1), w: (-1,0), e: (1,0)
  #   ATTRS = [:x, :y, {x_direction: :x_step}, {y_direction: :y_step}, :cycle, {start_time: :p1}, {firing_period: :p2}]
  #   def to_s
  #     super(self.instance_variables.select{|v| ATTRS.include?(v) })
  #   end
  # end

  class Transporter < BoardObject
    ATTRS = [:x, :y, {x_direction: :x_step}, {y_direction: :y_step}, :cycle]
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Bullet < BoardObject
    ATTRS = [:x, :y, {x_direction: :x_step}, {y_direction: :y_step}, :cycle, {owner: :p1}] # 0: player, 1: enemy
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end

  class Star < BoardObject
    ATTRS = [:x, :y, {x_direction: :x_step}, {y_direction: :y_step}, :cycle, {owner: :p1}] # 0: player, 1: enemy
    def to_s
      super(self.instance_variables.select{|v| ATTRS.include?(v) })
    end
  end
end
