##################################
# Part 1 - String Functions
##################################

is_whitespace:
	li $v0, 1 							# set return value to true
	li $t0, 0							# test null character
	beq $t0, $a0, is_whitespace_true
	li $t0, 10							# test new line character
	beq $t0, $a0, is_whitespace_true
	li $t0, 32							# test space character
	beq $t0, $a0, is_whitespace_true
	is_whitespace_false:
	li $v0, 0 							# it's not a "whitespace" so set to false
	is_whitespace_true:
	jr $ra
		
	# this will be calling is_whitespace, so we need to save any $s registers and the stack
cmp_whitespace:
	# need register convention since we are calling is_whitespace
	# move $a0, $a1 into $s0 and $s1 respectively
	# but since we're using $s0 and $s1... we need to save them first then load their original values at the end
	addi $sp, $sp, -12 # save registers on stack
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	
	move $s0, $a0	# save $a0 into $s0
	move $s1, $a1	# save $a1 into $s1
	
	jal is_whitespace 	# $a0 is already set for here
	move $s0, $v0 		# save the result of it into $s0
	
	move $a0, $s1		# move the next value into $a0
	jal is_whitespace	
	move $s1, $v0		# save the result of it into $s1
	
	li $t1, 1
	bne $s0, $t1, no_whitespace
	bne $s1, $t1, no_whitespace
	li $v0, 1
	j yes_whitespace

	no_whitespace:
	li $v0, 0
	yes_whitespace:

	lw $ra, 0($sp) # restore registers
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	addi $sp, $sp, 12
	jr $ra

strcpy:
	ble $a0, $a1, strcpy_done
	move $t0, $0					# counter
	
	strcpy_loop:
		beq $t0, $a2, strcpy_done
		lbu $t1,($a0)
		sb $t1, ($a1)
		addi $a0, $a0, 1
		addi $a1, $a1, 1
		addi $t0, $t0, 1
		j strcpy_loop
	
	strcpy_done:
	jr $ra
	
strlen:
	addi $sp, $sp, -12				# save registers on stack
	sw $ra, 0($sp)	
	sw $s0, 4($sp)					# holds original $a0
	sw $s1, 8($sp)					# holds counter value
	
	move $s1, $0					# counter
	move $s0, $a0
	strlen_loop:
		lbu $t1, ($s0)
		move $a0, $t1
		jal is_whitespace
		li $t2, 1
		beq $v0, $t2, strlen_done
		addi $s0, $s0, 1			# go to next "byte" in the string?
		addi $s1, $s1, 1			# increment counter
		j strlen_loop
	strlen_done:
	move $v0, $s1					# move the counter into the return
		
	lw $ra, 0($sp) 					# restore registers
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	addi $sp, $sp, 12
	jr $ra

##################################
# Part 2 - vt100 MMIO Functions
##################################

