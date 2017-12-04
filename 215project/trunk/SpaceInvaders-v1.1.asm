.data

	newLine:  .asciiz "\n"
	screen: .word 0x10000000 			# Find where screen is located
	pixel: 	.word 1024				# Stores the number of pixels in the screen
	key:	.word 0xffff0004			# Stores keyboard input
	end:	.word 0x10000d80 			# you lose if aliens reach this (address of cell #771)
	green:  .word 0x0000ff00
	red:	.word 0x00ff0000
	purple: .word 0x00ff00ff
	blue:	.word 0x000000ff
	black:	.word 0x00000000
	white:	.word 0x00ffffff	
	yellow:	.word 0x00ffff00	
	shipLocation1:	.word 0x10000d94
	shipLocation2:	.word 0x10000de4
	rightBarrier:	.word 0x10000df8
	leftBarrier:	.word 0x10000d84
	
.text

	Initialization:
	
		lw	$s0, shipLocation1
		lw	$s7, shipLocation2
		li 	$v0, 30
		syscall
		move 	$s1, $a0 		# s1 will store system start time
		li 	$s2, 0			# s2 will store miliseconds since start
		li	$s3, 0			# s3 will be the time since bullet was last updated
		li	$s4, 0			# s4 will be the time since last bullet was fired by the player
		li	$s5, 0			# s5 is used for direction of aliens movement: right =1, left =0
		li	$s6, 0			# s6 will be the invader update time
		li	$t8, 300		# t8 will be the delay counter, we decrement this as the aliens die, so they travel faster
		li	$t9, 36			# This register stores the number of aliens remaining (used for checking end condition)
		
		jal	invaderFirstDraw
	
	main:
		beqz	$t9, gameOverInit
		jal 	timer
		jal 	drawPlayer1
		jal	drawPlayer2
		jal 	input1
		jal	input2
		jal	iteratePixels	
			
		j 	main

	gameOverInit:
	# PURPOSE: initialize game over sequence
	# All registers can be used because it's the last sequence

		li	$t1, 1024			# initialize game over sequence
		lw	$t0, screen
		li	$t2, 0				# $t2 - delta time
		li	$t3, 0				# $t3 - time stamp
		j	gameOver
		
	gameOver:
	# PURPOSE: draw entire screen in black and exit
		
		# A new square is drawn every ms
		jal	timer
		sub	$t2, $s2, $t3
		blt	$t2, 1, gameOver
	 
	 	# Update time stamp, then color red if lost, green if won
		add	$t3, $s2, $zero
		lw	$t2, red
		bnez	$t9, continueGameOver
		lw	$t2, green
		
		continueGameOver:
 		sw	$t2, ($t0) 		#Draw colour($t2) on address $t0
		addi	$t0, $t0, 4 		#Move forward to last pixel on row
		subi	$t1, $t1, 1 		#Used to make sure $t1 is not 0
		bgtz	$t1, gameOver 		#if greater than 0, loop
		
		# Once the game is over, terminate the program
		j	exit
	
	timer:
		li 	$v0,30			# Get system time
		syscall
		sub 	$s2, $a0, $s1		# Sub system start time from current system time to get program runtime
	
		jr	$ra			# return
		
	drawPlayer1:

		# Drawing the moved player ship	
		lw	$t3, green
		sw	$t3,($s0)
		sw	$t3,124($s0)
		sw	$t3,128($s0)
		sw	$t3,132($s0)
	
		jr	$ra
		
	drawPlayer2:
	
		# Drawing the moved player ship	
		lw	$t3, purple
		sw	$t3,($s7)
		sw	$t3,124($s7)
		sw	$t3,128($s7)
		sw	$t3,132($s7)
	
		jr	$ra
		
	exit:	
		jal	colorBlackInit
		li	$v0, 10 		#Terminate
		syscall	

				
 	############### (1.1) - Input BLOCK ############### 
