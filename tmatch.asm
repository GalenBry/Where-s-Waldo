# Bryant
# Galen
.data
displayBuffer:  .space 0x80000  # space for 512x256 bitmap display 
errorBuffer:    .space 0x80000  # space to store match function
templateBuffer: .space 0x400	# space for 8x8 template
imageFileName:    .asciiz "pxlcon512x256cropgs.raw"  # filename of image to load 
templateFileName: .asciiz "template8x8gs.raw"	     # filename of template to load
#struct bufferInfo { int *buffer, int width, int height, char* filename }
imageBufferInfo:    .word displayBuffer  512 256  imageFileName
errorBufferInfo:    .word errorBuffer    512 256  0
templateBufferInfo: .word templateBuffer 8   8    templateFileName

.text
main:	la $a0, imageBufferInfo
	jal loadImage
	la $a0, templateBufferInfo
	jal loadImage
	la $a0, imageBufferInfo
	la $a1, templateBufferInfo
	la $a2, errorBufferInfo	
	jal matchTemplate        # MATCHING DONE HERE
	la $a0, errorBufferInfo
	jal findBest
	la $a0, imageBufferInfo
	move $a1, $v0
	jal highlight
	la $a0, errorBufferInfo	
	jal processError
	li $v0, 10		# exit
	syscall
	

##########################################################
# matchTemplate( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplate:	
	lw $s0, ($a0) #displayBufferInfo
	la $s0, ($s0) #address of diplayBuffer
	
	lw $s1, ($a1) #templateBufferInfo
	la $s1, ($s1) #adress of templateBuffer
	
	lw $s2, ($a2)  #errorBufferInfo
	la $s2, ($s2) #adress of errorBuffer
	
	lw $s3, 8($a0) #image height
	addi $s3, $s3, -8 #image height-8
	lw $s4, 4($a0) #image width
	addi $s4, $s4, -8#image width-8
	
	add $t9,$zero,$s0 #address of display
	
	li $s5, 0 #block pixelcounter
	li $s6, 0 #block counter
	
	li $t0, 0 #y=1
matchLoop1: bgt $t0, $s4, endMatch #if y <= imgage height-8
	addi $t0, $t0, 1 #y++
	li $t1, 0 #x=1 
matchLoop2: bgt $t1, $s3, matchLoop1 #if image width=x
	
	#traverse errorBuffer
	add $t8,$s2,$zero # load address of error plus error pixel counter
	addi $s2, $s2, 4 #++ error pixel counter
	
	#traverse templateBuffer
	add $t4,$s1,$zero # reset template buffer 

	#traverse displayBuffer
	add $t9,$s0,$zero #address of displayBuffer
	add $t9, $t9, $s6 #address with block offset
	add $s6, $s6, 4 #block counter
	
	addi $t1, $t1, 1 #x++
        li $t2, 0 #j=0      
matchLoop3: beq $t2, 8, matchLoop2 #if template height=j
	addi $t2, $t2, 1 #j++	
 	li $t3, 0 #i=0 
matchLoop4:  beq $t3, 8, matchLoop3 #if template height=i			
	
	#traverse templateBuffer 
	lw $v1, ($t4) #receive low byte data at that address
	addi $t4, $t4, 4 #next pixel
	
	#when line in block ends
	bne $t3, 7, loadPixel #if i= 7
	lw $v0, ($t9) #load byte at display
	addi $t9, $t9, 2020 #after 8 pixels, next line
	j nextLine
	
loadPixel: lw $v0, ($t9) #load byte at display
	addi $t9, $t9, 4 #next pixel

nextLine:
	#calculate |I[i+x][j+y] - T[i][j]|
	sub $v0, $v0, $v1 #I[i+x][j+y] - T[i][j]
	abs $v0, $v0 #absolute of ^
	
	#add to existing info at E[x,y]
	lw $v1, ($t8) #load byte at E[x,y]
	add $v0, $v0, $v1 
	
	sw $v0, ($t8) #place E[x,y]	
	
	addi $t3, $t3, 1 #i++
	j matchLoop4

endMatch: jr $ra	
	
	
	