set_state_color:
	move $t0, $a1
	srl $t3, $t0, 4 		# $t3 holds background_color [4bits]
	sll $t4, $t0, 28
	srl $t4, $t4, 28 		# $t4 holds foreground_color [4bits]
	
	li $t0, 0
	li $t1, 1
	li $t2, 2
	
	beqz $a2, set_state_color_default
	# below we are going to be setting the highlight_
		beq $a3, $t1, set_state_color_highlight_fg
		beq $a3, $t2, set_state_color_highlight_bg
		# reached if $a3 is 0
		sll $t8, $t3, 4
		or $t8, $t8, $t4
		sb $t8, 1($a0)
		j set_state_color_done
		set_state_color_highlight_fg:							# will be executed if $a3 is 1 OR 0
			# code here to change hightlight_foreground
			move $t5, $a0 			# get the struct begin address
			lbu $t6, 1($t5) 		# holds [struct] [highlight_bg][highlight_fg] # 1001 1111
			# we want to change highlight_fg, so srl4 then sll4 to erase the 4 bits
			srl $t6, $t6, 4
			sll $t6, $t6, 4
			# now we have [highlight_bg] ---- # 1001 0000
			or $t6, $t6, $t4
			# assumes that $t4 is ...0000 1101 (all zeroes except last 4 bits have value)
			# now we have [highlight_bg][*highlight_fg*] # 1001 1101
			sb $t6, 1($t5)
		bnez $a3, set_state_color_highlight_modedone			# if $a3 is NOT 0, then finished. otherwise also set BG
		set_state_color_highlight_bg:
			# code here to change hightlight_background
			move $t5, $a0 			# get the struct begin address
			lbu $t6, 1($t5) 		# holds [struct] [default_bg][default_fg] # 1001 1111
			# we want to change default_bg, so sll 28 srl 28 (preserve the original [default_fg])
			sll $t6, $t6, 28
			srl $t6, $t6, 28
			# now we have ---- [default_fg] # 0000 1111
			sll $t7, $t3, 4 # now 1101 0000
			or $t6, $t6, $t7
			# assumes that $t3 is ...0000 1101 0000 (all zeroes except last 4 bits have value)
			# now we have [*default_bg*][default_fg] # 1101 1111
			sb $t6, 1($t5)
		set_state_color_highlight_modedone:
		# done with modes so we're done with set_state_color_highlight setting
	j set_state_color_done
	set_state_color_default:
	# below we are going to be setting the default_
		beq $a3, $t1, set_state_color_default_fg
		beq $a3, $t2, set_state_color_default_bg
		# reached if $a3 is 0
		sll $t8, $t3, 4
		or $t8, $t8, $t4
		sb $t8, 0($a0)
		j set_state_color_done
		set_state_color_default_fg:							# will be executed if $a3 is 1 OR 0
			# code here to change default_foreground
			#lw $t5, ($a0)			# get the struct begin address
			move $t5, $a0 			# get the struct begin address
			lbu $t6, 0($t5) 		# holds [struct] [default_bg][default_fg] # 1001 1111
			# we want to change default_fg, so srl4 then sll4 to erase the 4 bits
			srl $t6, $t6, 4
			sll $t6, $t6, 4
			# now we have [default_bg] ---- # 1001 0000
			or $t6, $t6, $t4
			# assumes that $t4 is ...0000 1101 (all zeroes except last 4 bits have value)
			# now we have [default_bg][*default_fg*] # 1001 1101
			sb $t6, 0($t5)
		bnez $a3, set_state_color_default_modedone			# if $a3 is NOT 0, then finished. otherwise also set BG
		set_state_color_default_bg:
			# code here to change default_background
			move $t5, $a0 			# get the struct begin address
			lbu $t6, 0($t5) 		# holds [struct] [default_bg][default_fg] # 1001 1111
			# we want to change default_bg, so sll 28 srl 28 (preserve the original [default_fg])
			sll $t6, $t6, 28
			srl $t6, $t6, 28
			# now we have ---- [default_fg] # 0000 1111
			sll $t7, $t3, 4 # now 1101 0000
			or $t6, $t6, $t7
			# assumes that $t3 is ...0000 1101 0000 (all zeroes except last 4 bits have value)
			# now we have [*default_bg*][default_fg] # 1101 1111
			sb $t6, 0($t5)
		set_state_color_default_modedone:
	
	set_state_color_done:
	jr $ra

save_char:
	lbu $t0, 2($a0) 			# state_X
	lbu $t1, 3($a0)				# state_Y
	li $t3, 80
	li $t4, 2
	mul $t0, $t0, $t4	 		# $t0 = x * 2
	mul $t2, $t0, $t3	 		# $t2 = (x * 2) * 80
	mul $t1, $t1, $t4	 		# $t1 = y * 2
	add $t3, $t2, $t1	 		# $t3 = (x * 2 * 80) + (y * 2)
	addi $t3, $t3, 0xFFFF0000
	sb $a1, 0($t3)
	jr $ra

reset:
	li $t0, 2000						# $t0 = 2000 				# the total amount of cells in display
	li $t1, 0 							# $t1 = 0					# counter
	addi $t2, $0, 0xFFFF0000			# $t2 = 0xFFFF0000
	lbu $t3, 0($a0) 					# $t3 = DEFAULT_COLOR_BYTE
	#li $t3, 0x2D
	reset_loop:
		beq $t1, $t0, reset_loop_done	# if counter = 2000 then done_reset
		beqz $a1, reset_clear_both		# if COLOR_ONLY = 0 then clear both
		# Resets only the Cell Color Value
		sb $t3, 1($t2) 					# Store [struct] DEFAULT_COLOR_BYTE in CELL
		addi $t2, $t2, 2 				# $t2 = Next Cell
		addi $t1, $t1, 1				# $t1 = $t1 + 1
		j reset_loop
		
		reset_clear_both:				# Reset the Cell Color and Cell Char Value
			sb $t3, 1($t2) 				# Store [struct] DEFAULT_COLOR_BYTE in CELL
			sb $0, 0($t2)				# Store [null] \0 in CELL
			addi $t2, $t2, 2 			# $t2 = Next Cell
			addi $t1, $t1, 1			# $t1 = $t1 + 1
			j reset_loop
	reset_loop_done:
	jr $ra