#---------------------------------------------------------------# 
#$t0 contains the key press
#$t2 used as reset register for buttonPress function


	input1:
		
		lw	$t0, key 			# Updates key press
		lw	$t0, ($t0)
		
		beq	$t0, 0x00000077, condW	 	# if else statements for keyboard input
 		beq	$t0, 0x00000061, condA
 		beq	$t0, 0x00000064, condD
 		beq	$t0, 0x0000001B, condEsc	# Escape, terminates the program
	
		j	endCon 				

	condA:	
		# Checking if the player is on the left barrier
		lw	$t3, leftBarrier
		beq	$s0, $t3, buttonReset
		
 		beq	$s0, $t2, endCon 		# Checking if hit the right barrier, jumps to the conditional escape
 		add	$t4, $s0, $zero
 		subi	$s0, $s0, 4			# Move character one unit to the right
 		j 	eraseShip
 
	condD:
		# Checking if the player is on the left barrier	
		lw	$t3, rightBarrier
		beq	$s0, $t3, buttonReset
		
		beq	$s0, $t1, endCon 		# Checking if hit the left barrier, jumps to the conditional escape
		add	$t4, $s0, $zero
 		addi	$s0, $s0, 4			# Move character one unit to the left
 		j	eraseShip
 		
	condW:
		sub	$t7, $s2, $s4			# t7 is how many miliseconds since the bullet was last updated
		blt	$t7, 500, buttonReset		# Don't update blue if timer isn't ready
		
		add	$s4, $s2, $zero			# Save shooting update time
		lw	$t3, blue
		sw	$t3, -128($s0)
		j	buttonReset
	
	condEsc:
		j	exit
		
	eraseShip:
		# This block erases the pixels at the previous ship location after movement occurs
		lw	$t3, black
		sw	$t3, ($t4)
		sw	$t3, 124($t4)
		sw	$t3, 128($t4)
		sw	$t3, 132($t4)
		
		# Save return address and redraw ship
		addi	$sp, $sp, -4
		sw	$ra, 0($sp)
		
		jal	drawPlayer1
		
		lw	$ra, 0($sp)
		addi	$sp, $sp, 4
		
		j	buttonReset	
	
	buttonReset:
		# Resets the value stored in the "key" memory location; provides push-button functionality. 
		li	$t3, 2
		li	$a3, 0xffff0004  		# Store the key input address in a3
		sw	$t3, 0($a3) 			# Change the input value to t3
		j 	endCon

	#endCon:
		#jr	$ra				# Should return to "main"

	############## (1.2) - Input BLOCK ############### 
#---------------------------------------------------------------# 
#$t0 contains the key press
#$t2 used as reset register for buttonPress function


	input2:
		
		lw	$t0, key 			# Updates key press
		lw	$t0, ($t0)
		
		beq	$t0, 0x00000069, condI 		# if else statements for keyboard input
 		beq	$t0, 0x0000006A, condJ
 		beq	$t0, 0x0000006C, condL
 		beq	$t0, 0x0000001B, condEsc	# Escape, terminates the program
	
		j	endCon 				

	condJ:		
 		# Checking if the player is on the left barrier	
		lw	$t3, leftBarrier
		beq	$s7, $t3, buttonReset
		
 		beq	$s7, $t2, endCon 		# Checking if hit the right barrier, jumps to the conditional escape
 		add	$t4, $s7, $zero
 		subi	$s7, $s7, 4			# Move character one unit to the right
 		j 	eraseShip2
 
	condL:
		# Checking if the player is on the left barrier	
		lw	$t3, rightBarrier
		beq	$s7, $t3, buttonReset
		
		beq	$s7, $t1, endCon 		# Checking if hit the left barrier, jumps to the conditional escape
		add	$t4, $s7, $zero
 		addi	$s7, $s7, 4			# Move character one unit to the left
 		j	eraseShip2
 		
	condI:
		sub	$t7, $s2, $a2			# t7 is how many miliseconds since the bullet was last updated
		blt	$t7, 500, buttonReset		# Don't update blue if timer isn't ready
		
		add	$a2, $s2, $zero			# Save shooting update time
		lw	$t3, blue
		sw	$t3, -128($s7)
		j	buttonReset
		
	eraseShip2:
		# This block erases the pixels at the previous ship location after movement occurs
		lw	$t3, black
		sw	$t3, ($t4)
		sw	$t3, 124($t4)
		sw	$t3, 128($t4)
		sw	$t3, 132($t4)
		
		# Save return address and redraw ship
		addi	$sp, $sp, -4
		sw	$ra, 0($sp)
		
		jal	drawPlayer2
		
		lw	$ra, 0($sp)
		addi	$sp, $sp, 4
		
		j	buttonReset		
	
	endCon:
		jr	$ra				# Should return to "main"

		
