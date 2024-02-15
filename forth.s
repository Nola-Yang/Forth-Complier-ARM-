/* 
forth complier的组件：
1. dictionary, to find the pointer of Word
2. x0存codeword地址
3. flag+length怎么把flag放在高三位
4. 宏定义的link初始化的地址不对
*/

/*
Calling Convention
    x0: the addr of the codeworde (DOL)
    x19: instruction pointer，指向当前操作的数据或下一条指令的地址
    x28: stack pointer of the data stack
    x29: stack pointer of the return stack
*/

// Next, DTC & ITC, 执行instruction pointer指向地址的代码，并自动更新指向下一地址
// 直到Exit。ret通过exit来实现
.macro NEXT
    ldr x1, [x19], #8    
    br x1          
.endm


//data stack operations
.macro PUSHDS reg
    sub x28, x28, #8       
    str \reg, [x28]        
.endm

.macro POPDS reg
    ldr \reg, [x28]        
    add x28, x28, #8       
.endm

//return stack operations
.macro PUSHRSP reg
    sub x29, x29, #8       
    str \reg, [x29]        
.endm

.macro POPRSP reg
    ldr \reg, [x29]        
    add x29, x29, #8       
.endm


.section .text
.align 3
DOCOL:
    PUSHRSP x19           // 保存当前指令指针
    add x0, x0, #8       // 跳过word的头部信息，codeword is a pointer, 8bytes
    mov x19, x0
    NEXT


//分配空间建立return stack和data stack
.section .data
    .align 3
data_stack:
    .space 1024
    .align 3
return_stack:
    .space 1024

.section .text
.globl _start
_start:
    ldr x28, =data_stack + 1024    // 初始化数据栈指针
    ldr x29, =return_stack + 1024  // 初始化返回栈指针

    // x28 用作数据栈指针，var_S0 是一个地址，存储初始数据栈指针
    adr x0, var_S0
    str x28, [x0]

    // 设置数据段
    bl set_up_data_segment

    // 初始化解释器
    ldr x19, =cold_start
    NEXT    

    .set F_IMMED, 0x80    // 标记位立即词, 1000 0000
    .set F_HIDDEN, 0x20   // 标记位隐藏词, 0010 0000
    .set F_LENMASK, 0x1f  // 长度掩码, 0001 1111

    .set link, 0 //intialize the link pointer

.section .rodata
//store the addr of the "first" instruction
cold_start:
    .xword QUIT

.macro defword name, namelen, flags=0, label
    .section .rodata
    .align 3
    .globl \name\label
\name\label :
    .xword link        // link pointer
    .set link, \name\label
    .byte (\flags << 5) | (\namelen & 0x1F)    // flags + length byte
    .ascii "\name"           // the name
    .align 3                 // padding to next 8 bytes boundary
    .globl \label
\label :
    .xword DOCOL             // codeword - the interpreter
.endm



.macro defcode name, namelen, flags=0, label
    .section .rodata
    .align 3
    .globl \name\label
\name\label :
    .xword link        // link
    .set link, \name\label
    .byte (\flags << 5) | (\namelen & 0x1F)    // flags + length byte
    .ascii "\name"           // the name
    .align 3                 // padding to next 8 bytes boundary
    .globl \label
\label :
    .xword code_\label       // codeword
    .section .text
    .align 3                
    .globl code_\label
