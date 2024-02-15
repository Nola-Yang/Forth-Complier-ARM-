# Forth-Complier-ARM

This project is based on "jonesforth". I follow his tutorial to implement a simple Forth complier in armv7.

由于arm64中，stack是16 bytes alignment的，为了方便，我在数据段分配两个大小为1024 bytes的空间分别作为return stack和data stack

Word 的结构
<--- DICTIONARY ENTRY (HEADER) ----------------------->
	+------------------------+--------+---------- - - - - +----------- - - - -
	| LINK POINTER           |LENGTH/ | NAME	          | DEFINITION
	|			             | FLAGS  | and pading
	+--- (8 bytes) ----------+-8 byte-+- n bytes  - - -  -+----------- - - - -

Note:
1. Link pointer: Point to the previous word. Since the address is 8 bytes alignment, the lowest 3 bits can be used to store information.
2. The length of word is smaller than 31 characters(5 bits), and 3 bits is used as flag. 8bytes totally
3. For the 8 bytes alignment requirement of arm64, some pad is added. Then, the start address of instruction is the multiple of 8.

 pointer to previous word
	   ^
	   |
	+--|------+---+---+---+---+------------+
	| LINK    | 3 | D | U | P | code_DUP ---------------------> points to the assembly
	+---------+---+---+---+---+------------+		            code used to write DUP,
               len              codeword			            which ends with NEXT.
        |
	  LINK in next word

codeword:
为了执行一个复杂的word，就像c语言在一个函数中call另一个函数一样，我们借助codeword这个结构进行跳转。这里有两种情况，如果我们要call的word是编译器中本来就定义的，那么我们直接跳转到asm的地址去执行就好了。那么codeword中存的是一个跳转到执行代码的指针，如果我们要执行的是一个复合word，即，由其它word定义的word，codeword里面保存的则是解释器的地址，而这个解释器的作用，只不过是跳过这个codeword罢了。

Exit:
从return stack中取出地址返回