############### (1.1) - PIXEL LOOP BLOCK ############### 
#---------------------------------------------------------------# 
#

	iteratePixels:
		
		move	$t4, $s5
		sub	$t7, $s2, $s3			# t7 is how many miliseconds since the bullet was last updated
		sub	$t6, $s2, $s6			# t6 is how many miliseconds since the invaders was last updated
		li	$t0, 4096			# t0 will be the loop counter
		
		loop:
			beq 	$t0, 0, loopExit	# There are 4096/4 pixels on the screen
			lw	$t1, screen		
			add	$t1, $t1, $t0		# Add pixel counter to screen address to get current pixel address
		
			lw	$t2, blue		# Get blue
			lw	$t3, ($t1)		# Get current pixel color
			beq	$t2, $t3, ifBlue	# Skip to next loop if current pixel is not blue
			
			lw	$t2, white		# Get white
			beq	$t2, $t3, ifWhite	# Go to white branch if our pixel is white
			
			j 	iterate
		
		ifBlue:

			blt	$t7, 75, iterate	# Don't update blue if timer isn't ready
			
			# Save return address and go to blue pixel logic
			addi	$sp, $sp, -4
			sw	$ra, 0($sp)
		
			jal	bluePixel
		
			lw	$ra, 0($sp)
			addi	$sp, $sp, 4
				
			j	iterate
			
		ifWhite:
			
			blt	$t6, $t8, iterate	# Don't update white if timer isn't ready
			
			# Save return address and go to white pixel logic
			addi	$sp, $sp, -4
			sw	$ra, 0($sp)
		
			jal	whitePixel
		
			lw	$ra, 0($sp)
			addi	$sp, $sp, 4
				
			j	iterate

		iterate:
			addi	$t0, $t0, -4
			j 	loop
		
	loopExit:
		
		beq	$t4, 1, setRight
		beq	$t4, 0, setLeft
		
		setRight:
			li	$s5, 1
			j 	done
		setLeft:
			li	$s5, 0
			j 	done
		
	done:
		jr	$ra	
		
		
		
	bluePixel:
	
		add	$s3, $s2, $zero			# Save bullet update time
		
		# Check pixel above for collision
		lw	$t3, -128($t1)
		lw	$t2, white
		beq	$t3, $t2, bulletCollide
		
		# Check pixel below
		lw	$t3, 128($t1)
		lw	$t2, blue
		beq	$t3, $t2, twoPixels
		
		j	onePixel

		
		twoPixels:
			lw	$t2, black
			sw	$t2, 128($t1)
			j	doneBlue
		
		onePixel:
			blt	$t0, 256, deleteBlue	
			lw	$t2, blue
			sw	$t2, -128($t1)
			j	doneBlue
		
		deleteBlue:
			lw	$t2, black
			sw	$t2, ($t1)
			j	doneBlue
		
		bulletCollide:
			subi	$t8, $t8, 10		# Decreasing the delay between alien movements (happens when alien hit)
			subi	$t9, $t9, 1		# Decreases the number of aliens
			
			lw	$t2, black
			sw	$t2, ($t1)
			sw	$t2, -128($t1)
			
			lw	$t3, 128($t1)
			lw	$t2, white
			beq	$t2, $t3, doneBlue
			
			lw	$t2, black
			sw	$t2, 128($t1)
			j	doneBlue
	
	doneBlue:
	
		jr	$ra
		
		
	whitePixel:
	
		add	$s6, $s2, $zero			# Save invader update time
		
		# If the white pixel is on the last row, jump to game over
		bgt	$t0, 0x00000d80, gameOverInit

		beq	$s5, 1, moveInvaderRight
		beq	$s5, 0, moveInvaderLeft
		
		doneInvaderMove:
		#j	doneWhite
		
		bne	$t4, $s5, doneWhite
		
		#addi	$t0, $t0, 4
		div	$t5, $t0, 128
		mfhi	$t5
		
		beq	$t5, 120, rightEnd 
		
		div	$t5, $t0, 128		# If the remainder of currentPixel/128 is 0, the pixel is on the left side
		mfhi	$t5
		beq	$t5, 0, leftEnd
		
		j 	doneWhite
		
		leftEnd:
		
			li	$t4, 1			# Set direction to right
		
			# Save return address and go to blue pixel logic
			addi	$sp, $sp, -4
			sw	$ra, 0($sp)
		
			jal	moveInvadersDownAndRight
		
			lw	$ra, 0($sp)
			addi	$sp, $sp, 4
			
			j	doneWhite
			
		rightEnd:
			
			li	$t4, 0			# Set direction to left
			
			# Save return address and go to blue pixel logic
			addi	$sp, $sp, -4
			sw	$ra, 0($sp)
		
			jal	moveInvadersDownAndLeft
		
			lw	$ra, 0($sp)
			addi	$sp, $sp, 4
			
			j	doneWhite
			
			j	doneWhite
		
		moveInvaderLeft:
			
			lw	$t2, black
			sw	$t2, ($t1)		# Replace current alien location with black
			
			# Check pixel above for collision
			lw	$t3, -4($t1)
			lw	$t2, blue
			beq	$t3, $t2, leftAlienCollide
		
			addi	$t0, $t0, -4
			
			lw	$t1, screen		
			#addi	$t4, $t4, 4		
			add	$t1, $t1, $t0
			lw	$t2, white
			sw	$t2, ($t1)
			j	doneInvaderMove
			
			leftAlienCollide:
				subi	$t8, $t8, 10
				subi	$t9, $t9, 1
				lw	$t2, black
				#sw	$t2, ($t1)
				sw	$t2, -4($t1)
			
			j	doneInvaderMove
			
		moveInvaderRight:
			
			lw	$t2, black
			sw	$t2, ($t1)		# Replace current alien location with black
			
			# Check pixel above for collision
			lw	$t3, 4($t1)
			lw	$t2, blue
			beq	$t3, $t2, rightAlienCollide
		
			lw	$t2, white
			sw	$t2, 4($t1)
			
			j	doneInvaderMove
			
			rightAlienCollide:
				subi	$t8, $t8, 10
				subi	$t9, $t9, 1
				lw	$t2, black
				sw	$t2, 4($t1)
				j	doneInvaderMove
				
		moveInvadersDownAndRight:
		
			li	$t7, 3840
			
			moveDownLoop:
				blt	$t7, 384, moveDownExit
				
				# Check if current pixel is white
				lw	$t6, screen
				add	$t6, $t6, $t7
				lw	$t5, white
				lw	$t3, ($t6)
				bne	$t3, $t5, iterateMoveDown
				
				# Color pixel below white
				sw	$t5, 132($t6)
				lw	$t5, black
				sw	$t5, ($t6)
				
				
				iterateMoveDown:
					addi	$t7, $t7, -4
					j	moveDownLoop
					
			moveDownExit:
				jr	$ra
				
		moveInvadersDownAndLeft:
		
			li	$t7, 3840
			
			moveDownLoopLeft:
				blt	$t7, 384, moveDownLeftExit
				
				# Check if current pixel is white
				lw	$t6, screen
				add	$t6, $t6, $t7
				lw	$t5, white
				lw	$t3, ($t6)
				bne	$t3, $t5, iterateMoveDownLeft
				
				# Color pixel below white
				sw	$t5, 124($t6)
				lw	$t5, black
				sw	$t5, ($t6)
				
				
				iterateMoveDownLeft:
					addi	$t7, $t7, -4
					j	moveDownLoopLeft
					
			moveDownLeftExit:
				jr	$ra
			
	
	doneWhite:
	
		jr	$ra
		
		
		
		
		
		