clear_line:
	# void clear_line(byte x, byte y, byte color)
	# from (x, y) up to (x, 79)
	# FFFF0000 + ((x * 2) * 80) + (y * 2)
	
	li $t2, 2
	move $t0, $a0 		# $t0 = x
	move $t1, $a1 		# $t1 = y
	mul $t0, $t0, $t2 	# $t0 = x * 2
	mul $t1, $t1, $t2 	# $t1 = y * 2
	li $t2, 80			#
	mul $t0, $t0, $t2	# $t0 = x * 2 * 80
	add $t0, $t0, $t1	# $t0 = [(x * 2 * 80) + (y * 2)]
	
								# registers used in the loop
	addi $t0, $t0, 0xFFFF0000 	# $t0 = [(x * 2 * 80) + (y * 2)] + 0xFFFF0000
	li $t1, 0 					# counter = 0
	li $t2, 160					# max of counter
	li $t3, 0					# ASCII of "\0"
	move $t4, $a2				# holds [color] byte
	
	clear_line_loop:			
		beq $t1, $t2, clear_line_done
		
		sb $t3, 0($t0)			# store \0 into cell @ $t0

		# alter ASCII Character ABOVE this [1 byte]
		addi $t0, $t0, 1
		addi $t1, $t1, 1
		
		sb $t4, ($t0)			# store [color] into cell @ $t0
		
		# alter VT100 Color ABOVE this [1 byte]
		addi $t0, $t0, 1
		addi $t1, $t1, 1
		j clear_line_loop
	
	clear_line_done:
	jr $ra

set_cursor:
	lbu $t0, 2($a0) 			# Current X 
	lbu $t1, 3($a0) 			# Current Y
	li $t2, 80					# $t2 = 80
	li $t3, 2					# $t3 = 2
	mul $t2, $t2, $t3			# $t2 = 80 * 2 = 160
	mul $t0, $t0, $t2			# $t0 = x * 160
	li $t2, 2					# $t2 = 160 * 2
	mul $t1, $t1, $t2			# $t1 = y * 2
	add $t0, $t1, $t0			# $t0 = x * 160 + y * 2
	addi $t2, $t0, 0xFFFF0000 	# $t2 = x * 160 + y * 2 + 0xFFFF0000
	# $t2 holds address of current cursor location
	
	move $t3, $a1 				# New X
	move $t4, $a2 				# New Y
	li $t1, 80					# $t1 = 80
	li $t0, 2					# $t0 = 2
	mul $t1, $t1, $t0			# $t1 = 80 * 2 = 160
	mul $t3, $t3, $t1			# $t3 = x * 160
	li $t1, 2					# $t1 = 2
	mul $t4, $t4, $t1			# $t4 = y * 2
	add $t3, $t4, $t3			# $t3 = y * 2 + x * 160
	addi $t1, $t3, 0xFFFF0000	# $t1 = y * 2 + x * 160 + 0xFFFF0000
	# $t1 holds address of new cursor location
	
	sb $a1, 2($a0) 				# Store New X into [struct]
	sb $a2, 3($a0) 				# Store New Y into [struct]
		
	beqz $a3, set_cursor_clear_first # if $a3 = 0, clear cursor first
	# reached only if $a3 = 1 (begin case, we don't clear the original cursor. only set values)
	lbu $t3, 1($t1)				# load color_byte of new
	li $t9, 136	 				# 10001000
	xor $t3, $t3, $t9
	sb $t3, 1($t1)
	j set_cursor_done
	
	set_cursor_clear_first:
		# set the original position to default color (aka invert again i guess)
		lbu $t3, 1($t2)			# load color_byte of current
		li $t9, 136				# 10001000
		xor $t3, $t3, $t9
		sb $t3, 1($t2)
		
		lbu $t3, 1($t1)			# load color_byte of new
		li $t9, 136				# 10001000
		xor $t3, $t3, $t9
		sb $t3, 1($t1)
	set_cursor_done:
	jr $ra