code_\label :               // assembler code follows
.endm

    defcode "DROP",4,,DROP
	POPDS x0		// drop top of stack
	NEXT

    defcode "SWAP",4,,SWAP
	POPDS x0		// swap top two elements on stack
	POPDS x1
	PUSHDS x0
	PUSHDS x1
	NEXT

    defcode "DUP",3,,DUP
    ldr x0, [x28]
	PUSHDS x0
	NEXT

    defcode "OVER",4,,OVER
    ldr x0, [x28, #8]
	PUSHDS x0		// and push it on top
	NEXT

    defcode "ROT",3,,ROT
	POPDS x0
	POPDS x1
	POPDS x2
	PUSHDS x1
	PUSHDS x0
	PUSHDS x2
	NEXT

    defcode "-ROT",4,,NROT
	POPDS x0
	POPDS x1
	POPDS x2
	PUSHDS x0
	PUSHDS x2
	PUSHDS x1
	NEXT

    defcode "2DROP",5,,TWODROP // drop top two elements of stack
	POPDS x0
	POPDS x0
	NEXT

    defcode "2DUP",4,,TWODUP // duplicate top two elements of stack
    ldr x0, [x28]
    ldr x1, [x28, #8]
	PUSHDS x1
	PUSHDS x0
	NEXT

    defcode "2SWAP",5,,TWOSWAP // swap top two pairs of elements of stack
	POPDS x0
	POPDS x1
	POPDS x2
	POPDS x3
	PUSHDS x1
	PUSHDS x0
	PUSHDS x3
	PUSHDS x2
	NEXT

    defcode "?DUP",4,,QDUP	// duplicate top of stack if non-zero
    ldr x0, [x28]       
    cbnz x0, .Ldup     // 如果 x0（栈顶值）非零，则跳转到标签 .Ldup
    b .Lnext           // 否则，直接跳转到 NEXT 宏
.Ldup:
    PUSHDS x0
.Lnext:
    NEXT           

    defcode "1+",2,,INCR
    POPDS x0
    add x0, x0, #1
    PUSHDS x0	// increment top of stack
	NEXT 

    defcode "1-",2,,DECR
	POPDS x0
    sub x0, x0, #1
    PUSHDS x0	// decrement top of stack
	NEXT  

    defcode "8+",2,,INCR8
    POPDS x0
    add x0, x0, #8
    PUSHDS x0		// add 8 to top of stack
	NEXT

    defcode "8-",2,,DECR8
	POPDS x0
    sub x0, x0, #8
    PUSHDS x0			// subtract 8 from top of stack
	NEXT

    defcode "+",1,,ADD
	POPDS x0		// get top of stack
    POPDS x1
    add x1, x1, x0
    PUSHDS x1   // and add it to next word on stack
	NEXT

    defcode "-",1,,SUB
	POPDS x0		// get top of stack
    POPDS x1
    sub x1, x1, x0
    PUSHDS x1   	// and subtract it from next word on stack
	NEXT

    defcode "*",1,,MUL
    POPDS x0
	POPDS x1
	mull x0, x0, x1
	PUSHDS x0		// ignore overflow
	NEXT

    defcode "/MOD",4,,DIVMOD
    POPDS x1     // 从栈上 pop 出被除数到 x1
    POPDS x0   // 从栈上 pop 出除数到 x0，并更新栈指针
    cmp x0, #0
    beq .Ldiv_zero       // 如果除数为零，跳转到错误处理
    sdiv x2, x1, x0      // x2 = x1 / x0
    msub x3, x0, x2, x1  // x3 = x1 - x0 * x2
    PUSHDS x2  // push 商到栈上
    PUSHDS x3   // push 余数到栈上
    NEXT               // 跳转到下一个 Forth 词
.Ldiv_zero:
    NEXT
	

    defcode "=",1,,EQU	// top two words are equal?
	POPDS x0
	POPDS x1
	cmp x1, x0
	cset x0, eq          // 如果相等 (eq)，则将 w0 设置为 1；否则设置为 0
    PUSHDS x0
	NEXT

    defcode "<>",2,,NEQU	// top two words are not equal?
	POPDS x0
	POPDS x1
	cmp x1, x0
	cset x0, ne          // 如果不相等，则将 w0 设置为 1；否则设置为 0
    PUSHDS x0
	NEXT

    defcode "<",1,,LT
	POPDS x0
	POPDS x1
	cmp x0, x1           // 比较 x0 和 x1
    cset x0, lt          // 如果 x0 < x1 (lt)，则将 w0 设置为 1；否则设置为 0
	PUSHDS x0
	NEXT

    defcode ">", 1,, GT
    POPDS x0
	POPDS x1
	cmp x0, x1           
    cset x0, gt          
	PUSHDS x0
    NEXT

    defcode "<=",2,,LE
	POPDS x0
	POPDS x1
	cmp x0, x1           
    cset x0, le          
	PUSHDS x0
	NEXT

    defcode ">=",2,,GE
	POPDS x0
	POPDS x1
	cmp x0, x1           
    cset x0, ge          
	PUSHDS x0
	NEXT

    defcode "0=", 2,, ZEQU
    POPDS x0    // 从栈上 pop 出一个元素到 w0
    cbz x0, .Lzero      // 检查 w0 是否为零
    mov x0, #0          // 如果不为零，设置 w0 为 0
    b .Ldone            // 跳转到结束标签
.Lzero:
    mov x0, #1          // 如果为零，设置 w0 为 1
.Ldone:
    PUSHDS x0            
    NEXT  

    defcode "0<>", 3,, ZNEQU
    POPDS x0   
    cbnz x0, .Lnot_zero
    mov x0, #0          // 如果为零，设置 w0 为 0
    b .Ldone            // 跳转到结束标签
.Lnot_zero:
    mov w0, #1          // 如果非零，设置 w0 为 1
.Ldone:
    PUSHDS x0
    NEXT 

    defcode "0<", 2,, ZLT
    POPDS x0
    cmp x0, #0          
    cset x0, mi        
    PUSHDS x0
    NEXT 

    defcode "0>", 2,, ZGT
    POPDS x0
    cmp x0, #0          
    cset x0, gt        
    PUSHDS x0
    NEXT  

    defcode "0<=", 3,, ZLE
    POPDS x0
    cmp x0, #0          
    cset x0, le        
    PUSHDS x0
    NEXT             

    defcode "0>=",3,,ZGE
	POPDS x0
    cmp x0, #0          
    cset x0, ge        
    PUSHDS x0
	NEXT

    defcode "AND", 3,, AND
    POPDS x0
    ldr x1, [x28]
	and x0, x0, x1
    PUSHDS x0
    NEXT

    defcode "OR",2,,OR	// bitwise OR
	POPDS x0
    ldr x1, [x28]
	orr x0, x0, x1
    PUSHDS x0
	NEXT
    
    defcode "XOR",3,,XOR	// bitwise XOR
	POPDS x0
    ldr x1, [x28]
	xor x0, x0, x1
    PUSHDS x0
	NEXT

    defcode "INVERT", 6,, INVERT
    POPDS x0        // 从栈上加载元素到 w0
    mvn x0, x0          // 对 w0 执行位取反运算
    PUSHDS x0
    NEXT         

    defcode "EXIT",4,,EXIT
	POPRSP x19	// pop return stack into %esi
	NEXT

    defcode "LIT",3,,LIT
	ldr x0, [x19], #8
	PUSHDS x0	// push the literal number on to stack
	NEXT

    defcode "!",1,,STORE
	POPDS x1		// address to store at
	POPDS x0		// data to store there
    str x0, [x1]
	NEXT

    defcode "@",1,,FETCH
	POPDS x1		// address to fetch
    ldr x0, [x1]
	PUSHDS x1		// push value onto stack
	NEXT

    defcode "+!",2,,ADDSTORE
	POPDS x1		// address
	POPDS x0		// the amount to add
    ldr x2, [x1]
    add x2, x2, x0
    str x2, [x1]
	NEXT

    defcode "-!",2,,SUBSTORE
	POPDS x1		// address
	POPDS x0		// the amount to subtract
    ldr x2, [x1]
    sub x2, x2, x0
    str x2, [x1]
	NEXT

    defcode "C!",2,,STOREBYTE
	POPDS x1		// address to store at
	POPDS x0		// data to store there
    strb w0, [x1]
	NEXT

    defcode "C@",2,,FETCHBYTE
	POPDS x1		// address to fetch
	xor x0, x0, x0
	strb x0, [x1]		// fetch it
	PUSHDS x0		// push value onto stack
	NEXT

    defcode "C@C!",4,,CCOPY
    ldr x1, [x28, #8]    // 从栈上加载源地址到 x1
    ldrb w2, [x1]       // 从源地址 x1 加载一个字节到 w2
    POPDS x0
    strb w2, [x0]       // 将字节 w2 存储到目的地址 x0
    add x0, x0, #1      // 增加目的地址
    PUSHDS x0    // 更新栈上的目的地址
    add x1, x1, #1      // 增加源地址
    str x1, [x28, #8]    // 更新栈上的源地址
	NEXT

    defcode "CMOVE",5,,CMOVE
    mov x2, x19       // 保留 x19 (类似于 x86 中的 %esi)
    POPDS x3 // 从栈上加载长度
    POPDS x1  // 从栈上加载目的地址到 x1
    POPDS x0 // 从栈上加载源地址到 x0
// 循环复制字节
.Lcopy_loop:
    subs w3, w3, #1   // 减少计数器并设置条件标志
    b.lt .Ldone       // 如果计数器小于 0，则完成
    ldrb w4, [x0], #1 // 从源地址加载一个字节并增加源地址
    strb w4, [x1], #1 // 将字节存储到目的地址并增加目的地址
    b .Lcopy_loop     
.Ldone:
    mov x19, x2       // 恢复 x19
	NEXT

.macro defvar name, namelen, flags=0, label, initial=0
    defcode \name, \namelen, \flags, \label
    // 生成 Forth 代码将变量地址推入栈
    ldr x0, =var_\name   // 加载变量地址到 x0
    PUSHDS x0   // 将变量地址推入栈
    NEXT               // 跳转到下一个 Forth 词
    .data
    .align 3              
    .globl var_\name
var_\name :
    .xword \initial      
.endm

    defvar "STATE",5,,STATE
	defvar "HERE",4,,HERE
	defvar "LATEST",6,,LATEST,name_SYSCALL0 // SYSCALL0 must be last in built-in dictionary
	defvar "S0",2,,data_stack + 1024 //not sure. Stores the address of the top of the parameter stack
	defvar "BASE",4,,BASE,10

.macro defconst name, namelen, flags=0, label, value
    defcode \name, \namelen, \flags, \label
    mov x0, \value     // 将常量值加载到 x0
    PUSHDS x0
    NEXT             
.endm

    .set Nola_VERSION,47
    defconst "VERSION",7,,VERSION,Nola_VERSION
	defconst "R0",2,,RZ,return_stack + 1024
	defconst "DOCOL",5,,__DOCOL,DOCOL
	defconst "F_IMMED",7,,__F_IMMED,F_IMMED
	defconst "F_HIDDEN",8,,__F_HIDDEN,F_HIDDEN
	defconst "F_LENMASK",9,,__F_LENMASK,F_LENMASK

    defconst "SYS_EXIT",8,,SYS_EXIT,__NR_exit  //93
	defconst "SYS_OPEN",8,,SYS_OPEN,__NR_open //not found
	defconst "SYS_CLOSE",9,,SYS_CLOSE,__NR_close //57
	defconst "SYS_READ",8,,SYS_READ,__NR_read //63
	defconst "SYS_WRITE",9,,SYS_WRITE,__NR_write //64
	defconst "SYS_CREAT",9,,SYS_CREAT,__NR_creat //not found
	defconst "SYS_BRK",7,,SYS_BRK,__NR_brk //214

    defconst "O_RDONLY",8,,__O_RDONLY,0
	defconst "O_WRONLY",8,,__O_WRONLY,1
	defconst "O_RDWR",6,,__O_RDWR,2
	defconst "O_CREAT",7,,__O_CREAT,0100
	defconst "O_EXCL",6,,__O_EXCL,0200
	defconst "O_TRUNC",7,,__O_TRUNC,01000
	defconst "O_APPEND",8,,__O_APPEND,02000
	defconst "O_NONBLOCK",10,,__O_NONBLOCK,04000

    defcode ">R",2,,TOR
	POPDS x0		// pop parameter stack into x0
	PUSHRSP x0		// push it on to the return stack
	NEXT

    defcode "R>",2,,FROMR
	POPRSP x0		// pop return stack on to %eax
	PUSHDS x0		// and push on to parameter stack
	NEXT

    defcode "RSP@",4,,RSPFETCH
	PUSHDS x29
	NEXT

    defcode "RSP!",4,,RSPSTORE
	POPDS x29
	NEXT

    defcode "RDROP",5,,RDROP
	add x29, x29,  #8		// pop return stack and throw away
	NEXT

    defcode "DSP@", 4, , DSPFETCH
    mov x0, x28         
    PUSHDS x0
    NEXT             

    defcode "DSP!",4,,DSPSTORE
	POPDS x28
	NEXT


    defcode "KEY", 3, , KEY
    bl _KEY
    PUSHDS x0
    NEXT
// system call read into the buffer, then store
_KEY:
    // 检查是否用尽了输入缓冲区
    ldr x1, =currkey
    ldr x2, =bufftop
    ldr x1, [x1]
    ldr x2, [x2]
    cmp x1, x2
    b.ge _READ_INPUT_FROM_STDIN
    
    // 获取下一个键从输入缓冲区
    ldrb w0, [x1], #1
    str x1, =currkey
    ret

_READ_INPUT_FROM_STDIN:
    mov x0, xzr          // 1st param: stdin (file descriptor 0)
    ldr x1, =buffer      // 2nd param: addr of the buffer
    mov x2, BUFFER_SIZE // 3rd param: max length
    sdr x1, [currkey]
    mov x8, __NR_read    // syscall number for read
    svc 0                // Make the syscall
    cbz x0, key2           // If x0 <= 0, then exit
    add x1, x1, x0       // buffer + x0 = bufftop
    str x1, [bufftop]     // Store the new bufftop
    b _KEY

key2:  // Error or end of input: exit the program.
    mov x8, __NR_exit    // syscall number for exit
    svc 0                // Make the syscall

.data
.align 3
currkey:
    .xword buffer          // Current place in input buffer (next character to read).
bufftop:
    .xword buffer          // Last valid data in input buffer + 1.


    defcode "EMIT", 4, , EMIT
    POPDS x0
    bl _EMIT              
    NEXT                
_EMIT:
    mov x1, x0            // 把要输出的字符复制到 x1 寄存器
    ldr x2, =emit_scratch // 加载 emit_scratch 的地址到 x2
    strb w1, [x2]         // 把字符存储到 emit_scratch
    mov x0, #1            // 1st param: stdout (文件描述符 1)
    mov x1, x2            // 2nd param: emit_scratch 的地址
    mov x2, #1            // 3rd param: 输出长度为 1 字节
    mov x8, #__NR_write   // 系统调用号: write
    svc #0                // 触发系统调用
    ret

    .data
    .align 3
emit_scratch:
    .space 1              // EMIT 使用的暂存区


	defcode "WORD", 4, , WORD
    bl _WORD            
    PUSHDS x2
    PUSHDS x0  // 将长度推入栈
    NEXT              
_WORD:
    // 寻找第一个非空格字符，并跳过注释
word1:
    bl _KEY              // 获取下一个字符，返回在 x0 中
    cbz x0, word1           // 如果是空格，继续循环
    cmp w0, #'\\'        // 检查是否为注释开始
    b.eq word3              // 如果是注释，跳转到注释处理部分
    cmp w0, #' '
    b.eq word1
    ldr x2, =word_buffer // 加载 word_buffer 的地址到 x2
word2:
    mov w1, w0           // 将字符复制到 x1
    strb w1, [x2], #1    // 将字符存储到 word_buffer 并更新地址
    bl _KEY              // 获取下一个字符
    cmp w0, #' '         // 检查是否为空格
    b.ne 2b              // 如果不是空格，继续存储字符
    // 返回单词和长度
    sub x0, x2, #word_buffer // 计算长度
    ldr x2, =word_buffer
    ret
// 跳过注释
word3:
    bl _KEY              // 获取下一个字符
    cmp w0, #'\n'        // 检查是否为换行符
    b.ne word3              // 如果不是换行符，继续跳过字符
    b word1                 // 返回到搜索非空格字符的循环

    .data
word_buffer:
    .space 32            

    defcode "NUMBER", 6, , NUMBER
    POPDS x2     // 从栈上 pop 出字符串的长度
    POPDS x5     // 从栈上 pop 出字符串的地址
    bl _NUMBER
    PUSHDS x0  // 将解析的数字推入栈
    PUSHDS x2  // 将未解析字符的数量推入栈
    NEXT               
_NUMBER:
    // 初始化寄存器
    xor x0, x0, x0
    xor x1, x1, x1
    // 检查长度
    cbz x2, number5
    // 获取 BASE
    ldr w3, =var_BASE    // 加载 BASE 的地址
    ldr w3, [w3]        // 加载 BASE 的值

    // 检查是否为负数
    ldrb w1, [x5], #1    // 加载第一个字符
    PUSHDS x0
    cmp w1, #'-'         // 检查是否为负号
    b.ne number2
    // 是负号
    POPDS x0
    PUSHDS x1
    subs x2, x2, #1
    b.ne number1
    POPDS x1
    mov x2, #1           // 设置错误标志
    ret

number1:
    mull x0, x0, x3		//x0 *= BASE
    ldr w1, [x5]
    add x5, x5, #1

number2: 
    sub w1, w1, #'0'    
    cmp w1, #0         
    blt number4  
    cmp w1, #10
    blt number3
    sub w1, w1, #17
    blt number4           
    add w1, w1, #10

number3:	
    cmp w1, w3		// >= BASE?
	b.ge number4
    add x0, x0, x1
    subs x2, x2, #1
    b.ne number1

number4:
    POPDS x1
    cmp x1, #0
    b.eq number5
    neg x0, x0

number5:
    ret


    defcode "FIND", 4, , FIND
    POPDS x2  // 从栈上 pop 出字符串的长度
    POPDS x5     // 从栈上 pop 出字符串的地址
    bl _FIND
    PUSHDS x0  // 将查找到的字典条目地址（或 NULL）推入栈
    NEXT               // 跳转到下一个 Forth 词  

_FIND:
    // 保存 x19 寄存器，因为我们将在字符串比较中使用它
    PUSHDS x19
    // 加载 LATEST 指针，指向字典中最新的单词
    ldr x3, =var_LATEST
    ldr x3, [x3]

find1:  
    cbz x2, find4          // 检查是否为 NULL 指针（链表末尾）
    // 比较长度
    move x0, #0
    ldrb w0, [x3, #8]    // 加载单词的标志+长度字段
    and w0, w0, #(F_HIDDEN|F_LENMASK)
    cmp w0, w2
    b.ne find2

    // 比较字符串
    PUSHDS x2
    PUSHDS x5
    add x19, x3, #9  //pointer, 8bytes; length and flag, 1 bytes    
    
com1: 
    ldrb w11, [x19], #1   // 加载并更新 x19 指向的字符串的下一个字节
    ldrb w12, [x5], #1    // 加载并更新 x5 指向的字符串的下一个字节
    cmp w11, w12           // 比较两个字节
    b.ne find2              // 如果不匹配，跳转到不匹配处理标签
    subs x2, x2, #1      // 减少长度并检查是否为零
    b.ne com1                 // 如果不为零，继续比较
    POPDS x5
    POPDS x2

find2:  
    POPDS x5
    POPDS x2
    ldr x3, [x3]    //load the pointer form the word header
	b find1		

find4:	
    // Not found.
    POPDS x19
    mov x0, #0
    ret


    defcode ">CFA",4,,TCFA
    POPDS x5
	bl _TCFA
    PUSHDS x5
	NEXT
_TCFA:
    mov x0, x0
    add x5, x5, #8      // Skip link pointer.
    ldrb x0, [x5]       // Load flags+len into %al.
	add x5, x5, #1		// Skip flags+len byte.
    and w0, w0, #F_LENMASK  // Just the length, not the flags.
    add x5, x5, x0      // Skip the name.
    add x5, x5, #7      
    and x5, x5, #~7     // The codeword is -byte aligned.
	ret


    defword ">DFA", 4, , TDFA
    .xword TCFA    // >CFA 
    .xword INCR4   // 8+ 
    .xword EXIT    // EXIT

    defcode "CREATE",6,,CREATE

	// Get the name length and address.
	POPDS x2		// %ecx = length
	POPDS x1		// %ebx = address of name

	// Link pointer.
    ldr x5, =var_HERE
    ldr x0, =var_LATEST
    ldr x5, [x5]
    ldr x0, [x0]
    str x5, [x0]
    add x5, x5, #8

	// Length byte and the word itself.
	mov %cl,%al		// Get the length.
	stosb			// Store the length/flags byte.
	push %esi
	mov %ebx,%esi		// %esi = word
	rep movsb		// Copy the word
	pop %esi
	addl $3,%edi		// Align to next 4 byte boundary.
	andl $~3,%edi
  
	// Update LATEST and HERE.
	movl var_HERE,%eax
	movl %eax,var_LATEST
	movl %edi,var_HERE
	NEXT