invaderFirstDraw:
# PURPOSE: handles the initial drawing of borders and aliens, only executes once at beginning.																							

# $t0 - Designates current pixel being looked at by loop.
# $t1 - Used as a counter (stores amount of pixels in screen)
# $t2 - Miscellaneous, used as needed (colors, randoms, etc.)
# $t3 - Unused currently
# $t4 -	Movement flag (1 = Right, 0 = Left)
# $t5 - Unused currently
# $t6 - Color of previous pixel (for comparisons)
# $t7 - color of current pixel (for comparisons)	

	
 	lw	$t0, screen 		# Pixel that is being drawn
 	lw	$t1, pixel		# How many pixels are left
 	lw	$t2, white	 	# Colour (white) 0x00RRGGBB
 	
 			
drawTopBars:
# PURPOSE: Draw the borders on the top of the screen

	lw	$t2, yellow		# load the color yellow into $t2
 	sw	$t2, ($t0)		# Draw colour($t2) on address $t0
	addi	$t0, $t0, 4 		# Move forward to last pixel on row
	subi	$t1, $t1, 32 		# Used to make sure $t1 is not 0
	
	bgtz	$t1, drawTopBars 	#if greater than 0, loop
	
goToBottom:
# PURPOSE: Send the cursor to the bottom of the screen

	addi	$t0, $t0, 3840
	addi	$t1, $t1, 1024
	