move_cursor:
	#void move_cursor(struct state, char direction)
	# If the cursor is at (0,0) and the direction is specified as ‘h’ or ‘k’, the cursor remains at (0,0).
	# If the cursor is at (24,79) and the direction is specified as‘l’ or ‘j’, the cursor remains at(24,79).
	# CALL void set_cursor(struct state, byte x, byte y, 1)
	addi $sp, $sp, -4 # save registers on stack
	sw $ra, 0($sp)
	
	lbu $t2, 2($a0)		# current x
	lbu $t3, 3($a0)		# current y
	
	li $t0, 104						# h [left]
	beq $t0, $a1, move_cursor_left
	li $t0, 106						# j [down]
	beq $t0, $a1, move_cursor_down
	li $t0, 107						# k [up]
	beq $t0, $a1, move_cursor_up
	li $t0, 108						# l [right]
	beq $t0, $a1, move_cursor_right
	
	move_cursor_left:
		beqz $t3, move_cursor_done
		addi $t3, $t3, -1
		j move_cursor_done
		
	move_cursor_down:
		li $t4, 24
		beq $t2, $t4, move_cursor_done
		addi $t2, $t2, 1
		j move_cursor_done
		
	move_cursor_up:
		beqz $t2, move_cursor_done
		addi $t2, $t2, -1
		j move_cursor_done
		
	move_cursor_right:
		li $t4, 79
		beq $t3, $t4, move_cursor_done
		addi $t3, $t3, 1
		j move_cursor_done
		
	move_cursor_done:
	move $a1, $t2
	move $a2, $t3
	li $a3, 0
	jal set_cursor
	
	lw $ra, 0($sp) 					# restore registers
	addi $sp, $sp, 4
	jr $ra

mmio_streq:
	addi $sp, $sp, -12 # save registers on stack
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	
	# store original string addresses in $s0, $s1 since we're going to be calling strlen
	move $s0, $a0 #mmio
	move $s1, $a1
	
	# loop thru strlen
		# $s0 holds mmio
		# $s1 holds str2
	mmio_streq_string_loop:
		# prepare the chars/bytes for being called in cmp_whitespace
		lbu $a0, 0($s0)
		li $v0, 1
		syscall
		
		lbu $a0, 0($s1)
		li $v0, 1
		syscall
		
		lbu $a0, 0($s0)
		lbu $a1, 0($s1)
		jal cmp_whitespace
		move $t2, $v0			# store the return of cmp_whitespace in $t2
		li $t3, 1
		beq $t2, $t3, mmio_streq_string_loop_done
		
		# checking when to forceably end loop (only mmio_string ends)
		# hence in this case, if is_whitespace is true, it must be the case that they aren't equal
		lbu $a0, 0($s0)
		jal is_whitespace
		li $t0, 1
		li $t2, 0
		beq $t0, $v0, mmio_streq_string_loop_done
		
		# increment the strings
		addi $s0, $s0, 2		# increment mmio_string
		addi $s1, $s1, 1		# increment string_2
		j mmio_streq_string_loop
	mmio_streq_string_loop_done:
	move $v0, $t2
	
	lw $s1, 8($sp)
	lw $s0, 4($sp)
	lw $ra, 0($sp)
	addi $sp, $sp, 12
	jr $ra

##################################
# Part 3 - UI/UX Functions
##################################

handle_nl:
	#void handle_nl(struct state)
	addi $sp, $sp, -8
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	
	# preserve the address of [state]
	# b/c we are calling another function and also because we need to use the $a0 register to do so.
	move $s0, $a0
	
	# no need to move into $a0, cus $a0 already has what we want to pass
	li $a1, 10					# ASCII value of a new line character
	jal save_char				# store newLine at current pos
	
	lbu $a0, 2($s0)				# $a0 = current X
	lbu $a1, 3($s0)				# $a1 = current Y
	#li $t0, 79
	#bge $t0, $a1, handle_nl_no_line_to_clear 	# we want to clear the rest of the line, but if we're at the end of the line, there's no columns to clear...? so skip it.
	addi $a1, $a1, 1
	lbu $a2, 0($s0)				# $a2 = default_color
	jal clear_line				# clear rest of line
	#handle_nl_no_line_to_clear:
	
	# chunk sees if we are on the last line. if we are then we can't go to the next row.
	# so instead go to the start of the last line.
	li $t0, 24
	lbu $t1, 2($s0)
	beq $t1, $t0, handle_nl_reached_last_line_cursor_at_start
	
	# below goes to start of next line
	move $a0, $s0	# set [state]
	move $a1, $t1	# set X
	addi $a1, $a1, 1# next line
	li $a2, 0		# start of line
	li $a3, 0		# clear prev cursor
	jal set_cursor
	j handle_nl_done
	
	# go to the start of the last (current) line.
	handle_nl_reached_last_line_cursor_at_start:
	move $a0, $s0	# set [state]
	lbu $a1, 2($s0) # get X
	li $a2, 0		# start of line
	li $a3, 0		# clear prev cursor
	jal set_cursor
	
	handle_nl_done:
	lw $s0, 4($sp)
	lw $ra, 0($sp)
	addi $sp, $sp, 8
	jr $ra

