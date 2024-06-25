.386
dat segment use16
adr_packlog dd 0
  dw 1, buff, dat
adr_FAT dd 0
adr_RD dd 0
adr_FCLAST dd 0
сluster_size db 0
disk_letter db 2, 3 dup(?), 0Ah, 0Dh, '$'
DIR_buff db 8, 11 dup(20h), 0Ah, 0Dh, '$'
buff db 512 dup(?)
buff_FAT db 512 dup(?)
msg_enter_disk db 'Pleas enter the logical disk letter:', 0Ah, 0Dh, '$'
msg_enter_DIR db 'Pleas enter the short DIR name:', 0Ah, 0Dh, '$'
dat ends
lab segment use16
Assume ds:dat, cs:lab
   init_memseg: mov bx, dat
        mov ds, bx
        mov bx, dat
        mov es, bx
;##########################################
      init_path: lea dx, msg_enter_disk 
         call def_msg
         lea dx, disk_letter ; ввод буквы
         mov ah, 0Ah
         int 21h
         lea dx, msg_enter_DIR 
         call def_msg
         lea dx, DIR_buff ; ввод имени каталога
         mov ah, 0Ah
         int 21h
;##########################################
        init_log_disk: call switch
     jc short fin
;##########################################
         init_FAT_adr: mov eax, 0
      mov ax, word ptr buff+14
       mov dword ptr adr_FAT, eax
 init_RD_adr:    add ax, word ptr buff+22
    add ax, word ptr buff+22
    mov dword ptr adr_RD, eax
       mov dword ptr adr_packlog, eax
 init_FCLAST:  mov ax, word ptr buff+17
    mov dx, 32
    mul dx
    mov bx, 512
    div bx
    mov word ptr adr_FCLAST, ax
    lea si, adr_RD
    lodsd
    add dword ptr adr_FCLAST, eax
 init_CLSIZE:  mov al, buff+0Dh
    mov byte ptr сluster_size, al    
;##########################################
 init_rootDIR:  lea si, adr_RD
    lea di, adr_packlog
    movsd
    call switch
       jc short fin
;##########################################  
    next_page:  mov cx, 19
 init_ownDIR:  lea di, buff
 next_record:  lea si, DIR_buff+2
    cmpsd
    jne short not_match_0
    inc si ; Пофиксить
 next_half:  cmpsd
      je short open_DIR ; Каталог найден
      jne short not_match_1
not_match_0:  add di, 4h  ; смещаемся к следующей записи
 not_match_1:  add di, 18h ; смещаемся к следующей записи
      dec cx
      jne short next_record
      add dword ptr adr_packlog, 1
      call switch
      lea si, adr_packlog
      lea di, adr_FCLAST
      cmpsd
      jne short next_page
;###########################################
  fin:  mov ah, 4ch
         int 21h
;###########################################
 open_DIR:  mov ax, word ptr ds:[di+12h] ; номер кластера каталога
    sub ax, 2
    lea si, adr_FCLAST
    lea di, adr_packlog
    movsd
; Считаем сектора до нашего каталога
    mov bx, 0
    mov bl, byte ptr сluster_size
    mul bx
; Складываем с адресом первого кластера
    add word ptr adr_packlog, ax
    add word ptr adr_packlog, dx
    mov eax, dword ptr adr_packlog
    push eax 
;############################################
    call switch
    lea si, adr_FAT
    lea ax, buff_FAT
    call switch_buff
    call switch    
; Считаем размер каталога #############################
   init_clust_calc: mov cx, 0
      mov bl, сluster_size
      mov bh, 0
      push bx 
      push cx ; сохраняем в стек счетчик кол-ва кластеров
      mov eax, dword ptr adr_FAT
      push eax
      mov bx, word ptr buff+1Ah
      lea si, buff_FAT
      shl bx, 1 
      mov bp, bx
      ;add bp, si
      cmp bp, 200h
      jb short clust_count 
     je short clust_count
     add dword ptr adr_packlog, 1
     call switch
       clust_count: cmp word ptr ds:[bx+si+0h], 0FFFFh
          je short init_check_rec