drawBottomBar:
# PURPOSE: Draw the bottom borders

	lw	$t2, yellow		# load the color yellow into $t2
 	sw	$t2, ($t0) 		# Draw colour($t2) on address $t0
	addi	$t0, $t0, 4		# Move forward to last pixel on row
	subi	$t1, $t1, 32		# Used to make sure $t1 is not 0
	
	bgtz	$t1, drawBottomBar 	#if greater than 0, loop
	
goTo392:
# PUPROSE: Go to the address 392, (position of first alien to be drawn)

	li	$t0, 0x10000188		# goto address 392
	addi	$t1, $t1, 9

drawAliens1:
# PURPOSE: Draw the first row of aliens

	lw	$t2, white		# load the color white into $t2
	sw	$t2, ($t0) 		# Draw colour($t2) on address $t0
	addi	$t0, $t0, 8 		# Move forward to last pixel on row
	subi	$t1, $t1, 1 		# Used to make sure $t1 is not 0
	
	bgtz	$t1, drawAliens1 	#if greater than 0, loop
	
gotoNRow:
# PURSPOSE: Goes to the beginning of next alien row (Second row)
	addi	$t0, $t0, 184	
	addi	$t1, $t1, 9
	
drawAliens2:
# PURPOSE: Draws the second row of aliens

	lw	$t2, white		# load the color white in t2
	sw	$t2, ($t0) 		# Draw colour($t2) on address $t0
	addi	$t0, $t0, 8 		# Move forward to last pixel on row
	subi	$t1, $t1, 1 		# Used to make sure $t1 is not 0
	
	bgtz	$t1, drawAliens2 	# if greater than 0, loop
	 
gotoNNRow:
# PURPOSE: Goes to begininng of the third alien row

	addi	$t0, $t0, 184
	addi	$t1, $t1, 9
	
drawAliens3:
# PURPOSE: Draws the thrid row of aliens

	lw	$t2, white		# load the color white in t2
	sw	$t2, ($t0) 		# Draw colour($t2) on address $t0
	addi	$t0, $t0, 8		# Move forward to last pixel on row
	subi	$t1, $t1, 1 		# Used to make sure $t1 is not 0
	
	bgtz	$t1, drawAliens3 	#if greater than 0, loop

gotoNNNRow:
# PURPOSE: Goes to the begininng of the fourth row

	addi	$t0, $t0, 184
	addi	$t1, $t1, 9
	
drawAliens4:
# PURPOSE: Draw the fourth row of aliens
	lw	$t2, white		# load the color white in t2
	sw	$t2, ($t0) 		# Draw colour($t2) on address $t0
	addi	$t0, $t0, 8 		# Move forward to last pixel on row
	subi	$t1, $t1, 1 		# Used to make sure $t1 is not 0
	
	bgtz	$t1, drawAliens4 	# if greater than 0, loop
	
	jr 	$ra
				
colorBlackInit:
# PURPOSE: initialize game over sequence
# All registers can be used because it's the last sequence

	li	$t1, 1024			# initialize game over sequence
	lw	$t0, screen
	li	$t2, 0				# $t2 - delta time
	li	$t3, 0				# $t3 - time stamp
	j	colorBlack
		
colorBlack:
# PURPOSE: draw entire screen in black and exit

	lw	$t2, black
 	sw	$t2, ($t0) 		#Draw colour($t2) on address $t0
	addi	$t0, $t0, 4 		#Move forward to last pixel on row
	subi	$t1, $t1, 1 		#Used to make sure $t1 is not 0
	bgtz	$t1, colorBlack 	#if greater than 0, loop
	jr 	$ra
		
		
		
		
		
		
		