handle_backspace:
	addi $sp, $sp, -8
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	# get current cursor positions from [struct]
	# calculate address of current cursor position
	# strcpy(String src, String dest, int n)
	# src = address of current cursor position
	# dest = src - 2
	
	# original [state]
	move $s0, $a0
	
	lbu $t0, 2($s0)				# current X
	lbu $t1, 3($s0)				# current Y
	li $t2, 160					# 160
	mul $t0, $t0, $t2			# $t0 = x * 160
	li $t2, 2					# $t2 = 160 * 2
	mul $t1, $t1, $t2			# $t1 = y * 2
	add $t0, $t1, $t0			# $t0 = x * 160 + y * 2
	addi $t2, $t0, 0xFFFF0000 	# $t2 = x * 160 + y * 2 + 0xFFFF0000
	
	addi $a0, $t2, 2
	addi $a1, $t2, 0
	li $t0, 80
	lbu $t1, 3($s0)
	sub $a2, $t0, $t1
	li $t0, 2
	mul $a2, $a2, $t0
	jal strcpy
	
	# set the last char in the row to \0 and default color
	lbu $t0, 2($s0)				# current X
	li $t1, 79
	li $t2, 160					# 160
	mul $t0, $t0, $t2			# $t0 = x * 160
	li $t2, 2					# $t2 = 160 * 2
	mul $t1, $t1, $t2			# $t1 = y * 2
	add $t0, $t1, $t0			# $t0 = x * 160 + y * 2
	addi $t2, $t0, 0xFFFF0000 	# $t2 = x * 160 + y * 2 + 0xFFFF0000
	lbu $t0, 0($s0)
	sb $0, 0($t2)
	sb $t0, 1($t2)
	
	lw $s0, 4($sp)
	lw $ra, 0($sp)
	addi $sp, $sp, 8
	jr $ra

highlight:
	li $t2, 160					# 160
	mul $t0, $a0, $t2			# $t0 = x * 160
	li $t2, 2					# $t2 = 2
	mul $t1, $a1, $t2			# $t1 = y * 2
	add $t0, $t1, $t0			# $t0 = x * 160 + y * 2
	addi $t2, $t0, 0xFFFF0000 	# $t2 = x * 160 + y * 2 + 0xFFFF0000	
	
	li $t0, 0 		# counter
	highlight_loop:
		beq $t0, $a3, highlight_loop_done
		sb $a2, 1($t2)
		
		addi $t2, $t2, 2
		addi $t0, $t0, 1
		j highlight_loop
	highlight_loop_done:
	jr $ra

highlight_all:
	#void highlight_all(byte color, String[] dictionary)
	move $s0, $a0	# color.byte
	move $s1, $a1	# dictionary[] address
	move $s4, $a1	# dictionary[]++ address
	li $s2, 0		# x position
	li $s3, 0		# y position
	# $s4 holds incremented dictionary[]++4
	# $s5 holds word from dictionary
	li $s6, 0xFFFF0000
	highlight_all_loop:
		li $t0, 25
		bne $s2, $t0, highlight_all_loop_not_done
		# if reached, we've reached the end of the loop
		j highlight_all_loop_done
		
		highlight_all_loop_not_done:
			highlight_all_loop_dict:
				lw $s5, 0($s4)
				
				#move $a0, $s5
				#li $v0, 4
				#syscall
				
				lw $a0, ($s6)
				li $v0, 1
				syscall

				move $a0, $s6
				move $a1, $s4
				jal mmio_streq
				#li $v0, 1
				#syscall
				
				beqz $s5, highlight_all_loop_dict_done
				
				addi $s4, $s4, 4
				j highlight_all_loop_dict
			highlight_all_loop_dict_done:
		addi $s6, $s6, 2
		# end incrementer (o)
		li $t0, 79
		bne $t0, $s3, highlight_all_loop_increment_y
		# if reached, then y = 79. set y = 0 and increment x by 1.
		li $s3, 0
		addi $s2, $s2, 1
		j highlight_all_loop
		
		highlight_all_loop_increment_y:
		addi $s3, $s3, 1
		j highlight_all_loop
		
	highlight_all_loop_done:
	jr $ra
