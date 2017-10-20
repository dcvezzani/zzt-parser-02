tour_content = IO.read("./TOUR.ZZT")
tour_content = IO.read("./XXX.ZZT")

tour_content[0..10]

hex_length("1E-31")
hex_length("33-46")
hex_length("F1-104")
hex_length("106-104")
hex_length("108-200")
hex_length("00-108")
hex_add_dec("33", 190)

def hex_add_dec(hex, dec, zero=false)
  offset = (zero) ? (dec - 1) : dec
  (hex.to_i(16) + offset).to_s(16)
end

def hex_length(exp)
  parts = exp.split(/-/)
  (parts[1].to_i(16) - parts[0].to_i(16)) + 1
end

# size = "200".to_i(16)
# tour_content[0...size].length
#
# magic_number = tour_content[0..1].unpack("H4").first
# boards_count = tour_content[2..3].unpack("C").first + 1
# ammo = tour_content[4..5].unpack("C").first
# gems = tour_content[6..7].unpack("C").first
#
# magic_num, boards_cnt_z, ammo, gems = tour_content[0..("10".to_i(16))].unpack("H4S3")
# keys = tour_content[("08".to_i(16))..("0E".to_i(16))].unpack("C7")
# health, board_str, torch_cnt, tcycle_cnt, ecycle_cnt, padding, score = tour_content[("0F".to_i(16))..("1C".to_i(16))].unpack("S7")
# title_cnt = tour_content[("1D".to_i(16))..("1D".to_i(16))].unpack("C")

keys = [:magic_num, :boards_cnt_z, :ammo, :gems, :bk, :gk, :ck, :rk, :pk, :yk, :wk, :health, :board_str, :torch_cnt, :tcycle_cnt, :ecycle_cnt, :pad_01, :score, :title_cnt, :title_x, :flg1_cnt, :flg1, :flg2_cnt, :flg2, :flg3_cnt, :flg3, :flg4_cnt, :flg4, :flg5_cnt, :flg5, :flg6_cnt, :flg6, :flg7_cnt, :flg7, :flg8_cnt, :flg8, :flg9_cnt, :flg9, :pad_02, :timeleft, :pad_03, :saved_game, :pad_04 ]
values = tour_content[("00".to_i(16))..("200".to_i(16))].unpack("H4S3C7S7CA20CA20CA20CA20CA20CA20CA20CA20CA20CA20H20SH2CH249")
game_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

hex_add_dec("200", 1)

start = ("200".to_i(16))
board_size = tour_content[start..start+1].unpack("S").first #5138
board_stop = hex_add_dec("200", board_size+1).to_i(16)
#board_stop = hex_add_dec("201", 5138) #1613
#hex_length("03-23") #33

keys = [:board_size, :title_cnt, :title, :pad_01]
values = tour_content[(start+2)..board_stop].unpack("CA33H16").unshift(board_size)
board_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

# hex_length("00-33") #52
# hex_length("24-33") #16
#
# tour_content[("202".to_i(16))..("1613".to_i(16))].unpack("CA33H16")
#
# hex_length("00-34") #53
# hex_add_dec("200", 53) #235

start = ("200".to_i(16))

max_tile_cnt = 60*25 #1500
# start = ("235".to_i(16))
start = start + hex_length("00-33") + 1
tile_cnt = 0
tiles = []

while (tile_cnt < max_tile_cnt)
  repeat_cnt, code, colour = tour_content[start..board_stop].unpack("Caa")
  tile_cnt += repeat_cnt
  ("#{code}".to_i(16))
  tiles << [repeat_cnt, code.unpack('H*')[0], colour.unpack('H*')[0]]
  puts "<< #{tile_cnt}, #{tiles.last}"
  start += 3
end

# start.to_s(16)
hex_length("08-41")
hex_length("46-55")

keys = [:max_shots, :darkness, :bn, :bs, :bw, :be, :reenter, :message_len, :message, :pad_01, :time_limit, :pad_02, :obj_cnt]
values = tour_content[start..board_stop].unpack("C8H58H2SH16SSSSSSSSSSSSSSSSS")
game_board = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

start = ("1613".to_i(16))


# values = tour_content[("00".to_i(16))..("1D".to_i(16))].unpack("H4S3C7S7C")
# game = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
# title_len = hex_add_dec("1E", game[:title_cnt], true)
# tour_content[("32".to_i(16))..("46".to_i(16))].unpack("CA*")