###############################################################
# loadImage( bufferInfo* imageBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
loadImage:	lw $a3, 0($a0)  # int* buffer
		lw $a1, 4($a0)  # int width
		lw $a2, 8($a0)  # int height
		lw $a0, 12($a0) # char* filename
		mul $t0, $a1, $a2 # words to read (width x height) in a2
		sll $t0, $t0, 2	  # multiply by 4 to get bytes to read
		li $a1, 0     # flags (0: read, 1: write)
		li $a2, 0     # mode (unused)
		li $v0, 13    # open file, $a0 is null-terminated string of file name
		syscall
		move $a0, $v0     # file descriptor (negative if error) as argument for read
  		move $a1, $a3     # address of buffer to which to write
		move $a2, $t0	  # number of bytes to read
		li  $v0, 14       # system call for read from file
		syscall           # read from file
        	# $v0 contains number of characters read (0 if end-of-file, negative if error).
        	# We'll assume that we do not need to be checking for errors!
		# Note, the bitmap display doesn't update properly on load, 
		# so let's go touch each memory address to refresh it!
		move $t0, $a3	   # start address
		add $t1, $a3, $a2  # end address
loadloop:	lw $t2, ($t0)
		sw $t2, ($t0)
		addi $t0, $t0, 4
		bne $t0, $t1, loadloop
		jr $ra
		
		
#####################################################
# (offset, score) = findBest( bufferInfo errorBuffer )
# Returns the address offset and score of the best match in the error Buffer
findBest:	lw $t0, 0($a0)     # load error buffer start address	
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		li $v0, 0		# address of best match	
		li $v1, 0xffffffff 	# score of best match	
		lw $a1, 4($a0)    # load width
        	addi $a1, $a1, -7 # initialize column count to 7 less than width to account for template
fbLoop:		lw $t9, 0($t0)        # score
		sltu $t8, $t9, $v1    # better than best so far?
		beq $t8, $zero, notBest
		move $v0, $t0
		move $v1, $t9
notBest:	addi $a1, $a1, -1
		bne $a1, $0, fbNotEOL # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width
        	addi $a1, $a1, -7     # column count for next line is 7 less than width
        	addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
fbNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, fbLoop
		lw $t0, 0($a0)     # load error buffer start address	
		sub $v0, $v0, $t0  # return the offset rather than the address
		jr $ra
		

#####################################################
# highlight( bufferInfo imageBuffer, int offset )
# Applies green mask on all pixels in an 8x8 region
# starting at the provided addr.
highlight:	lw $t0, 0($a0)     # load image buffer start address
		add $a1, $a1, $t0  # add start address to offset
		lw $t0, 4($a0) 	# width
		sll $t0, $t0, 2	
		li $a2, 0xff00 	# highlight green
		li $t9, 8	# loop over rows
highlightLoop:	lw $t3, 0($a1)		# inner loop completely unrolled	
		and $t3, $t3, $a2
		sw $t3, 0($a1)
		lw $t3, 4($a1)
		and $t3, $t3, $a2
		sw $t3, 4($a1)
		lw $t3, 8($a1)
		and $t3, $t3, $a2
		sw $t3, 8($a1)
		lw $t3, 12($a1)
		and $t3, $t3, $a2
		sw $t3, 12($a1)
		lw $t3, 16($a1)
		and $t3, $t3, $a2
		sw $t3, 16($a1)
		lw $t3, 20($a1)
		and $t3, $t3, $a2
		sw $t3, 20($a1)
		lw $t3, 24($a1)
		and $t3, $t3, $a2
		sw $t3, 24($a1)
		lw $t3, 28($a1)
		and $t3, $t3, $a2
		sw $t3, 28($a1)
		add $a1, $a1, $t0	# increment address to next row	
		add $t9, $t9, -1	# decrement row count
		bne $t9, $zero, highlightLoop
		jr $ra

######################################################
# processError( bufferInfo error )
# Remaps scores in the entire error buffer. The best score, zero, 
# will be bright green (0xff), and errors bigger than 0x4000 will
# be black.  This is done by shifting the error by 5 bits, clamping
# anything bigger than 0xff and then subtracting this from 0xff.
processError:	lw $t0, 0($a0)     # load error buffer start address
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		lw $a1, 4($a0)     # load width as column counter
        	addi $a1, $a1, -7  # initialize column count to 7 less than width to account for template
pebLoop:	lw $v0, 0($t0)        # score
		srl $v0, $v0, 5       # reduce magnitude 
		slti $t2, $v0, 0x100  # clamp?
		bne  $t2, $zero, skipClamp
		li $v0, 0xff          # clamp!
skipClamp:	li $t2, 0xff	      # invert to make a score
		sub $v0, $t2, $v0
		sll $v0, $v0, 8       # shift it up into the green
		sw $v0, 0($t0)
		addi $a1, $a1, -1        # decrement column counter	
		bne $a1, $0, pebNotEOL   # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width to reset column counter
        	addi $a1, $a1, -7     # column count for next line is 7 less than width
        	addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
pebNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, pebLoop
		jr $ra