; Каталог не закончился ###############################
          pop eax
          pop cx
          inc cx
          push cx
          push eax
          inc si
          inc si
          jmp short clust_count
; Ищем файлы в кластере ###############################
    init_check_rec:  pop eax
       mov dword ptr adr_FAT, eax 
       mov dword ptr adr_packlog, eax 
       call switch
       mov bx, 0
       push bx ; смещение для FAT
       lea si, buff+40h
  chek_del:  cmp byte ptr ds:[si], 0E5h
     je short chek_file_0 
     add si, 20h
     jmp short last_adr              chek_file_0:  cmp byte ptr ds:[si+0bh], 0fh
    jne short chek_file_1
    add si, 20h
    jmp short last_adr
; Проверяем на подкаталлог 
       chek_file_1: test byte ptr ds:[si+0bh], 00010000b
    jz short chek_file_2_0
    add si, 20h
    jmp short last_adr
; Проверяем что файл удален мягко        
 chek_file_2_0:   lea di, buff_FAT
      mov bx, word ptr ds:[si+1Ah] 
     cmp bx, 0
     jne short chek_file_2_2
     add si, 20h
     jmp short last_adr
chek_file_2_2: shl bx, 1 
     pop ax 
     sub bx, ax
     push ax 
     cmp bx, 200h
     jb short chek_file_2_1
     je short chek_file_2_1 
     pop ax 
     add ax, bx 
     push ax 
     add dword ptr adr_FAT, 1
     lea si, adr_FAT
    lea ax, buff_FAT
    call switch_buff
    call switch
    jmp short chek_file_2_0 ; возвращаемся к проверке файла
 chek_file_2_1: cmp word ptr ds:[bx+di+0h], 0h
     je short last_adr
    mov byte ptr ds:[si], 40h
 last_adr:  lea ax, buff+1E0h
    cmp si, ax 
    jna short chek_del
    pop bp 
    pop cx 
    pop bx 
    dec bx 
    jz short last_clust
; записываем на диск сектор из буфера
    pop eax 
    mov dword ptr adr_packlog, eax
    lea dx, buff 
    mov word ptr adr_packlog+6, dx 
    push eax
    push bx
    push cx
    push bp
    call write
    pop bp
    pop cx
    pop bx
; Смещаемся в следующий сектор
    pop eax 
    inc eax 
    mov dword ptr adr_packlog, eax 
    push eax ; сохраняем в стек новый адрес
    lea ax, buff
    mov word ptr adr_packlog+6, ax 
    push bx ; отправляем оставшееся кол-во обратно в стек
    push cx 
    push bp 
    call switch ; загружаем следующий сектор
    lea si, buff
    jmp chek_del
last_clust:   cmp cx, 0
    je fin ; если каталог закончился
    dec cx
    pop bx 
    mov bl, byte ptr сluster_size
    pop eax
    inc eax
    mov dword ptr adr_packlog, eax
    push eax
    push bx ; сохраняем в стек кол-во секторов в кластере
    push bp 
    lea ax, buff
    mov word ptr adr_packlog+6, ax
    call switch
    lea si, buff
     jmp chek_del ; если каталог не закончился

   switch proc
       mov al, disk_letter+2
     sub al, 41h
     mov cx, 0FFFFh
     mov dx, 0h
     lea bx, dword ptr adr_packlog
     int 25h
     pop ax
       RET
   switch endp
   switch_buff proc
    lea di, adr_packlog
    movsd
    mov word ptr adr_packlog+6, ax
       RET
   switch_buff endp
   write proc
       mov al, disk_letter+2
       sub al, 41h
       mov cx, 0FFFFh
       mov dx, 0h
       lea bx, dword ptr adr_packlog
       int 26h
       pop ax
       RET
   write endp
   def_msg proc
    mov ah, 9h
    int 21h
    RET
 def_msg endp         
lab ends
 End init_memseg
